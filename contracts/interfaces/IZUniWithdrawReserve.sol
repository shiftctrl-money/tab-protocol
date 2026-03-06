// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IZUniWithdrawReserve {
   
    event ZWithdrawReserve(
        address indexed owner,
        address indexed receiver,
        uint256 vaultId,
        uint256 chainId,
        uint256 withdrawAmt,
        uint256 swapFromAmt,
        address receiveToken,
        uint256 receiveAmt
    );

    event RevertedWithdrawReserve(
        address indexed vaultOwner, 
        uint256 vaultId,
        uint256 chainId,
        uint256 withdrawAmt,
        address receiver, 
        address receiveToken, 
        uint256 receiveAmt
    );

    error UnsupportedReceiveToken();
    error InsufficientGasFee(uint256 availableGasFee, uint256 requiredGasFee);
    error InsufficientReserveAmt();
    error RevertTransferFailed(address receiver, address token, uint256 amt);

}