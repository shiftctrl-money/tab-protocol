// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IERC20Mint {
    function mint(address to, uint256 amount) external;
}