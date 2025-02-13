// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRulesUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IConfig} from "../interfaces/IConfig.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IVaultKeeper} from "../interfaces/IVaultKeeper.sol";

/**
 * @title Track and charge risk penalty, and liquidate vault if reserve ratio fall below configured threshold.
 * @notice Refer https://www.shiftctrl.money for details. 
 */
contract VaultKeeper is Initializable, AccessControlDefaultAdminRulesUpgradeable, UUPSUpgradeable, IVaultKeeper {

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    address public vaultManager;

    // Sync. values from Config contract.
    mapping(bytes32 => IConfig.TabParams) public tabParams; 
    
    // Duration of risk penalty frame
    uint256 public riskPenaltyFrameInSecond;
    
    // last checked timestamp (start of risk penalty time frame)
    uint256 public checkedTimestamp; 
    
    // Vaults to be tracked and charged risk penalty in current time frame
    uint256[] public vaultIdList;

    // key vaultId
    mapping(uint256 => VaultCacheDetails) public vaultMap; 

    // vault_owner: (id : largest_delta_value_in_current_frame)
    mapping(address => mapping(uint256 => uint256)) public largestVaultDelta; 

    // vaultId: RiskPenaltyCharge - Latest(last) risk penalty
    //   charge details based on vault id
    mapping(uint256 => RiskPenaltyCharge) public chargedMap; 
        
    constructor() {
        _disableInitializers();
    }

    /**
     * @param _admin Governance controller.
     * @param _admin2 Emergency governance controller.
     * @param _tabKeeperModule Authorized Tab-Keeper account.
     * @param _vaultManager Vault Manager contract.
     * @param _config Config contract.
     */
    function initialize(
        address _admin,
        address _admin2,
        address _upgrader,
        address _tabKeeperModule,
        address _vaultManager,
        address _config
    )
        public
        initializer
    {
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __UUPSUpgradeable_init();

        _grantRole(EXECUTOR_ROLE, _admin);
        _grantRole(EXECUTOR_ROLE, _admin2);
        _grantRole(EXECUTOR_ROLE, _tabKeeperModule);
        _grantRole(EXECUTOR_ROLE, _vaultManager);
        _setRoleAdmin(EXECUTOR_ROLE, DEPLOYER_ROLE);

        _grantRole(MAINTAINER_ROLE, _admin);
        _grantRole(MAINTAINER_ROLE, _admin2);
        _grantRole(MAINTAINER_ROLE, _tabKeeperModule);
        _grantRole(MAINTAINER_ROLE, _config);

        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _admin2);
        
        _grantRole(UPGRADER_ROLE, _upgrader);

        vaultManager = _vaultManager;
        riskPenaltyFrameInSecond = 24 hours; // 86400 = 60 * 60 * 24
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function updateVaultManagerAddress(address _vaultManager) external onlyRole(DEPLOYER_ROLE) {
        if (_vaultManager == address(0))
            revert ZeroAddress();
        if (_vaultManager.code.length == 0)
            revert InvalidVaultManager();
        emit UpdatedVaultManagerAddress(vaultManager, _vaultManager);
        vaultManager = _vaultManager;
        _grantRole(EXECUTOR_ROLE, _vaultManager);
    }

    /**
     * @dev Each Tab is associated with one set of `TabParams` values.
     * @param _tab Tab code list.
     * @param _tabParams Tab params list. Must have same array length as `_tab` array.
     */
    function setTabParams(
        bytes3[] calldata _tab,
        IConfig.TabParams[] calldata _tabParams
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        if (_tab.length != _tabParams.length)
            revert IConfig.InvalidArrayLength();

        bytes32 tabKey;
        for (uint256 i; i < _tab.length; i++) {
            tabKey = tabCodeToTabKey(_tab[i]);
            tabParams[tabKey].riskPenaltyPerFrame = _tabParams[i].riskPenaltyPerFrame;
            tabParams[tabKey].processFeeRate = _tabParams[i].processFeeRate;
            tabParams[tabKey].minReserveRatio = _tabParams[i].minReserveRatio;
            tabParams[tabKey].liquidationRatio = _tabParams[i].liquidationRatio;
            emit IConfig.UpdatedTabParams(
                _tab[i], 
                _tabParams[i].riskPenaltyPerFrame, 
                _tabParams[i].processFeeRate,
                _tabParams[i].minReserveRatio,
                _tabParams[i].liquidationRatio
            );
        }
    }

    /// @dev One unit of risk penalty is charged per each frame (in seconds, e.g. 24 hours)
    function setRiskPenaltyFrameInSecond(
        uint256 _riskPenaltyFrameInSecond
    ) 
        external 
        onlyRole(MAINTAINER_ROLE) 
    {
        if (_riskPenaltyFrameInSecond == 0)
            revert ZeroValue();
        emit UpdatedRiskPenaltyFrameInSecond(riskPenaltyFrameInSecond, _riskPenaltyFrameInSecond);
        riskPenaltyFrameInSecond = _riskPenaltyFrameInSecond;
    }

    /// @dev Returns true(expired) if current timestamp exceeded last check + configured frame duration
    function isExpiredRiskPenaltyCheck() external view returns (bool) {
        return block.timestamp >= (checkedTimestamp + riskPenaltyFrameInSecond);
    }

    /**
     * @dev Triggered by offchain service on fixed interval.
     * Pass in vaults details to calculate latest reserve ratio
     * If 120 < Reserve Ratio < 180 , calculate risk penalty
     * If Reserve Ratio < 120 , emit VaultLiquidation
     */
    function checkVault(
        uint256 _timestamp, 
        VaultDetails calldata v, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) 
        external 
        onlyRole(EXECUTOR_ROLE) 
    {
        if (_timestamp < checkedTimestamp)
            revert OutdatedTimestamp();
        if (v.reserveValue >= v.minReserveValue)
            revert NoDeltaValue();

        bool clearedRP = _pushAllVaultRiskPenalty(_timestamp, v.vaultId);

        if (checkedTimestamp == 0) {
            checkedTimestamp = _timestamp;
        }

        uint256 osTab = v.osTab;
        uint256 minReserveValue = v.minReserveValue;
        bytes32 tabKey = tabCodeToTabKey(v.tab);

        // current vault has been charged risk penalty from previous frame, recalc os tab
        if (clearedRP) {
            osTab += chargedMap[v.vaultId].chargedRP;
            minReserveValue = Math.mulDiv(osTab, tabParams[tabKey].minReserveRatio, 100);
        }
        uint256 reserveDelta = minReserveValue - v.reserveValue;
        uint256 vaultReserveRatio = calcReserveRatio(v.reserveValue, osTab);

        // liquidate this vault if RR < 120
        if (vaultReserveRatio < (tabParams[tabKey].liquidationRatio * 100)) {
            uint256 riskPenalty;
            if (largestVaultDelta[v.vaultOwner][v.vaultId] > reserveDelta) {
                riskPenalty =
                    calcRiskPenaltyAmt(tabParams[tabKey].riskPenaltyPerFrame, largestVaultDelta[v.vaultOwner][v.vaultId]);
            } else {
                riskPenalty = calcRiskPenaltyAmt(tabParams[tabKey].riskPenaltyPerFrame, reserveDelta);
            }

            emit StartVaultLiquidation(_timestamp, v.vaultOwner, v.vaultId, riskPenalty);
            emit RiskPenaltyCharged(_timestamp, v.vaultOwner, v.vaultId, reserveDelta, riskPenalty);
            IVaultManager(vaultManager).liquidateVault(v.vaultId, riskPenalty, sigPrice);
        } else {
            if (largestVaultDelta[v.vaultOwner][v.vaultId] > 0) {
                if (reserveDelta > largestVaultDelta[v.vaultOwner][v.vaultId]) {
                    largestVaultDelta[v.vaultOwner][v.vaultId] = reserveDelta;
                }
            } else {
                largestVaultDelta[v.vaultOwner][v.vaultId] = reserveDelta;
                vaultIdList.push(v.vaultId);
                vaultMap[v.vaultId] = VaultCacheDetails(v.vaultOwner, v.tab, vaultIdList.length - 1);
            }
        }
    }

    /// @dev Single vault risk penalty update whenever vault operation is performed by VaultManager
    function pushVaultRiskPenalty(address _vaultOwner, uint256 _vaultId) external onlyRole(EXECUTOR_ROLE) {
        if (largestVaultDelta[_vaultOwner][_vaultId] > 0 && vaultIdList.length > 0) {
            VaultCacheDetails memory vd = vaultMap[_vaultId];

            uint256 riskPenalty = calcRiskPenaltyAmt(
                tabParams[tabCodeToTabKey(vd.vaultTab)].riskPenaltyPerFrame, largestVaultDelta[vd.vaultOwner][_vaultId]
            );
            RiskPenaltyCharge memory riskPenaltyCharge =
                RiskPenaltyCharge(vd.vaultOwner, _vaultId, largestVaultDelta[vd.vaultOwner][_vaultId], riskPenalty);

            chargedMap[_vaultId] = riskPenaltyCharge;
            largestVaultDelta[vd.vaultOwner][_vaultId] = 0;

            emit RiskPenaltyCharged(
                block.timestamp,
                riskPenaltyCharge.owner,
                riskPenaltyCharge.vaultId,
                riskPenaltyCharge.delta,
                riskPenaltyCharge.chargedRP
            );
            IVaultManager(vaultManager).chargeRiskPenalty(
                riskPenaltyCharge.owner, riskPenaltyCharge.vaultId, riskPenaltyCharge.chargedRP
            );

            vaultMap[vaultIdList[vaultIdList.length - 1]].listIndex = vd.listIndex; // update map index of last item
            vaultIdList[vd.listIndex] = vaultIdList[vaultIdList.length - 1]; // copy last item to current(deleting item)
            vaultIdList.pop(); // remove last item
        }
    }

    /// @dev Called when risk penalty tracking frame is expired. To update all cached risk penalty into vault(s).
    function pushAllVaultRiskPenalty(uint256 _timestamp) public onlyRole(EXECUTOR_ROLE) {
        _pushAllVaultRiskPenalty(_timestamp, 0);
    }

    function isLiquidatingVault(
        bytes3 _tab,
        uint256 _totalReserve,
        uint256 _totalOS
    )
        external
        view
        returns (bool)
    {
        return calcReserveRatio(_totalReserve, _totalOS) < (tabParams[tabCodeToTabKey(_tab)].liquidationRatio * 100);
    }

    function getVaultMap(
        uint256 _vaultId
    ) 
        external 
        view 
        returns (VaultCacheDetails memory) 
    {
        return vaultMap[_vaultId];
    }

    function getChargedMap(
        uint256 _vaultId
    )
        external
        view
        returns (RiskPenaltyCharge memory)
    {
        return chargedMap[_vaultId];
    }

    function tabCodeToTabKey(bytes3 code) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(code));
    }

    function _pushAllVaultRiskPenalty(uint256 _timestamp, uint256 _vaultId) internal returns (bool clearedRP) {
        if (_timestamp < checkedTimestamp)
            revert OutdatedTimestamp();

        // next frame started, cleared all previous frame's cache
        if (checkedTimestamp > 0 && _timestamp >= (checkedTimestamp + riskPenaltyFrameInSecond)) {
            if (vaultIdList.length > 0) {
                uint256 vaultId;
                uint256 _gap = (_timestamp - checkedTimestamp) / riskPenaltyFrameInSecond;
                if (_gap == 0) {
                    _gap = 1;
                }
                checkedTimestamp = checkedTimestamp + (riskPenaltyFrameInSecond * _gap);

                for (uint256 r = 0; r < vaultIdList.length; r++) {
                    vaultId = vaultIdList[r];
                    VaultCacheDetails memory vd = vaultMap[vaultId];
                    uint256 riskPenalty = calcRiskPenaltyAmt(
                        tabParams[tabCodeToTabKey(vd.vaultTab)].riskPenaltyPerFrame, largestVaultDelta[vd.vaultOwner][vaultId]
                    );
                    RiskPenaltyCharge memory riskPenaltyCharge = RiskPenaltyCharge(
                        vd.vaultOwner, vaultId, largestVaultDelta[vd.vaultOwner][vaultId], riskPenalty
                    );
                    chargedMap[vaultId] = riskPenaltyCharge;
                    largestVaultDelta[vd.vaultOwner][vaultId] = 0;
                    if (_vaultId == vaultId) {
                        clearedRP = true;
                    }

                    emit RiskPenaltyCharged(
                        checkedTimestamp,
                        riskPenaltyCharge.owner,
                        riskPenaltyCharge.vaultId,
                        riskPenaltyCharge.delta,
                        riskPenaltyCharge.chargedRP
                    );
                    IVaultManager(vaultManager).chargeRiskPenalty(
                        riskPenaltyCharge.owner, riskPenaltyCharge.vaultId, riskPenaltyCharge.chargedRP
                    );
                }

                // reset current frame tracking
                vaultIdList = new uint256[](0);
                // vaultMap is not cleared, key pointer has been reset from vaultIdList
            }
        }
    }

    function calcRiskPenaltyAmt(uint256 _rate, uint256 _delta) internal pure returns (uint256) {
        return Math.mulDiv(_rate, _delta, 10000);
    }

    function calcReserveRatio(uint256 _reserveValue, uint256 _osAmt) internal pure returns (uint256) {
        return Math.mulDiv(_reserveValue, 10000, _osAmt);
    }

}
