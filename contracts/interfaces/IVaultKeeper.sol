// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPriceOracle} from "./IPriceOracle.sol";
import {IConfig} from "./IConfig.sol";

interface IVaultKeeper {
    struct VaultCacheDetails {
        address vaultOwner;
        bytes3 vaultTab;
        uint256 listIndex;
    }

    struct VaultDetails {
        address vaultOwner;
        uint256 vaultId;
        bytes3 tab;
        address reserveAddr; //replaced: bytes32 reserveKey;
        uint256 osTab;
        uint256 reserveValue;
        uint256 minReserveValue;
    }

    struct RiskPenaltyCharge {
        address owner;
        uint256 vaultId;
        uint256 delta;
        uint256 chargedRP;
    }

    function vaultManager() external view returns (address);
    function riskPenaltyFrameInSecond() external view returns (uint256);
    function checkedTimestamp() external view returns (uint256);
    function vaultIdList(uint256) external view returns (uint256);
    function getVaultMap(
        uint256
    ) 
        external 
        view 
        returns (VaultCacheDetails memory);
    function largestVaultDelta(address, uint256) external view returns (uint256);
    function getChargedMap(uint256)
        external
        view
        returns (RiskPenaltyCharge memory);

    function updateVaultManagerAddress(address) external;
    function setTabParams(
        bytes3[] calldata _tab,
        IConfig.TabParams[] calldata _tabParams
    ) 
        external;
    function setRiskPenaltyFrameInSecond(uint256 _riskPenaltyFrameInSecond) external;
    function isExpiredRiskPenaltyCheck() external view returns (bool);
    function checkVault(
        uint256 _timestamp, 
        VaultDetails calldata v, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) 
        external;
    function pushVaultRiskPenalty(address _vaultOwner, uint256 _vaultId) external;
    function pushAllVaultRiskPenalty(uint256 _timestamp) external;
    function isLiquidatingVault(
        bytes3 _tab,
        uint256 _totalReserve,
        uint256 _totalOS
    )
        external
        view
        returns (bool);
    function tabCodeToTabKey(bytes3 code) external pure returns(bytes32);

    event UpdatedVaultManagerAddress(address old, address _new);
    event UpdatedRiskPenaltyFrameInSecond(uint256 b4, uint256 _after);
    event RiskPenaltyCharged(
        uint256 indexed timestamp,
        address indexed vaultOwner,
        uint256 indexed vaultId,
        uint256 delta,
        uint256 riskPenaltyAmt
    );
    event StartVaultLiquidation(
        uint256 indexed timestamp, 
        address indexed vaultOwner, 
        uint256 indexed vaultId, 
        uint256 latestRiskPenaltyAmt
    );

    error ZeroValue();
    error ZeroAddress();
    error InvalidVaultManager();
    error OutdatedTimestamp();
    error NoDeltaValue();
}
