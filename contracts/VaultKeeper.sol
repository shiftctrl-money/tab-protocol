// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";
import "./shared/interfaces/IVaultManager.sol";

contract VaultKeeper is Initializable, AccessControlDefaultAdminRulesUpgradeable, UUPSUpgradeable {

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    // [start] ------------ Same Config setting ------------

    struct ReserveParams {
        uint256 minReserveRatio; // default 180
        uint256 liquidationRatio; // default 120
    }

    mapping(bytes32 => ReserveParams) public reserveParams;

    struct TabParams {
        uint256 riskPenaltyPerFrame; // default 150 for 1.5% for 1 frame = 24 hours, penalty_amt = delta *
            // riskPenaltyPerFrame
    }

    mapping(bytes3 => TabParams) public tabParams;

    event UpdatedReserveParams(bytes32[] reserveKey, uint256[] minReserveRatio, uint256[] liquidationRatio);
    event UpdatedTabParams(bytes3[] tab, uint256[] riskPenaltyPerFrame);
    event UpdatedRiskPenaltyFrameInSecond(uint256 b4, uint256 _after);

    // [end] ------------ Same Config setting ------------

    uint256 public riskPenaltyFrameInSecond; // Duration of risk penalty frame
    uint256 public checkedTimestamp; // last checked timestamp (start of risk penalty time frame)

    address public vaultManager;

    // Vaults to be tracked and charged risk penalty in current time frame
    uint256[] public vaultIdList;

    struct VaultCacheDetails {
        address vaultOwner;
        bytes3 vaultTab;
        uint256 listIndex;
    }

    mapping(uint256 => VaultCacheDetails) public vaultMap; // key vaultId
    mapping(address => mapping(uint256 => uint256)) public largestVaultDelta; // vault_owner: (id :
        // largest_delta_value_in_current_frame)

    struct VaultDetails {
        address vaultOwner;
        uint256 vaultId;
        bytes3 tab;
        bytes32 reserveKey;
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

    mapping(uint256 => RiskPenaltyCharge) public chargedMap; // vaultId: RiskPenaltyCharge Latest(last) risk penalty
        // charge details based on vault id

    event UpdatedVaultManagerAddress(address old, address _new);
    event RiskPenaltyCharged(
        uint256 indexed timestamp,
        address indexed vaultOwner,
        uint256 indexed vaultId,
        uint256 delta,
        uint256 riskPenaltyAmt
    );
    event StartVaultLiquidation(
        uint256 indexed timestamp, address indexed vaultOwner, uint256 indexed vaultId, uint256 latestRiskPenaltyAmt
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        address _admin2,
        address _deployer,
        address _authorizedRelayer,
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
        _grantRole(EXECUTOR_ROLE, _authorizedRelayer);
        _grantRole(EXECUTOR_ROLE, _vaultManager);
        _grantRole(MAINTAINER_ROLE, _admin);
        _grantRole(MAINTAINER_ROLE, _admin2);
        _grantRole(MAINTAINER_ROLE, _authorizedRelayer);
        _grantRole(MAINTAINER_ROLE, _config);
        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _admin2);
        _grantRole(DEPLOYER_ROLE, _deployer);
        vaultManager = _vaultManager;
        riskPenaltyFrameInSecond = 24 hours; // 86400 = 60 * 60 * 24
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function updateVaultManagerAddress(address _vaultManager) external onlyRole(DEPLOYER_ROLE) {
        _grantRole(EXECUTOR_ROLE, _vaultManager);
        emit UpdatedVaultManagerAddress(vaultManager, _vaultManager);
        vaultManager = _vaultManager;
    }

    /// @dev triggered from Config
    function setReserveParams(
        bytes32[] calldata _reserveKey,
        uint256[] calldata _minReserveRatio,
        uint256[] calldata _liquidationRatio
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        require(
            _reserveKey.length == _minReserveRatio.length && _reserveKey.length == _liquidationRatio.length,
            "INVALID_LENGTH"
        );
        for (uint256 i = 0; i < _reserveKey.length; i = unsafe_inc(i)) {
            require(_minReserveRatio[i] > 100, "INVALID_MIN_RESERVE_RATIO");
            require(_liquidationRatio[i] > 100, "INVALID_LIQUIDATION_RATIO");

            reserveParams[_reserveKey[i]].minReserveRatio = _minReserveRatio[i];
            reserveParams[_reserveKey[i]].liquidationRatio = _liquidationRatio[i];
        }
        emit UpdatedReserveParams(_reserveKey, _minReserveRatio, _liquidationRatio);
    }

    /// @dev triggered from Config
    function setTabParams(
        bytes3[] calldata _tabs,
        uint256[] calldata _riskPenaltyPerFrameList
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        require(_tabs.length == _riskPenaltyPerFrameList.length, "INVALID_LENGTH");
        for (uint256 i = 0; i < _tabs.length; i = unsafe_inc(i)) {
            require(_riskPenaltyPerFrameList[i] > 0, "INVALID_RP_PER_FRAME");

            tabParams[_tabs[i]].riskPenaltyPerFrame = _riskPenaltyPerFrameList[i];
        }
        emit UpdatedTabParams(_tabs, _riskPenaltyPerFrameList);
    }

    function setRiskPenaltyFrameInSecond(uint256 _riskPenaltyFrameInSecond) external onlyRole(MAINTAINER_ROLE) {
        require(_riskPenaltyFrameInSecond > 0, "INVALID_VALUE");
        emit UpdatedRiskPenaltyFrameInSecond(riskPenaltyFrameInSecond, _riskPenaltyFrameInSecond);
        riskPenaltyFrameInSecond = _riskPenaltyFrameInSecond;
    }

    /// @dev Returns true(expired) if current timestamp exceeded last check + frame duration
    function isExpiredRiskPenaltyCheck() external view returns (bool) {
        return block.timestamp >= (checkedTimestamp + riskPenaltyFrameInSecond);
    }

    /**
     * @dev Triggered by relayer when price is updated.
     * Pass in vaults details to calculate latest reserve ratio
     * If 120 < Reserve Ratio < 180 , calculate risk penalty
     * If Reserve Ratio < 120 , emit VaultLiquidation
     */
    function checkVault(uint256 _timestamp, VaultDetails memory v) external onlyRole(EXECUTOR_ROLE) {
        require(_timestamp >= checkedTimestamp, "OUTDATED_TIMESTAMP");
        require(v.reserveValue < v.minReserveValue, "NO_DELTA");

        bool clearedRP = _pushAllVaultRiskPenalty(_timestamp, v.vaultId);

        if (checkedTimestamp == 0) {
            checkedTimestamp = _timestamp;
        }

        uint256 osTab = v.osTab;
        uint256 minReserveValue = v.minReserveValue;

        // current vault has been charged risk penalty from previous frame, recalc os tab
        if (clearedRP) {
            osTab += chargedMap[v.vaultId].chargedRP;
            minReserveValue = FixedPointMathLib.mulDiv(osTab, reserveParams[v.reserveKey].minReserveRatio, 100);
        }
        uint256 reserveDelta = minReserveValue - v.reserveValue;
        uint256 vaultReserveRatio = calcReserveRatio(v.reserveValue, osTab);

        // liquidate this vault if RR < 120
        if (vaultReserveRatio < (reserveParams[v.reserveKey].liquidationRatio * 100)) {
            uint256 riskPenalty = 0;
            if (largestVaultDelta[v.vaultOwner][v.vaultId] > reserveDelta) {
                riskPenalty =
                    calcRiskPenaltyAmt(tabParams[v.tab].riskPenaltyPerFrame, largestVaultDelta[v.vaultOwner][v.vaultId]);
            } else {
                riskPenalty = calcRiskPenaltyAmt(tabParams[v.tab].riskPenaltyPerFrame, reserveDelta);
            }

            emit StartVaultLiquidation(_timestamp, v.vaultOwner, v.vaultId, riskPenalty);
            emit RiskPenaltyCharged(_timestamp, v.vaultOwner, v.vaultId, reserveDelta, riskPenalty);
            IVaultManager(vaultManager).liquidateVault(v.vaultOwner, v.vaultId, riskPenalty);
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
        require(block.timestamp >= checkedTimestamp, "OUTDATED_TIMESTAMP");
        if (largestVaultDelta[_vaultOwner][_vaultId] > 0 && vaultIdList.length > 0) {
            VaultCacheDetails memory vd = vaultMap[_vaultId];

            uint256 riskPenalty = calcRiskPenaltyAmt(
                tabParams[vd.vaultTab].riskPenaltyPerFrame, largestVaultDelta[vd.vaultOwner][_vaultId]
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
        bytes32 _reserveKey,
        uint256 _totalReserve,
        uint256 _totalOS
    )
        external
        view
        returns (bool)
    {
        return calcReserveRatio(_totalReserve, _totalOS) < (reserveParams[_reserveKey].liquidationRatio * 100);
    }

    function _pushAllVaultRiskPenalty(uint256 _timestamp, uint256 _vaultId) internal returns (bool clearedRP) {
        require(_timestamp >= checkedTimestamp, "OUTDATED_TIMESTAMP");

        // next frame started, cleared all previous frame's cache
        if (checkedTimestamp > 0 && _timestamp >= (checkedTimestamp + riskPenaltyFrameInSecond)) {
            if (vaultIdList.length > 0) {
                uint256 vaultId;
                uint256 _gap = (_timestamp - checkedTimestamp) / riskPenaltyFrameInSecond;
                if (_gap == 0) {
                    _gap = 1;
                }
                checkedTimestamp = checkedTimestamp + (riskPenaltyFrameInSecond * _gap);

                for (uint256 r = 0; r < vaultIdList.length; r = unsafe_inc(r)) {
                    vaultId = vaultIdList[r];
                    VaultCacheDetails memory vd = vaultMap[vaultId];
                    uint256 riskPenalty = calcRiskPenaltyAmt(
                        tabParams[vd.vaultTab].riskPenaltyPerFrame, largestVaultDelta[vd.vaultOwner][vaultId]
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

    // ------------------------- internal functions -------------------------------------------

    function calcRiskPenaltyAmt(uint256 _rate, uint256 _delta) internal pure returns (uint256) {
        return FixedPointMathLib.mulDiv(_rate, _delta, 10000);
    }

    function calcReserveRatio(uint256 _reserveValue, uint256 _osAmt) internal pure returns (uint256) {
        return FixedPointMathLib.mulDiv(_reserveValue, 10000, _osAmt);
    }

    function unsafe_inc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

}
