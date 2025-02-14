// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRules} 
    from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IReserveSafe} from "../interfaces/IReserveSafe.sol";

/**
 * @title  Storing BTC reserves.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract ReserveSafe is IReserveSafe, AccessControlDefaultAdminRules {
    bytes32 public constant UNLOCKER_ROLE = keccak256("UNLOCKER_ROLE");
    bytes32 public constant RESERVE_REGISTRY_ROLE = keccak256("RESERVE_REGISTRY_ROLE");
    
    mapping(address => uint256) public reserveDecimal;

    /**
     * @dev Only deploy One(1) `ReserveSafe` contract by default.
     * @param admin Governance controller.
     * @param admin2 Emergency governance controller.
     * @param vaultManager Protocol vault manager contract address.
     * @param reserveRegistry Reserve registry contract address.
     */
    constructor(
        address admin,
        address admin2,
        address vaultManager,
        address reserveRegistry
    )
        AccessControlDefaultAdminRules(1 days, admin)
    {
        _grantRole(UNLOCKER_ROLE, admin);
        _grantRole(UNLOCKER_ROLE, admin2);
        _grantRole(UNLOCKER_ROLE, vaultManager);

        _grantRole(RESERVE_REGISTRY_ROLE, admin);
        _grantRole(RESERVE_REGISTRY_ROLE, reserveRegistry);
    }

    /**
     * @dev Upon whitelisting new reserve type, the reserve token's decimals metadata is stored.
     * @param reserveAddr The adding reserve token address.
     * @param decimal Decimal places.
     */
    function setReserveDecimal(
        address reserveAddr, 
        uint256 decimal
    ) 
        external 
        onlyRole(RESERVE_REGISTRY_ROLE) 
    {
        if (decimal == 0)
            revert ZeroValue();
        reserveDecimal[reserveAddr] = decimal;
    }

    /**
     * @dev Used by `VaultManager` contract to unlock reserve upon reserve withdrawal request.
     * @param reserveAddress Token address of the reserve to be unlocked.
     * @param transferTo Recipient address (vault owner).
     * @param value Unlock stored amount (18 decimals). Convert to 8 decimals if applicable.
     */
    function unlockReserve(
        address reserveAddress, 
        address transferTo, 
        uint256 value
    ) 
        external 
        onlyRole(UNLOCKER_ROLE) 
    {
        uint256 valueIn8Decimal = getNativeTransferAmount(reserveAddress, value);
        SafeERC20.safeTransfer(IERC20(reserveAddress), transferTo, valueIn8Decimal);
        emit UnlockedReserve(msg.sender, transferTo, valueIn8Decimal);
    }
    
    /**
     * @dev Governance approved spending from Safe.
     * @param reserveAddress Token address of the reserve.
     * @param spender Address authorized to spend the reserve.
     * @param value Allowance amount.
     */
    function approveSpendFromSafe(
        address reserveAddress, 
        address spender, 
        uint256 value
    ) 
        external 
        onlyRole(UNLOCKER_ROLE) 
    {
        uint256 valueIn8Decimal = getNativeTransferAmount(reserveAddress, value);
        SafeERC20.safeIncreaseAllowance(IERC20(reserveAddress), spender, valueIn8Decimal);
        emit ApprovedSpender(spender, valueIn8Decimal);
    }

    /**
     * @dev Convert 18-decimals input value into reserve token's ERC-20 decimal value.
     * @param reserveAddr Reserve token address.
     * @param value Expect 18 decimals value.
     */
    function getNativeTransferAmount(
        address reserveAddr, 
        uint256 value
    ) 
        public 
        view 
        returns(uint256)
    {
        if (reserveDecimal[reserveAddr] == 18)
            return value;
        else
            return value / (10 ** (18 - reserveDecimal[reserveAddr]));
    }

}
