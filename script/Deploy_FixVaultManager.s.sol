// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import "../contracts/VaultManager.sol";

// To run in testnet only
contract FixVaultManager is Script {    
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
   
    address tabProxyAdmin = 0xE546f1d0671D79319C71edC1B42089f913bc9971;
    address governanceTimelockController = 0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46;
    address emergencyTimelockController = 0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F;
    address shiftCtrlEmergencyGovernor = 0xF9C8F1ECc0e701204616033f1d52Ff30B83009bB;
    address vaultManager = 0x6aA52f8b0bDf627f59E635dA95c735232881c93b;

    function run() external {
        vm.startBroadcast(deployer);

        // upgrade vaultmanager
        address updVaultManager = address(new VaultManager());
        console.log("VaultManager Impl; ", updVaultManager);
        
        address[] memory targets = new address[](1);
        targets[0] = tabProxyAdmin;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("upgrade(address,address)", vaultManager, updVaultManager);
        IGovernor(shiftCtrlEmergencyGovernor).propose(targets, values, calldatas, "testnet-upgradeVaultManagerD1507");

        vm.stopBroadcast();
    }

}