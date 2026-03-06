// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPriceData} from "./IUniTabOperation.sol";

interface IZUniWithdrawTab {
    function withdrawTab(
        uint256 _vaultId,
        uint256 _withdrawTabAmt,
        address _destination,
        address _receiver,
        IPriceData.UpdatePriceData calldata sigPrice
    ) external payable;

    event ZWithdrawTab(
        address indexed owner,
        address indexed receiver,
        uint256 vaultId,
        uint256 chainId,
        bytes32 tabKey,
        uint256 withdrawTabAmt,
        address destination
    );

    error ZeroValue();
    error ZeroAddress();
    error ZeroDestinationGas();
}