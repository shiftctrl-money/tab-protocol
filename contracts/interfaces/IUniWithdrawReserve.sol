// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPriceData} from "../interfaces/IUniTabOperation.sol";

interface IUniWithdrawReserve {
    function setAuthorizedDestinations(address[] calldata addrs, bool[] calldata isAuthorized) external;

    function withdrawReserve(
        uint256 _vaultId,
        uint256 _withdrawAmt,
        address _destination,
        address _receiver,
        address _receiveToken,
        uint256 _minAmountOut,
        IPriceData.UpdatePriceData calldata sigPrice
    ) external;

    event AuthorizedDestination(address indexed destination, bool isAuthorized);

    event WithdrawReserve(
        address indexed owner,
        uint256 vaultId,
        uint256 withdrawAmt,
        address destination,
        address receiver,
        address receiveToken
    );

    error InvalidLength();
    error InvalidVault();
    error InvalidDestination();
}