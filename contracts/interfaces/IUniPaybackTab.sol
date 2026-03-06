// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniPaybackTab {
    function updateZetaToken(address _zetaToken) external;

    function updateVaultManager(address _vaultManager) external;

    function paybackTab(
        address _vaultOwner,
        uint256 _vaultId,
        address _paybackTab,
        uint256 _paybackAmt
    ) external;

    event UpdatedZetaToken(
        address indexed oldZetaToken,
        address indexed newZetaToken
    );

    event UpdatedVaultManager(
        address indexed oldVaultManager,
        address indexed newVaultManager
    );

    event PaybackTab(
        address indexed vaultOwner, 
        uint256 vaultId, 
        address paybackTab,
        uint256 paybackAmt
    );

    error ZeroPayback();
}
