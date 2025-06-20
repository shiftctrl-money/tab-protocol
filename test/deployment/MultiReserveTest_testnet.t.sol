// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CTRL} from "../../contracts/token/CTRL.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {PriceOracle} from "../../contracts/oracle/PriceOracle.sol";
import {PriceOracleManager} from "../../contracts/oracle/PriceOracleManager.sol";
import {VaultManager} from "../../contracts/core/VaultManager.sol";
import {TabERC20} from "../../contracts/token/TabERC20.sol";
import {ITransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @dev Refer foundry.toml `no_match_test` option to turn off this test.
 * Run test with `forge test --match-path test/deployment/MultiReserveTest_testnet.t.sol -vvvv --rpc-url https://base-sepolia.g.alchemy.com/v2/API_KEY`
 */
contract MultiReserveTest_testnet is Test {

    address owner = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56; // deployer: testnet

    PriceOracle priceOracle;
    PriceOracleManager priceOracleManager;
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
    address reserveRegistry;
    address tabProxyAdminAddr;
    address config;
    address vaultKeeper;

    function setUp() public {
        console.log("Upgrade is started on testnet id ", block.chainid);
        ctrl = CTRL(0x193410b8cdeD8F4D63E43D0f2AeD99bd862ed1Bc);
        shiftCtrlGovernor = 0x89E7068cf18F22765D1F2902d1BaB8C839B8d013;
        governance = 0x783bDAF73E8F40672421204d6FF3f448767d72c6;
        emergencyGov = 0x997275213b66AEAAb4042dF9457F2913969368f2;
        vaultManagerAddr = 0xeAf6aB024D4a7192322090Fea1C402a5555cD107;
        priceOracleManagerAddr = 0xBdFd9503f62A23092504eD072158092B6B3342ac;
        tabRegistry = 0x9b2F93f5be029Fbb4Cb51491951943f7368b2f1C;
        oracleRelayerSignerAddr = 0x6cC15689B28227d97481Fac73614cD8D35ede6D2;
        reserveRegistry = 0xDA8A64cDFaeb08b3f28b072b0d4aC371953F5B6E;
        tabProxyAdminAddr = 0xF44013D4BE0F452938B0b805Bc5Bf0D3Fbd4102c;
        config = 0x25B9982A32106EeB2Aa052319011De58A7d33457;
        vaultKeeper = 0x303818F385f1675BBB07dDE155987f6b7041753c;
    }

    function nextBlock(uint256 increment) public {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
    }

    function test_deploy_testnet() public {
        vm.startPrank(owner);

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
            reserveRegistry,
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

        nextBlock(2 days +  1 hours); // voting delay

        // Simulate voting, queue, execute
        IGovernor(shiftCtrlGovernor).castVote(proposalId, 1);

        nextBlock(3 days +  1 hours); // voting period

        bytes32 description = keccak256(bytes("multiReserves: update vault manager and price oracle"));
        IGovernor(shiftCtrlGovernor).queue(targets, values, calldatas, description);

        nextBlock(2 days +  1 hours); // timelock delay

        IGovernor(shiftCtrlGovernor).execute(targets, values, calldatas, description);

        // Post upgrade checks
        assertEq(address(VaultManager(vaultManagerAddr).priceOracle()), address(priceOracle));
        assertEq(priceOracleManager.priceOracle(), address(priceOracle));

        // Existing vault operations should still work
        address vaultOwner = 0x16601e7dBf2642bF7832053417eE0E17C9c49f93;
        vm.startPrank(vaultOwner);

        TabERC20 sUSD = TabERC20(0xc99E6c8Fb2cD8adA848FFcDfafC46d2D300B443b);   // sUSD BASE Sepolia testnet address
        uint256 oriBalance = sUSD.balanceOf(vaultOwner);
        sUSD.approve(vaultManagerAddr, 100e18); // Approve vault manager to spend sUSD
        VaultManager(vaultManagerAddr).paybackTab(vaultOwner, 1, 100e18);
        assertEq(sUSD.balanceOf(vaultOwner), oriBalance - 100e18);
    }
}