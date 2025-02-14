// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IReserveSafe {
    function setReserveDecimal(
        address reserveAddr, 
        uint256 decimal
    ) external;

    function unlockReserve(
        address reserveAddress, 
        address transferTo, 
        uint256 value
    ) external;

    function approveSpendFromSafe(
        address reserveAddress, 
        address spender, 
        uint256 value
    ) external;

    function getNativeTransferAmount(
        address reserveAddr, 
        uint256 value
    ) 
        external 
        returns(uint256);

    event UnlockedReserve(address indexed requester, address indexed transferTo, uint256 value);
    event ApprovedSpender(address indexed spender, uint256 value);

    error ZeroValue();
}