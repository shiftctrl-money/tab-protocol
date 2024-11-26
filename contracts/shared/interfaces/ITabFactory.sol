// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ITabFactory {

    function createTab(
        bytes3 _tabName,
        string memory _name,
        string memory _symbol,
        address _admin,
        address _vaultManager,
        address _tabProxyAdmin
    )
        external
        returns (address);

}
