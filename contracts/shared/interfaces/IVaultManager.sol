// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVaultManager {

    function pause() external;
    function unpause() external;
    function configContractAddress(
        address _config,
        address _reserveRegistry,
        address _tabRegistry,
        address _priceOracle,
        address _keeper
    )
        external;
    function getOwnerList() external view returns (address[] memory);
    function getAllVaultIDByOwner(address _owner) external view returns (uint256[] memory);
    function initNewTab(bytes3 _tab) external;
    function createVault(bytes32 _reserveKey, uint256 _reserveAmt, bytes3 _tab, uint256 _tabAmt) external;
    function adjustTab(uint256 _vaultId, uint256 _tabAmt, bool _toWithdraw) external;
    function adjustReserve(uint256 _vaultId, uint256 _reserveAmt, bool _toWithdraw) external;
    function chargeRiskPenalty(address _vaultOwner, uint256 _vaultId, uint256 _amt) external;
    function liquidateVault(address _vaultOwner, uint256 _vaultId, uint256 _osRiskPenalty) external;
    function ctrlAltDel(bytes3 _tab, uint256 _btcTabRate, address _protocolVaultAddr) external;

}
