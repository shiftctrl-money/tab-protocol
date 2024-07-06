// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Deployer } from "./Deployer.t.sol";
import { IAuctionManager } from "../../contracts/shared/interfaces/IAuctionManager.sol";
import { IPriceOracle } from "../../contracts/oracle/interfaces/IPriceOracle.sol";
import { IConfig } from "../../contracts/shared/interfaces/IConfig.sol";
import { IGovernanceAction } from "../../contracts/governance/interfaces/IGovernanceAction.sol";
import { TabERC20 } from "../../contracts/token/TabERC20.sol";
import { VaultUtils } from "../../contracts/VaultUtils.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract AuctionManagerTest is Test, Deployer {

    bytes32 private reserve_cBTC = keccak256("CBTC");

    uint256[] vaultIDs;
    bytes3[] _tabs;
    uint256[] _prices;
    uint256[] _timestamps;

    // AuctionBid
    address bidder;
    uint256 bidTimestamp;
    uint256 bidPrice;
    uint256 bidQty;

    address tab;
    uint256 totalBiddedTab;
    uint256 startTime;
    uint256 auctionStepDurationInSec;

    VaultUtils vaultUtils;

    // getVaultDetails
    bytes3 tabCode;
    bytes32 resKey;
    uint256 price;
    uint256 reserveAmt;
    uint256 osTab;
    uint256 reserveValue;
    uint256 minReserveValue;

    event UpdatedContractAddr(address oldVMAddr, address newVMAddr, address oldRRAddr, address newRRAddr);
    event ActiveAuction(
        uint256 indexed auctionId,
        address reserve,
        uint256 maxAvailableQty,
        uint256 auctionPrice,
        address tab,
        uint256 validTill
    );
    event LiquidatedVaultAuction(
        uint256 vaultId, address reserveAddr, uint256 maxReserveQty, address tabAddr, uint256 startPrice
    );
    event SuccessfulBid(uint256 indexed auctionId, address indexed bidder, uint256 bidPrice, uint256 bidQty);

    error InvalidVault(address vaultOwner, uint256 vaultId);

    function setUp() public {
        test_deploy();
        vaultUtils = new VaultUtils(address(vaultManager), address(reserveRegistry), address(config));

        vaultKeeper.setRiskPenaltyFrameInSecond(10);

        tabRegistry.createTab(0x555344); // USD
        _tabs = new bytes3[](1);
        _tabs[0] = 0x555344; // USD
        _prices = new uint256[](1);
        _timestamps = new uint256[](1);
        _prices[0] = 20000e18; //  drop to BTC/USD 10799.99 later
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);

        cBTC.mint(eoa_accounts[0], 6e18);
        cBTC.mint(eoa_accounts[5], 10e18);
        cBTC.mint(eoa_accounts[9], 10e18);
        assertEq(cBTC.balanceOf(eoa_accounts[0]), 6e18);

        vm.startPrank(eoa_accounts[0]);
        cBTC.approve(address(vaultManager), 6e18);
        vaultManager.createVault(reserve_cBTC, 6e18, 54000e18, signer.getUpdatePriceSignature(_tabs[0], _prices[0], _timestamps[0]));
        vaultIDs = vaultManager.getAllVaultIDByOwner(eoa_accounts[0]);
        assertEq(vaultIDs[0], 1);
        (tabCode, resKey, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[0], vaultIDs[0], priceOracle.getPrice(0x555344));
        assertEq(resKey, keccak256("CBTC"));
        assertEq(price, 20000e18);
        assertEq(reserveAmt, 6e18);
        assertEq(osTab, 54000e18);
        assertEq(reserveValue, 120000e18);
        assertEq(minReserveValue, FixedPointMathLib.mulDiv(54000e18, 180, 100));
        vm.stopPrank();

        // create another vault to get sUSD for bidding
        vm.startPrank(eoa_accounts[9]);
        cBTC.approve(address(vaultManager), 10e18);
        vaultManager.createVault(reserve_cBTC, 10e18, 60000e18, signer.getUpdatePriceSignature(_tabs[0], _prices[0], _timestamps[0]));
        vm.stopPrank();

        // price dropped and keeper's checkVault triggered liquidation
        tab = tabRegistry.tabs(0x555344);
        (,, auctionStepDurationInSec,) = IConfig(address(config)).auctionParams();

        _tabs = new bytes3[](1);
        _tabs[0] = 0x555344; // USD
        _prices = new uint256[](1);
        _timestamps = new uint256[](1);
        _prices[0] = 1079999e16;
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        bytes memory checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256),(address,address,bytes3,uint256,uint256,uint8,bytes32,bytes32))",
            block.timestamp,
            eoa_accounts[0],
            vaultIDs[0],
            _tabs[0],
            reserve_cBTC,
            54000e18,
            6e18,
            FixedPointMathLib.mulDiv(54000e18, 180, 100),
            signer.getUpdatePriceSignature(_tabs[0], _prices[0], _timestamps[0])
        );
        startTime = block.timestamp;
        vm.expectEmit(auctionManagerAddr);
        emit ActiveAuction(
            vaultIDs[0],
            address(cBTC),
            6e18,
            FixedPointMathLib.mulDiv(_prices[0], 90, 100),
            tab,
            startTime + auctionStepDurationInSec
        );
        vm.expectEmit(vaultManagerAddr);
        emit LiquidatedVaultAuction(
            vaultIDs[0], address(cBTC), 6e18, tab, FixedPointMathLib.mulDiv(_prices[0], 90, 100)
        );
        bytes memory data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);

        // transfer tabs to bidders
        vm.startPrank(eoa_accounts[0]);
        TabERC20(tab).transfer(eoa_accounts[1], 10000e18);
        TabERC20(tab).transfer(eoa_accounts[2], 10000e18);
        TabERC20(tab).transfer(eoa_accounts[3], 10000e18);
        vm.stopPrank();
    }

    function nextBlock(uint256 increment) internal {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
    }

    function testSetContractAddress() public {
        vm.expectEmit(auctionManagerAddr);
        emit UpdatedContractAddr(vaultManagerAddr, address(10), address(reserveRegistry), address(11));
        IAuctionManager(auctionManagerAddr).setContractAddr(address(10), address(11));
        assertEq(IAuctionManager(auctionManagerAddr).vaultManagerAddr(), address(10));
        assertEq(IAuctionManager(auctionManagerAddr).reserveRegistryAddr(), address(11));
    }

    function testSetMaxStep() public {
        vm.expectRevert("INVALID_STEP");
        IAuctionManager(auctionManagerAddr).setMaxStep(0);

        IAuctionManager(auctionManagerAddr).setMaxStep(100);
    }

    // refer auction excel file
    function testCreateAuction() public {
        assertEq(cBTC.balanceOf(auctionManagerAddr), 6e18); // full vault reserve is transferred to auction manager
        assertEq(IAuctionManager(auctionManagerAddr).auctionCount(), 1);
        assertEq(IAuctionManager(auctionManagerAddr).auctionVaultIds(0), vaultIDs[0]);

        (uint256 reserveQty, uint256 auctionAvailableQty, uint256 osTabAmt, uint256 auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
        assertEq(reserveQty, 6e18);
        assertEq(auctionAvailableQty, FixedPointMathLib.divWad(osTabAmt, auctionPrice));
        assertEq(osTabAmt, 54000e18 + 145791e16);
        assertEq(auctionPrice, FixedPointMathLib.mulDiv(_prices[0], 90, 100)); // 90% of market price (10% discount on
            // auction start price)

        IAuctionManager.AuctionStep[] memory auctionSteps =
            IAuctionManager(auctionManagerAddr).getAuctionSteps(vaultIDs[0]);
        IAuctionManager.AuctionStep memory lastAuctionStep;
        for (uint256 i = 0; i < auctionSteps.length; i++) {
            if (auctionSteps[i].stepPrice == 0) {
                lastAuctionStep = auctionSteps[i - 1];
                break;
            }
            // console.log("step : ", i);
            // console.log("start time: ", auctionSteps[i].startTime);
            // console.log("step price: ", auctionSteps[i].stepPrice);
            assertEq(auctionSteps[i].startTime, startTime + (i * auctionStepDurationInSec));
        }

        (IAuctionManager.AuctionStep memory auctionStep, uint256 lastStepTimestamp) =
            IAuctionManager(auctionManagerAddr).getAuctionPrice(vaultIDs[0], block.timestamp);
        assertEq(auctionStep.startTime, startTime);
        assertEq(auctionStep.stepPrice, FixedPointMathLib.mulDiv(_prices[0], 90, 100));
        assertEq(lastStepTimestamp, lastAuctionStep.startTime);
        uint256 auctionStartPrice = auctionStep.stepPrice;

        // bidder 1
        vm.startPrank(eoa_accounts[1]);
        TabERC20(tab).approve(auctionManagerAddr, 10000e18);
        vm.expectEmit(auctionManagerAddr);
        emit SuccessfulBid(vaultIDs[0], eoa_accounts[1], auctionStartPrice, 1e18);
        IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], 1e18);
        assertEq(cBTC.balanceOf(eoa_accounts[1]), 1e18); // received BTC from bidding
        assertEq(TabERC20(tab).balanceOf(eoa_accounts[1]), 10000e18 - auctionStartPrice); // paid Tabs
        vm.stopPrank();

        // bidder 2
        vm.startPrank(eoa_accounts[2]);
        TabERC20(tab).approve(auctionManagerAddr, 10000e18);
        vm.expectEmit(auctionManagerAddr);
        emit SuccessfulBid(vaultIDs[0], eoa_accounts[2], auctionStartPrice, 1e18);
        IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], 1e18);
        assertEq(cBTC.balanceOf(eoa_accounts[2]), 1e18);
        assertEq(TabERC20(tab).balanceOf(eoa_accounts[2]), 10000e18 - auctionStartPrice);
        vm.stopPrank();

        (reserveQty, auctionAvailableQty, osTabAmt, auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
        assertEq(reserveQty, 6e18 - 1e18 - 1e18);
        assertEq(auctionAvailableQty, FixedPointMathLib.divWad(osTabAmt, FixedPointMathLib.mulDiv(_prices[0], 90, 100)));
        assertEq(osTabAmt, 54000e18 + 145791e16 - auctionStartPrice - auctionStartPrice);
        assertEq(auctionPrice, auctionStartPrice);

        auctionSteps = IAuctionManager(auctionManagerAddr).getAuctionSteps(vaultIDs[0]);

        // next step started, auction price is reduced
        nextBlock(auctionStepDurationInSec);
        startTime = block.timestamp;
        (auctionStep, lastStepTimestamp) = IAuctionManager(auctionManagerAddr).getAuctionPrice(vaultIDs[0], startTime);
        assertEq(auctionStep.startTime, startTime);
        assertEq(
            auctionStep.stepPrice, FixedPointMathLib.mulDiv(FixedPointMathLib.mulDiv(_prices[0], 90, 100), 97, 100)
        ); // 10% of market price then reduced 3%

        // bidder 3
        nextBlock(auctionStepDurationInSec + 30);
        auctionSteps = IAuctionManager(auctionManagerAddr).getAuctionSteps(vaultIDs[0]);
        (auctionStep, lastStepTimestamp) = IAuctionManager(auctionManagerAddr).getAuctionPrice(vaultIDs[0], startTime);

        vm.startPrank(eoa_accounts[3]);
        TabERC20(tab).approve(auctionManagerAddr, 10000e18);
        vm.expectEmit(auctionManagerAddr);
        emit SuccessfulBid(
            vaultIDs[0], eoa_accounts[3], FixedPointMathLib.mulDiv(auctionSteps[1].stepPrice, 97, 100), 1e18
        );
        IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], 1e18);
        assertEq(cBTC.balanceOf(eoa_accounts[3]), 1e18);
        assertEq(
            TabERC20(tab).balanceOf(eoa_accounts[3]),
            10000e18 - FixedPointMathLib.mulDiv(auctionSteps[1].stepPrice, 97, 100)
        );
        vm.stopPrank();

        // Original balance 6, after 3 bidders (each qty 1) = 6 -3 = 3
        assertEq(cBTC.balanceOf(auctionManagerAddr), 3e18);

        auctionSteps = IAuctionManager(auctionManagerAddr).getAuctionSteps(vaultIDs[0]);
        (reserveQty, auctionAvailableQty, osTabAmt, auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
        assertEq(reserveQty, 6e18 - 3e18);
        assertEq(auctionAvailableQty, FixedPointMathLib.divWad(osTabAmt, auctionPrice));
        assertEq(osTabAmt, 54000e18 + 145791e16 - auctionStartPrice - auctionStartPrice - auctionSteps[0].stepPrice);
        assertEq(auctionPrice, auctionSteps[0].stepPrice);
        auctionStartPrice = auctionSteps[1].stepPrice; // MLP

        // reached minimum liquidation price
        nextBlock(1000);

        auctionSteps = IAuctionManager(auctionManagerAddr).getAuctionSteps(vaultIDs[0]);
        assertEq(auctionSteps[0].startTime, 0);
        assertEq(auctionSteps[0].stepPrice, auctionStartPrice);

        (reserveQty, auctionAvailableQty, osTabAmt, auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
        assertEq(reserveQty, 3e18);
        assertEq(auctionAvailableQty, 3e18);
        assertEq(auctionPrice, auctionStartPrice); // MLP

        for (uint256 i = 0; i < 3; i++) {
            (bidder, bidTimestamp, bidPrice, bidQty) = IAuctionManager(auctionManagerAddr).auctionBid(vaultIDs[0], i);
            assertEq(bidder, eoa_accounts[i + 1]);

            totalBiddedTab += FixedPointMathLib.mulWad(bidPrice, bidQty);
        }
        assertEq(osTabAmt, 54000e18 + 145791e16 - totalBiddedTab);

        // last bidder, clear all outstanding tabs
        vm.startPrank(eoa_accounts[9]);
        TabERC20(tab).approve(auctionManagerAddr, 60000e18);
        vm.expectEmit(auctionManagerAddr);
        emit SuccessfulBid(vaultIDs[0], eoa_accounts[9], auctionPrice, 3e18);
        IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], 3e18);
        assertEq(cBTC.balanceOf(eoa_accounts[9]), 3e18);
        assertEq(TabERC20(tab).balanceOf(eoa_accounts[9]), 60000e18 - osTabAmt);
        vm.stopPrank();

        (tabCode, resKey, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[0], vaultIDs[0], priceOracle.getPrice(0x555344));
        assertEq(reserveAmt, 0);
        assertEq(osTab, 0);
        assertEq(reserveValue, 0);
    }

    function testInvalidAccessOnLiquidatedVault() public {
        // expect revert: non-owner try to access liquidated vault
        vm.startPrank(eoa_accounts[1]);
        vm.expectRevert(abi.encodeWithSelector(InvalidVault.selector, eoa_accounts[1], vaultIDs[0]));
        vaultManager.paybackTab(vaultIDs[0], 10e18);
        vm.stopPrank();

        cBTC.mint(eoa_accounts[0], 10e18);

        // expect revert: try to pay back Tabs on liquidated vault
        vm.startPrank(eoa_accounts[0]);
        vm.expectRevert("LIQUIDATED");
        vaultManager.paybackTab(vaultIDs[0], 10e18);

        // expect revert: vault owner increased reserve on liquidated vault
        cBTC.approve(address(vaultManager), 10e18);
        vm.expectRevert(abi.encodeWithSelector(InvalidVault.selector, eoa_accounts[0], vaultIDs[0]));
        vaultManager.depositReserve(vaultIDs[0], 10e18);
        vm.stopPrank();

        // expect revert: non-owner to increase reserve on liquidated vault
        vm.startPrank(eoa_accounts[1]);
        vm.expectRevert(abi.encodeWithSelector(InvalidVault.selector, eoa_accounts[1], vaultIDs[0]));
        vaultManager.depositReserve(vaultIDs[0], 10e18);
        vm.stopPrank();
    }

    function testLeftoverReserve() public {
        (uint256 reserveQty, uint256 auctionAvailableQty, uint256 osTabAmt, uint256 auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
        uint256 expectedLeftoverReserve = reserveQty - auctionAvailableQty;
        // console.log("expectedLeftoverReserve: ", expectedLeftoverReserve);

        // console.log("reserveQty: ", reserveQty);
        // console.log("auctionAvailableQty: ", auctionAvailableQty);
        // console.log("osTabAmt: ", osTabAmt);
        // console.log("auctionPrice: ", auctionPrice);

        vm.startPrank(eoa_accounts[9]);
        TabERC20(tab).approve(auctionManagerAddr, 60000e18);
        vm.expectEmit(auctionManagerAddr);
        // bid all available reserves
        emit SuccessfulBid(
            vaultIDs[0],
            eoa_accounts[9],
            FixedPointMathLib.mulDiv(1079999e16, 90, 100),
            FixedPointMathLib.divWad(osTabAmt, auctionPrice)
        );
        IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], 6e18);
        assertEq(cBTC.balanceOf(eoa_accounts[9]), auctionAvailableQty);
        assertEq(TabERC20(tab).balanceOf(eoa_accounts[9]), 60000e18 - osTabAmt);

        (reserveQty, auctionAvailableQty, osTabAmt, auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
        assertEq(reserveQty, expectedLeftoverReserve);
        assertEq(auctionAvailableQty, 0);
        assertEq(osTabAmt, 0);
        assertEq(auctionPrice, 0);

        (tabCode, resKey, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[0], vaultIDs[0], priceOracle.getPrice(0x555344));
        assertEq(resKey, keccak256("CBTC"));
        assertEq(price, 1079999e16);
        assertEq(reserveAmt, expectedLeftoverReserve);
        assertEq(osTab, 0);
        assertEq(reserveValue, FixedPointMathLib.mulWad(expectedLeftoverReserve, price));
        assertEq(minReserveValue, 0);

        // expect revert: non-owner attempt to claim leftover
        IPriceOracle.UpdatePriceData memory priceData = signer.getUpdatePriceSignature(tabCode, price, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(InvalidVault.selector, eoa_accounts[9], vaultIDs[0]));
        vaultManager.withdrawReserve(vaultIDs[0], reserveValue, priceData);
        vm.stopPrank();

        // claimed leftover by vault owner
        vm.startPrank(eoa_accounts[0]);
        uint256 balB4Claim = cBTC.balanceOf(eoa_accounts[0]);
        vaultManager.withdrawReserve(vaultIDs[0], reserveAmt, signer.getUpdatePriceSignature(tabCode, price, block.timestamp));
        assertEq(cBTC.balanceOf(eoa_accounts[0]), balB4Claim + reserveAmt);
        vm.stopPrank();
    }

    function testInvalidBid() public {
        uint256 reserveQty = 0;
        uint256 auctionAvailableQty = 0;
        uint256 osTabAmt = 0;
        uint256 auctionPrice = 0;
        IAuctionManager.AuctionStep memory auctionStep;
        IAuctionManager.AuctionStep[] memory auctionSteps;
        uint256 lastStepTimestamp = 0;

        vm.startPrank(eoa_accounts[9]);
        TabERC20(tab).approve(auctionManagerAddr, 60000e18);

        vm.expectRevert("INVALID_AUCTION_ID");
        IAuctionManager(auctionManagerAddr).bid(123, 6e18);

        vm.expectRevert("INVALID_BID_QTY");
        IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], 0);

        vm.expectRevert("INVALID_AUCTION_ID");
        (reserveQty, auctionAvailableQty, osTabAmt, auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(10);

        vm.expectRevert("INVALID_AUCTION_ID");
        (auctionStep, lastStepTimestamp) = IAuctionManager(auctionManagerAddr).getAuctionPrice(10, block.timestamp);

        vm.expectRevert("INVALID_AUCTION_ID");
        auctionSteps = IAuctionManager(auctionManagerAddr).getAuctionSteps(10);

        vm.stopPrank();
    }

    function testBidWithMinLiquidationPrice() public {
        // auction opened for long time and no bidder,
        // expected auction price dropped tod min. liquidation price at this point
        nextBlock(182);

        (uint256 reserveQty, uint256 auctionAvailableQty, uint256 osTabAmt, uint256 auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
        uint256 expectedLeftoverReserve = reserveQty - auctionAvailableQty;
        assertEq(expectedLeftoverReserve, 0);

        vm.startPrank(eoa_accounts[9]);
        TabERC20(tab).approve(auctionManagerAddr, 60000e18);
        vm.expectEmit(auctionManagerAddr);
        // bid all available reserves
        emit SuccessfulBid(vaultIDs[0], eoa_accounts[9], auctionPrice, 6e18);
        IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], 6e18);
        assertEq(cBTC.balanceOf(eoa_accounts[9]), 6e18);
        assertEq(TabERC20(tab).balanceOf(eoa_accounts[9]), 60000e18 - osTabAmt);

        (reserveQty, auctionAvailableQty, osTabAmt, auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
        assertEq(reserveQty, 0);
        assertEq(auctionAvailableQty, 0);
        assertEq(osTabAmt, 0);
        assertEq(auctionPrice, 0);

        (tabCode, resKey, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[0], vaultIDs[0], priceOracle.getPrice(0x555344));
        assertEq(resKey, keccak256("CBTC"));
        assertEq(price, 1079999e16);
        assertEq(reserveAmt, 0);
        assertEq(osTab, 0);
        assertEq(reserveValue, 0);
        assertEq(minReserveValue, 0);
    }

    function testBid(uint256 fuzzyBidQty) public {
        vm.assume(fuzzyBidQty > 0 && fuzzyBidQty <= 6e18);
        require(fuzzyBidQty > 0 && fuzzyBidQty <= 6e18);

        (uint256 reserveQty, uint256 auctionAvailableQty, uint256 osTabAmt, uint256 auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);

        uint256 actualBidQty = fuzzyBidQty;
        uint256 clearedOSTab = FixedPointMathLib.mulWad(fuzzyBidQty, auctionPrice);
        if (fuzzyBidQty > auctionAvailableQty) {
            actualBidQty = auctionAvailableQty;
            clearedOSTab = osTabAmt;
        }

        uint256 expectedLeftoverReserve = reserveQty - actualBidQty;

        vm.startPrank(eoa_accounts[9]);
        TabERC20(tab).approve(auctionManagerAddr, 60000e18);

        vm.expectEmit(auctionManagerAddr);
        emit SuccessfulBid(vaultIDs[0], eoa_accounts[9], auctionPrice, actualBidQty);
        IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], fuzzyBidQty);

        assertEq(cBTC.balanceOf(eoa_accounts[9]), actualBidQty);
        assertEq(TabERC20(tab).balanceOf(eoa_accounts[9]), 60000e18 - clearedOSTab);
        (reserveQty, auctionAvailableQty, osTabAmt, auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
        assertEq(reserveQty, expectedLeftoverReserve);
        assertEq(auctionAvailableQty, auctionPrice > 0 ? FixedPointMathLib.divWad(osTabAmt, auctionPrice) : 0);

        // bid remaining reserve
        if (auctionAvailableQty > 0) {
            expectedLeftoverReserve = reserveQty - auctionAvailableQty;
            vm.expectEmit(auctionManagerAddr);
            emit SuccessfulBid(vaultIDs[0], eoa_accounts[9], auctionPrice, auctionAvailableQty);
            IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], reserveQty);
            (reserveQty, auctionAvailableQty, osTabAmt, auctionPrice) =
                IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
            assertEq(reserveQty, expectedLeftoverReserve);
            assertEq(auctionAvailableQty, 0);
            assertEq(osTabAmt, 0);
            assertEq(auctionPrice, 0);
            vm.stopPrank();
        }
    }

    function testSmallBids() public {
        (uint256 reserveQty, uint256 auctionAvailableQty, uint256 osTabAmt, uint256 auctionPrice) =
            IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);

        vm.startPrank(eoa_accounts[9]);
        TabERC20(tab).approve(auctionManagerAddr, 60000e18);

        uint256[] memory bidQtyList = new uint256[](10);
        bidQtyList[0] = 1;
        bidQtyList[1] = 10;
        bidQtyList[2] = 1e2;
        bidQtyList[3] = 1e3;
        bidQtyList[4] = 1e6;
        bidQtyList[5] = 1e9;
        bidQtyList[6] = 1e12;
        bidQtyList[7] = 1e13;
        bidQtyList[8] = 1e14;
        bidQtyList[9] = 1e15;

        uint256 btcBalance = 0;
        uint256 tabBalance = TabERC20(tab).balanceOf(eoa_accounts[9]); // 60000e18
        for (uint256 i = 0; i < 10; i++) {
            nextBlock(60);
            (reserveQty, auctionAvailableQty, osTabAmt, auctionPrice) =
                IAuctionManager(auctionManagerAddr).getAuctionState(vaultIDs[0]);
            btcBalance += bidQtyList[i];
            tabBalance -= FixedPointMathLib.mulWad(bidQtyList[i], auctionPrice);

            IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], bidQtyList[i]);
            assertEq(cBTC.balanceOf(eoa_accounts[9]), btcBalance);
            assertEq(TabERC20(tab).balanceOf(eoa_accounts[9]), tabBalance);
        }
        vm.stopPrank();
    }

    // from default 60 seconds to 120 seconds, existing (on-going) auction is not affected
    function testIncreaseStepDuration() public {
        auctionStepDurationInSec = 120;
        IGovernanceAction(governanceActionAddr).updateAuctionParams(
            90, 95, auctionStepDurationInSec, auctionManagerAddr
        );

        _prices[0] = 7150e18;
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);

        vaultIDs = vaultManager.getAllVaultIDByOwner(eoa_accounts[9]);
        assertEq(vaultIDs[0], 2);

        (tabCode, resKey, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[9], vaultIDs[0], priceOracle.getPrice(0x555344));
        bytes memory checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256),(address,address,bytes3,uint256,uint256,uint8,bytes32,bytes32))",
            block.timestamp,
            eoa_accounts[9],
            vaultIDs[0],
            _tabs[0],
            reserve_cBTC,
            osTab,
            reserveValue,
            minReserveValue,
            signer.getUpdatePriceSignature(_tabs[0], _prices[0], _timestamps[0])
        );
        startTime = block.timestamp;
        vm.expectEmit(auctionManagerAddr);
        emit ActiveAuction(
            vaultIDs[0],
            address(cBTC),
            reserveAmt,
            FixedPointMathLib.mulDiv(_prices[0], 90, 100),
            tab,
            startTime + auctionStepDurationInSec
        );
        vm.expectEmit(vaultManagerAddr);
        emit LiquidatedVaultAuction(
            vaultIDs[0], address(cBTC), reserveAmt, tab, FixedPointMathLib.mulDiv(_prices[0], 90, 100)
        );
        Address.functionCall(vaultKeeperAddr, checkVaultData);

        // auction started with configured auctionStepDurationInSec = 120

        IAuctionManager.AuctionStep[] memory auctionSteps =
            IAuctionManager(auctionManagerAddr).getAuctionSteps(vaultIDs[0]);
        IAuctionManager.AuctionStep memory lastAuctionStep;
        for (uint256 i = 0; i < auctionSteps.length; i++) {
            if (auctionSteps[i].stepPrice == 0) {
                lastAuctionStep = auctionSteps[i - 1];
                break;
            }
            // console.log("step : ", i);
            // console.log("start time: ", auctionSteps[i].startTime);
            // console.log("step price: ", auctionSteps[i].stepPrice);
            assertEq(auctionSteps[i].startTime, startTime + (i * auctionStepDurationInSec));
        }

        (
            address reserve,
            uint256 reserveQty,
            ,
            ,
            uint256 startPrice,
            uint256 auctionStepPriceDiscount,
            uint256 retAuctionStepDurationInSec,
            uint256 startTimestamp,
        ) = IAuctionManager(auctionManagerAddr).auctionDetails(vaultIDs[0]);
        assertEq(reserve, address(cBTC));
        assertEq(reserveQty, 10e18);
        assertEq(startPrice, FixedPointMathLib.mulDiv(_prices[0], 90, 100));
        assertEq(auctionStepPriceDiscount, 95);
        assertEq(retAuctionStepDurationInSec, auctionStepDurationInSec);
        assertEq(startTimestamp, startTime);

        vm.startPrank(eoa_accounts[9]);
        TabERC20(tab).approve(auctionManagerAddr, 60000e18);
        IAuctionManager(auctionManagerAddr).bid(vaultIDs[0], 9e18);
        vm.stopPrank();
    }

    function testInvalidCreateAuction() public {
        vm.startPrank(eoa_accounts[9]);
        vm.expectRevert(); // required MANAGER_ROLE
        IAuctionManager(auctionManagerAddr).createAuction(
            123, // vaultId
            address(cBTC), // reserve
            10e18, // reserveQty
            tab, // tab
            10000e18, // osTabAmt
            1000e18, // startPrice
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );
        vm.stopPrank();

        vm.expectRevert("SUBZERO_RESERVE_QTY");
        IAuctionManager(auctionManagerAddr).createAuction(
            123, // vaultId
            address(cBTC), // reserve
            0, // reserveQty (INVALID)
            tab, // tab
            10000e18, // osTabAmt
            1000e18, // startPrice
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );

        vm.expectRevert("SUBZERO_TAB_AMT");
        IAuctionManager(auctionManagerAddr).createAuction(
            123, // vaultId
            address(cBTC), // reserve
            10e18, // reserveQty
            tab, // tab
            0, // osTabAmt (INVALID)
            1000e18, // startPrice
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );

        vm.expectRevert("ZERO_START_PRICE");
        IAuctionManager(auctionManagerAddr).createAuction(
            123, // vaultId
            address(cBTC), // reserve
            10e18, // reserveQty
            tab, // tab
            10000e18, // osTabAmt
            0, // startPrice (INVALID)
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );

        vm.expectRevert("EXISTED_AUCTION_ID");
        IAuctionManager(auctionManagerAddr).createAuction(
            1, // vaultId (EXISTED)
            address(cBTC), // reserve
            10e18, // reserveQty
            tab, // tab
            10000e18, // osTabAmt
            1000e18, // startPrice
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );

        // valid creation
        vm.expectEmit(auctionManagerAddr);
        emit ActiveAuction(3, address(cBTC), 10e18, 1000e18, tab, (block.timestamp + 60));
        IAuctionManager(auctionManagerAddr).createAuction(
            3, // vaultId
            address(cBTC), // reserve
            10e18, // reserveQty
            tab, // tab
            10000e18, // osTabAmt
            1000e18, // startPrice
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );
    }

}
