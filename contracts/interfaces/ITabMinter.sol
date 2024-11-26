// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ITabMinter {
    function updateAddress(address _tabFactory, address _tabProxyAdmin) external;

    function tabs(bytes3) external returns(address);

    function createAndMint(
        bytes3 tabCode,
        string calldata name,
        string calldata symbol,
        address mintTo,
        uint256 mintAmount
    ) external returns(address);
}