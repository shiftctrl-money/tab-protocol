// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniProtocolVaultSellTab {
    function updateZetaToken(address _zetaToken) external;

    function updateProtocolVault(address _protocolVault) external;

    function sellTab(
        address _reserveAddr,
        address _tabToken,
        uint256 _tabAmt,
        address _receiver
    ) external;

    event UpdatedZetaToken(
        address indexed oldZetaToken,
        address indexed newZetaToken
    );

    event UpdatedProtocolVault(
        address indexed oldProtocolVault,
        address indexed newProtocolVault
    );

    event SellTab(
        address indexed seller,
        address indexed receiver, 
        address reserveAddr, 
        address tabToken,
        uint256 tabAmt
    );

    error ZeroTab();
}
