// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../contracts/oracle/PriceOracle.sol";
import "../contracts/oracle/PriceOracleManager.sol";
import "../contracts/VaultManager.sol";
import "../contracts/governance/GovernanceAction.sol";

// To run in testnet only
contract FixPriceOracle is Script {
    bytes32 reserve_WBTC = keccak256("WBTC");
    bytes32 reserve_CBTC = keccak256("CBTC");

    address PRICE_RELAYER = 0xD3a4079989d39A2994D471650f68E3ec6094c003;
    
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    address skybitCreate3Factory = 0xA8D5D2166B1FB90F70DF5Cc70EA7a1087bCF1750;
    address wBTC = 0xF859eF009E632C7df37a73D5827A84FF0B43aDe6;
    address cBTC = 0x538a7C3b36315554DDa6B1f8321c2e50fd95a271;
    
    address priceOracle;
    address governanceTimelockController = 0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46;
    address emergencyTimelockController = 0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F;
    address vaultManager = 0x6aA52f8b0bDf627f59E635dA95c735232881c93b;
    address priceOracleManager = 0xcfE44C253C9b37FDD54d36C600D33Cbf3edfA5B7;
    address tabRegistry = 0x5B2949601CDD3721FF11bF55419F427c9C118e2c;

    address config = 0x1a13d6a511A9551eC1A493C26362836e80aC4d65;
    address reserveRegistry = 0x2A4Dc0e2Ff4210ec81b14eC97CE3fB755824B0C7;
    address vaultKeeper = 0xd67937ca4d249a4caC262B18c3cCB747042Dd51B;
    
    address governanceAction = 0x7375C23a3815455D673c7366C2102e3685537B20;
    address shiftCtrlGovernor = 0xf6dD022b6404454fe75Bc0276A8E98DEF9D0Fb03;
    address shiftCtrlEmergencyGovernor = 0xF9C8F1ECc0e701204616033f1d52Ff30B83009bB;

    function run() external {
        vm.startBroadcast(deployer);

        // deploy updated PriceOracle
        priceOracle = address(new PriceOracle(governanceTimelockController, emergencyTimelockController, vaultManager, priceOracleManager, tabRegistry, PRICE_RELAYER));
        console.log("PriceOracle: ", priceOracle);
        PriceOracleManager(priceOracleManager).setPriceOracle(priceOracle);
        VaultManager(vaultManager).configContractAddress(
            config, reserveRegistry, tabRegistry, priceOracle, vaultKeeper
        ); 

        // governanceAction create new tab and setPeggedTab
        // proposeGovernanceAction();

        // execGovernanceAction();

        vm.stopBroadcast();
    }

    function proposeGovernanceAction() internal {
        address[] memory targets = new address[](2);
        targets[0] = governanceAction;
        targets[1] = governanceAction;
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeCall(GovernanceAction.createNewTab, (bytes3(abi.encodePacked("PSO"))));
        calldatas[1] = abi.encodeCall(GovernanceAction.setPeggedTab, (bytes3(abi.encodePacked("PSO")), bytes3(abi.encodePacked("USD")), 100));
        IGovernor(shiftCtrlEmergencyGovernor).propose(targets, values, calldatas, "testnet-peggedTab");
    }

    function execGovernanceAction() internal {
        address[] memory targets = new address[](2);
        targets[0] = governanceAction;
        targets[1] = governanceAction;
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeCall(GovernanceAction.createNewTab, (bytes3(abi.encodePacked("PSO"))));
        calldatas[1] = abi.encodeCall(GovernanceAction.setPeggedTab, (bytes3(abi.encodePacked("PSO")), bytes3(abi.encodePacked("USD")), 100));
        bytes32 description = keccak256(bytes("testnet-peggedTab"));
        IGovernor(shiftCtrlEmergencyGovernor).execute(targets, values, calldatas, description);
    }

}