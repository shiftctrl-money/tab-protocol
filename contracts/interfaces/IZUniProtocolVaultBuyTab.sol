// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IZUniProtocolVaultBuyTab {
    function updateProtocolVault(address _protocolVault) external;

    event UpdatedProtocolVault(
        address indexed oldProtocolVault,
        address indexed newProtocolVault
    );

    event ZBuyTab(
        address indexed receiver,
        uint256 chainId,
        uint256 sourceReserveAmount,
        uint256 btcReserveAmount,
        uint256 receiveGasAmount,
        bytes32 tabKey,
        uint256 receiveTabAmount
    );

    error GasTransferFailed();

}