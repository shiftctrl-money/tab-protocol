// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniDepositReserve {
    function depositReserve(
        address _vaultOwner,
        uint256 _vaultId, 
        address _sendToken,
        uint256 _sendAmount,
        uint256 _btcOutMin
    ) external payable;

    event DepositReserve(
        address indexed vaultOwner,
        uint256 vaultId,
        address sendToken,
        uint256 sendAmount,
        uint256 sendGasAmt
    );

    event TokenOrGasTransferReverted(
        address indexed token,
        address indexed receiver, 
        uint256 tokenAmt,
        uint256 gasAmt,
        uint256 returnedTokenOrGasAmount
    );

    error InvalidSendTokenOrAmount();
    error ZeroReserve();
    error GasRefundFailed();
}