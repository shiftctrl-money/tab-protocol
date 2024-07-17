// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../contracts/token/WBTC.sol";
import "../contracts/token/CTRL.sol";
import "../contracts/Config.sol";
import "../contracts/ReserveRegistry.sol";
import "../contracts/ReserveSafe.sol";

// To run in testnet only
contract DeployWBTC is Script {
    bytes32 reserve_WBTC = keccak256("WBTC");
    
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    address skybitCreate3Factory = 0xA8D5D2166B1FB90F70DF5Cc70EA7a1087bCF1750;
    address wbtc;
    address ctrl = 0xa2e9A36e4535E1c832A6c54aEA4b9954889342d3;
    address tabProxyAdmin = 0xE546f1d0671D79319C71edC1B42089f913bc9971;
    address governanceTimelockController = 0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46;
    address emergencyTimelockController = 0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F;
    address vaultManager = 0x6aA52f8b0bDf627f59E635dA95c735232881c93b;
    address config = 0x1a13d6a511A9551eC1A493C26362836e80aC4d65;
    address reserveRegistry = 0x666A895b1fcda4272A29d67c40b91a15e469F442;
    address reserveSafe; // for WBTC

    function run() external {
        vm.startBroadcast(deployer);

        wbtc = deployWBTC(governanceTimelockController, emergencyTimelockController, deployer, tabProxyAdmin);
        console.log("WBTC: ", wbtc);

        reserveSafe = address(new ReserveSafe(governanceTimelockController, emergencyTimelockController, vaultManager, wbtc));
        console.log("ReserveSafe (WBTC): ", reserveSafe);
        ReserveRegistry(reserveRegistry).addReserve(reserve_WBTC, wbtc, reserveSafe);
        
        bytes32[] memory reserve = new bytes32[](1);
        reserve[0] = reserve_WBTC;
        uint256[] memory processFeeRate = new uint256[](1);
        processFeeRate[0] = 0;
        uint256[] memory minReserveRatio = new uint256[](1);
        minReserveRatio[0] = 180;
        uint256[] memory liquidationRatio = new uint256[](1);
        liquidationRatio[0] = 120;
        Config(config).setReserveParams(reserve, processFeeRate, minReserveRatio, liquidationRatio);

        WBTC(wbtc).mint(deployer, 1000000e18);
        WBTC(wbtc).mint(0x034d0ee42160Ca411bB2Ef5424Be1dFBEffb8a03, 1000000e18);  // faucet
        CTRL(ctrl).mint(0x034d0ee42160Ca411bB2Ef5424Be1dFBEffb8a03, 10000000e18); // faucet, Required 10000 CTRL to propose in regular governance

        WBTC(wbtc).approve(vaultManager, 1000e18);
        vm.stopBroadcast();
    }

    function deployWBTC(address _governanceTimelockController, address _governanceAction, address _deployer, address _tabProxyAdmin) internal returns(address) {
        address wBTCImplementation = address(new WBTC());
        bytes memory wBtcInitData = abi.encodeWithSignature("initialize(address,address,address)", _governanceTimelockController, _governanceAction, _deployer);
        return (
            address(new TransparentUpgradeableProxy(wBTCImplementation, _tabProxyAdmin, wBtcInitData))
        );
    }
}