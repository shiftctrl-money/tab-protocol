// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPriceData} from "../interfaces/IUniTabOperation.sol";

interface IUniWithdrawTab {
    function setAuthorizedDestinations(address[] calldata addrs, bool[] calldata isAuthorized) external;

    function withdrawTab(
        uint256 _vaultId,
        uint256 _withdrawTabAmt,
        address _destination,
        address _receiver,
        IPriceData.UpdatePriceData calldata sigPrice
    ) external payable;

    event AuthorizedDestination(address indexed destination, bool isAuthorized);

    event WithdrawTab(
        address indexed owner,
        uint256 vaultId,
        uint256 withdrawTabAmt,
        address destination,
        address receiver,
        uint256 fundedGasAmt
    );

    event RevertWithdrawTab(
        address indexed owner,
        uint256 vaultId,
        uint256 withdrawTabAmt,
        uint256 revertedGasAmt
    );

    error InvalidLength();
    error InvalidVault();
    error InvalidDestination();
    error ReversalGasFailed(address sender, uint256 amt);
}