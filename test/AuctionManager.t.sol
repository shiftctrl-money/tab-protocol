// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {IAuctionManager} from "../contracts/interfaces/IAuctionManager.sol";
import {IVaultKeeper} from "../contracts/interfaces/IVaultKeeper.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";

contract AuctionManagerTest is Deployer {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant AUCTION_ROLE = keccak256("AUCTION_ROLE");

    bytes3 usd = bytes3(abi.encodePacked("USD"));
    address tab;
    TabERC20 sUSD;
    uint256 vaultId = 1;
    address reserve_cbBTC;
    uint256 startTime;
    uint256 auctionStepDurationInSec = 60;
    uint256 totalBiddedTab;

    // AuctionBid
    address bidder;
    uint256 bidTimestamp;
    uint256 bidPrice;
    uint256 bidQty;

    // VaultUtils.getVaultDetails
    bytes3 tabCode;
    address reserveAddr;
    uint256 price;
    uint256 reserveAmt;
    uint256 osTab;
    uint256 reserveValue;
    uint256 minReserveValue;

    function setUp() public {
        deploy();

        reserve_cbBTC = address(cbBTC);

        vm.startPrank(address(governanceTimelockController));
        vaultKeeper.setRiskPenaltyFrameInSecond(10);
        governanceAction.createNewTab(usd);
        priceOracle.setDirectPrice(usd, 20000e18, block.timestamp); // drop to BTC/USD 10799.99 later
        vm.stopPrank();

        vm.startPrank(deployer);
        cbBTC.mint(eoa_accounts[0], 6e8);
        cbBTC.mint(eoa_accounts[5], 10e8);
        cbBTC.mint(eoa_accounts[9], 10e8);
        assertEq(cbBTC.balanceOf(eoa_accounts[0]), 6e8);

        vm.startPrank(eoa_accounts[0]);
        cbBTC.approve(address(vaultManager), 6e8);
        vaultManager.createVault(reserve_cbBTC, 6e18, 54000e18, signer.getUpdatePriceSignature(usd, 20000e18, block.timestamp));
        assertEq(vaultId, 1);
        (tabCode, reserveAddr, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[0], vaultId, priceOracle.getPrice(usd));
        assertEq(reserveAddr, address(cbBTC));
        assertEq(price, 20000e18);
        assertEq(reserveAmt, 6e18);
        assertEq(osTab, 54000e18);
        assertEq(reserveValue, 120000e18);
        assertEq(minReserveValue, Math.mulDiv(54000e18, 180, 100));

        // create another vault to get sUSD for bidding
        vm.startPrank(eoa_accounts[9]);
        cbBTC.approve(address(vaultManager), 10e8);
        vaultManager.createVault(reserve_cbBTC, 10e18, 60000e18, signer.getUpdatePriceSignature(usd, 20000e18, block.timestamp));
        
        // price dropped and keeper's checkVault triggered liquidation
        tab = tabRegistry.getTabAddress(usd);
        sUSD = TabERC20(tab);
        
        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, 1079999e16, block.timestamp + 1);

        vm.startPrank(address(governanceTimelockController));
        IVaultKeeper.VaultDetails memory vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            vaultId,
            usd,
            reserve_cbBTC,
            54000e18,
            6e18,
            Math.mulDiv(54000e18, 180, 100)
        );

        startTime = block.timestamp;
        vm.expectEmit(address(auctionManager));
        emit IAuctionManager.ActiveAuction(
            vaultId,
            address(cbBTC),
            6e18,
            Math.mulDiv(1079999e16, 90, 100),
            tab,
            startTime + auctionStepDurationInSec
        );
        vm.expectEmit(address(vaultManager));
        emit IVaultManager.LiquidatedVaultAuction(
            vaultId, address(cbBTC), 6e18, tab, Math.mulDiv(1079999e16, 90, 100)
        );
        vaultKeeper.checkVault(
            block.timestamp,
            vd,
            priceData
        );

        // transfer tabs to bidders
        vm.startPrank(eoa_accounts[0]);
        sUSD.transfer(eoa_accounts[1], 10000e18);
        sUSD.transfer(eoa_accounts[2], 10000e18);
        sUSD.transfer(eoa_accounts[3], 10000e18);
    }

    function test_permission() public {
        assertEq(auctionManager.defaultAdmin() , address(governanceTimelockController));
        assertEq(auctionManager.hasRole(MANAGER_ROLE, address(governanceTimelockController)), true);
        assertEq(auctionManager.hasRole(MANAGER_ROLE, address(emergencyTimelockController)), true);
        assertEq(auctionManager.hasRole(AUCTION_ROLE, address(vaultManager)), true);
        
        assertEq(auctionManager.vaultManagerAddr(), address(vaultManager));
        assertEq(auctionManager.reserveSafe(), address(reserveSafe));
        assertEq(auctionManager.maxStep(), 9);
        assertEq(auctionManager.auctionCount(), 1); // triggred 1 auction from setup
        
        vm.expectRevert();
        auctionManager.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        auctionManager.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        auctionManager.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(auctionManager.defaultAdmin() , owner);
    }

    function test_setVaultManagerAddr() public {
        vm.expectRevert(); // unauthorized
        auctionManager.setVaultManagerAddr(owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(IAuctionManager.ZeroAddress.selector);
        auctionManager.setVaultManagerAddr(address(0));
        vm.expectRevert(IAuctionManager.InvalidContractAddress.selector);
        auctionManager.setVaultManagerAddr(eoa_accounts[2]);

        vm.expectEmit();
        emit IAuctionManager.UpdatedVaultManagerAddr(address(vaultManager), owner);
        auctionManager.setVaultManagerAddr(owner);
        assertEq(auctionManager.vaultManagerAddr(), owner);
        assertEq(auctionManager.hasRole(AUCTION_ROLE, owner), true);
    }

    function test_setReserveSafe() public {
        vm.expectRevert(); // unauthorized
        auctionManager.setReserveSafe(owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(IAuctionManager.ZeroAddress.selector);
        auctionManager.setReserveSafe(address(0));
        vm.expectRevert(IAuctionManager.InvalidContractAddress.selector);
        auctionManager.setReserveSafe(eoa_accounts[2]);

        vm.expectEmit();
        emit IAuctionManager.UpdatedReserveSafeAddr(address(reserveSafe), owner);
        auctionManager.setReserveSafe(owner);
        assertEq(auctionManager.reserveSafe(), owner);
    }

    function test_setMaxStep(uint256 _step) public {
        vm.assume(_step > 0 && _step < type(uint256).max);
        require(_step > 0 && _step < type(uint256).max);

        vm.expectRevert(); // unauthorized
        auctionManager.setMaxStep(_step);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(IAuctionManager.ZeroValue.selector);
        auctionManager.setMaxStep(0);

        vm.expectEmit();
        emit IAuctionManager.UpdatedMaxStep(auctionManager.maxStep(), _step);
        auctionManager.setMaxStep(_step);
        assertEq(auctionManager.maxStep(), _step);
    }

    /// @dev Refer excel fie for simulated auction data: auction_veryCloseBids.xlsx
    function test_createAuction() public {
        uint256 startPrice = 1079999e16;
        address auctionManagerAddr = address(auctionManager);

        assertEq(cbBTC.balanceOf(auctionManagerAddr), 6e8); // full vault reserve is transferred to auction manager
        assertEq(auctionManager.auctionCount(), 1);
        assertEq(auctionManager.auctionVaultIds(0), vaultId);

        IAuctionManager.AuctionState memory auctionState = auctionManager.getAuctionState(vaultId);
        assertEq(auctionState.reserveQty, 6e18);
        assertEq(auctionState.auctionAvailableQty, Math.mulDiv(auctionState.osTabAmt, 1e18, auctionState.auctionPrice));
        assertEq(auctionState.osTabAmt, 54000e18 + 145791e16);
        assertEq(auctionState.auctionPrice, Math.mulDiv(startPrice, 90, 100));

        IAuctionManager.AuctionStep[] memory auctionSteps = auctionManager.getAuctionSteps(vaultId);
        IAuctionManager.AuctionStep memory lastAuctionStep;
        for (uint256 i = 0; i < auctionSteps.length; i++) {
            if (auctionSteps[i].stepPrice == 0) {
                lastAuctionStep = auctionSteps[i - 1];
                break;
            }
            assertEq(auctionSteps[i].startTime, startTime + (i * auctionStepDurationInSec));
        }

        (IAuctionManager.AuctionStep memory auctionStep, uint256 lastStepTimestamp) =
            auctionManager.getAuctionPrice(vaultId, block.timestamp);
        assertEq(auctionStep.startTime, startTime);
        assertEq(auctionStep.stepPrice, Math.mulDiv(startPrice, 90, 100));
        assertEq(lastStepTimestamp, lastAuctionStep.startTime);
        uint256 auctionStartPrice = auctionStep.stepPrice;

        // bidder 1
        vm.startPrank(eoa_accounts[1]);
        sUSD.approve(auctionManagerAddr, 10000e18);
        vm.expectEmit(auctionManagerAddr);
        emit IAuctionManager.SuccessfulBid(vaultId, eoa_accounts[1], auctionStartPrice, 1e18, 1e8);
        auctionManager.bid(vaultId, 1e18);
        assertEq(cbBTC.balanceOf(eoa_accounts[1]), 1e8); // received BTC from bidding
        assertEq(sUSD.balanceOf(eoa_accounts[1]), 10000e18 - auctionStartPrice); // paid Tabs

        // bidder 2
        vm.startPrank(eoa_accounts[2]);
        sUSD.approve(auctionManagerAddr, 10000e18);
        vm.expectEmit(auctionManagerAddr);
        emit IAuctionManager.SuccessfulBid(vaultId, eoa_accounts[2], auctionStartPrice, 1e18, 1e8);
        auctionManager.bid(vaultId, 1e18);
        assertEq(cbBTC.balanceOf(eoa_accounts[2]), 1e8);
        assertEq(sUSD.balanceOf(eoa_accounts[2]), 10000e18 - auctionStartPrice);

        auctionState = auctionManager.getAuctionState(vaultId);
        assertEq(auctionState.reserveQty, 6e18 - 1e18 - 1e18);
        assertEq(auctionState.auctionAvailableQty, Math.mulDiv(auctionState.osTabAmt, 1e18, Math.mulDiv(startPrice, 90, 100)));
        assertEq(auctionState.osTabAmt, 54000e18 + 145791e16 - auctionStartPrice - auctionStartPrice);
        assertEq(auctionState.auctionPrice, auctionStartPrice);

        auctionSteps = auctionManager.getAuctionSteps(vaultId);

        // next step started, auction price is reduced
        nextBlock(auctionStepDurationInSec);
        startTime = block.timestamp;
        (auctionStep, lastStepTimestamp) = auctionManager.getAuctionPrice(vaultId, block.timestamp);
        assertEq(auctionStep.startTime, startTime);
        assertEq(
            auctionStep.stepPrice, Math.mulDiv(Math.mulDiv(startPrice, 90, 100), 97, 100)
        ); // 10% of market price then reduced 3%

        // bidder 3
        nextBlock(auctionStepDurationInSec + 10);
        auctionSteps = auctionManager.getAuctionSteps(vaultId);
        (auctionStep, lastStepTimestamp) = auctionManager.getAuctionPrice(vaultId, block.timestamp);

        vm.startPrank(eoa_accounts[3]);
        sUSD.approve(auctionManagerAddr, 10000e18);
        vm.expectEmit(auctionManagerAddr);
        emit IAuctionManager.SuccessfulBid(
            vaultId, eoa_accounts[3], Math.mulDiv(auctionSteps[1].stepPrice, 97, 100), 1e18, 1e8
        );
        auctionManager.bid(vaultId, 1e18);
        assertEq(cbBTC.balanceOf(eoa_accounts[3]), 1e8);
        assertEq(
            sUSD.balanceOf(eoa_accounts[3]),
            10000e18 - Math.mulDiv(auctionSteps[1].stepPrice, 97, 100)
        );
        vm.stopPrank();

        // Original balance 6, after 3 bidders (each qty 1) = 6 -3 = 3
        assertEq(cbBTC.balanceOf(auctionManagerAddr), 3e8);
        auctionSteps = auctionManager.getAuctionSteps(vaultId);
        auctionState = auctionManager.getAuctionState(vaultId);
        assertEq(auctionState.reserveQty, 6e18 - 3e18);
        assertEq(auctionState.auctionAvailableQty, Math.mulDiv(auctionState.osTabAmt, 1e18, auctionState.auctionPrice));
        assertEq(auctionState.osTabAmt, 54000e18 + 145791e16 - auctionStartPrice - auctionStartPrice - auctionStep.stepPrice);
        assertEq(auctionState.auctionPrice, auctionSteps[0].stepPrice);
        auctionStartPrice = auctionSteps[auctionSteps.length-1].stepPrice; // Min. Liquidation Price

        // reached minimum liquidation price
        nextBlock(1000);

        auctionSteps = auctionManager.getAuctionSteps(vaultId);
        assertEq(auctionSteps[0].startTime, 0);
        assertEq(auctionSteps[0].stepPrice, auctionStartPrice);

        auctionState = auctionManager.getAuctionState(vaultId);
        assertEq(auctionState.reserveQty, 3e18);
        assertEq(auctionState.auctionAvailableQty, 3e18);
        assertEq(auctionState.auctionPrice, auctionStartPrice); // MLP

        for (uint256 i = 0; i < 3; i++) {
            (bidder, bidTimestamp, bidPrice, bidQty) = auctionManager.auctionBid(vaultId, i);
            assertEq(bidder, eoa_accounts[i + 1]);

            totalBiddedTab += Math.mulDiv(bidPrice, bidQty, 1e18);
        }
        assertEq(auctionState.osTabAmt, 54000e18 + 145791e16 - totalBiddedTab);

        // last bidder, clear all outstanding tabs
        vm.startPrank(eoa_accounts[9]);
        sUSD.approve(auctionManagerAddr, 60000e18);
        vm.expectEmit(auctionManagerAddr);
        emit IAuctionManager.SuccessfulBid(vaultId, eoa_accounts[9], auctionState.auctionPrice, 3e18, 3e8);
        auctionManager.bid(vaultId, 3e18);
        assertEq(cbBTC.balanceOf(eoa_accounts[9]), 3e8);
        assertEq(sUSD.balanceOf(eoa_accounts[9]), 60000e18 - auctionState.osTabAmt);
        vm.stopPrank();

        (tabCode, reserveAddr, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[0], vaultId, priceOracle.getPrice(usd));
        assertEq(reserveAmt, 0);
        assertEq(osTab, 0);
        assertEq(reserveValue, 0);
    }

    function test_bid(uint256 fuzzyBidQty) public {
        vm.assume(fuzzyBidQty > 0 && fuzzyBidQty <= 6e18);
        require(fuzzyBidQty > 0 && fuzzyBidQty <= 6e18);
        address auctionManagerAddr = address(auctionManager);

        IAuctionManager.AuctionState memory auctionState = auctionManager.getAuctionState(vaultId);

        uint256 actualBidQty = fuzzyBidQty;
        uint256 clearedOSTab = Math.mulDiv(fuzzyBidQty, auctionState.auctionPrice, 1e18);
        if (fuzzyBidQty > auctionState.auctionAvailableQty) {
            actualBidQty = auctionState.auctionAvailableQty;
            clearedOSTab = auctionState.osTabAmt;
        }

        uint256 expectedLeftoverReserve = auctionState.reserveQty - actualBidQty;

        vm.startPrank(eoa_accounts[9]);
        sUSD.approve(auctionManagerAddr, 60000e18);

        vm.expectEmit(auctionManagerAddr);
        emit IAuctionManager.SuccessfulBid(
            vaultId, 
            eoa_accounts[9], 
            auctionState.auctionPrice, 
            actualBidQty, 
            reserveSafe.getNativeTransferAmount(address(cbBTC), actualBidQty
        ));
        auctionManager.bid(vaultId, fuzzyBidQty);

        assertEq(cbBTC.balanceOf(eoa_accounts[9]), reserveSafe.getNativeTransferAmount(address(cbBTC), actualBidQty));
        assertEq(sUSD.balanceOf(eoa_accounts[9]), 60000e18 - clearedOSTab);

        auctionState = auctionManager.getAuctionState(vaultId);
        assertEq(auctionState.reserveQty, expectedLeftoverReserve);
        assertEq(auctionState.auctionAvailableQty, auctionState.auctionPrice > 0 ? 
            Math.mulDiv(auctionState.osTabAmt, 1e18, auctionState.auctionPrice) : 0);

        // bid remaining reserve
        if (auctionState.auctionAvailableQty > 0) {
            expectedLeftoverReserve = auctionState.reserveQty - auctionState.auctionAvailableQty;
            vm.expectEmit(auctionManagerAddr);
            emit IAuctionManager.SuccessfulBid(
                vaultId, 
                eoa_accounts[9], 
                auctionState.auctionPrice, 
                auctionState.auctionAvailableQty, 
                reserveSafe.getNativeTransferAmount(address(cbBTC), auctionState.auctionAvailableQty
            ));
            auctionManager.bid(vaultId, auctionState.reserveQty);
            auctionState = auctionManager.getAuctionState(vaultId);
            assertEq(auctionState.reserveQty, expectedLeftoverReserve);
            assertEq(auctionState.auctionAvailableQty, 0);
            assertEq(auctionState.osTabAmt, 0);
            assertEq(auctionState.auctionPrice, 0);
            vm.stopPrank();
        }
    }

    function test_bid_smallQty() public {
        IAuctionManager.AuctionState memory auctionState;

        vm.startPrank(eoa_accounts[9]);
        sUSD.approve(address(auctionManager), 60000e18);

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
        uint256 tabBalance = sUSD.balanceOf(eoa_accounts[9]); // 60000e18
        for (uint256 i = 0; i < 10; i++) {
            nextBlock(1);
            auctionState = auctionManager.getAuctionState(vaultId);
            btcBalance += bidQtyList[i];
            tabBalance -= Math.mulDiv(bidQtyList[i], auctionState.auctionPrice, 1e18);

            auctionManager.bid(vaultId, bidQtyList[i]);
            assertEq(cbBTC.balanceOf(eoa_accounts[9]), reserveSafe.getNativeTransferAmount(address(cbBTC), btcBalance));
            assertEq(sUSD.balanceOf(eoa_accounts[9]), tabBalance);
        }
        vm.stopPrank();
    }

    /// @dev Assume auction started for long time without bidder,
    /// hence auction price dropped to minimum liquidation price.
    function test_bid_withMinLiquidationPrice() public {
        nextBlock(182);

        IAuctionManager.AuctionState memory auctionState = auctionManager.getAuctionState(vaultId);
        uint256 expectedLeftoverReserve = auctionState.reserveQty - auctionState.auctionAvailableQty;
        assertEq(expectedLeftoverReserve, 0);

        vm.startPrank(eoa_accounts[9]);
        sUSD.approve(address(auctionManager), 60000e18);
        vm.expectEmit(address(auctionManager));
        // bid all available reserves
        emit IAuctionManager.SuccessfulBid(vaultId, eoa_accounts[9], auctionState.auctionPrice, 6e18, 6e8);
        auctionManager.bid(vaultId, 6e18);
        assertEq(cbBTC.balanceOf(eoa_accounts[9]), 6e8);
        assertEq(sUSD.balanceOf(eoa_accounts[9]), 60000e18 - auctionState.osTabAmt);

        auctionState = auctionManager.getAuctionState(vaultId);
        assertEq(auctionState.reserveQty, 0);
        assertEq(auctionState.auctionAvailableQty, 0);
        assertEq(auctionState.osTabAmt, 0);
        assertEq(auctionState.auctionPrice, 0);

        (tabCode, reserveAddr, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[0], vaultId, priceOracle.getPrice(usd));
        assertEq(reserveAddr, address(cbBTC));
        assertEq(price, 1079999e16);
        assertEq(reserveAmt, 0);
        assertEq(osTab, 0);
        assertEq(reserveValue, 0);
        assertEq(minReserveValue, 0);
    }

    function test_bid_invalidBid() public {
        vm.startPrank(eoa_accounts[9]);
        sUSD.approve(address(auctionManager), 60000e18);

        vm.expectRevert(IAuctionManager.InvalidAuction.selector);
        auctionManager.bid(123, 6e18);

        vm.expectRevert(IAuctionManager.ZeroValue.selector);
        auctionManager.bid(vaultId, 0);

        IAuctionManager.AuctionState memory auctionState = auctionManager.getAuctionState(10);
        assertEq(auctionState.reserveQty, 0);
        assertEq(auctionState.auctionAvailableQty, 0);
        assertEq(auctionState.osTabAmt, 0);
        assertEq(auctionState.auctionPrice, 0);

        vm.stopPrank();
    }

    function test_InvalidAccessOnLiquidatedVault() public {
        // expect revert: non-owner try to access liquidated vault
        vm.startPrank(eoa_accounts[1]);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[1], vaultId));
        vaultManager.paybackTab(eoa_accounts[1], vaultId, 10e18);

        vm.startPrank(deployer);
        cbBTC.mint(eoa_accounts[0], 10e8);

        // expect revert: try to pay back Tabs on liquidated vault
        vm.startPrank(eoa_accounts[0]);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidLiquidatedVault.selector, vaultId));
        vaultManager.paybackTab(eoa_accounts[0], vaultId, 10e18);

        // expect revert: vault owner increased reserve on liquidated vault
        cbBTC.approve(address(vaultManager), 10e8);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[0], vaultId));
        vaultManager.depositReserve(eoa_accounts[0], vaultId, 10e18);
        vm.stopPrank();

        // expect revert: non-owner to increase reserve on liquidated vault
        vm.startPrank(eoa_accounts[1]);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[1], vaultId));
        vaultManager.depositReserve(eoa_accounts[1], vaultId, 10e18);
        vm.stopPrank();
    }

    function test_bid_claim_leftoverReserve() public {
        IAuctionManager.AuctionState memory auctionState = auctionManager.getAuctionState(vaultId);
        uint256 expectedLeftoverReserve = auctionState.reserveQty - auctionState.auctionAvailableQty;
       
        vm.startPrank(eoa_accounts[9]);
        sUSD.approve(address(auctionManager), 60000e18);
        vm.expectEmit(address(auctionManager));
        // bid all available reserves
        emit IAuctionManager.SuccessfulBid(
            vaultId,
            eoa_accounts[9],
            Math.mulDiv(1079999e16, 90, 100),
            Math.mulDiv(auctionState.osTabAmt, 1e18, auctionState.auctionPrice),
            reserveSafe.getNativeTransferAmount(address(cbBTC), Math.mulDiv(auctionState.osTabAmt, 1e18, auctionState.auctionPrice))
        );
        auctionManager.bid(vaultId, 6e18);
        assertEq(cbBTC.balanceOf(eoa_accounts[9]), reserveSafe.getNativeTransferAmount(address(cbBTC), auctionState.auctionAvailableQty));
        assertEq(sUSD.balanceOf(eoa_accounts[9]), 60000e18 - auctionState.osTabAmt);

        auctionState = auctionManager.getAuctionState(vaultId);
        assertEq(auctionState.reserveQty, expectedLeftoverReserve);
        assertEq(auctionState.auctionAvailableQty, 0);
        assertEq(auctionState.osTabAmt, 0);
        assertEq(auctionState.auctionPrice, 0);

        (tabCode, reserveAddr, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[0], vaultId, priceOracle.getPrice(usd));
        assertEq(reserveAddr, address(cbBTC));
        assertEq(price, 1079999e16);
        assertEq(reserveAmt, expectedLeftoverReserve);
        assertEq(osTab, 0);
        assertEq(reserveValue, Math.mulDiv(expectedLeftoverReserve, price, 1e18));
        assertEq(minReserveValue, 0);

        // expect revert: non-owner attempt to claim leftover
        priceData = signer.getUpdatePriceSignature(usd, price, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[9], vaultId));
        vaultManager.withdrawReserve(vaultId, reserveValue, priceData);
        
        // claimed leftover by vault owner
        vm.startPrank(eoa_accounts[0]);
        uint256 balB4Claim = cbBTC.balanceOf(eoa_accounts[0]);
        vaultManager.withdrawReserve(vaultId, reserveAmt, signer.getUpdatePriceSignature(usd, price, block.timestamp));
        assertEq(cbBTC.balanceOf(eoa_accounts[0]), reserveSafe.getNativeTransferAmount(address(cbBTC), balB4Claim + reserveAmt));
        vm.stopPrank();
    }

    /// @dev Auction step duration is increased from default 60 seconds to 120 seconds, 
    /// and existing (on-going) auction is not affected.
    function test_IncreaseStepDuration() public {
        auctionStepDurationInSec = 120;
        uint256 startPrice = 7150e18;

        vm.startPrank(address(governanceTimelockController));
        governanceAction.updateAuctionParams(90, 95, auctionStepDurationInSec, address(auctionManager));
        nextBlock(10);
        priceOracle.setDirectPrice(usd, startPrice, block.timestamp);
        
        vm.startPrank(eoa_accounts[9]);
        priceData = signer.getUpdatePriceSignature(usd, startPrice, block.timestamp);

        vaultId = 2;
        (tabCode, reserveAddr, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[9], vaultId, priceOracle.getPrice(usd));
        
        vm.startPrank(address(governanceTimelockController));
        IVaultKeeper.VaultDetails memory vd = IVaultKeeper.VaultDetails(
            eoa_accounts[9],
            vaultId,
            usd,
            reserve_cbBTC,
            osTab,
            reserveValue,
            minReserveValue
        );
        startTime = block.timestamp;
        vm.expectEmit(address(auctionManager));
        emit IAuctionManager.ActiveAuction(
            vaultId,
            address(cbBTC),
            reserveAmt,
            Math.mulDiv(startPrice, 90, 100),
            tab,
            startTime + auctionStepDurationInSec
        );
        vm.expectEmit(address(vaultManager));
        emit IVaultManager.LiquidatedVaultAuction(
            vaultId, address(cbBTC), reserveAmt, tab, Math.mulDiv(startPrice, 90, 100)
        );
        vaultKeeper.checkVault(
            block.timestamp,
            vd,
            priceData
        );

        // auction started with configured auctionStepDurationInSec = 120
        IAuctionManager.AuctionStep[] memory auctionSteps = auctionManager.getAuctionSteps(vaultId);
        IAuctionManager.AuctionStep memory lastAuctionStep;
        for (uint256 i = 0; i < auctionSteps.length; i++) {
            if (auctionSteps[i].stepPrice == 0) {
                lastAuctionStep = auctionSteps[i - 1];
                break;
            }
            assertEq(auctionSteps[i].startTime, startTime + (i * auctionStepDurationInSec));
        }

        IAuctionManager.AuctionDetails memory ad = auctionManager.getAuctionDetails(vaultId);
        assertEq(ad.reserve, address(cbBTC));
        assertEq(ad.reserveQty, 10e18);
        assertEq(ad.startPrice, Math.mulDiv(startPrice, 90, 100));
        assertEq(ad.auctionStepPriceDiscount, 95);
        assertEq(ad.auctionStepDurationInSec, auctionStepDurationInSec);
        assertEq(ad.startTimestamp, startTime);

        vm.startPrank(eoa_accounts[9]);
        sUSD.approve(address(auctionManager), 60000e18);
        auctionManager.bid(vaultId, 9e18);
        vm.stopPrank();
    }

    function test_InvalidCreateAuction() public {
        vm.expectRevert(); // required AUCTION_ROLE
        auctionManager.createAuction(
            123, // vaultId
            address(cbBTC), // reserve
            10e18, // reserveQty
            tab, // tab
            10000e18, // osTabAmt
            1000e18, // startPrice
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );
        vm.stopPrank();

        vm.startPrank(address(vaultManager));

        vm.expectRevert(IAuctionManager.ZeroValue.selector);
        auctionManager.createAuction(
            123, // vaultId
            address(cbBTC), // reserve
            0, // reserveQty (INVALID)
            tab, // tab
            10000e18, // osTabAmt
            1000e18, // startPrice
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );

        vm.expectRevert(IAuctionManager.ZeroValue.selector);
        auctionManager.createAuction(
            123, // vaultId
            address(cbBTC), // reserve
            10e18, // reserveQty
            tab, // tab
            0, // osTabAmt (INVALID)
            1000e18, // startPrice
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );

        vm.expectRevert(IAuctionManager.ZeroValue.selector);
        auctionManager.createAuction(
            123, // vaultId
            address(cbBTC), // reserve
            10e18, // reserveQty
            tab, // tab
            10000e18, // osTabAmt
            0, // startPrice (INVALID)
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );

        vm.expectRevert(IAuctionManager.ExistedAuction.selector);
        auctionManager.createAuction(
            1, // vaultId (EXISTED)
            address(cbBTC), // reserve
            10e18, // reserveQty
            tab, // tab
            10000e18, // osTabAmt
            1000e18, // startPrice
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );

        // valid creation
        emit IAuctionManager.ActiveAuction(3, address(cbBTC), 10e18, 1000e18, tab, (block.timestamp + 60));
        auctionManager.createAuction(
            3, // vaultId
            address(cbBTC), // reserve
            10e18, // reserveQty
            tab, // tab
            10000e18, // osTabAmt
            1000e18, // startPrice
            97, // auctionStepPriceDiscount
            60 // auctionStepDurationInSec
        );
    }

}
