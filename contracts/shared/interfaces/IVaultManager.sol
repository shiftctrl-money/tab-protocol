// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../../oracle/interfaces/IPriceOracle.sol";

interface IVaultManager {
    struct Vault {
        address reserveAddr; // locked reserve address, e.g. WBTC, cBTC
        uint256 reserveAmt; // reserve value (18 decimals)
        address tab; // minted tab currency
        uint256 tabAmt; // tab currency value (18 decimals)
        uint256 osTabAmt; // other O/S tab, e.g. risk penalty or fee amt
        uint256 pendingOsMint; // osTabAmt to be minted out
    }
    function vaults(address, uint256) external view returns(Vault memory);
    function configContractAddress(
        address _config,
        address _reserveRegistry,
        address _tabRegistry,
        address _priceOracle,
        address _keeper
    ) external;
    function getOwnerList() external view returns (address[] memory);
    function getAllVaultIDByOwner(address _owner) external view returns (uint256[] memory);
    function createVault(
        bytes32 _reserveKey, 
        uint256 _reserveAmt, 
        uint256 _tabAmt, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) external;
    function withdrawTab(uint256 _vaultId, uint256 _tabAmt, IPriceOracle.UpdatePriceData calldata sigPrice) external;
    function paybackTab(uint256 _vaultId, uint256 _tabAmt) external;
    function withdrawReserve(uint256 _vaultId, uint256 _reserveAmt, IPriceOracle.UpdatePriceData calldata sigPrice) external;
    function depositReserve(uint256 _vaultId, uint256 _reserveAmt) external;
    function chargeRiskPenalty(address _vaultOwner, uint256 _vaultId, uint256 _amt) external;
    function liquidateVault(
        address _vaultOwner, 
        uint256 _vaultId, 
        uint256 _osRiskPenalty, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) external;
    function ctrlAltDel(bytes3 _tab, uint256 _btcTabRate, address _protocolVaultAddr) external;

}
