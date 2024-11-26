// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ITabERC20 {

    function mint(address, uint256) external;
    function burnFrom(address, uint256) external;
    function tabCode() external view returns (bytes3);

}
