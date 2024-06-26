// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IVaultManager } from "./shared/interfaces/IVaultManager.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";
import "lib/solady/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AuctionManager is AccessControlDefaultAdminRules, ReentrancyGuard {

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public vaultManagerAddr;

    struct AuctionDetails {
        address reserve;
        uint256 reserveQty;
        address tab;
        uint256 osTabAmt;
        uint256 startPrice; // auction start price
        uint256 auctionStepPriceDiscount;
        uint256 auctionStepDurationInSec;
        uint256 startTimestamp;
        uint256 lastStepTimestamp;
    }

    struct AuctionState {
        uint256 reserveQty;
        uint256 auctionAvailableQty; // quantity available to bid
        uint256 osTabAmt;
        uint256 auctionPrice;
    }

    struct AuctionBid {
        address bidder;
        uint256 bidTimestamp;
        uint256 bidPrice; // reserve bid price = AuctionState.auctionPrice
        uint256 bidQty;
    }

    struct AuctionStep {
        uint256 startTime;
        uint256 stepPrice;
    }

    // key = vaultId
    mapping(uint256 => AuctionDetails) public auctionDetails;
    mapping(uint256 => AuctionState) private auctionState;
    mapping(uint256 => AuctionBid[]) public auctionBid;

    uint256 public auctionCount;
    uint256[] public auctionVaultIds;
    uint256 public maxStep;

    event UpdatedVaultManager(address oldAddr, address newAddr);
    event ActiveAuction(
        uint256 indexed auctionId,
        address reserve,
        uint256 maxAvailableQty,
        uint256 auctionPrice,
        address tab,
        uint256 validTill
    );
    event SuccessfulBid(uint256 indexed auctionId, address indexed bidder, uint256 bidPrice, uint256 bidQty);

    /**
     * @param _admin governance
     * @param _admin2 emergency governance
     * @param _vaultManager vault manager contract
     */
    constructor(
        address _admin,
        address _admin2,
        address _vaultManager
    )
        AccessControlDefaultAdminRules(1 days, _admin)
    {
        _grantRole(MANAGER_ROLE, _admin);
        _grantRole(MANAGER_ROLE, _admin2);
        _grantRole(MANAGER_ROLE, _vaultManager);

        vaultManagerAddr = _vaultManager;
        auctionCount = 0;
        maxStep = 9; // actual size = 10 with index 9 reserved for min. liquidation price
    }

    function setVaultManager(address _vaultManager) external onlyRole(MANAGER_ROLE) {
        emit UpdatedVaultManager(vaultManagerAddr, _vaultManager);
        vaultManagerAddr = _vaultManager;
    }

    function setMaxStep(uint256 _maxStep) external onlyRole(MANAGER_ROLE) {
        require(_maxStep > 0, "INVALID_STEP");
        maxStep = _maxStep;
    }

    function createAuction(
        uint256 vaultId,
        address reserve,
        uint256 reserveQty,
        address tab,
        uint256 osTabAmt,
        uint256 startPrice,
        uint256 auctionStepPriceDiscount,
        uint256 auctionStepDurationInSec
    )
        external
        onlyRole(MANAGER_ROLE)
    {
        require(reserveQty > 0, "SUBZERO_RESERVE_QTY");
        require(osTabAmt > 0, "SUBZERO_TAB_AMT");
        require(startPrice > 0, "ZERO_START_PRICE");
        require(auctionDetails[vaultId].osTabAmt == 0, "EXISTED_AUCTION_ID");

        auctionDetails[vaultId] = AuctionDetails(
            reserve,
            reserveQty,
            tab,
            osTabAmt,
            startPrice,
            auctionStepPriceDiscount,
            auctionStepDurationInSec,
            block.timestamp,
            0
        );

        auctionState[vaultId] = AuctionState(
            reserveQty,
            FixedPointMathLib.divWad(osTabAmt, startPrice), // auctionAvailableQty, quantity available to bid
            osTabAmt,
            startPrice
        );

        auctionCount = auctionCount + 1;
        auctionVaultIds.push(vaultId);

        emit ActiveAuction(
            vaultId,
            reserve,
            auctionState[vaultId].reserveQty,
            startPrice,
            tab,
            (block.timestamp + auctionStepDurationInSec)
        );
    }

    function bid(uint256 auctionId, uint256 bidQty) external nonReentrant {
        AuctionState storage state = auctionState[auctionId];
        AuctionDetails storage det = auctionDetails[auctionId];
        require(state.auctionAvailableQty > 0, "INVALID_AUCTION_ID");
        require(bidQty > 0, "INVALID_BID_QTY");

        // determine current auction step price
        (AuctionStep memory auctionStep,) = getAuctionPrice(auctionId, block.timestamp);
        require(auctionStep.stepPrice > 0, "INVALID_STEP_PRICE");

        uint256 auctionAvailableQty = FixedPointMathLib.divWad(state.osTabAmt, auctionStep.stepPrice);

        uint256 bidTabAmt = 0;

        // set max. available bid qty if applicable
        if (bidQty > auctionAvailableQty) {
            bidQty = auctionAvailableQty;
            bidTabAmt = state.osTabAmt;
        } else {
            // bidder pays bid amount in Tab
            bidTabAmt = FixedPointMathLib.mulWad(auctionStep.stepPrice, bidQty);
        }

        SafeTransferLib.safeTransferFrom(det.tab, msg.sender, address(this), bidTabAmt); // required approval from
            // bidder

        // save bid details
        auctionBid[auctionId].push(AuctionBid(msg.sender, block.timestamp, auctionStep.stepPrice, bidQty));

        // update auction state
        state.reserveQty = state.reserveQty - bidQty;
        state.osTabAmt = (bidQty == auctionAvailableQty) ? 0 : (state.osTabAmt - bidTabAmt);
        state.auctionAvailableQty = FixedPointMathLib.divWad(state.osTabAmt, auctionStep.stepPrice);
        state.auctionPrice = auctionStep.stepPrice;

        if (state.osTabAmt > 0) {
            (, uint256 lastStepTimestamp) = getAuctionPrice(auctionId, block.timestamp);
            det.lastStepTimestamp = lastStepTimestamp;
        }

        // transfer reserve BTC to bidder
        SafeTransferLib.safeTransfer(det.reserve, msg.sender, bidQty);

        emit SuccessfulBid(auctionId, msg.sender, auctionStep.stepPrice, bidQty);

        // update Vault
        SafeTransferLib.safeApprove(det.tab, vaultManagerAddr, bidTabAmt);
        IVaultManager(vaultManagerAddr).adjustTab(auctionId, bidTabAmt, false);

        // auction is completed with leftover reserve, transfer back to Vault
        if (state.reserveQty > 0 && state.auctionAvailableQty == 0 && state.osTabAmt == 0) {
            SafeTransferLib.safeApprove(det.reserve, vaultManagerAddr, state.reserveQty);
            IVaultManager(vaultManagerAddr).adjustReserve(auctionId, state.reserveQty, false);
        }
    }

    function getAuctionState(uint256 auctionId) external view returns (AuctionState memory state) {
        state = auctionState[auctionId];
        require(state.auctionPrice > 0, "INVALID_AUCTION_ID");

        (AuctionStep memory auctionStep,) = getAuctionPrice(auctionId, block.timestamp);

        uint256 auctionAvailableQty =
            auctionStep.stepPrice > 0 ? FixedPointMathLib.divWad(state.osTabAmt, auctionStep.stepPrice) : 0;
        state.auctionAvailableQty = auctionAvailableQty;
        state.auctionPrice = auctionStep.stepPrice;
    }

    function getAuctionPrice(
        uint256 auctionId,
        uint256 timestamp
    )
        public
        view
        returns (AuctionStep memory auctionStep, uint256 lastStepTimestamp)
    {
        AuctionStep[] memory auctionSteps = getAuctionSteps(auctionId);

        uint256 i = auctionSteps.length - 1;
        for (; i >= 0; i--) {
            if (auctionSteps[i].stepPrice > 0) {
                if (
                    lastStepTimestamp == 0 // set lastStepTimestamp value one time only on last valid item in list
                ) {
                    lastStepTimestamp = auctionSteps[i].startTime;
                }
                if (timestamp >= auctionSteps[i].startTime) {
                    auctionStep = auctionSteps[i];
                    break;
                }
            }
            if (
                i == 0 // avoid negative value on uint i
            ) {
                break;
            }
        }
    }

    function getAuctionSteps(uint256 auctionId) public view returns (AuctionStep[] memory auctionSteps) {
        AuctionState memory state = auctionState[auctionId];
        AuctionDetails memory det = auctionDetails[auctionId];
        require(det.reserveQty > 0, "INVALID_AUCTION_ID");
        if (state.osTabAmt == 0) {
            auctionSteps = new AuctionStep[](1);
            return auctionSteps;
        }

        uint256 auctionPrice = state.auctionPrice;
        uint256 minLiquidationPrice = FixedPointMathLib.mulDiv(state.osTabAmt, 1e18, state.reserveQty);

        // auction price reached minLiquidationPrice (last step),
        // stay in this state until all reserve qty is bidded
        if (
            auctionPrice <= minLiquidationPrice
                || (det.lastStepTimestamp > 0 && block.timestamp > det.lastStepTimestamp)
        ) {
            auctionSteps = new AuctionStep[](1);
            auctionSteps[0] = AuctionStep(0, minLiquidationPrice);
            return auctionSteps;
        }

        auctionSteps = new AuctionStep[](maxStep + 1);
        uint256 step = 1;
        uint256 stepTime = 0;
        if (state.auctionPrice == det.startPrice) {
            stepTime = det.startTimestamp;
        } else {
            stepTime =
                det.startTimestamp + ((block.timestamp / det.auctionStepDurationInSec) * det.auctionStepDurationInSec);
        }
        auctionSteps[0] = AuctionStep(stepTime, auctionPrice);

        while (FixedPointMathLib.mulDiv(auctionPrice, det.auctionStepPriceDiscount, 100) > minLiquidationPrice) {
            auctionPrice = FixedPointMathLib.mulDiv(auctionPrice, det.auctionStepPriceDiscount, 100);
            stepTime = stepTime + det.auctionStepDurationInSec;
            auctionSteps[step] = AuctionStep(stepTime, auctionPrice);
            step++;
            if (step == maxStep) {
                break;
            }
        }

        // last step - opened to bid on auctionPrice = minimum liquidation price
        auctionSteps[step] = AuctionStep(stepTime + det.auctionStepDurationInSec, minLiquidationPrice);
    }

}
