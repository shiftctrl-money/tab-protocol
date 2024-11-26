// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ITabFactory {
    function changeTabERC20Addr(address newTabAddr) external;

    function createTab(
        string calldata name,
        string calldata symbol,
        address admin,
        address minter,
        address tabProxyAdmin
    ) external returns (address);
}