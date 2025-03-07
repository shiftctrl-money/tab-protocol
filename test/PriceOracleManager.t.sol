// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ITransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PriceOracleManager_newImpl} from "./upgrade/PriceOracleManager_newImpl.sol"; 
import {IGovernanceAction} from "../contracts/interfaces/IGovernanceAction.sol";
import {IPriceOracleManager} from "../contracts/interfaces/IPriceOracleManager.sol";

contract PriceOracleManagerTest is Deployer {
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");
    bytes32 public constant PAYMENT_ROLE = keccak256("PAYMENT_ROLE");

    address[10] providerList;
    uint256[10] feedCount;

    IPriceOracleManager.OracleProvider provider;
    IPriceOracleManager.Info info;
    IPriceOracleManager.Tracker tracker;

    function setUp() public {
        deploy();

        vm.startPrank(address(governanceTimelockController));
        governanceAction.addPriceOracleProvider(
            eoa_accounts[7], // provider
            address(ctrl), // paymentTokenAddress
            1e18, // paymentAmtPerFeed
            150, // blockCountPerFeed: every 150 blocks, expect min. 1 feed
            10, // feedSize: provider sends at least 10 currency pairs per feed
            bytes32(abi.encodePacked("127.0.0.1,192.168.1.1")) // whitelistedIPAddr
        );
        governanceAction.addPriceOracleProvider(
            eoa_accounts[8],
            address(ctrl),
            1e18,
            150,
            10,
            bytes32(abi.encodePacked("123.123.123.123,192.168.100.100"))
        );
        governanceAction.addPriceOracleProvider(
            eoa_accounts[9],
            address(ctrl),
            1e18,
            150,
            10,
            bytes32(abi.encodePacked("1.2.3.4,5.6.7.8,1.2.3.4,5.6.7.8"))
        ); // 4 IP, max length 31
        vm.stopPrank();

        providerList[0] = eoa_accounts[7];
        providerList[1] = eoa_accounts[8];
        providerList[2] = eoa_accounts[9];

        // assume feed count submission on every 6 hours (21600 seconds)
        // on 5 minutes interval feed, expect total 72 feed submission within 6 hours
        feedCount[0] = 70;
        feedCount[1] = 71;
        feedCount[2] = 72;

        for (uint256 i = 3; i < 10; i++) {
            providerList[i] = address(0);
            feedCount[i] = 0;
        }
    }

    function test_permission() public {
        assertEq(priceOracleManager.defaultAdmin() , address(governanceTimelockController));
        assertEq(priceOracleManager.hasRole(MAINTAINER_ROLE, address(governanceTimelockController)), true);
        assertEq(priceOracleManager.hasRole(MAINTAINER_ROLE, address(emergencyTimelockController)), true);
        assertEq(priceOracleManager.hasRole(MAINTAINER_ROLE, address(governanceAction)), true);
        assertEq(priceOracleManager.hasRole(MAINTAINER_ROLE, oracleProviderPerformanceSignerAddr), true); // _authorizedCaller: tab-oracle 
        
        assertEq(priceOracleManager.hasRole(CONFIG_ROLE, address(governanceTimelockController)), true);
        assertEq(priceOracleManager.hasRole(CONFIG_ROLE, address(emergencyTimelockController)), true);
        assertEq(priceOracleManager.hasRole(CONFIG_ROLE, address(governanceAction)), true);
        assertEq(priceOracleManager.hasRole(CONFIG_ROLE, address(tabRegistry)), true);
        
        assertEq(priceOracleManager.hasRole(UPGRADER_ROLE, address(tabProxyAdmin)), true);

        assertEq(priceOracleManager.getRoleAdmin(PAYMENT_ROLE), MAINTAINER_ROLE);

        assertEq(priceOracleManager.priceOracle(), address(priceOracle));
        assertEq(priceOracleManager.defBlockGenerationTimeInSecond(), 2);
        assertEq(priceOracleManager.movementDelta(), 500);
        assertEq(priceOracleManager.inactivePeriod(), priceOracle.inactivePeriod());

        vm.expectRevert();
        priceOracleManager.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        priceOracleManager.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        priceOracleManager.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(priceOracleManager.defaultAdmin() , owner);

        assertEq(priceOracleManager.hasRole(PAYMENT_ROLE, eoa_accounts[7]), true);
        assertEq(priceOracleManager.hasRole(PAYMENT_ROLE, eoa_accounts[8]), true);
        assertEq(priceOracleManager.hasRole(PAYMENT_ROLE, eoa_accounts[9]), true);
    }

    function test_upgrade() public {
        assertEq(tabProxyAdmin.owner(), address(governanceTimelockController));
        vm.startPrank(address(governanceTimelockController));
        tabProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(priceOracleManager)), 
            address(new PriceOracleManager_newImpl()),
            abi.encodeWithSignature("upgraded(string)", "upgraded_v2")
        );

        PriceOracleManager_newImpl upgraded_v2 = PriceOracleManager_newImpl(address(priceOracleManager));
        assertEq(keccak256(bytes(upgraded_v2.version())), keccak256("upgraded_v2"));
        assertEq(upgraded_v2.newFunction(), 1e18);

        vm.expectRevert(); // unauthorized
        upgraded_v2.upgraded("test");
        vm.stopPrank();

        assertEq(upgraded_v2.providerCount(), 6);
        assertEq(upgraded_v2.activeProvider(eoa_accounts[7]), true);
        assertEq(upgraded_v2.activeProviderCount(), 6);
    }

    function test_setPriceOracle() public {
        vm.expectRevert(); // unauthorized
        priceOracleManager.setPriceOracle(eoa_accounts[1]);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(IPriceOracleManager.ZeroAddress.selector);
        priceOracleManager.setPriceOracle(address(0));
        vm.expectEmit();
        emit IPriceOracleManager.UpdatedPriceOracleAddress(address(priceOracle), eoa_accounts[1]);
        priceOracleManager.setPriceOracle(eoa_accounts[1]);
        assertEq(priceOracleManager.priceOracle(), eoa_accounts[1]);
        vm.stopPrank();
    }

    function test_setDefBlockGenerationTimeInSecond(uint256 sec) public {
        vm.assume(sec > 0);
        require(sec > 0);
        
        vm.expectRevert(); // unauthorized
        priceOracleManager.setDefBlockGenerationTimeInSecond(sec);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        priceOracleManager.setDefBlockGenerationTimeInSecond(0);
        vm.expectEmit();
        emit IPriceOracleManager.AdjustedSecondPerBlock(priceOracleManager.defBlockGenerationTimeInSecond(), sec);
        priceOracleManager.setDefBlockGenerationTimeInSecond(sec);
        assertEq(priceOracleManager.defBlockGenerationTimeInSecond(), sec);
        vm.stopPrank();
    }

    function test_updateConfig(uint256 value) public {
        vm.assume(value > 0);
        require(value > 0);
        
        vm.expectRevert(); // unauthorized
        priceOracleManager.updateConfig(value, value);
        
        vm.startPrank(address(governanceTimelockController));

        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        priceOracleManager.updateConfig(0, value);
        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        priceOracleManager.updateConfig(value, 0);

        vm.expectEmit();
        emit IPriceOracleManager.PriceConfigUpdated(priceOracleManager.movementDelta(), value, priceOracleManager.inactivePeriod(), value);
        priceOracleManager.updateConfig(value, value);
        assertEq(priceOracleManager.movementDelta(), value);
        assertEq(priceOracleManager.inactivePeriod(), value);
        assertEq(priceOracle.inactivePeriod(), value);
        vm.stopPrank();
    }

    function test_getConfig() public view {
        (uint256 x, uint256 y, uint256 z) = priceOracleManager.getConfig();
        assertEq(priceOracleManager.defBlockGenerationTimeInSecond(), x);
        assertEq(priceOracleManager.movementDelta(), y);
        assertEq(priceOracleManager.inactivePeriod(), z);
    }

    function test_providerCount() public {
        assertEq(priceOracleManager.providerCount(), 6);
        vm.startPrank(address(governanceTimelockController));
        governanceAction.addPriceOracleProvider(
            eoa_accounts[6],
            address(ctrl),
            1e18,
            150,
            10,
            bytes32(abi.encodePacked("123.123.123.123,192.168.100.100"))
        );
        vm.stopPrank();
        assertEq(priceOracleManager.providerCount(), 7);
    }

    function test_activeProvider_activeProviderCount() public {
        assertEq(priceOracleManager.activeProvider(eoa_accounts[7]), true);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[8]), true);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[9]), true);
        assertEq(priceOracleManager.activeProviderCount(), 6);
        
        vm.startPrank(address(governanceTimelockController));
        priceOracleManager.pauseProvider(eoa_accounts[7]);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[7]), false);
        assertEq(priceOracleManager.activeProviderCount(), 5);
        
        priceOracleManager.disableProvider(eoa_accounts[8], block.number, block.timestamp);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[8]), false);
        assertEq(priceOracleManager.activeProviderCount(), 4);

        priceOracleManager.pauseProvider(eoa_accounts[9]);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[9]), false);
        assertEq(priceOracleManager.activeProviderCount(), 3);
        vm.stopPrank();
    }

    function test_priceOracleProvider() public {
        provider = priceOracleManager.getProvider(eoa_accounts[7]);
        assertEq(provider.index, 3);
        // assertEq(provider.activatedSinceBlockNum, 1);
        // assertEq(provider.activatedTimestamp, 1);

        provider = priceOracleManager.getProvider(eoa_accounts[8]);
        assertEq(provider.index, 4);
        // assertEq(provider.activatedSinceBlockNum, 1);
        // assertEq(provider.activatedTimestamp, 1);

        provider = priceOracleManager.getProvider(eoa_accounts[9]);
        assertEq(provider.index, 5);
        // assertEq(provider.activatedSinceBlockNum, 1);
        // assertEq(provider.activatedTimestamp, 1);

        info = priceOracleManager.getProviderInfo(eoa_accounts[7]);
        assertEq(info.paymentTokenAddress, address(ctrl));
        assertEq(info.paymentAmtPerFeed, 1e18);
        assertEq(info.blockCountPerFeed, 150);
        assertEq(info.feedSize, 10);
        assertEq(info.whitelistedIPAddr, bytes32(abi.encodePacked("127.0.0.1,192.168.1.1")));

        info = priceOracleManager.getProviderInfo(eoa_accounts[8]);
        assertEq(info.paymentTokenAddress, address(ctrl));
        assertEq(info.paymentAmtPerFeed, 1e18);
        assertEq(info.blockCountPerFeed, 150);
        assertEq(info.feedSize, 10);
        assertEq(info.whitelistedIPAddr, bytes32(abi.encodePacked("123.123.123.123,192.168.100.100")));

        info = priceOracleManager.getProviderInfo(eoa_accounts[9]);
        assertEq(info.paymentTokenAddress, address(ctrl));
        assertEq(info.paymentAmtPerFeed, 1e18);
        assertEq(info.blockCountPerFeed, 150);
        assertEq(info.feedSize, 10);
        assertEq(info.whitelistedIPAddr, bytes32(abi.encodePacked("1.2.3.4,5.6.7.8,1.2.3.4,5.6.7.8")));

        tracker = priceOracleManager.getProviderTracker(eoa_accounts[7]);
        // assertEq(tracker.lastUpdatedTimestamp, 1);
        // assertEq(tracker.lastUpdatedBlockId, 1);
        // assertEq(tracker.lastPaymentBlockId, 1);
        assertEq(tracker.osPayment, 0);
        assertEq(tracker.feedMissCount, 0);

        tracker = priceOracleManager.getProviderTracker(eoa_accounts[8]);
        // assertEq(tracker.lastUpdatedTimestamp, 1);
        // assertEq(tracker.lastUpdatedBlockId, 1);
        // assertEq(tracker.lastPaymentBlockId, 1);
        assertEq(tracker.osPayment, 0);
        assertEq(tracker.feedMissCount, 0);

        tracker = priceOracleManager.getProviderTracker(eoa_accounts[9]);
        // assertEq(tracker.lastUpdatedTimestamp, 1);
        // assertEq(tracker.lastUpdatedBlockId, 1);
        // assertEq(tracker.lastPaymentBlockId, 1);
        assertEq(tracker.osPayment, 0);
        assertEq(tracker.feedMissCount, 0);
    }

    function test_addProvider(uint256 value) public {
        vm.assume(value > 0 && value < (type(uint256).max - 100));
        require(value > 0 && value < (type(uint256).max - 100));
        
        vm.expectRevert(); // unauthorized
        priceOracleManager.addProvider(value, value, owner, address(ctrl), value, value, value, bytes32(""));
        
        vm.startPrank(address(governanceTimelockController));

        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        priceOracleManager.addProvider(0, value, owner, address(ctrl), value, value, value, bytes32(""));
        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        priceOracleManager.addProvider(value, 0, owner, address(ctrl), value, value, value, bytes32(""));
        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        priceOracleManager.addProvider(value, value, owner, address(ctrl), 0, value, value, bytes32(""));
        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        priceOracleManager.addProvider(value, value, owner, address(ctrl), value, 0, value, bytes32(""));
        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        priceOracleManager.addProvider(value, value, owner, address(ctrl), value, value, 0, bytes32(""));

        vm.expectRevert(IPriceOracleManager.ZeroAddress.selector);
        priceOracleManager.addProvider(value, value, address(0), address(ctrl), value, value, value, bytes32(""));
        vm.expectRevert(IPriceOracleManager.ZeroAddress.selector);
        priceOracleManager.addProvider(value, value, owner, address(0), value, value, value, bytes32(""));

        vm.expectRevert(abi.encodeWithSelector(IPriceOracleManager.ExistedProvider.selector, eoa_accounts[7]));
        priceOracleManager.addProvider(value, value, eoa_accounts[7], address(ctrl), value, value, value, bytes32(""));

        vm.expectEmit();
        emit IPriceOracleManager.NewPriceOracleProvider(
            value,
            value,
            owner,
            address(ctrl),
            value,
            value,
            value,
            bytes32("")
        );
        priceOracleManager.addProvider(value, value, owner, address(ctrl), value, value, value, bytes32(""));
        
        nextBlock(value + 1);
        assertEq(priceOracleManager.activeProvider(owner), true);
        assertEq(priceOracleManager.activeProviderCount(), 7);

        vm.stopPrank();
    }

    function test_configureProvider(uint256 value) public {
        vm.assume(value > 0 && value < (type(uint256).max - 100));
        require(value > 0 && value < (type(uint256).max - 100));

        vm.expectRevert(); // unauthorized
        governanceAction.configurePriceOracleProvider(eoa_accounts[7], address(this), value, value, value, "123.222.444.555");
        
        bytes32 ip = bytes32(abi.encodePacked("123.222.444.555"));

        vm.startPrank(address(governanceTimelockController));

        vm.expectRevert(abi.encodeWithSelector(IPriceOracleManager.InvalidProvider.selector, owner));
        governanceAction.configurePriceOracleProvider(owner, address(this), value, value, value, ip);

        vm.expectRevert(IPriceOracleManager.ZeroAddress.selector);
        governanceAction.configurePriceOracleProvider(eoa_accounts[7], address(0), value, value, value, ip);

        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        governanceAction.configurePriceOracleProvider(eoa_accounts[7], address(this), 0, value, value, ip);
        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        governanceAction.configurePriceOracleProvider(eoa_accounts[7], address(this), value, 0, value, ip);
        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        governanceAction.configurePriceOracleProvider(eoa_accounts[7], address(this), value, value, 0, ip);

        vm.expectEmit();
        emit IPriceOracleManager.ConfigProvider(
            eoa_accounts[7], 
            address(this), 
            value, 
            value, 
            value, 
            ip
        );
        governanceAction.configurePriceOracleProvider(eoa_accounts[7], address(this), value, value, value, ip);

        provider = priceOracleManager.getProvider(eoa_accounts[7]);
        assertEq(provider.index, 3);
        // assertEq(provider.activatedSinceBlockNum, 1);
        // assertEq(provider.activatedTimestamp, 1);

        info = priceOracleManager.getProviderInfo(eoa_accounts[7]);
        assertEq(info.paymentTokenAddress, address(this));
        assertEq(info.paymentAmtPerFeed, value);
        assertEq(info.blockCountPerFeed, value);
        assertEq(info.feedSize, value);
        assertEq(info.whitelistedIPAddr, ip);

        tracker = priceOracleManager.getProviderTracker(eoa_accounts[7]);
        // assertEq(tracker.lastUpdatedTimestamp, 1);
        // assertEq(tracker.lastUpdatedBlockId, 1);
        // assertEq(tracker.lastPaymentBlockId, 1);
        assertEq(tracker.osPayment, 0);
        assertEq(tracker.feedMissCount, 0);

        vm.stopPrank();
    }

    function test_pauseProvider_unpauseProvider() public {
        vm.expectRevert(); // unauthorized
        governanceAction.pausePriceOracleProvider(eoa_accounts[7]);
        vm.expectRevert();
        governanceAction.unpausePriceOracleProvider(eoa_accounts[7]);
        
        vm.startPrank(address(governanceTimelockController));
        
        vm.expectRevert(abi.encodeWithSelector(IPriceOracleManager.InvalidProvider.selector, eoa_accounts[6]));
        governanceAction.pausePriceOracleProvider(eoa_accounts[6]); // provider not existed

        vm.expectRevert(abi.encodeWithSelector(IPriceOracleManager.InvalidProvider.selector, eoa_accounts[6]));
        governanceAction.unpausePriceOracleProvider(eoa_accounts[6]); // provider not existed

        vm.expectEmit(address(priceOracleManager));
        emit IPriceOracleManager.PausedProvider(eoa_accounts[7]);
        vm.expectEmit(address(governanceAction));
        emit IGovernanceAction.PausedPriceOracleProvider(eoa_accounts[7]);
        governanceAction.pausePriceOracleProvider(eoa_accounts[7]);

        provider = priceOracleManager.getProvider(eoa_accounts[7]);
        assertEq(provider.paused, true);

        vm.expectRevert(abi.encodeWithSelector(IPriceOracleManager.InvalidProvider.selector, eoa_accounts[7]));
        governanceAction.pausePriceOracleProvider(eoa_accounts[7]); // already paused

        vm.expectEmit(address(priceOracleManager));
        emit IPriceOracleManager.UnpausedProvider(eoa_accounts[7]);
        vm.expectEmit(address(governanceAction));
        emit IGovernanceAction.UnpausedPriceOracleProvider(eoa_accounts[7]);
        governanceAction.unpausePriceOracleProvider(eoa_accounts[7]);

        provider = priceOracleManager.getProvider(eoa_accounts[7]);
        assertEq(provider.paused, false);

        vm.expectRevert(abi.encodeWithSelector(IPriceOracleManager.InvalidProvider.selector, eoa_accounts[7]));
        governanceAction.unpausePriceOracleProvider(eoa_accounts[7]); // already unpaused

        vm.stopPrank();
    }

    function test_disableProvider() public {
        vm.expectRevert(); // unauthorized
        governanceAction.removePriceOracleProvider(eoa_accounts[4], 1, 1); // not existed

        vm.startPrank(address(governanceTimelockController));

        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        governanceAction.removePriceOracleProvider(eoa_accounts[7], 0, 1);
        vm.expectRevert(IPriceOracleManager.ZeroValue.selector);
        governanceAction.removePriceOracleProvider(eoa_accounts[7], 1, 0);

        vm.expectRevert();
        governanceAction.removePriceOracleProvider(eoa_accounts[6], 1, 1); // provider not existed

        vm.expectEmit(address(priceOracleManager));
        emit IPriceOracleManager.DisabledProvider(eoa_accounts[7], 1, 1);
        vm.expectEmit(address(governanceAction));
        emit IGovernanceAction.RemovedPriceOracleProvider(eoa_accounts[7], 1, 1);
        governanceAction.removePriceOracleProvider(eoa_accounts[7], 1, 1);

        provider = priceOracleManager.getProvider(eoa_accounts[7]);
        // assertEq(provider.disabledOnBlockId, 1);
        // assertEq(provider.disabledTimestamp, 1);
        assertEq(priceOracleManager.providerCount(), 6);
        assertEq(priceOracleManager.activeProviderCount(), 5);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[7]), false);

        vm.expectRevert(abi.encodeWithSelector(IPriceOracleManager.InvalidProvider.selector, eoa_accounts[7]));
        governanceAction.unpausePriceOracleProvider(eoa_accounts[7]); // already removed

        vm.stopPrank();
    }

    function test_submitProviderFeedCount() public {
        vm.expectRevert(); // unauthorized
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, block.timestamp);

        // assume tab-oracle module submits provider performance on every 6 hours
        nextBlock(6 hours); 
        
        vm.startPrank(oracleProviderPerformanceSignerAddr);

        uint256 amtToPay = 72 * 1e18;
        vm.expectEmit();
        emit IPriceOracleManager.MissedFeed(providerList[0], 2, 2);
        emit IPriceOracleManager.MissedFeed(providerList[1], 1, 1);
        emit IPriceOracleManager.PaymentReady(providerList[2], amtToPay, amtToPay);
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, block.timestamp);

        tracker = priceOracleManager.getProviderTracker(eoa_accounts[7]);
        assertEq(tracker.lastUpdatedTimestamp, block.timestamp);
        assertEq(tracker.lastUpdatedBlockId, block.number);
        // assertEq(tracker.lastPaymentBlockId, 1);
        assertEq(tracker.osPayment, 70e18);
        assertEq(tracker.feedMissCount, 2);

        tracker = priceOracleManager.getProviderTracker(eoa_accounts[8]);
        assertEq(tracker.lastUpdatedTimestamp, block.timestamp);
        assertEq(tracker.lastUpdatedBlockId, block.number);
        // assertEq(tracker.lastPaymentBlockId, 1);
        assertEq(tracker.osPayment, 71e18);
        assertEq(tracker.feedMissCount, 1);

        tracker = priceOracleManager.getProviderTracker(eoa_accounts[9]);
        assertEq(tracker.lastUpdatedTimestamp, block.timestamp);
        assertEq(tracker.lastUpdatedBlockId, block.number);
        // assertEq(tracker.lastPaymentBlockId, 1);
        assertEq(tracker.osPayment, 72e18);
        assertEq(tracker.feedMissCount, 0);

        nextBlock(10); // short period since last update, expect no payment
        vm.startPrank(oracleProviderPerformanceSignerAddr);
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, block.timestamp);
        tracker = priceOracleManager.getProviderTracker(eoa_accounts[7]);
        assertEq(tracker.lastUpdatedTimestamp, block.timestamp);
        assertEq(tracker.lastUpdatedBlockId, block.number);
        // assertEq(tracker.lastPaymentBlockId, 1);
        assertEq(tracker.osPayment, 70e18);
        assertEq(tracker.feedMissCount, 2);

        vm.stopPrank();
    }

    function test_withdrawPayment() public {
        vm.expectRevert(); // unauthorized
        priceOracleManager.withdrawPayment(address(this));

        vm.startPrank(address(governanceTimelockController));
        governanceAction.removePriceOracleProvider(eoa_accounts[7], block.timestamp, block.timestamp);
        vm.stopPrank();
        vm.startPrank(eoa_accounts[7]);
        vm.expectRevert(abi.encodeWithSelector(IPriceOracleManager.InvalidProvider.selector, eoa_accounts[7]));
        priceOracleManager.withdrawPayment(address(this));
        vm.stopPrank();

        feedCount[1] = 0; // eoa_accounts[8] is having zero submission count

        // submit feed performance for 3 providers
        nextBlock(6 hours); 
        vm.startPrank(oracleProviderPerformanceSignerAddr);
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, block.timestamp);

        vm.startPrank(eoa_accounts[8]);
        vm.expectRevert(IPriceOracleManager.ZeroOutstandingAmount.selector);
        priceOracleManager.withdrawPayment(address(this));
        vm.stopPrank();

        vm.startPrank(eoa_accounts[9]);
        vm.expectRevert(abi.encodeWithSelector(IPriceOracleManager.InsufficientBalance.selector, 72e18));
        priceOracleManager.withdrawPayment(address(this));
        vm.stopPrank();

        vm.startPrank(eoa_accounts[9]);
        vm.expectEmit();
        emit IPriceOracleManager.GiveUpPayment(eoa_accounts[9], 72e18);
        priceOracleManager.withdrawPayment(address(0));
        tracker = priceOracleManager.getProviderTracker(eoa_accounts[9]);
        assertEq(tracker.lastUpdatedTimestamp, block.timestamp);
        assertEq(tracker.lastUpdatedBlockId, block.number);
        assertEq(tracker.lastPaymentBlockId, block.number);
        assertEq(tracker.osPayment, 0);
        assertEq(tracker.feedMissCount, 0);
        vm.stopPrank();

        nextBlock(6 hours);
        vm.startPrank(oracleProviderPerformanceSignerAddr);
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, block.timestamp);

        vm.startPrank(deployer);
        ctrl.mint(address(priceOracleManager), 100e18);

        vm.startPrank(eoa_accounts[9]);
        vm.expectEmit();
        emit IPriceOracleManager.WithdrewPayment(eoa_accounts[9], 72e18);
        priceOracleManager.withdrawPayment(address(this));
        vm.stopPrank();
        tracker = priceOracleManager.getProviderTracker(eoa_accounts[9]);
        assertEq(tracker.lastUpdatedTimestamp, block.timestamp);
        assertEq(tracker.lastUpdatedBlockId, block.number);
        assertEq(tracker.lastPaymentBlockId, block.number);
        assertEq(tracker.osPayment, 0);
        assertEq(tracker.feedMissCount, 0);
        assertEq(ctrl.balanceOf(address(this)), 72e18);
        assertEq(ctrl.balanceOf(address(priceOracleManager)), 100e18 - 72e18);
    }
}
