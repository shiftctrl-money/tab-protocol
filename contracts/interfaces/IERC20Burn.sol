// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IERC20Burn {
    function burn(uint256 value) external;
    function burnFrom(address account, uint256 value) external;
}