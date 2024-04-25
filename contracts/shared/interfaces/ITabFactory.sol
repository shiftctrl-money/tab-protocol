// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITabFactory {

    function createTab(bytes3 _tabName) external returns (address);

}
