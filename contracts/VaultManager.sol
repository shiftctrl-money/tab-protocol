// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";
import "lib/solady/src/utils/SafeTransferLib.sol";
import "./shared/interfaces/ITabERC20.sol";
import "./shared/interfaces/ITabRegistry.sol";
import "./shared/interfaces/IReserveSafe.sol";
import "./shared/interfaces/IReserveRegistry.sol";
import "./shared/interfaces/IConfig.sol";
import "./shared/interfaces/IVaultKeeper.sol";
import "./shared/interfaces/IProtocolVault.sol";
import "./oracle/interfaces/IPriceOracle.sol";
import "./shared/interfaces/IAuctionManager.sol";

contract VaultManager is Initializable, AccessControlDefaultAdminRulesUpgradeable, UUPSUpgradeable {

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant UI_ROLE = keccak256("UI_ROLE");

    struct Vault {
        address reserveAddr; // locked reserve address, e.g. WBTC, cBTC
        uint256 reserveAmt; // reserve value (18 decimals)
        address tab; // minted tab currency
        uint256 tabAmt; // tab currency value (18 decimals)
        uint256 osTabAmt; // other O/S tab, e.g. risk penalty or fee amt
        uint256 pendingOsMint; // osTabAmt to be minted out
    }

    address[] public ownerList;
    mapping(address => uint256[]) public vaultOwners; // vault_owner: array of id
    mapping(address => mapping(uint256 => Vault)) public vaults; // vault_owner: (id : vault)
    uint256 public vaultId; // vault running id

    struct LiquidatedVault {
        address vaultOwner;
        address auctionAddr;
    }

    mapping(uint256 => LiquidatedVault) public liquidatedVaults; // vaultId : LiquidatedVault

    IConfig config;
    IReserveRegistry reserveRegistry;
    IPriceOracle priceOracle;
    IVaultKeeper vaultKeeper;
    address tabRegistry;

    struct CtrlAltDelData {
        int256 uniqReserveCount; // index point to unique reserve type
        uint256 totalTabAmt; // total tab amount of the vaults to be depegged
        uint256 tabToMint; // total tab amount pending to mint
        uint256 totalReserve; // total reserve amount of the reserve type
        uint256 totalReserveConso; // total reserve to be consolidated
    }

    event UpdatedContract(
        address _config, address _reserveRegistry, address _tabRegistry, address _priceOracle, address _keeper
    );
    event NewVault(
        uint256 indexed id, address indexed owner, address reserveAddr, uint256 reserveAmt, address tab, uint256 tabAmt
    );
    event TabWithdraw(address indexed vaultOwner, uint256 indexed id, uint256 withdrawAmt, uint256 newAmt);
    event TabReturned(address indexed vaultOwner, uint256 indexed id, uint256 returnedAmt, uint256 newAmt);
    event ReserveWithdraw(address indexed vaultOwner, uint256 indexed id, uint256 withdrawAmt, uint256 newAmt);
    event ReserveAdded(address indexed vaultOwner, uint256 indexed id, uint256 addedAmt, uint256 newAmt);
    event RiskPenaltyCharged(address indexed vaultOwner, uint256 indexed id, uint256 riskPenaltyAmt, uint256 newAmt);
    event LiquidatedVaultAuction(
        uint256 vaultId, address reserveAddr, uint256 maxReserveQty, address tabAddr, uint256 startPrice
    );
    event CtrlAltDel(
        bytes3 indexed tab, uint256 btcTabRate, uint256 totalTabs, uint256 totalReserve, uint256 consoReserve
    );

    error InvalidVault(address vaultOwner, uint256 vaultId);
    error LiquidatingVault(address vaultOwner, uint256 vaultId);

    modifier tabRegistryCallerOnly() {
        require(_msgSender() == tabRegistry, "Unauthorised Caller!");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, address _admin2, address _deployer, address _ui) public initializer {
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __UUPSUpgradeable_init();

        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _admin2);
        _grantRole(DEPLOYER_ROLE, _deployer);
        _grantRole(UI_ROLE, _ui);
        _setRoleAdmin(KEEPER_ROLE, DEPLOYER_ROLE);
        vaultId = 0;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    /**
     * @dev Called once upon deployment. Governance to change contract implementation if needed.
     * Call related grantRole to changed address.
     */
    function configContractAddress(
        address _config,
        address _reserveRegistry,
        address _tabRegistry,
        address _priceOracle,
        address _keeper
    )
        external
        onlyRole(DEPLOYER_ROLE)
    {
        config = IConfig(_config);
        reserveRegistry = IReserveRegistry(_reserveRegistry);
        tabRegistry = _tabRegistry;
        priceOracle = IPriceOracle(_priceOracle);
        vaultKeeper = IVaultKeeper(_keeper);
        _grantRole(KEEPER_ROLE, _keeper);
        emit UpdatedContract(_config, _reserveRegistry, _tabRegistry, _priceOracle, _keeper);
    }

    function getOwnerList() external view returns (address[] memory) {
        return ownerList;
    }

    function getAllVaultIDByOwner(address _owner) external view returns (uint256[] memory) {
        return vaultOwners[_owner];
    }

    /// @dev UI calls this first (before createVault) to activate new tab.
    /// Once called, wait for the new tab's latest pricing is updated/ready, then call createVault.
    /// Expect valid tab (correct currency code, pricing is supported) is enforced in UI before calling this.
    function initNewTab(bytes3 _tab) external onlyRole(UI_ROLE) {
        ITabRegistry(tabRegistry).createTab(_tab);
    }

    function createVault(bytes32 _reserveKey, uint256 _reserveAmt, bytes3 _tab, uint256 _tabAmt) external {
        require(_reserveKey != 0x00, "INVALID_KEY"); // 0x00 is reserved default not available for vault operation

        address _vaultOwner = _msgSender();
        require(_vaultOwner != address(0), "UNAUTHORIZED");

        require(ITabRegistry(tabRegistry).ctrlAltDelTab(_tab) == 0, "CTRL_ALT_DEL_DONE");
        require(ITabRegistry(tabRegistry).frozenTabs(_tab) == false, "FROZEN_TAB");

        // lock reserve
        address reserveAddr = reserveRegistry.reserveAddr(_reserveKey);
        address reserveSafe = reserveRegistry.reserveSafeAddr(_reserveKey);
        require(
            reserveAddr != address(0) && reserveSafe != address(0) && reserveRegistry.enabledReserve(_reserveKey),
            "INVALID_RESERVE"
        );
        SafeTransferLib.safeTransferFrom(reserveAddr, _vaultOwner, reserveSafe, _reserveAmt); // assume approve called
            // on vault
            // manager b4

        // load config
        (, uint256 minReserveRatio,) = config.reserveParams(_reserveKey);
        require(minReserveRatio > 0, "INVALID_CONFIG");

        // validate withdrawal tab amt
        uint256 price = priceOracle.getPrice(_tab);
        require(price > 0, "INVALID_TAB_PRICE");
        require(_maxWithdraw(_reserveValue(price, _reserveAmt), minReserveRatio, 0) >= _tabAmt, "EXCEED_MAX_WITHDRAW");

        // withdraw tab
        address tab = ITabRegistry(tabRegistry).createTab(_tab); // return existing tab's address or create new if it is
            // non-existed/new tab
        ++vaultId;
        if (
            vaultOwners[_vaultOwner].length == 0 // unique new owner
        ) {
            ownerList.push(_vaultOwner);
        }
        vaultOwners[_vaultOwner].push(vaultId);
        vaults[_vaultOwner][vaultId] = Vault(reserveAddr, _reserveAmt, tab, _tabAmt, 0, 0);
        ITabERC20(tab).mint(_vaultOwner, _tabAmt);

        emit NewVault(vaultId, _vaultOwner, reserveAddr, _reserveAmt, tab, _tabAmt);
    }

    /// @dev Called by user (vault owner) to payback/withdraw Tab.
    /// @dev Called by auction contract whenever receiving valid bid. Bidder pays Tab to payback to liquidated vault.
    function adjustTab(uint256 _vaultId, uint256 _tabAmt, bool _toWithdraw) external {
        address _vaultOwner = _msgSender();
        require(_vaultOwner != address(0), "UNAUTHORIZED");
        require(_tabAmt > 0, "ZERO_VALUE");

        Vault storage v = vaults[_vaultOwner][_vaultId];
        if (v.tabAmt == 0) {
            if (liquidatedVaults[_vaultId].auctionAddr == _vaultOwner) {
                v = vaults[liquidatedVaults[_vaultId].vaultOwner][_vaultId];
            } else {
                revert InvalidVault(_vaultOwner, _vaultId);
            }
        } else {
            require(ITabRegistry(tabRegistry).frozenTabs(ITabERC20(v.tab).tabCode()) == false, "FROZEN_TAB");
            require(liquidatedVaults[_vaultId].auctionAddr == address(0), "LIQUIDATED");
            vaultKeeper.pushVaultRiskPenalty(_vaultOwner, _vaultId);
        }

        bytes3 _tab = ITabERC20(v.tab).tabCode();

        if (_toWithdraw) {
            // retrieve price
            uint256 price = priceOracle.getPrice(_tab);
            require(price > 0, "INVALID_TAB_PRICE");

            // config
            (, uint256 minReserveRatio,) = config.reserveParams(reserveRegistry.reserveKey(v.reserveAddr));
            require(minReserveRatio > 0, "INVALID_CONFIG");

            // calculate tab withdrawl fee
            (, uint256 processFeeRate) = config.tabParams(_tab);
            uint256 chargedFee = _calcFee(processFeeRate, _tabAmt);

            // record & transfer out additional tab withdrew
            require(
                (_maxWithdraw(_reserveValue(price, v.reserveAmt), minReserveRatio, v.tabAmt + v.osTabAmt + chargedFee))
                    >= _tabAmt,
                "WITHDRAW_EXTRA_MRR"
            );
            v.tabAmt += _tabAmt;
            v.osTabAmt += chargedFee;
            v.pendingOsMint += chargedFee;
            ITabERC20(v.tab).mint(_vaultOwner, _tabAmt);

            emit TabWithdraw(_vaultOwner, _vaultId, _tabAmt, v.tabAmt);
        } else {
            // payback(add) tab
            require(_tabAmt <= (v.tabAmt + v.osTabAmt), "RETURN_EXTRA_AMT");

            // send tab to treasury if there is O/S amount in vault (avoid minting)
            uint256 treasuryAmt = (_tabAmt >= v.pendingOsMint) ? v.pendingOsMint : _tabAmt;
            if (treasuryAmt > 0) {
                v.pendingOsMint -= treasuryAmt;
                SafeTransferLib.safeTransferFrom(v.tab, _vaultOwner, config.treasury(), treasuryAmt); // required
                    // tabERC20.approve called on vault manager
            }

            if (v.osTabAmt >= _tabAmt) {
                v.osTabAmt -= _tabAmt;
            } else {
                v.tabAmt -= (_tabAmt - v.osTabAmt);
                v.osTabAmt = 0;
            }

            uint256 amtToBurn = _tabAmt >= treasuryAmt ? (_tabAmt - treasuryAmt) : 0;
            if (amtToBurn > 0) {
                ITabERC20(v.tab).burnFrom(_vaultOwner, amtToBurn);
            }

            emit TabReturned(_vaultOwner, _vaultId, _tabAmt, v.tabAmt);
        }
    }

    /// @dev Called by user (vault owner) to increase/withdraw vault reserve.
    /// @dev Called by auction contract when receiving last bid that fully settle outstanding tab with left-over reserve
    /// (if any) post auction.
    function adjustReserve(uint256 _vaultId, uint256 _reserveAmt, bool _toWithdraw) external {
        address _vaultOwner = _msgSender();
        require(_vaultOwner != address(0), "UNAUTHORIZED");
        require(_reserveAmt > 0, "ZERO_VALUE");

        Vault storage v = vaults[_vaultOwner][_vaultId];
        if (v.reserveAmt == 0) {
            if (
                liquidatedVaults[_vaultId].auctionAddr == _vaultOwner
                    || liquidatedVaults[_vaultId].vaultOwner == _vaultOwner
            ) {
                v = vaults[liquidatedVaults[_vaultId].vaultOwner][_vaultId];
            } else {
                revert InvalidVault(_vaultOwner, _vaultId);
            }
        } else {
            require(_reserveAmt <= v.reserveAmt, "EXCEED_RESERVE");
            require(ITabRegistry(tabRegistry).frozenTabs(ITabERC20(v.tab).tabCode()) == false, "FROZEN_TAB");
            vaultKeeper.pushVaultRiskPenalty(_vaultOwner, _vaultId);
        }

        bytes3 _tab = ITabERC20(v.tab).tabCode();
        bytes32 reserveKey = reserveRegistry.reserveKey(v.reserveAddr);
        if (_toWithdraw) {
            uint256 price = priceOracle.getPrice(_tab);
            require(price > 0, "INVALID_TAB_PRICE");

            (uint256 processFeeRate, uint256 minReserveRatio,) = config.reserveParams(reserveKey);
            require(minReserveRatio > 0, "INVALID_CONFIG");

            // calculate tab withdrawl fee
            uint256 cf = _calcFee(processFeeRate, _reserveAmt);
            uint256 chargedFee = cf * price; // converted to tab amt

            uint256 totalOs = (v.tabAmt + v.osTabAmt + chargedFee);
            if (totalOs > 0) {
                require(
                    _reserveAmt <= _withdrawableReserveAmt(price, v.reserveAmt, minReserveRatio, totalOs),
                    "EXCEED_WITHDRAWABLE_AMT"
                );
            }

            // transfer out requested withdrawal reserve amount
            address reserveSafe = reserveRegistry.reserveSafeAddr(reserveKey);
            v.reserveAmt -= _reserveAmt;
            require(IReserveSafe(reserveSafe).unlockReserve(_vaultOwner, _reserveAmt), "FAILED_TRF_RESERVE");
            emit ReserveWithdraw(_vaultOwner, _vaultId, _reserveAmt, v.reserveAmt);
        } else {
            // deposit more reserve
            v.reserveAmt += _reserveAmt;

            // lock reserve
            address reserveAddr = reserveRegistry.reserveAddr(reserveKey);
            address reserveSafe = reserveRegistry.reserveSafeAddr(reserveKey);
            require(
                reserveAddr != address(0) && reserveSafe != address(0) && reserveRegistry.enabledReserve(reserveKey),
                "INVALID_RESERVE"
            );
            SafeTransferLib.safeTransferFrom(reserveAddr, _vaultOwner, reserveSafe, _reserveAmt); // assume approve
                // called on vault
                // manager b4

            // mint O/S fee amt to treasury (if any)
            if (v.pendingOsMint > 0) {
                ITabERC20(v.tab).mint(config.treasury(), v.pendingOsMint);
                v.pendingOsMint = 0;
            }

            emit ReserveAdded(_vaultOwner, _vaultId, _reserveAmt, v.reserveAmt);
        }
    }

    function chargeRiskPenalty(address _vaultOwner, uint256 _vaultId, uint256 _amt) external onlyRole(KEEPER_ROLE) {
        Vault storage v = vaults[_vaultOwner][_vaultId];
        require(v.tabAmt > 0, "INVALID_VAULT");

        v.osTabAmt += _amt;
        v.pendingOsMint += _amt;

        emit RiskPenaltyCharged(_vaultOwner, _vaultId, _amt, v.osTabAmt);
    }

    /// @dev Reserve Delta = minReserveValue - reserveValue
    /// @dev Reserve Ratio(RR) = reserveValue / osTab * 100
    function getVaultDetails(
        address _vaultOwner,
        uint256 _vaultId
    )
        external
        view
        returns (
            bytes3 tab,
            bytes32 reserveKey,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            uint256 reserveValue,
            uint256 minReserveValue
        )
    {
        Vault memory v = vaults[_vaultOwner][_vaultId];
        reserveAmt = v.reserveAmt;

        tab = ITabERC20(v.tab).tabCode();
        price = priceOracle.getPrice(tab);
        require(price > 0, "INVALID_TAB_PRICE");

        reserveKey = reserveRegistry.reserveKey(v.reserveAddr);
        (, uint256 minReserveRatio,) = config.reserveParams(reserveKey);
        require(minReserveRatio > 0, "INVALID_CONFIG");

        osTab = v.tabAmt + v.osTabAmt;
        reserveValue = _reserveValue(price, v.reserveAmt);
        minReserveValue = FixedPointMathLib.mulDiv(osTab, minReserveRatio, 100);
    }

    /**
     * @dev Triggered when VaultKeeper confirmed liquidation
     * @param _vaultOwner address of vault owner
     * @param _vaultId unique id of the vault
     * @param _osRiskPenalty Current outstanding risk penalty value to be charged up to the point of declaring vault
     * liquidation.
     */
    function liquidateVault(
        address _vaultOwner,
        uint256 _vaultId,
        uint256 _osRiskPenalty
    )
        external
        onlyRole(KEEPER_ROLE)
    {
        Vault storage v = vaults[_vaultOwner][_vaultId];
        require(v.tabAmt > 0, "INVALID_VAULT");

        v.osTabAmt += _osRiskPenalty;
        v.pendingOsMint += _osRiskPenalty;
        emit RiskPenaltyCharged(_vaultOwner, _vaultId, _osRiskPenalty, v.osTabAmt);

        (
            uint256 auctionStartPriceDiscount,
            uint256 auctionStepPriceDiscount,
            uint256 auctionStepDurationInSec,
            address auctionManager
        ) = config.auctionParams();

        liquidatedVaults[_vaultId] = LiquidatedVault(_vaultOwner, auctionManager);
        uint256 startPrice =
            FixedPointMathLib.mulDiv(priceOracle.getPrice(ITabERC20(v.tab).tabCode()), auctionStartPriceDiscount, 100);

        IAuctionManager(auctionManager).createAuction(
            _vaultId,
            v.reserveAddr,
            v.reserveAmt,
            v.tab,
            (v.tabAmt + v.osTabAmt),
            startPrice,
            auctionStepPriceDiscount,
            auctionStepDurationInSec
        );
        emit LiquidatedVaultAuction(_vaultId, v.reserveAddr, v.reserveAmt, v.tab, startPrice);

        // Transfer full reserve to auction contract.
        // When liquidation auction ended, leftover reserve is transferred back by calling adjustReserve function
        address reserveSafe = reserveRegistry.reserveSafeAddr(reserveRegistry.reserveKey(v.reserveAddr));
        require(IReserveSafe(reserveSafe).unlockReserve(auctionManager, v.reserveAmt), "RESERVE_APPROVAL");

        v.reserveAmt = 0;
    }

    /// @dev After ctrl-alt-del is completed, fixed price is determined and set (no longer used oracle price)
    function ctrlAltDel(bytes3 _tab, uint256 _btcTabRate, address _protocolVaultAddr) external tabRegistryCallerOnly {
        address tabAddr = ITabRegistry(tabRegistry).tabs(_tab);
        require(tabAddr != address(0), "INVALID_TAB");

        address[] memory addrs = new address[](vaultId);
        uint256[] memory reserves = new uint256[](vaultId);
        uint256[] memory tabAmts = new uint256[](vaultId);
        CtrlAltDelData memory data = CtrlAltDelData(-1, 0, 0, 0, 0);

        // iterate all vaults of the Tab type
        for (uint256 i = 0; i < ownerList.length; i = unsafe_inc(i)) {
            uint256[] memory ownerVaultIds = vaultOwners[ownerList[i]];

            for (uint256 n = 0; n < ownerVaultIds.length; n = unsafe_inc(n)) {
                Vault storage v = vaults[ownerList[i]][ownerVaultIds[n]];

                // Vault Tab = CtrlAltDel's Tab && Vault is not liquidated
                if (v.tab == tabAddr && liquidatedVaults[ownerVaultIds[n]].auctionAddr == address(0)) {
                    // update risk penalty value (if any)
                    vaultKeeper.pushVaultRiskPenalty(ownerList[i], ownerVaultIds[n]);

                    uint256 totalOS = v.tabAmt + v.osTabAmt;

                    // Revert if the vault breaches liquidation ratio with supplied _btcTabRate
                    if (
                        vaultKeeper.isLiquidatingVault(
                            reserveRegistry.reserveKey(v.reserveAddr), _reserveValue(_btcTabRate, v.reserveAmt), totalOS
                        )
                    ) {
                        revert LiquidatingVault(ownerList[i], ownerVaultIds[n]);
                    }

                    // accumulate total reserve amount based on reserve type
                    uint256 vaultReserve = FixedPointMathLib.mulDiv(totalOS, 1e18, _btcTabRate);
                    int256 idx = findMatchedAddr(addrs, v.reserveAddr);

                    if (idx < 0) {
                        data.uniqReserveCount = data.uniqReserveCount + 1;
                        addrs[uint256(data.uniqReserveCount)] = v.reserveAddr;
                        reserves[uint256(data.uniqReserveCount)] = vaultReserve;
                        tabAmts[uint256(data.uniqReserveCount)] += totalOS;
                    } else {
                        reserves[uint256(idx)] += vaultReserve;
                        tabAmts[uint256(idx)] += totalOS;
                    }

                    data.totalReserve += v.reserveAmt;

                    // accumulate total tab amount
                    data.totalTabAmt += totalOS;
                    if (v.pendingOsMint > 0) {
                        // clear un-minted amount
                        data.tabToMint += v.pendingOsMint;
                        v.pendingOsMint = 0;
                    }

                    // reserve to be consolidated
                    data.totalReserveConso += vaultReserve;

                    v.reserveAmt -= vaultReserve; // excess reserve remained in vault.
                    v.tabAmt = 0;
                    v.osTabAmt = 0;
                }
            }
        }

        if (data.tabToMint > 0) {
            ITabERC20(tabAddr).mint(config.treasury(), data.tabToMint);
        }

        for (uint256 i = 0; i < addrs.length; i = unsafe_inc(i)) {
            if (addrs[i] == address(0)) {
                break;
            }

            IProtocolVault(_protocolVaultAddr).initCtrlAltDel(addrs[i], reserves[i], tabAddr, tabAmts[i], _btcTabRate);
            // transfer reserve from Safe to ProtocolVault contract
            IReserveSafe(reserveRegistry.reserveAddrSafe(addrs[i])).unlockReserve(_protocolVaultAddr, reserves[i]);
        }

        emit CtrlAltDel(_tab, _btcTabRate, data.totalTabAmt, data.totalReserve, data.totalReserveConso);
    }

    // ------------------------- internal functions -------------------------------------------

    function _reserveValue(uint256 price, uint256 _reserveAmt) internal pure returns (uint256) {
        return FixedPointMathLib.mulWad(price, _reserveAmt);
    }

    function _maxWithdraw(uint256 reserveValue, uint256 mrr, uint256 osTab) internal pure returns (uint256) {
        return FixedPointMathLib.zeroFloorSub(FixedPointMathLib.mulDiv(reserveValue, 100, mrr), osTab);
    }

    function _withdrawableReserveAmt(
        uint256 price,
        uint256 _reserveAmt,
        uint256 mrr,
        uint256 osTab
    )
        internal
        pure
        returns (uint256)
    {
        uint256 rv = _reserveValue(price, _reserveAmt);
        return FixedPointMathLib.divWad((rv - FixedPointMathLib.mulDiv(osTab, mrr, 100)), price);
    }

    function _calcFee(uint256 processFeeRate, uint256 amt) internal pure returns (uint256) {
        return FixedPointMathLib.mulDiv(processFeeRate, amt, 100);
    }

    function _msgSender() internal view override returns (address) {
        return msg.sender;
    }

    function findMatchedAddr(address[] memory _addr, address _toMatch) internal pure returns (int256 index) {
        for (uint256 j = 0; j < _addr.length; j = unsafe_inc(j)) {
            if (_addr[j] == _toMatch) {
                return int256(j);
            }
        }
        return -1;
    }

    function unsafe_inc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

}
