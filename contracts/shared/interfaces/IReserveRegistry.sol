// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IReserveRegistry {

    function reserveAddr(bytes32) external view returns (address);

    function reserveKey(address) external view returns (bytes32);

    function reserveSafeAddr(bytes32) external view returns (address);

    function reserveAddrSafe(address) external view returns (address);

    function enabledReserve(bytes32) external returns (bool);

    function isEnabledReserve(address) external view returns (bool);

    function addReserve(bytes32 key, address _token, address _safe) external;

    function removeReserve(bytes32 key) external;

}
