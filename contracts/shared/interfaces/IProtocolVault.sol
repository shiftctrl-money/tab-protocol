// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProtocolVault {

    function initCtrlAltDel(
        address _reserveAddr,
        uint256 _reserveAmt,
        address _tabAddr,
        uint256 _tabAmt,
        uint256 _reserveTabPrice
    )
        external;
    function updateReserveRegistry(address _reserveRegistry) external;
    function buyTab(address _reserveAddr, address _tabAddr, uint256 _reserveAmt) external returns (uint256);
    function sellTab(address _reserveAddr, address _tabAddr, uint256 _tabAmt) external returns (uint256);

}
