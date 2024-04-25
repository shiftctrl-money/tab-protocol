// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { FixedPointMathLib } from "lib/solady/src/utils/FixedPointMathLib.sol";
import { IGovernanceAction } from "../../contracts/governance/interfaces/IGovernanceAction.sol";
import { IPriceOracleManager } from "../../contracts/oracle/interfaces/IPriceOracleManager.sol";

import { Deployer } from "./Deployer.t.sol";
import { RateSimulator } from "./helper/RateSimulator.sol";

contract PriceOracleManagerTest is Test, Deployer {

    IGovernanceAction governanceAction;

    IPriceOracleManager priceOracleManager;
    RateSimulator rs;

    // updatePrice
    bytes3[10] tab10;
    uint256[10] price10;
    bytes updatePriceData;

    // submitProviderFeedCount
    address[10] providerList;
    uint256[10] feedCount;

    bytes data;

    struct TabPool {
        bytes3 tab;
        uint256 timestamp;
        uint256 listSize;
        uint256[9] mediumList;
    }

    TabPool[10] tabPools;

    struct CID {
        bytes32 ipfsCID_1;
        bytes32 ipfsCID_2;
    }

    struct OracleProvider {
        uint256 index;
        uint256 activatedSinceBlockId;
        uint256 activatedTimestamp;
        uint256 disabledOnBlockId;
        uint256 disabledTimestamp;
        bool paused;
    }

    struct Tracker {
        uint256 lastUpdatedTimestamp;
        uint256 lastUpdatedBlockId;
        uint256 lastPaymentBlockId;
        uint256 osPayment; // accumulated payment
        uint256 feedMissCount; // value increased whenever provider missed configured feed count
    }

    struct Info {
        address paymentTokenAddress;
        uint256 paymentAmtPerFeed;
        uint256 blockCountPerFeed;
        uint256 feedSize;
        bytes32 whitelistedIPAddr;
    }

    bytes32 cid1;
    bytes32 cid2;
    string cid;
    CID cidParts;

    event PausedPriceOracleProvider(address indexed _provider);
    event UnpausedPriceOracleProvider(address indexed _provider);
    event RemovedPriceOracleProvider(address indexed _provider, uint256 blockNum, uint256 timestamp);
    event PriceUpdated(uint256 indexed _timestamp, string indexed cid);
    event MedianPriceStorage(uint256 indexed timestamp, bytes3 indexed tab, uint256[] prices, uint256 median);
    event IgnoredPrice(
        bytes3 indexed tab, uint256 indexed timestamp, uint256 droppedMedianPrice, uint256 existingPrice
    );
    event UpdatedPrice(bytes3 indexed _tab, uint256 _oldPrice, uint256 _newPrice, uint256 _timestamp);
    event MissedFeed(address indexed provider, uint256 missedCount, uint256 totalMissedCount);
    event UpdatedDefBlockGenerationTimeInSecond(uint256 b4, uint256 _after);
    event AdjustedSecondPerBlock(uint256 old_value, uint256 new_value);
    event PaymentReady(address indexed provider, uint256 added, uint256 totalOS);
    event WithdrewPayment(address indexed provider, uint256 amt);
    event GiveUpPayment(address indexed provider, uint256 amt);

    event Upgraded(address indexed implementation);

    function setUp() public {
        test_deploy();

        governanceAction = IGovernanceAction(governanceActionAddr);
        priceOracleManager = IPriceOracleManager(priceOracleManagerAddr);

        rs = new RateSimulator();
        (tab10, price10) = rs.retrieve10(100);

        for (uint256 i = 0; i < 10; i++) {
            vaultManager.initNewTab(tab10[i]); // tab creation order: TabRegistry, PriceOracleManager
            uint256[9] memory prices;
            for (uint256 n = 0; n < 9; n++) {
                prices[n] = price10[i] + n;
            }
            tabPools[i] = TabPool(tab10[i], block.timestamp, 9, prices);
        }

        (cid1, cid2, cid) = generateCID("bafkreiflhctgqx6pcu6kkzqo5nxkhttdxsduopoajd7irdcehs4fdrzwj4");
        cidParts = CID(cid1, cid2);

        nextBlock(1);
        governanceAction.addPriceOracleProvider(
            eoa_accounts[7], // provider
            address(ctrl), // paymentTokenAddress
            1000000000000000000, // paymentAmtPerFeed
            25, // blockCountPerFeed: expect 1 feed for each 25 blocks
            10, // feedSize: provider sends at least 10 currency pairs per feed
            bytes32(abi.encodePacked("127.0.0.1,192.168.1.1")) // whitelistedIPAddr
        );

        nextBlock(1);
        governanceAction.addPriceOracleProvider(
            eoa_accounts[8],
            address(ctrl),
            1000000000000000000,
            25,
            10,
            bytes32(abi.encodePacked("123.123.123.123,192.168.100.100"))
        );

        nextBlock(1);
        governanceAction.addPriceOracleProvider(
            eoa_accounts[9],
            address(ctrl),
            1000000000000000000,
            25,
            10,
            bytes32(abi.encodePacked("1.2.3.4,5.6.7.8,1.2.3.4,5.6.7.8"))
        ); // 4 IP, max length 31

        providerList[0] = eoa_accounts[7];
        providerList[1] = eoa_accounts[8];
        providerList[2] = eoa_accounts[9];

        feedCount[0] = 1;
        feedCount[1] = 2;
        feedCount[2] = 3;

        for (uint256 i = 3; i < 10; i++) {
            providerList[i] = address(0);
            feedCount[i] = 0;
        }
    }

    function nextBlock(uint256 increment) internal {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
        for (uint256 i = 0; i < tabPools.length; i++) {
            tabPools[i].timestamp = block.timestamp;
        }
    }

    function testCreateTab() public {
        assertEq(tabRegistry.activatedTabCount(), 10);
        for (uint256 i = 0; i < 10; i++) {
            assertEq(tabRegistry.tabList(i), tab10[i]);
            emit log_address(tabRegistry.tabs(tab10[i]));

            assertEq(priceOracleManager.tabList(i), tab10[i]);
            assertEq(priceOracleManager.tabs(tab10[i]), true);
        }
    }

    function testPriceOracleProvider() public {
        nextBlock(1);

        assertEq(priceOracleManager.providerCount(), 3);
        assertEq(priceOracleManager.activeProviderCount(), 3);

        assertEq(priceOracleManager.activeProvider(eoa_accounts[7]), true);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[8]), true);
        assertEq(priceOracleManager.activeProvider(eoa_accounts[9]), true);

        assertEq(priceOracleManager.providerList(0), eoa_accounts[7]);
        assertEq(priceOracleManager.providerList(1), eoa_accounts[8]);
        assertEq(priceOracleManager.providerList(2), eoa_accounts[9]);

        uint256 index;
        uint256 activatedSinceBlockId;
        uint256 activatedTimestamp;

        (index, activatedSinceBlockId, activatedTimestamp,,,) = priceOracleManager.providers(eoa_accounts[7]);
        assertEq(index, 0);
        assertEq(activatedSinceBlockId, 2);
        assertEq(activatedTimestamp, 2);

        (index, activatedSinceBlockId, activatedTimestamp,,,) = priceOracleManager.providers(eoa_accounts[8]);
        assertEq(index, 1);
        assertEq(activatedSinceBlockId, 3);
        assertEq(activatedTimestamp, 3);

        (index, activatedSinceBlockId, activatedTimestamp,,,) = priceOracleManager.providers(eoa_accounts[9]);
        assertEq(index, 2);
        assertEq(activatedSinceBlockId, 4);
        assertEq(activatedTimestamp, 4);

        uint256 govActivatedSinceBlockId;
        uint256 govActivatedTimestamp;
        (govActivatedSinceBlockId, govActivatedTimestamp,,) = governanceAction.providers(eoa_accounts[7]);
        assertEq(govActivatedSinceBlockId, 2);
        assertEq(govActivatedTimestamp, 2);

        (govActivatedSinceBlockId, govActivatedTimestamp,,) = governanceAction.providers(eoa_accounts[8]);
        assertEq(govActivatedSinceBlockId, 3);
        assertEq(govActivatedTimestamp, 3);

        (govActivatedSinceBlockId, govActivatedTimestamp,,) = governanceAction.providers(eoa_accounts[9]);
        assertEq(govActivatedSinceBlockId, 4);
        assertEq(govActivatedTimestamp, 4);

        address paymentTokenAddress;
        uint256 paymentAmtPerFeed;
        uint256 blockCountPerFeed;
        uint256 feedSize;
        bytes32 whitelistedIPAddr;

        (paymentTokenAddress, paymentAmtPerFeed, blockCountPerFeed, feedSize, whitelistedIPAddr) =
            priceOracleManager.providerInfo(eoa_accounts[7]);
        assertEq(paymentTokenAddress, address(ctrl));
        assertEq(paymentAmtPerFeed, 1000000000000000000);
        assertEq(blockCountPerFeed, 25);
        assertEq(feedSize, 10);
        assertEq(whitelistedIPAddr, bytes32(abi.encodePacked("127.0.0.1,192.168.1.1")));

        (paymentTokenAddress, paymentAmtPerFeed, blockCountPerFeed, feedSize, whitelistedIPAddr) =
            priceOracleManager.providerInfo(eoa_accounts[8]);
        assertEq(paymentTokenAddress, address(ctrl));
        assertEq(paymentAmtPerFeed, 1000000000000000000);
        assertEq(blockCountPerFeed, 25);
        assertEq(feedSize, 10);
        assertEq(whitelistedIPAddr, bytes32(abi.encodePacked("123.123.123.123,192.168.100.100")));

        (paymentTokenAddress, paymentAmtPerFeed, blockCountPerFeed, feedSize, whitelistedIPAddr) =
            priceOracleManager.providerInfo(eoa_accounts[9]);
        assertEq(paymentTokenAddress, address(ctrl));
        assertEq(paymentAmtPerFeed, 1000000000000000000);
        assertEq(blockCountPerFeed, 25);
        assertEq(feedSize, 10);
        assertEq(whitelistedIPAddr, bytes32(abi.encodePacked("1.2.3.4,5.6.7.8,1.2.3.4,5.6.7.8")));

        uint256 lastUpdatedTimestamp;
        uint256 lastUpdatedBlockId;
        uint256 lastPaymentBlockId;
        uint256 osPayment;
        uint256 feedMissCount;

        (lastUpdatedTimestamp, lastUpdatedBlockId, lastPaymentBlockId, osPayment, feedMissCount) =
            priceOracleManager.providerTracker(eoa_accounts[7]);
        assertEq(lastUpdatedTimestamp, 2);
        assertEq(lastUpdatedBlockId, 2);
        assertEq(lastPaymentBlockId, 2);
        assertEq(osPayment, 0);
        assertEq(feedMissCount, 0);

        (lastUpdatedTimestamp, lastUpdatedBlockId, lastPaymentBlockId, osPayment, feedMissCount) =
            priceOracleManager.providerTracker(eoa_accounts[8]);
        assertEq(lastUpdatedTimestamp, 3);
        assertEq(lastUpdatedBlockId, 3);
        assertEq(lastPaymentBlockId, 3);
        assertEq(osPayment, 0);
        assertEq(feedMissCount, 0);

        (lastUpdatedTimestamp, lastUpdatedBlockId, lastPaymentBlockId, osPayment, feedMissCount) =
            priceOracleManager.providerTracker(eoa_accounts[9]);
        assertEq(lastUpdatedTimestamp, 4);
        assertEq(lastUpdatedBlockId, 4);
        assertEq(lastPaymentBlockId, 4);
        assertEq(osPayment, 0);
        assertEq(feedMissCount, 0);
    }

    function testConfigureProvider() public {
        vm.startPrank(eoa_accounts[5]);
        vm.expectRevert();
        governanceAction.configurePriceOracleProvider(
            eoa_accounts[7], address(this), 999, 1, 1, "123.222.444.555"
        );
        vm.stopPrank();

        governanceAction.configurePriceOracleProvider(
            eoa_accounts[7], address(this), 999, 10, 99, "123.222.444.555"
        );

        address paymentTokenAddress;
        uint256 paymentAmtPerFeed;
        uint256 blockCountPerFeed;
        uint256 feedSize;
        bytes32 whitelistedIPAddr;
        (paymentTokenAddress, paymentAmtPerFeed, blockCountPerFeed, feedSize, whitelistedIPAddr) =
            priceOracleManager.providerInfo(eoa_accounts[7]);
        assertEq(paymentTokenAddress, address(this));
        assertEq(paymentAmtPerFeed, 999);
        assertEq(blockCountPerFeed, 10);
        assertEq(feedSize, 99);
        assertEq(whitelistedIPAddr, bytes32(abi.encodePacked("123.222.444.555")));
    }

    function testPauseProvider() public {
        vm.startPrank(eoa_accounts[5]);
        vm.expectRevert();
        governanceAction.pausePriceOracleProvider(eoa_accounts[7]); // no permission

        vm.expectRevert();
        priceOracleManager.pauseProvider(eoa_accounts[7]); // no permission

        vm.stopPrank();

        vm.expectRevert();
        governanceAction.pausePriceOracleProvider(eoa_accounts[6]); // provider not existed

        vm.expectEmit(true, false, false, true);
        emit PausedPriceOracleProvider(eoa_accounts[8]);
        governanceAction.pausePriceOracleProvider(eoa_accounts[8]);

        // attempt to pause again when provider is already paused
        vm.expectRevert();
        governanceAction.pausePriceOracleProvider(eoa_accounts[8]);
    }

    function testUnpauseProvider() public {
        vm.startPrank(eoa_accounts[5]);
        vm.expectRevert();
        governanceAction.unpausePriceOracleProvider(eoa_accounts[7]); // no permission

        vm.stopPrank();

        vm.expectRevert();
        governanceAction.unpausePriceOracleProvider(eoa_accounts[7]); // provider is active

        vm.expectRevert();
        governanceAction.unpausePriceOracleProvider(eoa_accounts[0]); // provider not existed

        vm.expectEmit(true, false, false, true);
        emit PausedPriceOracleProvider(eoa_accounts[9]);
        governanceAction.pausePriceOracleProvider(eoa_accounts[9]);

        vm.expectEmit(true, false, false, true);
        emit UnpausedPriceOracleProvider(eoa_accounts[9]);
        governanceAction.unpausePriceOracleProvider(eoa_accounts[9]);
    }

    function testDisableProvider() public {
        vm.expectRevert();
        governanceAction.removePriceOracleProvider(eoa_accounts[4], 1, 1); // not existed

        vm.expectRevert();
        governanceAction.removePriceOracleProvider(eoa_accounts[7], 0, 0); // zero block number and timestamp

        nextBlock(1);
        uint256 index;
        uint256 disabledOnBlockId;
        uint256 disabledTimestamp;
        uint256 activeCount = priceOracleManager.activeProviderCount();
        console.log("active provider before disable: ", activeCount); // 3

        vm.expectEmit(true, false, false, true);
        emit RemovedPriceOracleProvider(eoa_accounts[7], block.number + 10, block.timestamp + 10);
        governanceAction.removePriceOracleProvider(eoa_accounts[7], block.number + 10, block.timestamp + 10);
        assertEq(activeCount - 1, priceOracleManager.activeProviderCount());

        address lastProvider = priceOracleManager.providerList(2); // expect to be eoa_accounts[9]
        (index,,, disabledOnBlockId, disabledTimestamp,) = priceOracleManager.providers(lastProvider);
        assertEq(index, 2);

        (index,,, disabledOnBlockId, disabledTimestamp,) = priceOracleManager.providers(eoa_accounts[7]);
        assertEq(index, 0);
        assertEq(disabledOnBlockId, 15);
        assertEq(disabledTimestamp, 15);

        governanceAction.removePriceOracleProvider(eoa_accounts[9], block.number + 10, block.timestamp + 10);
        governanceAction.removePriceOracleProvider(eoa_accounts[8], block.number + 10, block.timestamp + 10);

        assertEq(0, priceOracleManager.activeProviderCount());
        assertEq(3, priceOracleManager.providerCount());

        nextBlock(1);
        vm.expectRevert(); // already disabled
        governanceAction.removePriceOracleProvider(eoa_accounts[8], block.number + 10, block.timestamp + 10); 
    }

    function testWithdrawPayment() public {
        nextBlock(1);

        vm.expectRevert();
        priceOracleManager.withdrawPayment(eoa_accounts[3]); // no permission

        vm.startPrank(eoa_accounts[7]);

        vm.expectRevert();
        priceOracleManager.withdrawPayment(eoa_accounts[3]); // no os amt

        vm.stopPrank();

        governanceAction.configurePriceOracleProvider(
            eoa_accounts[7], address(ctrl), 1000000000000000000, 25, 10, "123.222.444.555"
        );
        governanceAction.configurePriceOracleProvider(
            eoa_accounts[8], address(ctrl), 1000000000000000000, 25, 10, "123.222.444.555"
        );

        vm.expectEmit(true, true, true, true, priceOracleManagerAddr);
        emit AdjustedSecondPerBlock(12, 1);
        vm.expectEmit(true, true, true, true, governanceActionAddr);
        emit UpdatedDefBlockGenerationTimeInSecond(12, 1);
        governanceAction.setDefBlockGenerationTimeInSecond(1);

        nextBlock(300);
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData); // first time feed sent

        uint256 paymentTimestamp = block.timestamp;
        vm.expectEmit();
        emit PaymentReady(eoa_accounts[7], 1e18, 1e18);
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, paymentTimestamp);

        Tracker memory t;
        (t.lastUpdatedTimestamp, t.lastUpdatedBlockId, t.lastPaymentBlockId, t.osPayment, t.feedMissCount) =
            priceOracleManager.providerTracker(eoa_accounts[7]);

        assertEq(t.lastUpdatedTimestamp, paymentTimestamp);
        assertEq(t.feedMissCount, 11);
        assertEq(t.osPayment, 1e18);
        console.log("Triggered first updatePrice.");

        nextBlock(12 hours);
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData); // second time feed

        paymentTimestamp = block.timestamp;
        vm.expectEmit();
        emit PaymentReady(eoa_accounts[7], 1e18, 2e18);
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, paymentTimestamp);

        (t.lastUpdatedTimestamp, t.lastUpdatedBlockId, t.lastPaymentBlockId, t.osPayment, t.feedMissCount) =
            priceOracleManager.providerTracker(eoa_accounts[7]);

        assertEq(t.lastUpdatedTimestamp, paymentTimestamp);
        assertEq(t.feedMissCount, 11 + (60 * 60 * 12 / 25) - 1);
        assertEq(t.osPayment, 2e18);

        nextBlock(1 minutes);
        vm.startPrank(eoa_accounts[7]);
        vm.expectRevert();
        priceOracleManager.withdrawPayment(eoa_accounts[1]); // revert InsufficientBalance
        vm.stopPrank();

        ctrl.mint(priceOracleManagerAddr, 2e18);

        vm.startPrank(eoa_accounts[7]);
        vm.expectEmit(true, true, true, true);
        emit WithdrewPayment(eoa_accounts[7], 2e18);
        priceOracleManager.withdrawPayment(eoa_accounts[1]);
        vm.stopPrank();

        (t.lastUpdatedTimestamp, t.lastUpdatedBlockId, t.lastPaymentBlockId, t.osPayment, t.feedMissCount) =
            priceOracleManager.providerTracker(eoa_accounts[7]);
        assertEq(t.osPayment, 0);
        assertEq(t.lastPaymentBlockId, block.number);
        assertEq(ctrl.balanceOf(priceOracleManagerAddr), 0);
        console.log("withdrawal is performed successfully");

        // earn and give up payment
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);

        nextBlock(12 hours);

        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);

        paymentTimestamp = block.timestamp;
        feedCount[0] = 2;
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, paymentTimestamp);

        (t.lastUpdatedTimestamp, t.lastUpdatedBlockId, t.lastPaymentBlockId, t.osPayment, t.feedMissCount) =
            priceOracleManager.providerTracker(eoa_accounts[7]);
        assertEq(t.lastUpdatedTimestamp, paymentTimestamp);
        assertEq(t.feedMissCount, 11 + (60 * 60 * 12 / 25) - 1 + 2 + (60 * 60 * 12 / 25) - 2); // 1738 + 2(60/25=2.4) + 1728 - 2 = 3466
        assertEq(t.osPayment, 2e18);
        console.log("preparing to give up payment...");

        nextBlock(1 minutes);
        vm.startPrank(eoa_accounts[7]);
        vm.expectEmit(true, true, true, true, priceOracleManagerAddr);
        emit GiveUpPayment(eoa_accounts[7], 2e18);
        priceOracleManager.withdrawPayment(address(0));
        vm.stopPrank();

        (t.lastUpdatedTimestamp, t.lastUpdatedBlockId, t.lastPaymentBlockId, t.osPayment, t.feedMissCount) =
            priceOracleManager.providerTracker(eoa_accounts[7]);
        assertEq(t.osPayment, 0);
        assertEq(t.lastPaymentBlockId, block.number);
        console.log("give up payment done.");
    }

    function generateCID(string memory s) internal pure returns (bytes32, bytes32, string memory) {
        bytes memory bcid = abi.encodePacked(s);
        bytes memory part1 = new bytes(32);
        for (uint256 i = 0; i < 31; i++) {
            part1[i] = bcid[i];
        }
        bytes memory part2 = new bytes(28);
        for (uint256 i = 0; i < 28; i++) {
            part2[i] = bcid[i + 31];
        }
        return (bytes32(part1), bytes32(part2), s);
    }

    function testUpdatePrice() public {
        nextBlock(1);

        vm.startPrank(eoa_accounts[2]);
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        vm.expectRevert();
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData); // no permission
        vm.stopPrank();

        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);
        for (uint256 i = 0; i < tabPools.length; i++) {
            assertEq(priceOracleManager.prices(tab10[i]), priceOracle.getOldPrice(tab10[i]));
            assertEq(priceOracleManager.lastUpdated(tab10[i]), priceOracle.lastUpdated(tab10[i]));
        }

        nextBlock(5 minutes);

        uint256 oldPrice = priceOracleManager.prices(tab10[0]);
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        // within 5 minutes update again, expect ignored price due to same price
        vm.expectEmit();
        emit IgnoredPrice(tabPools[0].tab, tabPools[0].timestamp, oldPrice, oldPrice);
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);

        // changed price +10%, expect price is accepted & updated
        for (uint256 i = 0; i < tabPools.length; i++) {
            tabPools[i].mediumList[4] = FixedPointMathLib.mulDiv(tabPools[i].mediumList[4], 110, 100);
        } // medium item is changed
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        vm.expectEmit(address(priceOracle));
        emit UpdatedPrice(tabPools[0].tab, oldPrice, tabPools[0].mediumList[4], tabPools[0].timestamp);
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);

        nextBlock(30 minutes);

        oldPrice = tabPools[0].mediumList[4];
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        // within 30m and same price, expect ignore
        vm.expectEmit();
        emit IgnoredPrice(tabPools[0].tab, tabPools[0].timestamp, oldPrice, oldPrice);
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);

        nextBlock(30 minutes);
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        // now >= (last_updated + inactivePeriod 1 hour), accept feed
        vm.expectEmit(address(priceOracle));
        emit UpdatedPrice(tabPools[0].tab, oldPrice, oldPrice, tabPools[0].timestamp);
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);
    }

    function testUpdatePrice_missedFeed() public {
        nextBlock(1);

        governanceAction.configurePriceOracleProvider(
            eoa_accounts[7], address(ctrl), 1e18, 25, 10, "123.222.444.555"
        );

        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        vm.expectEmit(address(priceOracle));
        emit UpdatedPrice(tabPools[0].tab, 0, tabPools[0].mediumList[4], tabPools[0].timestamp);
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);

        // expected missing count for 1 hours = 60 * 60 / 12 / 25 = 12
        nextBlock(1 hours);

        feedCount[0] = 0;
        feedCount[1] = 0;
        feedCount[2] = 0;
        vm.expectEmit();
        emit MissedFeed(providerList[0], 12, 12);
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, block.timestamp);

        nextBlock(1 hours);
        vm.expectEmit();
        emit MissedFeed(providerList[0], 12, 24);
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, block.timestamp);

        nextBlock(1 hours);
        feedCount[0] = 2;
        vm.expectEmit();
        emit MissedFeed(providerList[0], 10, 36 - 2);
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, block.timestamp);

        nextBlock(5 minutes + 1);
        feedCount[0] = 1;
        vm.expectEmit();
        emit PaymentReady(providerList[0], 1e18, 3e18); // prev 2 feeds + current 1 feed
        priceOracleManager.submitProviderFeedCount(providerList, feedCount, block.timestamp);
    }

    function testUpdatePrice_mediumList() public {
        for (uint256 i = 0; i < 10; i++) {
            tabPools[i].listSize = 4;
        } // even medium list size
        for (uint256 i = 4; i < 9; i++) {
            tabPools[0].mediumList[i] = 0;
        }

        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        vm.expectEmit(address(priceOracle));
        emit UpdatedPrice(
            tabPools[0].tab, 0, (tabPools[0].mediumList[1] + tabPools[0].mediumList[2]) / 2, tabPools[0].timestamp
        );
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);
    }

}
