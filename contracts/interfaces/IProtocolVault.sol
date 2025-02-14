// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IProtocolVault {
    struct PVault {
        address reserveAddr; // BTC reserve address
        uint256 reserveAmt;
        address tab; // Tab address
        uint256 tabAmt; // Tab reserve amount
        uint256 price; // RESERVE/TAB price rate
    }

    function updateReserveSafe(address _reserveSafe) external;

    function initCtrlAltDel(
        address _reserveAddr,
        uint256 _reserveAmt,
        address _tabAddr,
        uint256 _tabAmt,
        uint256 _reserveTabPrice
    )
        external;

    function buyTab(address _reserveAddr, address _tabAddr, uint256 _reserveAmt) external returns (uint256);

    function sellTab(address _reserveAddr, address _tabAddr, uint256 _tabAmt) external returns (uint256);

    event UpdatedReserveSafe(address _valueFrom, address _valueTo);
    event InitCtrlAltDel(address reserveAddr, uint256 reserveAmt, address tabAddr, uint256 tabAmt, uint256 price);
    event BuyTab(address indexed buyer, address reserveAddr, uint256 reserveAmt, address tabAddr, uint256 tabAmt);
    event SellTab(address indexed seller, address reserveAddr, uint256 reserveAmt, address tabAddr, uint256 tabAmt);

    error ExistedProtovolVault();
    error NotExistedProtocolVault();
    error ZeroValue();
    error InsufficientReserveBalance();
    error ZeroAddress();
    error InvalidReserveSafe();
}
