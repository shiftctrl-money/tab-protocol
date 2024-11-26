// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ITabProxy {
    error UnauthorizedRequester();

    function mint(
        address tabMinter,
        address requester,
        bytes3 tabCode, 
        string calldata name, 
        string calldata symbol, 
        address mintTo, 
        uint256 mintAmount
    ) external returns(address);
}