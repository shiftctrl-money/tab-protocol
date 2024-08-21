// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../../oracle/interfaces/IPriceOracle.sol";

interface IVaultKeeper {

    function riskPenaltyFrameInSecond() external view returns (uint256);
    function checkedTimestamp() external view returns (uint256);
    function vaultManager() external view returns (address);
    function vaultIdList(uint256) external view returns (uint256);
    function vaultMap(uint256) external view returns (address vaultOwner, bytes3 vaultTab, uint256 listIndex);
    function largestVaultDelta(address, uint256) external view returns (uint256);
    function chargedMap(uint256)
        external
        view
        returns (address owner, uint256 vaultId, uint256 delta, uint256 chargedRP);
    function updateVaultManagerAddress(address) external;

    function setReserveParams(
        bytes32[] calldata _reserveKey,
        uint256[] calldata _minReserveRatio,
        uint256[] calldata _liquidationRatio
    )
        external;

    function setTabParams(bytes3[] calldata _tabs, uint256[] calldata _riskPenaltyPerFrameList) external;

    function setRiskPenaltyFrameInSecond(uint256 _riskPenaltyFrameInSecond) external;

    struct VaultDetails {
        address vaultOwner;
        uint256 vaultId;
        bytes3 tab;
        bytes32 reserveKey;
        uint256 osTab;
        uint256 reserveValue;
        uint256 minReserveValue;
    }

    function isExpiredRiskPenaltyCheck() external view returns (bool);
    function checkVault(uint256 _timestamp, VaultDetails calldata v, IPriceOracle.UpdatePriceData calldata sigPrice) external;
    function pushVaultRiskPenalty(address _vaultOwner, uint256 _vaultId) external;
    function pushAllVaultRiskPenalty(uint256 _timestamp) external;
    function isLiquidatingVault(
        bytes32 _reserveKey,
        uint256 _totalReserve,
        uint256 _totalOS
    )
        external
        view
        returns (bool);

}
