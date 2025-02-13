// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ITabERC20 {
    function tabCode() external view returns (bytes3);
    function tabKey() external view returns (bytes32);
    function mint(address, uint256) external;
    function burnFrom(address, uint256) external;
}
