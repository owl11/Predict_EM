// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {PredictEM} from "../src/predictEM.sol";
import {mockUSDC} from "../src/mockUSDC.sol";

contract DeployPredictEM is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (PredictEM, mockUSDC, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        mockUSDC mUSDC = new mockUSDC();

        PredictEM predictMarket = new PredictEM(address(mUSDC), address(wethUsdPriceFeed));
        vm.stopBroadcast();
        return (predictMarket, mUSDC, helperConfig);
    }
}
