    // SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PriceConverter} from "./lib/PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ShareLogic} from "./CoreLibs/ShareLogic.sol";
import {dateTimeWrapper} from "./CoreLibs/dateTimeWrapper.sol";

contract PredictEM is ShareLogic, dateTimeWrapper {
    error Insufficient_shares();
    error PredictEM__NotOwner();
    error PredictEM__MarketClosed();

    IERC20 public immutable USDC;
    address private immutable i_owner;
    AggregatorV3Interface public s_priceFeed;

    bool public locked;
    uint8 private constant buyID = 1;
    uint8 private constant sellID = 2;
    uint16 public marketID;
    mapping(uint16 => mapping(uint256 price => uint8 _winningSide)) public cycle;

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != i_owner) revert PredictEM__NotOwner();
        _;
    }

    modifier marketState(uint16 _id) {
        if (block.timestamp >= IDToData[_id].closingTimestamp) revert PredictEM__MarketClosed();
        _;
    }

    constructor(address _usdc, address priceFeed) {
        s_priceFeed = AggregatorV3Interface(priceFeed);
        USDC = IERC20(_usdc);
        i_owner = msg.sender;
    }

    function startMarket() public onlyOwner returns (bool marketCreated) {
        // uint256 day = DateTimeLib.weekday(openingTimestamp);
        // if (day != 1) {
        //     revert();
        // }
        require(!isClosed(marketID), "marketExists!");
        marketID++;
        CycleData storage data = IDToData[marketID];

        data.openingTimestamp = block.timestamp;
        data.openingPrice = getPrice();
        data.closingTimestamp = block.timestamp + 6 days + 21 hours;

        cycle[marketID][data.openingPrice] = 0; // winning side is set to 0, the contract will change it to 1/2 later on depending on the winning side

        marketCreated = createMarket();
        return marketCreated;
    }

    function quickBuy(uint256 shareAmountToBuy, uint8 _side) public marketState(marketID) returns (uint256 tokensIn) {
        uint256 supply = totalSupply[_side];
        tokensIn = getPriceOut(supply, shareAmountToBuy);
        USDC.transferFrom(msg.sender, address(this), tokensIn);
        _mint(msg.sender, _side, shareAmountToBuy);

        marketMake(_side, shareAmountToBuy, buyID);
        return tokensIn;
    }

    function quickSell(uint256 shareAmountToSell, uint8 _side)
        public
        marketState(marketID)
        returns (uint256 tokensOut)
    {
        uint256 supply = totalSupply[_side];
        tokensOut = getPriceOut(supply - shareAmountToSell, shareAmountToSell);
        USDC.transfer(msg.sender, tokensOut);
        _burn(msg.sender, _side, shareAmountToSell);
        marketMake(_side, shareAmountToSell, sellID);

        return tokensOut;
    }

    function buy(uint256 USDAmountIn, uint256 shareAmountOut, uint8 _side)
        public
        marketState(marketID)
        returns (uint256 tokensIn)
    {
        uint256 supply = totalSupply[_side];
        tokensIn = getPriceOut(supply, shareAmountOut);

        // Transfer the user's funds to the contract
        USDC.transferFrom(msg.sender, address(this), USDAmountIn);

        _mint(msg.sender, _side, shareAmountOut);

        marketMake(_side, shareAmountOut, buyID);
        return tokensIn;
    }

    function sell(uint256 shareAmountIn, uint256 USDAmountOut, uint8 _side)
        public
        marketState(marketID)
        returns (uint256 tokensOut)
    {
        uint256 supply = totalSupply[_side];
        //tokensOut = getPriceOut(supply - shareAmountIn, shareAmountIn) / 10**15;
        tokensOut = getPriceOut(supply - shareAmountIn, shareAmountIn);
        require(USDAmountOut <= tokensOut, "Insufficient tokens");
        // tokensOut = tokensOut / 1000 * 1000; // Round down to the nearest integer and zero out the last three digits
        // Transfer the user's tokens to the contract
        // ...
        USDC.transfer(msg.sender, tokensOut);
        _burn(msg.sender, _side, shareAmountIn);
        // Transfer the USDC.e to the user
        marketMake(_side, shareAmountIn, sellID);

        return tokensOut;
    }

    function getContractUSDCBalance() public view returns (uint256 balance) {
        balance = USDC.balanceOf(address(this));
    }

    function getContractAnyTokenBalance(address _token) public view returns (uint256 balance) {
        IERC20 token = IERC20(_token);
        balance = token.balanceOf(address(this));
    }

    function withdraw() public onlyOwner {
        uint256 balance = getContractUSDCBalance();
        if (balance > 0) {
            USDC.transfer(msg.sender, balance);
        } else {
            revert();
        }
    }

    function withdrawAnyToken(address _token) public onlyOwner {
        IERC20 token = IERC20(_token);

        uint256 balance = getContractAnyTokenBalance(_token);
        if (balance > 0) {
            token.transfer(msg.sender, balance);
        } else {
            revert();
        }
    }

    function getPrice() public view returns (uint256 answer) {
        answer = PriceConverter.getConversionRate(1, s_priceFeed);
    }

    function determineWinner() public {
        CycleData storage data = IDToData[marketID];
        // if (isClosed(marketID)) {
        uint256 winnerPrice = getPrice();
        // uint256 supply;
        // SharesLogic._mint(address(this), 1, 1);
        if (winnerPrice > data.openingPrice) {
            // Side 1 wins
            cycle[marketID][data.openingPrice] = 1;
            // _burn(supply, 2, supply);
        } else {
            // Side 2 wins
            cycle[marketID][data.openingPrice] = 2;

            // _burn(supply, 1, supply);
            // }
        }
        data.ClosingPrice = winnerPrice;
    }

    function withdrawWinnings(uint16 _marketId, uint8 _side) public {
        // require(isClosed(_side), "Market is not closed");
        // require(locked, "Winner not determined");
        CycleData memory data = IDToData[marketID];
        uint8 winSide = cycle[_marketId][data.openingPrice];
        if (winSide != _side) {
            revert();
        }

        uint256 userBalance = balanceOf[msg.sender][_side];
        if (userBalance < 1) {
            revert Insufficient_shares();
        }
        uint256 totalBalance = USDC.balanceOf(address(this));
        uint256 winningAmount = (totalBalance * userBalance) / totalSupplyMinusMM(_side);

        USDC.transfer(msg.sender, winningAmount);
    }
}
