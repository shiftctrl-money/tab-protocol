// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/Config.sol";
import "../contracts/AuctionManager.sol";

// To run in testnet only
contract FixAuctionManager is Script {    
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
   
    address governanceTimelockController = 0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46;
    address emergencyTimelockController = 0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F;
    address vaultManager = 0x6aA52f8b0bDf627f59E635dA95c735232881c93b;
    address reserveRegistry = 0x2A4Dc0e2Ff4210ec81b14eC97CE3fB755824B0C7;
    address config = 0x1a13d6a511A9551eC1A493C26362836e80aC4d65;

    function run() external {
        vm.startBroadcast(deployer);

        // AuctionManager - re-deploy
        address auctionManager = address(new AuctionManager(governanceTimelockController, emergencyTimelockController, vaultManager, reserveRegistry));
        console.log("AuctionManager: ", auctionManager);
        Config(config).setAuctionParams(90, 97, 60, auctionManager);

        vm.stopBroadcast();
    }

}