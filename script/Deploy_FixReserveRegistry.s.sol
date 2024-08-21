// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../contracts/Config.sol";
import "../contracts/ReserveRegistry.sol";
import "../contracts/AuctionManager.sol";
import "../contracts/ReserveSafe.sol";
import "../contracts/VaultManager.sol";
import "../contracts/VaultUtils.sol";
import "../contracts/TabProxyAdmin.sol";
import "../contracts/ProtocolVault.sol";

// To run in testnet only
contract FixReserveRegistry is Script {
    bytes32 reserve_WBTC = keccak256("WBTC");
    bytes32 reserve_CBTC = keccak256("CBTC");
    
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    address skybitCreate3Factory = 0xA8D5D2166B1FB90F70DF5Cc70EA7a1087bCF1750;
    address wBTC = 0xF859eF009E632C7df37a73D5827A84FF0B43aDe6;
    address cBTC = 0x538a7C3b36315554DDa6B1f8321c2e50fd95a271;
    
    address tabProxyAdmin = 0xE546f1d0671D79319C71edC1B42089f913bc9971;
    address tabRegistry = 0x5B2949601CDD3721FF11bF55419F427c9C118e2c;
    address priceOracle = 0x4a6D701F5CD7605be2eC9EA1D945f07D8DdbD1f0;
    address priceOracleManager = 0xcfE44C253C9b37FDD54d36C600D33Cbf3edfA5B7;
    address vaultKeeper = 0xd67937ca4d249a4caC262B18c3cCB747042Dd51B;
    address shiftCtrlGovernor = 0xf6dD022b6404454fe75Bc0276A8E98DEF9D0Fb03;
    address shiftCtrlEmergencyGovernor = 0xF9C8F1ECc0e701204616033f1d52Ff30B83009bB;
    address governanceTimelockController = 0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46;
    address emergencyTimelockController = 0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F;
    address governanceAction = 0x7375C23a3815455D673c7366C2102e3685537B20;
    address protocolVault = 0x67E332459A81F3d64142829541b6fec608356B63;
    
    address vaultManager = 0x6aA52f8b0bDf627f59E635dA95c735232881c93b;
    address config = 0x1a13d6a511A9551eC1A493C26362836e80aC4d65;
    address vaultUtils = 0xd84E8dfD237D4c8ab47B2291441b1d4826EBDf01;
    address reserveRegistry;
    address reserveSafeCBTC = 0x9120c1Cb0c5eBa7946865E1EEa2C584f2865821C;
    address reserveSafeWBTC = 0xEc0e4922F4427b06475A5fd3ec729467BbaB8de3;

    function run() external {
        vm.startBroadcast(deployer);

        // reserve registry
        reserveRegistry = address(new ReserveRegistry(governanceTimelockController, emergencyTimelockController, governanceAction, deployer));
        console.log("ReserveRegistry: ", reserveRegistry);
        // ReserveRegistry(reserveRegistry).addReserve(reserve_WBTC, cBTC, reserveSafeCBTC);
        // ReserveRegistry(reserveRegistry).addReserve(reserve_CBTC, wBTC, reserveSafeWBTC);
        ReserveRegistry(reserveRegistry).addReserve(reserve_WBTC, wBTC, reserveSafeWBTC);
        ReserveRegistry(reserveRegistry).addReserve(reserve_CBTC, cBTC, reserveSafeCBTC);
        
        VaultUtils(vaultUtils).setContractAddress(vaultManager, reserveRegistry, config);
        VaultManager(vaultManager).configContractAddress(
            config, reserveRegistry, tabRegistry, priceOracle, vaultKeeper
        ); 
        
        // governanceAction update reserveRegistry address
        proposeGovernanceActionChangeAddr();

        // AuctionManager - re-deploy
        address auctionManager = address(new AuctionManager(governanceTimelockController, emergencyTimelockController, vaultManager, reserveRegistry));
        console.log("AuctionManager: ", auctionManager);
        Config(config).setAuctionParams(90, 97, 60, auctionManager);

        // upgrade vaultmanager
        address updVaultManager = address(new VaultManager());
        console.log("VaultManager Impl; ", updVaultManager);
        proposeUpgradeVaultManager(updVaultManager);

        // upgrade protocol vault
        address updProtocolVault = address(new ProtocolVault());
        console.log("Protocol Vault Impl: ", updProtocolVault);
        proposeUpgradeProtocolVault(updProtocolVault);

        vm.stopBroadcast();
    }

    function proposeGovernanceActionChangeAddr() internal {
        address[] memory targets = new address[](1);
        targets[0] = governanceAction;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setContractAddress(address,address,address,address)", config, tabRegistry, reserveRegistry, priceOracleManager);
        IGovernor(shiftCtrlEmergencyGovernor).propose(targets, values, calldatas, "testnet-updateReserveRegistry");
    }

    function proposeUpgradeVaultManager(address newImplAddr) internal {
        address[] memory targets = new address[](1);
        targets[0] = tabProxyAdmin;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("upgrade(address,address)", vaultManager, newImplAddr);
        IGovernor(shiftCtrlEmergencyGovernor).propose(targets, values, calldatas, "testnet-upgradeVaultManager");
    }

    function proposeUpgradeProtocolVault(address newImplAddr) internal {
        address[] memory targets = new address[](1);
        targets[0] = tabProxyAdmin;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("upgrade(address,address)", protocolVault, newImplAddr);
        IGovernor(shiftCtrlEmergencyGovernor).propose(targets, values, calldatas, "testnet-upgradeProtocolVault");

        targets[0] = protocolVault;
        calldatas[0] = abi.encodeWithSignature("updateReserveRegistry(address)", reserveRegistry);
        IGovernor(shiftCtrlGovernor).propose(targets, values, calldatas, "testnet-updateReserveRegistry");
    }

}