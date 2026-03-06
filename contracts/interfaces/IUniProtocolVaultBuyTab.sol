// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniProtocolVaultBuyTab {
    function setAuthorizedDestinations(address[] calldata addrs, bool[] calldata isAuthorized) external;

    function buyTab(
        address _destination,
        address _receiver,
        address _sendToken, 
        uint256 _sendAmount, 
        uint256 _receiveGasAmt,
        bytes32 _receiveTabKey,
        uint256 _btcOutMin
    ) external payable;

    event AuthorizedDestination(address indexed destination, bool isAuthorized);

    event TokenOrGasTransferReverted(
        address indexed token,
        address indexed receiver, 
        uint256 tokenAmt,
        uint256 gasAmt,
        uint256 returnedTokenOrGasAmount
    );

    event BuyTab(
        address indexed sender,
        address indexed receiver,
        address destination,
        address sendToken,
        uint256 sendAmount,
        uint256 sendGasAmt,
        uint256 receiveGasAmt,
        bytes32 receiveTabKey
    );

    error InvalidLength();
    error InvalidDestination();
    error InvalidSendTokenOrAmount();
    error ZeroReserve();
    error ZeroTabKey();
    error GasRefundFailed();
}