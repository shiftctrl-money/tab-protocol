// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./shared/interfaces/IERC20.sol";

contract ReserveSafe is AccessControlDefaultAdminRules {

    bytes32 public constant UNLOCKER_ROLE = keccak256("UNLOCKER_ROLE");

    IERC20 public reserveInterface;

    event UnlockedReserve(address indexed requester, address indexed transferTo, uint256 value);
    event ApprovedSpender(address indexed spender, uint256 value);

    /// @dev Create new ReserveSafe contract to store new type of reserve (e.g. WBTC, cBTC)
    constructor(
        address _admin,
        address _admin2,
        address _vaultManager,
        address _reserveAddr
    )
        AccessControlDefaultAdminRules(1 days, _admin)
    {
        _grantRole(UNLOCKER_ROLE, _admin);
        _grantRole(UNLOCKER_ROLE, _admin2);
        _grantRole(UNLOCKER_ROLE, _vaultManager);
        reserveInterface = IERC20(_reserveAddr);
    }

    /// @dev Unlocked value must follow reserve token's decimal value.
    function unlockReserve(address _reserveOwner, uint256 value) external onlyRole(UNLOCKER_ROLE) returns (bool) {
        emit UnlockedReserve(msg.sender, _reserveOwner, value);
        SafeERC20.safeTransfer(reserveInterface, _reserveOwner, value);
        return true;
    }

    function approveSpend(address spender, uint256 value) external onlyRole(UNLOCKER_ROLE) returns (bool) {
        emit ApprovedSpender(spender, value);
        SafeERC20.safeIncreaseAllowance(reserveInterface, spender, value);
        return true;
    }

}
