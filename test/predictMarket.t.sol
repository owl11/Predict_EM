// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DeployPredictEM, PredictEM} from "../script/DeployPredictEM.s.sol";
import {mockUSDC} from "../src/mockUSDC.sol";
import {HelperConfig, MockV3Aggregator, ERC20Mock} from "../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract predictEMTest is StdCheats, Test {
    PredictEM public predictEM;
    mockUSDC public mUSDC;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;
    uint256 public constant USDC_DECIMALS = 1e6;
    uint256 public constant STARTING_USER_BALANCE = 1000 ether * 10 ** 6;
    address public user = address(69);

    function setUp() public {
        DeployPredictEM deployer = new DeployPredictEM();
        (predictEM, mUSDC, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        if (block.chainid == 31_337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }
        mockUSDC(mUSDC).mint(user, STARTING_USER_BALANCE);
    }

    function test_marketCreated() public {
        vm.startBroadcast(deployerKey);
        bool state = predictEM.startMarket();
        vm.stopBroadcast();
        assertEq(state, true);
    }

    function test_Fail_marketCreateUser() public {
        vm.startPrank(user);
        vm.expectRevert(PredictEM.PredictEM__NotOwner.selector);
        predictEM.startMarket();
        vm.stopPrank();
    }

    modifier marketCreated() {
        vm.startBroadcast(deployerKey);
        predictEM.startMarket();
        vm.stopBroadcast();
        _;
    }

    modifier marketCreatedAndSharesBoughtUp() {
        vm.startBroadcast(deployerKey);
        predictEM.startMarket();
        vm.stopBroadcast();
        vm.startPrank(user);
        mUSDC.approve(address(predictEM), 100000000000000000000000);
        predictEM.quickBuy(20000, 1);
        vm.stopPrank();
        _;
    }

    modifier marketCreatedAndSharesBoughtDown() {
        vm.startBroadcast(deployerKey);
        predictEM.startMarket();
        vm.stopBroadcast();
        vm.startPrank(user);
        mUSDC.approve(address(predictEM), 100000000000000000000000);
        predictEM.quickBuy(100000, 2);
        vm.stopPrank();
        _;
    }

    function testBuyUpSharesUp() public marketCreatedAndSharesBoughtDown {
        console.log(predictEM.getPricePerSide(1, 1));
        console.log(predictEM.getPricePerSide(2, 1));
        vm.startPrank(user);
        mUSDC.approve(address(predictEM), 100000000000000000000000);
        predictEM.quickBuy(1000, 1);
        vm.stopPrank();
    }

    function testBuyUpSharesDown() public marketCreatedAndSharesBoughtUp {
        vm.startPrank(user);
        mUSDC.approve(address(predictEM), 100000000000000000000000);
        predictEM.quickBuy(1, 2);
        vm.stopPrank();
    }

    function testSellUpShares() public marketCreatedAndSharesBoughtUp {
        vm.startPrank(user);
        predictEM.quickSell(1000, 1);
        vm.stopPrank();
    }

    function testBuyAlotOfShares() public marketCreated {
        vm.startPrank(user);
        mUSDC.approve(address(predictEM), 100000000000000000000000);
        predictEM.quickBuy(1001, 1);
        predictEM.quickBuy(110000, 1);

        predictEM.quickBuy(50000, 2);
        predictEM.quickBuy(50000, 2);
        predictEM.quickBuy(110000, 1);
        predictEM.quickBuy(50000, 2);
        predictEM.quickBuy(110000, 1);

        predictEM.quickSell(110000, 1);
        predictEM.quickSell(110000, 1);
        predictEM.quickSell(110000, 1);
        predictEM.quickBuy(50000, 2);
        predictEM.quickSell(50000, 2);
        predictEM.quickSell(50000, 2);
        predictEM.quickSell(50000, 2);
        predictEM.quickSell(50000, 2);
        vm.stopPrank();
    }

    function testBuyAlotOfShares_2() public marketCreated {
        vm.startPrank(user);

        mUSDC.approve(address(predictEM), 100000000000000000000000);
        predictEM.quickBuy(1001, 1); //1
        predictEM.quickBuy(110000, 1); //2
        predictEM.quickBuy(50000, 2); //3
        predictEM.quickBuy(50000, 2); //4
        predictEM.quickBuy(110000, 1); //5
        predictEM.quickBuy(50000, 2); //6
        predictEM.quickBuy(110000, 1); //7
        predictEM.getbalanceOf(user, 1);
        predictEM.quickSell(330000, 1);

        predictEM.quickBuy(50000, 2);
        predictEM.quickSell(200000, 2);
        predictEM.quickSell(1000, 1);

        predictEM.quickBuy(50000, 2);
        predictEM.quickBuy(200000, 1);
        predictEM.quickSell(5000, 1);
        predictEM.quickBuy(200000, 1);
        predictEM.quickSell(45000, 1);
        predictEM.quickSell(350000, 1);

        predictEM.quickSell(50000, 2);
        predictEM.quickBuy(500, 2);
        predictEM.quickBuy(500, 1);
        console.log(
            predictEM.getbalanceOf(address(predictEM), 1),
            predictEM.getbalanceOf(address(predictEM), 2),
            predictEM.totalSupplyMinusMM(1),
            predictEM.totalSupplyMinusMM(2)
        );

        console.log(predictEM.getContractUSDCBalance());
        console.log(predictEM.getPricePerSide(1, 1));

        console.log(predictEM.getPricePerSide(2, 1));
        vm.stopPrank();
    }

    // function testParity() public marketCreated {
    //     vm.startPrank(user);
    //     mUSDC.approve(address(predictEM), 100000000000000000000000);
    //     predictEM.quickBuy(50000, 2);
    //     predictEM.quickBuy(200000, 1);
    //     uint256 balance_1 = predictEM.totalSupplyMinusMM(1);
    //     uint256 balance_2 = predictEM.totalSupplyMinusMM(2);
    //     uint256 parity;
    //     if (balance_1 > balance_2) {
    //         parity = balance_1 / balance_2;
    //     } else {
    //         parity = balance_2 / balance_1;
    //     }

    //     uint256 Parity = predictEM.totalSupplyMinusMM(1) + predictEM.totalSupplyMinusMM(2);
    //     // console.log("parity between Useralance and MMBalance:", mmParity, Parity);
    // }

    function testSellDownShares() public marketCreatedAndSharesBoughtDown {
        vm.startPrank(user);
        predictEM.quickSell(100000, 2);
        vm.stopPrank();
        uint256 priceSide_1 = predictEM.getPricePerSide(1, 1);
        uint256 priceSide_2 = predictEM.getPricePerSide(2, 1);
        console.log("combiend price is:", priceSide_1 + priceSide_2);
        console.log(predictEM.getTotalSupply(1));
        console.log(predictEM.getTotalSupply(2));
    }
}
