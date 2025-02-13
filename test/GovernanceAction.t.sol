// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {ITransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {CBBTC} from "../contracts/token/CBBTC.sol";
import {GovernanceAction_newImpl} from "./upgrade/GovernanceAction_newImpl.sol";
import {IConfig} from "../contracts/interfaces/IConfig.sol";
import {IGovernanceAction} from "../contracts/interfaces/IGovernanceAction.sol";
import {IPriceOracleManager} from "../contracts/interfaces/IPriceOracleManager.sol";

contract GovernanceActionTest is Deployer {
    IPriceOracleManager.OracleProvider provider;
    IPriceOracleManager.Info info;

    function setUp() public {
        deploy();
    }

    function test_permission() public {
        assertEq(governanceAction.defaultAdmin() , address(governanceTimelockController));
        assertEq(governanceAction.hasRole(MAINTAINER_ROLE, address(governanceTimelockController)), true);
        assertEq(governanceAction.hasRole(MAINTAINER_ROLE, address(emergencyTimelockController)), true);
        assertEq(governanceAction.hasRole(MAINTAINER_ROLE, owner), false);
        assertEq(governanceAction.hasRole(UPGRADER_ROLE, address(tabProxyAdmin)), true);
        
        vm.expectRevert();
        governanceAction.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        governanceAction.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        governanceAction.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(governanceAction.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        assertEq(tabProxyAdmin.owner(), address(governanceTimelockController));
        vm.startPrank(address(governanceTimelockController));
        tabProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(governanceAction)), 
            address(new GovernanceAction_newImpl()),
            abi.encodeWithSignature("upgraded(string)", "governanceAction_v2")
        );

        GovernanceAction_newImpl governanceAction_v2 = GovernanceAction_newImpl(address(governanceAction));
        assertEq(keccak256(bytes(governanceAction_v2.version())), keccak256("governanceAction_v2"));
        assertEq(governanceAction_v2.newFunction(), 1e18);

        vm.expectRevert();
        governanceAction_v2.upgraded("test");

        vm.stopPrank();
    }

    function test_setContractAddress() public {
        vm.expectRevert(); // unauthorized
        governanceAction.setContractAddress(owner, owner, owner, owner);

        assertEq(governanceAction.configAddress(), address(config));
        assertEq(governanceAction.tabRegistryAddress(), address(tabRegistry));
        assertEq(governanceAction.reserveRegistryAddress(), address(reserveRegistry));
        assertEq(governanceAction.priceOracleManagerAddress(), address(priceOracleManager));

        vm.startPrank(address(governanceTimelockController));

        // no changes by updating address(0)
        governanceAction.setContractAddress(address(0), address(0), address(0), address(0));
        assertEq(governanceAction.configAddress(), address(config));
        assertEq(governanceAction.tabRegistryAddress(), address(tabRegistry));
        assertEq(governanceAction.reserveRegistryAddress(), address(reserveRegistry));
        assertEq(governanceAction.priceOracleManagerAddress(), address(priceOracleManager));

        vm.expectEmit();
        emit IGovernanceAction.UpdatedConfig(address(config), owner);
        emit IGovernanceAction.UpdatedTabRegistry(address(tabRegistry), owner);
        emit IGovernanceAction.UpdatedReserveRegistry(address(reserveRegistry), owner);
        emit IGovernanceAction.UpdatedPriceOracleManagerAddr(address(priceOracleManager), owner);
        governanceAction.setContractAddress(owner, owner, owner, owner);
        assertEq(governanceAction.configAddress(), owner);
        assertEq(governanceAction.tabRegistryAddress(), owner);
        assertEq(governanceAction.reserveRegistryAddress(), owner);
        assertEq(governanceAction.priceOracleManagerAddress(), owner);

        vm.stopPrank();
    }

    function test_setDefBlockGenerationTimeInSecond() public {
        vm.expectRevert(); // unauthorized
        governanceAction.setDefBlockGenerationTimeInSecond(100);

        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit();
        emit IGovernanceAction.UpdatedDefBlockGenerationTimeInSecond(100);
        governanceAction.setDefBlockGenerationTimeInSecond(100);
        assertEq(priceOracleManager.defBlockGenerationTimeInSecond(), 100);
        vm.stopPrank();
    }

    function test_updateTabParams() public {
        bytes3[] memory tabs = new bytes3[](2);
        tabs[0] = bytes3(abi.encodePacked("USD"));
        tabs[1] = bytes3(abi.encodePacked("AUD"));
        IConfig.TabParams[] memory tabParams = new IConfig.TabParams[](2);
        tabParams[0].riskPenaltyPerFrame = 1;
        tabParams[0].processFeeRate = 1;
        tabParams[0].minReserveRatio = 1;
        tabParams[0].liquidationRatio = 1;
        tabParams[1].riskPenaltyPerFrame = 2;
        tabParams[1].processFeeRate = 2;
        tabParams[1].minReserveRatio = 2;
        tabParams[1].liquidationRatio = 2;

        vm.expectRevert(); // unauthorized
        governanceAction.updateTabParams(tabs, tabParams);

        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit();
        emit IGovernanceAction.UpdatedTabParams(2);
        governanceAction.updateTabParams(tabs, tabParams);
        vm.stopPrank();

        tabParams[0] = config.getTabParams(tabs[0]);
        assertEq(1, tabParams[0].riskPenaltyPerFrame);
        assertEq(1, tabParams[0].processFeeRate);
        assertEq(1, tabParams[0].minReserveRatio);
        assertEq(1, tabParams[0].liquidationRatio);
        tabParams[1] = config.getTabParams(tabs[1]);
        assertEq(2, tabParams[1].riskPenaltyPerFrame);
        assertEq(2, tabParams[1].processFeeRate);
        assertEq(2, tabParams[1].minReserveRatio);
        assertEq(2, tabParams[1].liquidationRatio);
    }

    function test_updateAuctionParams() public {
        vm.expectRevert(); // unauthorized
        governanceAction.updateAuctionParams(1, 1, 1, owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit();
        emit IGovernanceAction.UpdatedAuctionParams(1, 1, 1, owner);
        governanceAction.updateAuctionParams(1, 1, 1, owner);
        vm.stopPrank();

        IConfig.AuctionParams memory auctionParams = config.getAuctionParams();
        assertEq(auctionParams.auctionStartPriceDiscount, 1);
        assertEq(auctionParams.auctionStepPriceDiscount, 1);
        assertEq(auctionParams.auctionStepDurationInSec, 1);
        assertEq(auctionParams.auctionManager, owner);
    }

    function test_disableTab_enableTab() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        vm.expectRevert(); // unauthorized
        governanceAction.disableTab(usd);
        vm.expectRevert();
        governanceAction.enableTab(usd);

        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(usd);
        bytes32 usdKey = tabRegistry.tabCodeToTabKey(usd);
        assertEq(tabRegistry.frozenTabs(usdKey), false);

        governanceAction.disableTab(usd);
        assertEq(tabRegistry.frozenTabs(usdKey), true);

        governanceAction.enableTab(usd);
        assertEq(tabRegistry.frozenTabs(usdKey), false);
        vm.stopPrank();
    }

    function test_disableAllTabs_enableAllTabs() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        bytes3 aud = bytes3(abi.encodePacked("AUD"));
        vm.expectRevert(); // unauthorized
        governanceAction.disableAllTabs();
        vm.expectRevert();
        governanceAction.enableAllTabs();

        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(usd);
        governanceAction.createNewTab(aud);
        bytes32 usdKey = tabRegistry.tabCodeToTabKey(usd);
        bytes32 audKey = tabRegistry.tabCodeToTabKey(aud);
        assertEq(tabRegistry.frozenTabs(usdKey), false);
        assertEq(tabRegistry.frozenTabs(audKey), false);

        governanceAction.disableAllTabs();
        assertEq(tabRegistry.frozenTabs(usdKey), true);
        assertEq(tabRegistry.frozenTabs(audKey), true);

        governanceAction.enableAllTabs();
        assertEq(tabRegistry.frozenTabs(usdKey), false);
        assertEq(tabRegistry.frozenTabs(audKey), false);
        vm.stopPrank();
    }

    function test_setPeggedTab() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        bytes3 peg = bytes3(abi.encodePacked("PEG"));
        bytes32 usdKey = tabRegistry.tabCodeToTabKey(usd);
        bytes32 pegKey = tabRegistry.tabCodeToTabKey(peg);
        vm.expectRevert(); // unauthorized
        governanceAction.setPeggedTab(peg, usd, 100);

        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(usd);
        governanceAction.createNewTab(peg);

        priceOracle.setDirectPrice(usd, 60000e18, block.timestamp);
        governanceAction.setPeggedTab(peg, usd, 100);

        vm.stopPrank();

        assertEq(tabRegistry.activatedTabCount(), 2);
        assertEq(keccak256(abi.encodePacked(peg)), keccak256(abi.encodePacked(tabRegistry.tabList(1))));
        assertEq(tabRegistry.peggedTabCount(), 1);
        assertEq(keccak256(abi.encodePacked(peg)), keccak256(abi.encodePacked(tabRegistry.peggedTabList(0))));
        assertEq(tabRegistry.peggedTabMap(pegKey), usdKey);
        assertEq(tabRegistry.peggedTabPriceRatio(pegKey), 100);
    }

    function test_createNewTab() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        vm.expectRevert(); // unauthorized
        governanceAction.createNewTab(usd);

        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit(false, false, false, false);
        emit IGovernanceAction.NewTab(usd, owner);
        governanceAction.createNewTab(usd);
        vm.stopPrank();

        TabERC20 sUSD = TabERC20(tabRegistry.getTabAddress(usd));
        assertEq(sUSD.balanceOf(owner), 0);

        vm.startPrank(address(vaultManager));
        sUSD.mint(owner, 100e18);
        assertEq(sUSD.balanceOf(owner), 100e18);
        vm.stopPrank();
    }

    function test_addReserve_disableReserve() public {
        CBBTC newReserve = new CBBTC(owner);
        assertEq(reserveSafe.reserveDecimal(address(newReserve)), 0);

        vm.expectRevert(); // unauthorized
        governanceAction.addReserve(address(newReserve), address(reserveSafe));
        vm.expectRevert();
        governanceAction.disableReserve(address(newReserve));

        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit();
        emit IGovernanceAction.AddedReserve(address(newReserve), address(reserveSafe));
        governanceAction.addReserve(address(newReserve), address(reserveSafe));
        assertEq(reserveRegistry.isEnabledReserve(address(newReserve)), address(reserveSafe));
        assertEq(reserveSafe.reserveDecimal(address(newReserve)), 8);

        vm.expectEmit();
        emit IGovernanceAction.RemovedReserve(address(newReserve));
        governanceAction.disableReserve(address(newReserve));
        assertEq(reserveRegistry.isEnabledReserve(address(newReserve)), address(0));
        vm.stopPrank();
    }

    function test_addPriceOracleProvider_configurePriceOracleProvider_removePriceOracleProvider() public {
        vm.expectRevert(); // unauthorized
        governanceAction.addPriceOracleProvider(eoa_accounts[7], address(ctrl), 1e18, 100, 100, bytes32(""));
        vm.expectRevert();
        governanceAction.configurePriceOracleProvider(eoa_accounts[7], address(ctrl), 1e18, 100, 100, bytes32(""));
        vm.expectRevert();
        governanceAction.removePriceOracleProvider(eoa_accounts[7], block.number, block.timestamp);

        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit();
        emit IGovernanceAction.NewPriceOracleProvider(
            block.number,
            block.timestamp,
            eoa_accounts[7], 
            address(ctrl), 
            1e18, 
            100, 
            100, 
            bytes32("")
        );
        governanceAction.addPriceOracleProvider(eoa_accounts[7], address(ctrl), 1e18, 100, 100, bytes32(""));
        assertEq(priceOracleManager.providerCount(), 1);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[7]), true);
        info = priceOracleManager.getProviderInfo(eoa_accounts[7]);
        assertEq(info.paymentTokenAddress, address(ctrl));
        assertEq(info.paymentAmtPerFeed, 1e18);
        assertEq(info.blockCountPerFeed, 100);
        assertEq(info.feedSize, 100);
        assertEq(info.whitelistedIPAddr, bytes32(""));

        vm.expectEmit();
        emit IGovernanceAction.ConfigPriceOracleProvider(
            eoa_accounts[7], 
            owner, 
            8e18, 
            99, 
            98, 
            bytes32("192.168.1.1")
        );
        governanceAction.configurePriceOracleProvider(eoa_accounts[7], owner, 8e18, 99, 98, bytes32("192.168.1.1"));
        assertEq(priceOracleManager.providerCount(), 1);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[7]), true);
        info = priceOracleManager.getProviderInfo(eoa_accounts[7]);
        assertEq(info.paymentTokenAddress, owner);
        assertEq(info.paymentAmtPerFeed, 8e18);
        assertEq(info.blockCountPerFeed, 99);
        assertEq(info.feedSize, 98);
        assertEq(info.whitelistedIPAddr, bytes32("192.168.1.1"));

        vm.expectEmit();
        emit IGovernanceAction.RemovedPriceOracleProvider(eoa_accounts[7], block.number, block.timestamp);
        governanceAction.removePriceOracleProvider(eoa_accounts[7], block.number, block.timestamp);
        provider = priceOracleManager.getProvider(eoa_accounts[7]);
        assertEq(provider.disabledOnBlockId, block.number);
        assertEq(provider.disabledTimestamp, block.timestamp);
        assertEq(priceOracleManager.providerCount(), 1);
        assertEq(priceOracleManager.activeProviderCount(), 0);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[7]), false);

        vm.stopPrank();
    }

    function test_pausePriceOracleProvider_unpausePriceOracleProvider() public {
        vm.expectRevert(); // unauthorized
        governanceAction.pausePriceOracleProvider(eoa_accounts[7]);
        vm.expectRevert();
        governanceAction.unpausePriceOracleProvider(eoa_accounts[7]);

        vm.startPrank(address(governanceTimelockController));
        governanceAction.addPriceOracleProvider(eoa_accounts[7], address(ctrl), 1e18, 100, 100, bytes32(""));

        vm.expectEmit();
        emit IGovernanceAction.PausedPriceOracleProvider(eoa_accounts[7]);
        governanceAction.pausePriceOracleProvider(eoa_accounts[7]);
        provider = priceOracleManager.getProvider(eoa_accounts[7]);
        assertEq(provider.paused, true);

        vm.expectEmit();
        emit IGovernanceAction.UnpausedPriceOracleProvider(eoa_accounts[7]);
        governanceAction.unpausePriceOracleProvider(eoa_accounts[7]);
        provider = priceOracleManager.getProvider(eoa_accounts[7]);
        assertEq(provider.paused, false);

        vm.stopPrank();
    }

    function test_ctrlAltDel() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        bytes32 usdKey = tabRegistry.tabCodeToTabKey(usd);
        vm.expectRevert(); // unauthorized
        governanceAction.ctrlAltDel(usd, 100);

        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(usd);

        vm.expectEmit();
        emit IGovernanceAction.CtrlAltDelTab(usd, 100);
        governanceAction.ctrlAltDel(usd, 100);
        assertEq(tabRegistry.ctrlAltDelTab(usdKey), 100);
        assertEq(priceOracle.ctrlAltDelTab(usd), 100);
        vm.stopPrank();
    }
}
