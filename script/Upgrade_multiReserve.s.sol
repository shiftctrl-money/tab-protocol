// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {CTRL} from "../contracts/token/CTRL.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {PriceOracle} from "../contracts/oracle/PriceOracle.sol";
import {PriceOracleManager} from "../contracts/oracle/PriceOracleManager.sol";
import {ReserveRegistry} from "../contracts/reserve/ReserveRegistry.sol";
import {VaultManager} from "../contracts/core/VaultManager.sol";
import {ITransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/*
 * @notice Refer https://github.com/shiftctrl-money/tab-oracle/issues/2
 * PriceOracle contract is upgraded to support multiple reserves. For example, 
 * cbBTC/sUSD, WBTC/sUSD prices are updated in the same contract.
 * 
 * Testnet: 
  Upgrade is started on testnet id  84532
  priceOracle:  0x61AC8eaf1880a9E85Af3C34c0d62588eACD1CB76
  vaultManager(impl):  0x9F362f149B161B1b8Df3bF02a8ef94E2168A1f50
  Proposal created with ID:  46361081338096919900597981395997329650918010701155622056562850297782656932225

 * Mainnet:
  Upgrade is started on chain id 8453 BASE mainnet...
  priceOracle:  0x0eB8De03B9398Ac043218BAFd6Fce15950fAA8Cf
  vaultManager(impl):  0x908AaB3701eb069366C17Eb9a58cbaFDBAAAcabb
  Proposal created with ID:  79189382921291531791938112866080452889452389687662959478184891151960607611580 
  
 */
contract Upgrade_multiReserve is Script {

    address owner;

    PriceOracle priceOracle;
    PriceOracleManager priceOracleManager;
    ReserveRegistry reserveRegistry;
    VaultManager vaultManager;
    ProxyAdmin tabProxyAdmin;
    CTRL ctrl;

    address shiftCtrlGovernor;
    address governance;
    address emergencyGov;
    address vaultManagerAddr;
    address priceOracleManagerAddr;
    address tabRegistry;
    address oracleRelayerSignerAddr;
    address reserveRegistryAddr;
    address tabProxyAdminAddr;
    address config;
    address vaultKeeper;

    function run() external {
        if (block.chainid == 8453)
            owner = 0x553A9FB9B5590EE27d8ddc589005afca99D51aa3; // mainnet
        else 
            owner = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56; // testnet
        
        vm.startBroadcast(owner);

        if (block.chainid == 8453) { // Base mainnet
            console.log("Upgrade is started on chain id 8453 BASE mainnet...");
            ctrl = CTRL(0x505568c65fF95E5e97Ca97B476BEb0db64F91499);
            shiftCtrlGovernor = 0x747E429c1ceb8b0FB576650BEd6623785eAb0348;
            governance = 0x75977C03b7AFc9B0E645A6402B2b46E438F146D5;
            emergencyGov = 0x4bedAa52B64A4b8aff01a5354516c2897ecEf58B;
            vaultManagerAddr = 0x11138452B689fd55d5Ad3991A6166dbBb6C2A774;
            priceOracleManagerAddr = 0x5f6c5A786a1Aa89d3B18606f93Dc6bfA011a2fBC;
            tabRegistry = 0x01D988944c3Bb067f56e600619345C3dB161f444;
            oracleRelayerSignerAddr = 0x7A50C47A1594318dfBFFA26F56c2B47E0d4e113b;
            reserveRegistryAddr = 0xb59B6ba5426255B669C3966261aC4b2D59A76943;
            tabProxyAdminAddr = 0x65FB1EF0f9C15b2653421D9008fd7E55889890E2;
            config = 0xC81455d98AD16db5043c775bD1eCd2677E39e670;
            vaultKeeper = 0xBbFD14d040b7E3b3cC3eef52DCB1E84Cb3E397C5;

            // ctrl.mint(owner, 10000e18); // 10K to propose
            // ctrl.delegate(owner);

        } else { // testnet 84532
            console.log("Upgrade is started on testnet id ", block.chainid);
            ctrl = CTRL(0x193410b8cdeD8F4D63E43D0f2AeD99bd862ed1Bc);
            shiftCtrlGovernor = 0x89E7068cf18F22765D1F2902d1BaB8C839B8d013;
            governance = 0x783bDAF73E8F40672421204d6FF3f448767d72c6;
            emergencyGov = 0x997275213b66AEAAb4042dF9457F2913969368f2;
            vaultManagerAddr = 0xeAf6aB024D4a7192322090Fea1C402a5555cD107;
            priceOracleManagerAddr = 0xBdFd9503f62A23092504eD072158092B6B3342ac;
            tabRegistry = 0x9b2F93f5be029Fbb4Cb51491951943f7368b2f1C;
            oracleRelayerSignerAddr = 0x6cC15689B28227d97481Fac73614cD8D35ede6D2;
            reserveRegistryAddr = 0xDA8A64cDFaeb08b3f28b072b0d4aC371953F5B6E;
            tabProxyAdminAddr = 0xF44013D4BE0F452938B0b805Bc5Bf0D3Fbd4102c;
            config = 0x25B9982A32106EeB2Aa052319011De58A7d33457;
            vaultKeeper = 0x303818F385f1675BBB07dDE155987f6b7041753c;

            // ctrl.delegate(owner);
        }

        priceOracle = new PriceOracle(
            governance,                 // Governance action
            emergencyGov,               // Emergency governance action
            vaultManagerAddr,           // Vault manager
            priceOracleManagerAddr,     // Price oracle manager
            tabRegistry,                // Tab registry
            oracleRelayerSignerAddr     // Oracle price signer
        );
        priceOracleManager = PriceOracleManager(priceOracleManagerAddr);
        priceOracleManager.setPriceOracle(address(priceOracle));
        console.log("priceOracle: ", address(priceOracle));

        tabProxyAdmin = ProxyAdmin(tabProxyAdminAddr);
        address[] memory targets = new address[](2);
        targets[0] = tabProxyAdminAddr;
        targets[1] = vaultManagerAddr;

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        
        bytes[] memory calldatas = new bytes[](2);
        // Propose #1: Upgrade VaultManager contract
        vaultManager = new VaultManager();
        console.log("vaultManager(impl): ", address(vaultManager));
        calldatas[0] = abi.encodeWithSelector(
            tabProxyAdmin.upgradeAndCall.selector, 
            ITransparentUpgradeableProxy(vaultManagerAddr), 
            address(vaultManager),
            bytes("")
        );
        // Propose #2: Update vaultManager's priceOracle address
        calldatas[1] = abi.encodeWithSelector(
            vaultManager.configContractAddress.selector,
            config,
            reserveRegistryAddr,
            tabRegistry,
            address(priceOracle),
            vaultKeeper
        );

        // Voting delay = 2 days, Voting period = 3 days, Proposal threshold = 10000
        // Quorum = 5%, 2 days timelock delay
        uint256 proposalId = IGovernor(shiftCtrlGovernor).propose(
            targets, 
            values, 
            calldatas, 
            "multiReserves: update vault manager and price oracle"
        );
        console.log("Proposal created with ID: ", proposalId);

        console.log("Upgrade is completed.");
        vm.stopBroadcast();
    }

}