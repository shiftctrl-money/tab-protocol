// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ITabFactory {

    function createTab(
        address _admin,
        address _vaultManager,
        string memory _name,
        string memory _symbol
    )
        external
        returns (address);

}