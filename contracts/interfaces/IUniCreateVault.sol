// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPriceData} from "../interfaces/IUniTabOperation.sol";

interface IUniCreateVault {
    function setAuthorizedDestinations(address[] calldata addrs, bool[] calldata isAuthorized) external;

    function createVault(
        address _destination,
        address _receiver,
        address _sendToken, 
        uint256 _sendAmount, 
        uint256 _receiveGasAmt,
        uint256 _receiveTabAmt, 
        uint256 _btcOutMin,
        IPriceData.UpdatePriceData calldata sigPrice
    ) external payable;

    event AuthorizedDestination(address indexed destination, bool isAuthorized);

    event TokenOrGasTransferReverted(
        address indexed token,
        address indexed receiver, 
        uint256 tokenAmt,
        uint256 gasAmt,
        uint256 returnedTokenOrGasAmount
    );

    event CreateVault(
        address indexed sender,
        address indexed receiver,
        address destination,
        address sendToken,
        uint256 sendAmount,
        uint256 sendGasAmt,
        uint256 receiveGasAmt,
        bytes32 tabKey,
        uint256 receiveTabAmount
    );

    error InvalidLength();
    error InvalidDestination();
    error InvalidSendTokenOrAmount();
    error ZeroTabAmount();
    error ZeroReserve();
    error GasRefundFailed();
}