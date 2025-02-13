// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IReserveRegistry {
    function reserveAddrSafe(address) external view returns(address);
    function enabledReserve(address) external view returns(bool);
    function reserveSafe() external view returns(address);
    function isEnabledReserve(address _reserveAddr) external view returns (address);

    function addReserve(address _token, address _safe) external;
    function removeReserve(address _token) external;
    function updateReserveSafe(address _safe) external;
    
    event AddedReserve(address _addr, address _safe, uint256 _decimals);
    event RemovedReserve(address _token);
    event UpdatedReserveSafe(address b4, address _after);

    error ZeroAddress();
    error InvalidReserveSafe();
    error ExistedReserveToken();
    error InvalidReserveToken();
    error InvalidDecimals(uint256 decimals);
}