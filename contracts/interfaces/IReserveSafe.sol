// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IReserveSafe {

    function unlockReserve(address _reserveOwner, uint256 value) external returns (bool);
    function approveSpend(address spender, uint256 value) external returns (bool);

}
