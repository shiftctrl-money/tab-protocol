// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRules} 
    from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IAuctionManager} from "../interfaces/IAuctionManager.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IReserveSafe} from "../interfaces/IReserveSafe.sol";

/**
 * @title Vault liquidation by auction. Big on BTC vault reserves to recover outstanding Tabs.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract AuctionManager is AccessControlDefaultAdminRules, ReentrancyGuard, IAuctionManager {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant AUCTION_ROLE = keccak256("AUCTION_ROLE");

    address public vaultManagerAddr;
    address public reserveSafe;

    // key = vaultId
    mapping(uint256 => AuctionDetails) public auctionDetails;
    mapping(uint256 => AuctionState) private auctionState;
    mapping(uint256 => AuctionBid[]) public auctionBid;

    uint256 public auctionCount;
    uint256[] public auctionVaultIds;
    uint256 public maxStep;

    /**
     * @param _admin Governance controller
     * @param _admin2 Emergency governance controller
     * @param _vaultManager Protocol vault manager contract
     * @param _reserveSafe Reserve safe contract address
     */
    constructor(
        address _admin,
        address _admin2,
        address _vaultManager,
        address _reserveSafe
    )
        AccessControlDefaultAdminRules(1 days, _admin)
    {
        _grantRole(MANAGER_ROLE, _admin);
        _grantRole(MANAGER_ROLE, _admin2);

        _grantRole(AUCTION_ROLE, _vaultManager);
        _setRoleAdmin(AUCTION_ROLE, MANAGER_ROLE);
        
        vaultManagerAddr = _vaultManager;
        reserveSafe = _reserveSafe;
        maxStep = 9; // actual size = 10 with index 9 reserved for min. liquidation price
    }

    /// @dev Grant MANAGER_ROLE to updated vaultManager address.
    function setVaultManagerAddr(address _vaultManager) external onlyRole(MANAGER_ROLE) {
        if (_vaultManager == address(0))
            revert ZeroAddress();
        if (_vaultManager.code.length == 0)
            revert InvalidContractAddress();
        emit UpdatedVaultManagerAddr(vaultManagerAddr, _vaultManager);
        vaultManagerAddr = _vaultManager;
        _grantRole(AUCTION_ROLE, vaultManagerAddr);
    }

    function setReserveSafe(address _reserveSafe) external onlyRole(MANAGER_ROLE) {
        if (_reserveSafe == address(0))
            revert ZeroAddress();
        if (_reserveSafe.code.length == 0)
            revert InvalidContractAddress();
        emit UpdatedReserveSafeAddr(reserveSafe, _reserveSafe);
        reserveSafe = _reserveSafe;
    }

    function setMaxStep(uint256 _maxStep) external onlyRole(MANAGER_ROLE) {
        if (_maxStep == 0)
            revert ZeroValue();
        emit UpdatedMaxStep(maxStep, _maxStep);
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
        onlyRole(AUCTION_ROLE)
    {
        if (reserveQty == 0)
            revert ZeroValue();
        if (osTabAmt == 0)
            revert ZeroValue();
        if (startPrice == 0)
            revert ZeroValue();
        if (auctionDetails[vaultId].osTabAmt > 0)
            revert ExistedAuction();

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
            Math.mulDiv(osTabAmt, 1e18, startPrice), // auctionAvailableQty, quantity available to bid
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

    /**
     * @dev User pays Tabs to bid on discounted BTC.
     * Required allowance to spend Tabs. 
     * @param auctionId Unique auction ID.
     * @param bidQty BTC Bid Quantity. 
     * If `bidQty` exceeds available BTC quantity, 
     * set to available BTC quantity.
     */
    function bid(uint256 auctionId, uint256 bidQty) external nonReentrant {
        AuctionState storage state = auctionState[auctionId];
        AuctionDetails storage det = auctionDetails[auctionId];
        if (state.auctionAvailableQty == 0)
            revert InvalidAuction();
        if (bidQty == 0)
            revert ZeroValue();

        // determine current auction step price
        (AuctionStep memory auctionStep,) = getAuctionPrice(auctionId, block.timestamp);
        if (auctionStep.stepPrice == 0)
            revert ZeroStepPrice();

        uint256 auctionAvailableQty = Math.mulDiv(state.osTabAmt, 1e18, auctionStep.stepPrice);

        uint256 bidTabAmt;

        // set max. available bid qty if applicable
        if (bidQty > auctionAvailableQty) {
            bidQty = auctionAvailableQty;
            bidTabAmt = state.osTabAmt;
        } else {
            // bidder pays bid amount in Tab
            bidTabAmt = Math.mulDiv(auctionStep.stepPrice, bidQty, 1e18);
        }

        // required allowance from bidder 
        SafeERC20.safeTransferFrom(IERC20(det.tab), msg.sender, address(this), bidTabAmt);

        // save bid details
        auctionBid[auctionId].push(AuctionBid(msg.sender, block.timestamp, auctionStep.stepPrice, bidQty));

        // update auction state
        state.reserveQty = state.reserveQty - bidQty;
        state.osTabAmt = (bidQty == auctionAvailableQty) ? 0 : (state.osTabAmt - bidTabAmt);
        state.auctionAvailableQty = Math.mulDiv(state.osTabAmt, 1e18, auctionStep.stepPrice);
        state.auctionPrice = auctionStep.stepPrice;

        if (state.osTabAmt > 0) {
            (, uint256 lastStepTimestamp) = getAuctionPrice(auctionId, block.timestamp);
            det.lastStepTimestamp = lastStepTimestamp;
        }  

        // transfer reserve BTC to bidder - convert from 18 to 8 decimals
        uint256 paidBTC = IReserveSafe(reserveSafe).getNativeTransferAmount(det.reserve, bidQty);
        SafeERC20.safeTransfer(IERC20(det.reserve), msg.sender, paidBTC);
        emit SuccessfulBid(auctionId, msg.sender, auctionStep.stepPrice, bidQty, paidBTC);

        // update Vault
        SafeERC20.safeIncreaseAllowance(IERC20(det.tab), vaultManagerAddr, bidTabAmt);
        IVaultManager(vaultManagerAddr).paybackTab(address(this), auctionId, bidTabAmt);

        // auction is completed with leftover reserve, transfer back to Vault
        if (state.reserveQty > 0 && state.auctionAvailableQty == 0 && state.osTabAmt == 0) {
            SafeERC20.safeIncreaseAllowance(
                IERC20(det.reserve), 
                vaultManagerAddr, 
                IReserveSafe(reserveSafe).getNativeTransferAmount(det.reserve, state.reserveQty)
            );
            IVaultManager(vaultManagerAddr).depositReserve(address(this), auctionId, state.reserveQty);
        }
    }

    function getAuctionDetails(
        uint256 auctionId
    )
        external 
        view 
        returns(AuctionDetails memory) 
    {
        return auctionDetails[auctionId];
    }

    function getAuctionState(
        uint256 auctionId
    ) 
        external 
        view 
        returns (AuctionState memory state) 
    {
        state = auctionState[auctionId];
        if (state.auctionPrice == 0) // auction is not found, vault is not liquidated
            return state;

        (AuctionStep memory auctionStep,) = getAuctionPrice(auctionId, block.timestamp);

        uint256 auctionAvailableQty =
            auctionStep.stepPrice > 0 ? Math.mulDiv(state.osTabAmt, 1e18, auctionStep.stepPrice) : 0;
        state.auctionAvailableQty = auctionAvailableQty;
        state.auctionPrice = auctionStep.stepPrice;
    }

    function getAuctionBid(
        uint256 auctionId
    ) 
        external 
        view 
        returns(AuctionBid[] memory)
    {
        return auctionBid[auctionId];
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
                // set lastStepTimestamp value one time only on last valid item in list
                if (lastStepTimestamp == 0) 
                    lastStepTimestamp = auctionSteps[i].startTime;
                
                if (timestamp >= auctionSteps[i].startTime) {
                    auctionStep = auctionSteps[i];
                    break;
                }
            }
            // avoid negative value on uint i
            if (i == 0 )
                break;
        }
    }

    function getAuctionSteps(
        uint256 auctionId
    )   
        public 
        view 
        returns (AuctionStep[] memory auctionSteps) 
    {
        AuctionState memory state = auctionState[auctionId];
        AuctionDetails memory det = auctionDetails[auctionId];
        if (det.reserveQty == 0)
            revert ZeroValue();
        if (state.osTabAmt == 0) {
            auctionSteps = new AuctionStep[](1);
            return auctionSteps;
        }

        uint256 auctionPrice = state.auctionPrice;
        uint256 minLiquidationPrice = Math.mulDiv(state.osTabAmt, 1e18, state.reserveQty);

        // auction price reached minLiquidationPrice (last step),
        // stay in this state until all reserve qty is bidded
        if (auctionPrice <= minLiquidationPrice || 
            (det.lastStepTimestamp > 0 && 
                block.timestamp > det.lastStepTimestamp)
        ) {
            auctionSteps = new AuctionStep[](1);
            auctionSteps[0] = AuctionStep(0, minLiquidationPrice);
            return auctionSteps;
        }

        auctionSteps = new AuctionStep[](maxStep + 1);
        uint256 step = 1;
        uint256 stepTime = det.startTimestamp;
        auctionSteps[0] = AuctionStep(stepTime, auctionPrice);

        while (Math.mulDiv(auctionPrice, det.auctionStepPriceDiscount, 100) > minLiquidationPrice) {
            auctionPrice = Math.mulDiv(auctionPrice, det.auctionStepPriceDiscount, 100);
            stepTime = stepTime + det.auctionStepDurationInSec;
            auctionSteps[step] = AuctionStep(stepTime, auctionPrice);
            step++;
            if (step == maxStep)
                break;
        }

        // last step - opened to bid on auctionPrice = minimum liquidation price
        auctionSteps[step] = AuctionStep(stepTime + det.auctionStepDurationInSec, minLiquidationPrice);
    }

}
