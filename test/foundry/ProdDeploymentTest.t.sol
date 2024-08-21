// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ITransparentUpgradeableProxy, TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import { ProdDeployer } from "./ProdDeployer.t.sol";
import { CTRL } from "../../contracts/token/CTRL.sol";
import { CBTC } from "../../contracts/token/CBTC.sol";
import { WBTC } from "../../contracts/token/WBTC.sol";
import { TabERC20 } from "../../contracts/token/TabERC20.sol";
import { IPriceOracle } from "../../contracts/oracle/interfaces/IPriceOracle.sol";

contract ProdDeploymentTest is Test, ProdDeployer {

    IPriceOracle.UpdatePriceData priceData;

    function setUp() public {
        deploy();
    }

    function nextBlock(uint256 increment) internal {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
    }

    function test_CTRL() public {
        assertEq(ctrl.cap(), 1000000000e18);
        assertEq(ctrl.decimals(), 18);
        assertEq(ctrl.defaultAdmin(), deployer); // skipped ownership transfer
        assertEq(ctrl.owner(), deployer);
        assertEq(ctrl.defaultAdminDelay(), 1 days);
        assertEq(ctrl.name(), "shiftCTRL");
        assertEq(ctrl.symbol(), "CTRL");
        assertEq(ctrl.hasRole(keccak256("UPGRADER_ROLE"), deployer), true);
        assertEq(ctrl.hasRole(keccak256("UPGRADER_ROLE"), address(governanceTimelockController)), true);
        assertEq(ctrl.hasRole(keccak256("UPGRADER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(ctrl.hasRole(keccak256("MINTER_ROLE"), deployer), true);
        assertEq(ctrl.CLOCK_MODE(), "mode=timestamp");

        assertEq(ctrlProxyAdmin.owner(), address(governanceTimelockController));
        assertEq(ctrlProxyAdmin.getProxyAdmin(ITransparentUpgradeableProxy(address(ctrl))), address(ctrlProxyAdmin));

        vm.startPrank(address(governanceTimelockController));
        CTRL updCTRL = new CTRL();
        bytes memory initData = abi.encodeCall(CTRL.initialize, (deployer));
        CTRL prxCTRL = CTRL(address(new TransparentUpgradeableProxy(address(updCTRL), address(ctrlProxyAdmin), initData)));
        ctrlProxyAdmin.upgrade(ITransparentUpgradeableProxy(address(prxCTRL)), address(new CTRL()));
        vm.stopPrank();
    }

    function test_WBTC() public {
        assertEq(wBTC.decimals(), 8);
        assertEq(wBTC.defaultAdmin(), address(governanceTimelockController));
        assertEq(wBTC.owner(), address(governanceTimelockController));
        assertEq(wBTC.defaultAdminDelay(), 1 days);
        assertEq(wBTC.name(), "Token Wrapped BTC");
        assertEq(wBTC.symbol(), "WBTC");
        assertEq(wBTC.hasRole(keccak256("UPGRADER_ROLE"), address(governanceTimelockController)), true);
        assertEq(wBTC.hasRole(keccak256("UPGRADER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(wBTC.hasRole(keccak256("MINTER_ROLE"), deployer), true);

        assertEq(wBTCProxyAdmin.owner(), address(governanceTimelockController));
        assertEq(wBTCProxyAdmin.getProxyAdmin(ITransparentUpgradeableProxy(address(wBTC))), address(wBTCProxyAdmin));

        vm.startPrank(address(governanceTimelockController));
        WBTC token = new WBTC();
        bytes memory initData = abi.encodeCall(WBTC.initialize, (deployer,deployer,deployer));
        WBTC prx = WBTC(address(new TransparentUpgradeableProxy(address(token), address(wBTCProxyAdmin), initData)));
        wBTCProxyAdmin.upgrade(ITransparentUpgradeableProxy(address(prx)), address(new WBTC()));
        vm.stopPrank();
    }

    function test_CBTC() public {
        assertEq(cBTC.decimals(), 18);
        assertEq(cBTC.defaultAdmin(), address(governanceTimelockController));
        assertEq(cBTC.owner(), address(governanceTimelockController));
        assertEq(cBTC.defaultAdminDelay(), 1 days);
        assertEq(cBTC.name(), "shiftCTRL Wrapped BTC");
        assertEq(cBTC.symbol(), "cBTC");
        assertEq(cBTC.hasRole(keccak256("UPGRADER_ROLE"), address(governanceTimelockController)), true);
        assertEq(cBTC.hasRole(keccak256("UPGRADER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(cBTC.hasRole(keccak256("MINTER_ROLE"), deployer), true);

        assertEq(cBTCProxyAdmin.owner(), address(governanceTimelockController));
        assertEq(cBTCProxyAdmin.getProxyAdmin(ITransparentUpgradeableProxy(address(cBTC))), address(cBTCProxyAdmin));

        vm.startPrank(address(governanceTimelockController));
        CBTC token = new CBTC();
        bytes memory initData = abi.encodeCall(CBTC.initialize, (deployer,deployer,deployer));
        CBTC prx = CBTC(address(new TransparentUpgradeableProxy(address(token), address(cBTCProxyAdmin), initData)));
        cBTCProxyAdmin.upgrade(ITransparentUpgradeableProxy(address(prx)), address(new CBTC()));
        vm.stopPrank();
    }

    function test_TabERC20() public {
        vm.startPrank(address(governanceTimelockController));
        TabERC20 sUSD = TabERC20(tabRegistry.createTab(bytes3(abi.encodePacked("USD"))));
        vm.stopPrank();

        assertEq(sUSD.decimals(), 18);
        assertEq(sUSD.defaultAdmin(), address(governanceTimelockController));
        assertEq(sUSD.owner(), address(governanceTimelockController));
        assertEq(sUSD.defaultAdminDelay(), 1 days);
        assertEq(sUSD.name(), "Sound USD");
        assertEq(sUSD.symbol(), "sUSD");
        assertEq(sUSD.hasRole(keccak256("UPGRADER_ROLE"), address(governanceTimelockController)), true);
        assertEq(sUSD.hasRole(keccak256("MINTER_ROLE"), address(vaultManager)), true);

        assertEq(tabProxyAdmin.owner(), address(governanceTimelockController));
        assertEq(tabProxyAdmin.getProxyAdmin(ITransparentUpgradeableProxy(address(sUSD))), address(tabProxyAdmin));

        vm.startPrank(address(governanceTimelockController));
        TabERC20 token = new TabERC20();
        bytes memory initData = abi.encodeCall(TabERC20.initialize, ("New_sUSD","sUSD",deployer,deployer));
        TabERC20 prx = TabERC20(address(new TransparentUpgradeableProxy(address(token), address(tabProxyAdmin), initData)));
        tabProxyAdmin.upgrade(ITransparentUpgradeableProxy(address(prx)), address(new TabERC20()));
        vm.stopPrank();
    }

    function test_ShiftCtrlGovernor() public {
        assertEq(shiftCtrlGovernor.name(), "ShiftCtrlGovernor");
        assertEq(shiftCtrlGovernor.timelock(), address(governanceTimelockController));
        assertEq(shiftCtrlGovernor.proposalThreshold(), 10000e18); // 10K
        assertEq(shiftCtrlGovernor.quorumNumerator(), 5);
        assertEq(shiftCtrlGovernor.votingDelay(), 2 days);
        assertEq(shiftCtrlGovernor.votingPeriod(), 3 days);

        ctrl.mint(deployer, 10000e18);
        ctrl.delegate(deployer);
        nextBlock(1);
        ctrl.beginDefaultAdminTransfer(address(governanceTimelockController));
        address[] memory targets = new address[](1);
        targets[0] = address(ctrl);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(AccessControlDefaultAdminRulesUpgradeable.acceptDefaultAdminTransfer, ());
        uint256 proposalId = shiftCtrlGovernor.propose(targets, values, calldatas, "ctrl-acceptDefaultAdminTransfer");
        nextBlock(2 days + 1 minutes); // voting delay
        shiftCtrlGovernor.castVote(proposalId, 1); // GovernorCountingSimple.VoteType.For
        nextBlock(3 days + 1 minutes); // voting period
        bytes32 description = keccak256(bytes("ctrl-acceptDefaultAdminTransfer"));
        shiftCtrlGovernor.queue(targets, values, calldatas, description);
        nextBlock(2 days + 1 minutes); // exec delay (passed 1 day of admin transfer delay too)
        shiftCtrlGovernor.execute(targets, values, calldatas, description);
        assertEq(ctrl.defaultAdmin(), address(governanceTimelockController));
        assertEq(ctrl.owner(), address(governanceTimelockController));
    }

    function test_ShiftCtrlEmergencyGovernor() public {
        assertEq(shiftCtrlEmergencyGovernor.name(), "ShiftCtrlEmergencyGovernor");
        assertEq(shiftCtrlEmergencyGovernor.timelock(), address(emergencyTimelockController));
        assertEq(shiftCtrlEmergencyGovernor.proposalThreshold(), 1000000e18); // 1M
        assertEq(shiftCtrlEmergencyGovernor.quorumNumerator(), 5);
        assertEq(shiftCtrlEmergencyGovernor.votingDelay(), 0);
        assertEq(shiftCtrlEmergencyGovernor.votingPeriod(), 30 minutes);

        ctrl.mint(deployer, 1000000e18);
        ctrl.delegate(deployer);
        nextBlock(1);
        ctrl.beginDefaultAdminTransfer(address(emergencyTimelockController));
        address[] memory targets = new address[](1);
        targets[0] = address(ctrl);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(AccessControlDefaultAdminRulesUpgradeable.acceptDefaultAdminTransfer, ());
        uint256 proposalId = shiftCtrlEmergencyGovernor.propose(targets, values, calldatas, "ctrl-acceptDefaultAdminTransfer");
        nextBlock(1);
        shiftCtrlEmergencyGovernor.castVote(proposalId, 1); // GovernorCountingSimple.VoteType.For
        nextBlock(30 minutes + 1 minutes);
        bytes32 description = keccak256(bytes("ctrl-acceptDefaultAdminTransfer"));
        shiftCtrlEmergencyGovernor.queue(targets, values, calldatas, description);
        nextBlock(1 days); // admin transfer delay
        shiftCtrlEmergencyGovernor.execute(targets, values, calldatas, description);
        assertEq(ctrl.defaultAdmin(), address(emergencyTimelockController));
        assertEq(ctrl.owner(), address(emergencyTimelockController));
    }

    function test_RegularTimelockController() public view {
        address controller = address(shiftCtrlGovernor);
        assertEq(governanceTimelockController.hasRole(TIMELOCK_ADMIN_ROLE, controller), true);
        assertEq(governanceTimelockController.hasRole(EXECUTOR_ROLE, controller), true);
        assertEq(governanceTimelockController.hasRole(PROPOSER_ROLE, controller), true);
        assertEq(governanceTimelockController.hasRole(CANCELLER_ROLE, controller), true);
        assertEq(governanceTimelockController.getMinDelay(), 2 days);
    }

    function test_EmergencyTimelockController() public view {
        address controller = address(shiftCtrlEmergencyGovernor);
        assertEq(emergencyTimelockController.hasRole(TIMELOCK_ADMIN_ROLE, controller), true);
        assertEq(emergencyTimelockController.hasRole(EXECUTOR_ROLE, controller), true);
        assertEq(emergencyTimelockController.hasRole(PROPOSER_ROLE, controller), true);
        assertEq(emergencyTimelockController.hasRole(CANCELLER_ROLE, controller), true);
        assertEq(emergencyTimelockController.getMinDelay(), 0);
    }

    function test_GovernanceAction() public {
        bytes32 MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
        assertEq(governanceAction.hasRole(MAINTAINER_ROLE, address(governanceTimelockController)), true);
        assertEq(governanceAction.hasRole(MAINTAINER_ROLE, address(emergencyTimelockController)), true);
        assertEq(governanceAction.hasRole(MAINTAINER_ROLE, deployer), false); // called renounceRole
        assertEq(governanceAction.defBlockGenerationTimeInSecond(), 12);

        vm.startPrank(deployer);
        vm.expectRevert();
        governanceAction.setContractAddress(deployer, deployer, deployer, deployer);
        vm.stopPrank();

        bytes3 sUSD = bytes3(abi.encodePacked("USD"));
        vm.startPrank(address(governanceTimelockController));

        governanceAction.createNewTab(sUSD);
        bytes32[] memory _reserveKey = new bytes32[](1);
        _reserveKey[0] = keccak256("WBTC");
        uint256[] memory _processFeeRate = new uint256[](1);
        _processFeeRate[0] = 0;
        uint256[] memory _minReserveRatio = new uint256[](1);
        _minReserveRatio[0] = 180;
        uint256[] memory _liquidationRatio = new uint256[](1);
        _liquidationRatio[0] = 120;
        governanceAction.updateReserveParams(_reserveKey, _processFeeRate, _minReserveRatio, _liquidationRatio);
        
        bytes3[] memory _tab = new bytes3[](1);
        _tab[0] = sUSD;
        uint256[] memory _riskPenaltyPerFrame = new uint256[](1);
        _riskPenaltyPerFrame[0] = 150;
        governanceAction.updateTabParams(_tab, _riskPenaltyPerFrame, _processFeeRate);

        governanceAction.updateAuctionParams(90, 97, 60, address(auctionManager));
        governanceAction.disableTab(sUSD);
        governanceAction.enableTab(sUSD);
        governanceAction.disableAllTabs();
        governanceAction.enableAllTabs();
        priceOracle.setDirectPrice(sUSD, 60000e18, block.timestamp);
        governanceAction.setPeggedTab(bytes3(abi.encodePacked("XXX")), sUSD, 100000e18);
        governanceAction.addReserve(keccak256("XBTC"), address(ctrl), address(vaultManager));
        governanceAction.disableReserve(keccak256("XBTC"));
        governanceAction.addPriceOracleProvider(eoa_accounts[1], address(ctrl), 1, 1, 1, bytes32(""));
        governanceAction.configurePriceOracleProvider(eoa_accounts[1], address(ctrl), 1, 1, 1, bytes32(""));
        governanceAction.pausePriceOracleProvider(eoa_accounts[1]);
        governanceAction.unpausePriceOracleProvider(eoa_accounts[1]);
        governanceAction.removePriceOracleProvider(eoa_accounts[1], block.number, block.timestamp);
        governanceAction.ctrlAltDel(sUSD, 1);

        vm.stopPrank();
    }

    function test_VaultManager() public {
        vm.expectRevert(); // unauthorized
        vaultManager.configContractAddress(deployer, deployer, deployer, deployer, deployer);

        wBTC.mint(address(governanceTimelockController), 2e8);
        
        vm.startPrank(address(governanceTimelockController));
        vaultManager.configContractAddress(address(config), address(reserveRegistry), address(tabRegistry), address(priceOracle), address(vaultKeeper));
        
        bytes3 sUSD = bytes3(abi.encodePacked("USD"));
        governanceAction.createNewTab(sUSD);

        priceData = signer.getUpdatePriceSignature(sUSD, 60000e18, block.timestamp);
        wBTC.approve(address(vaultManager), 1e8);
        vaultManager.createVault(reserve_wBTC, 1e18, 10000e18, priceData);

        priceData = signer.getUpdatePriceSignature(sUSD, 60000e18, block.timestamp);
        vaultManager.withdrawReserve(1, 1e17, priceData);

        wBTC.approve(address(vaultManager), 1e7);
        vaultManager.depositReserve(1, 1e17);

        TabERC20(tabRegistry.tabs(sUSD)).approve(address(vaultManager), 5000e18);
        vaultManager.paybackTab(1, 5000e18);

        priceData = signer.getUpdatePriceSignature(sUSD, 60000e18, block.timestamp);
        vaultManager.withdrawTab(1, 28333e18, priceData);
        
        vm.stopPrank();

        vm.expectRevert();
        vaultManager.chargeRiskPenalty(address(governanceTimelockController), 1, 10e18); // unauthorized

        vm.startPrank(address(vaultKeeper));
        vaultManager.chargeRiskPenalty(address(governanceTimelockController), 1, 10e18);
        
        priceData = signer.getUpdatePriceSignature(sUSD, 30000e18, block.timestamp);
        vaultManager.liquidateVault(address(governanceTimelockController), 1, 10e18, priceData);
        vm.stopPrank();

        vm.startPrank(address(governanceTimelockController));
        priceData = signer.getUpdatePriceSignature(sUSD, 60000e18, block.timestamp);
        wBTC.approve(address(vaultManager), 1e8);
        vaultManager.createVault(reserve_wBTC, 1e18, 10000e18, priceData);
        governanceAction.ctrlAltDel(sUSD, 50000e18);
        vm.stopPrank();

        wBTC.mint(address(governanceTimelockController), 1e8);        
        vm.startPrank(address(governanceTimelockController));
        wBTC.approve(address(vaultManager), 1e8);
        priceData = signer.getUpdatePriceSignature(sUSD, 60000e18, block.timestamp);
        vm.expectRevert("CTRL_ALT_DEL_DONE"); // sUSD tab has been CTRL_ALT_DEL above
        vaultManager.createVault(reserve_wBTC, 1e18, 10000e18, priceData);

        // assume unauthorized oracle signer to generate signature
        signer.updateSigner(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720, 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6);
        bytes3 sEUR = bytes3(abi.encodePacked("EUR"));
        governanceAction.createNewTab(sEUR);
        priceData = signer.getUpdatePriceSignature(sEUR, 100000e18, block.timestamp);
        vm.expectRevert("INVALID_ROLE");
        vaultManager.createVault(reserve_wBTC, 1e18, 10000e18, priceData);
        vm.stopPrank();
    }

    function test_TabRegistry() public {
        assertEq(tabRegistry.hasRole(keccak256("USER_ROLE"), address(governanceTimelockController)), true);
        assertEq(tabRegistry.hasRole(keccak256("USER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(tabRegistry.hasRole(keccak256("USER_ROLE"), address(governanceAction)), true);
        assertEq(tabRegistry.hasRole(keccak256("USER_ROLE"), address(vaultManager)), true);
        assertEq(tabRegistry.hasRole(keccak256("MAINTAINER_ROLE"), address(governanceTimelockController)), true);
        assertEq(tabRegistry.hasRole(keccak256("MAINTAINER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(tabRegistry.hasRole(keccak256("MAINTAINER_ROLE"), address(governanceAction)), true);
        assertEq(tabRegistry.hasRole(keccak256("MAINTAINER_ROLE"), deployer), false);
        assertEq(tabRegistry.hasRole(keccak256("TAB_PAUSER_ROLE"), address(governanceTimelockController)), true);
        assertEq(tabRegistry.hasRole(keccak256("TAB_PAUSER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(tabRegistry.hasRole(keccak256("TAB_PAUSER_ROLE"), address(governanceAction)), true);
        assertEq(tabRegistry.hasRole(keccak256("TAB_PAUSER_ROLE"), address(KEEPER_RELAYER)), true);
        assertEq(tabRegistry.hasRole(keccak256("ALL_TAB_PAUSER_ROLE"), address(governanceTimelockController)), true);
        assertEq(tabRegistry.hasRole(keccak256("ALL_TAB_PAUSER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(tabRegistry.hasRole(keccak256("ALL_TAB_PAUSER_ROLE"), address(governanceAction)), true);

        vm.startPrank(eoa_accounts[1]);
        vm.expectRevert(); // unauthorized
        tabRegistry.setTabFactory(deployer);
        vm.stopPrank();

        vm.startPrank(address(governanceTimelockController));
        tabRegistry.setTabFactory(deployer);
        tabRegistry.setVaultManagerAddress(deployer);
        tabRegistry.setConfigAddress(deployer);
        tabRegistry.setPriceOracleManagerAddress(deployer);
        tabRegistry.setGovernanceAction(deployer);
        tabRegistry.setProtocolVaultAddress(deployer);
        vm.stopPrank();
    }

    function test_TabFactory() public {
        assertEq(tabFactory.hasRole(keccak256("USER_ROLE"), address(governanceTimelockController)), true);
        assertEq(tabFactory.hasRole(keccak256("USER_ROLE"), address(tabRegistry)), true);
        vm.expectRevert();
        tabFactory.changeTabERC20Addr(deployer);

        vm.startPrank(address(governanceTimelockController));
        tabFactory.changeTabERC20Addr(address(new TabERC20()));
        vm.stopPrank();
    }

    function test_reserves() public {
        assertEq(reserveRegistry.hasRole(keccak256("MAINTAINER_ROLE"), address(governanceTimelockController)), true);
        assertEq(reserveRegistry.hasRole(keccak256("MAINTAINER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(reserveRegistry.hasRole(keccak256("MAINTAINER_ROLE"), address(governanceAction)), true);
        assertEq(reserveRegistry.hasRole(keccak256("MAINTAINER_ROLE"), deployer), false);
        vm.expectRevert(); // unauthorized
        reserveRegistry.addReserve(keccak256("TEST"), deployer, deployer);
        
        vm.startPrank(address(governanceTimelockController));
        reserveRegistry.addReserve(keccak256("CTRL"), address(ctrl), address(wBTCReserveSafe));
        assertEq(reserveRegistry.isEnabledReserve(address(ctrl)), true);
        reserveRegistry.removeReserve(keccak256("CTRL"));
        assertEq(reserveRegistry.isEnabledReserve(address(ctrl)), false);
        vm.stopPrank();

        assertEq(wBTCReserveSafe.hasRole(keccak256("UNLOCKER_ROLE"), address(governanceTimelockController)), true);
        assertEq(wBTCReserveSafe.hasRole(keccak256("UNLOCKER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(wBTCReserveSafe.hasRole(keccak256("UNLOCKER_ROLE"), address(vaultManager)), true);

        vm.expectRevert(); // unauthorized
        wBTCReserveSafe.unlockReserve(deployer, 10e18);
        vm.expectRevert();
        wBTCReserveSafe.approveSpend(deployer, 10e18);
    }

    function test_AuctionManager() public view {
        assertEq(auctionManager.hasRole(keccak256("MANAGER_ROLE"), address(governanceTimelockController)), true);
        assertEq(auctionManager.hasRole(keccak256("MANAGER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(auctionManager.hasRole(keccak256("MANAGER_ROLE"), address(vaultManager)), true);
        assertEq(auctionManager.vaultManagerAddr(), address(vaultManager));
        assertEq(auctionManager.reserveRegistryAddr(), address(reserveRegistry));
        assertEq(auctionManager.auctionCount(), 0);
        assertEq(auctionManager.maxStep(), 9);
    }

    function test_Config() public view {
        assertEq(config.hasRole(keccak256("MAINTAINER_ROLE"), address(governanceTimelockController)), true);
        assertEq(config.hasRole(keccak256("MAINTAINER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(config.hasRole(keccak256("MAINTAINER_ROLE"), address(governanceAction)), true);
        assertEq(config.hasRole(keccak256("MAINTAINER_ROLE"), deployer), false);
        assertEq(config.hasRole(keccak256("MAINTAINER_ROLE"), address(tabRegistry)), true);
        assertEq(config.treasury(), TREASURY);
        assertEq(config.vaultKeeper(), address(vaultKeeper));
        assertEq(config.tabRegistry(), address(tabRegistry));
    }

    function test_PriceOracleManager() public {
        assertEq(priceOracleManager.hasRole(keccak256("MAINTAINER_ROLE"), address(governanceTimelockController)), true);
        assertEq(priceOracleManager.hasRole(keccak256("MAINTAINER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(priceOracleManager.hasRole(keccak256("MAINTAINER_ROLE"), address(governanceAction)), true);
        assertEq(priceOracleManager.hasRole(keccak256("MAINTAINER_ROLE"), deployer), false);
        assertEq(priceOracleManager.hasRole(keccak256("MAINTAINER_ROLE"), PRICE_RELAYER), true);
        assertEq(priceOracleManager.hasRole(keccak256("CONFIG_ROLE"), address(governanceTimelockController)), true);
        assertEq(priceOracleManager.hasRole(keccak256("CONFIG_ROLE"), address(emergencyTimelockController)), true);
        assertEq(priceOracleManager.hasRole(keccak256("CONFIG_ROLE"), address(governanceAction)), true);
        assertEq(priceOracleManager.hasRole(keccak256("CONFIG_ROLE"), address(tabRegistry)), true);
        assertEq(priceOracleManager.movementDelta(), 500);
        assertEq(priceOracleManager.inactivePeriod(), 1 hours);
        assertEq(priceOracleManager.defBlockGenerationTimeInSecond(), 12);

        vm.expectRevert(); // unauthorized
        priceOracleManager.addNewTab(bytes3(abi.encodePacked("ABC")));

        vm.startPrank(address(governanceTimelockController));
        priceOracleManager.setOraclePriceSize(100);
        priceOracleManager.addNewTab(bytes3(abi.encodePacked("XXX")));
        priceOracleManager.setDefBlockGenerationTimeInSecond(100);
        vm.stopPrank();
    }

    function test_PriceOracle() public {
        assertEq(priceOracle.hasRole(keccak256("FEEDER_ROLE"), address(governanceTimelockController)), true);
        assertEq(priceOracle.hasRole(keccak256("FEEDER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(priceOracle.hasRole(keccak256("FEEDER_ROLE"), address(priceOracleManager)), true);
        assertEq(priceOracle.hasRole(keccak256("FEEDER_ROLE"), address(vaultManager)), true);
        assertEq(priceOracle.hasRole(keccak256("PAUSER_ROLE"), address(governanceTimelockController)), true);
        assertEq(priceOracle.hasRole(keccak256("PAUSER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(priceOracle.hasRole(keccak256("TAB_REGISTRY_ROLE"), address(tabRegistry)), true);
        assertEq(priceOracle.inactivePeriod(), 1 hours);
        
        vm.expectRevert();
        priceOracle.pause();
    }

    function test_VaultKeeper() public {
        assertEq(vaultKeeper.hasRole(keccak256("EXECUTOR_ROLE"), address(governanceTimelockController)), true);
        assertEq(vaultKeeper.hasRole(keccak256("EXECUTOR_ROLE"), address(emergencyTimelockController)), true);
        assertEq(vaultKeeper.hasRole(keccak256("EXECUTOR_ROLE"), address(KEEPER_RELAYER)), true);
        assertEq(vaultKeeper.hasRole(keccak256("EXECUTOR_ROLE"), address(vaultManager)), true);
        assertEq(vaultKeeper.hasRole(keccak256("MAINTAINER_ROLE"), address(governanceTimelockController)), true);
        assertEq(vaultKeeper.hasRole(keccak256("MAINTAINER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(vaultKeeper.hasRole(keccak256("MAINTAINER_ROLE"), address(KEEPER_RELAYER)), true);
        assertEq(vaultKeeper.hasRole(keccak256("MAINTAINER_ROLE"), address(config)), true);
        assertEq(vaultKeeper.hasRole(keccak256("DEPLOYER_ROLE"), address(governanceTimelockController)), true);
        assertEq(vaultKeeper.hasRole(keccak256("DEPLOYER_ROLE"), address(emergencyTimelockController)), true);
        assertEq(vaultKeeper.hasRole(keccak256("DEPLOYER_ROLE"), deployer), false);
        assertEq(vaultKeeper.vaultManager(), address(vaultManager));
        assertEq(vaultKeeper.riskPenaltyFrameInSecond(), 24 hours);

        vm.startPrank(eoa_accounts[1]); // unauthorized
        vm.expectRevert();
        vaultKeeper.updateVaultManagerAddress(deployer);
        vm.expectRevert();
        vaultKeeper.setRiskPenaltyFrameInSecond((24 hours) * 2);
        vm.stopPrank();

        vm.startPrank(address(governanceTimelockController));
        vaultKeeper.setRiskPenaltyFrameInSecond((24 hours) * 2);
        vm.stopPrank();
    }

}