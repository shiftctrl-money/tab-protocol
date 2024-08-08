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
import "./shared/interfaces/IAuctionManager.sol";

/**
 * @title  Manage vault to deposit/withdraw reserve and mint/burn Tabs.
 * @notice Refer https://www.shiftctrl.money for details. 
 */
contract VaultManager is Initializable, AccessControlDefaultAdminRulesUpgradeable, UUPSUpgradeable {

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

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
    uint256 public vaultId; // running vault id

    struct LiquidatedVault {
        address vaultOwner;
        address auctionAddr;
    }
    mapping(uint256 => LiquidatedVault) public liquidatedVaults; // vaultId : LiquidatedVault
    
    struct CtrlAltDelData {
        int256 uniqReserveCount; // index point to unique reserve type
        uint256 totalTabAmt; // total tab amount of the vaults to be depegged
        uint256 tabToMint; // total tab amount pending to mint
        uint256 totalReserve; // total reserve amount of the reserve type
        uint256 totalReserveConso; // total reserve to be consolidated
    }
    
    IConfig config;
    IReserveRegistry reserveRegistry;
    IPriceOracle priceOracle;
    IVaultKeeper vaultKeeper;
    address tabRegistry;

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

    function initialize(address _admin, address _admin2, address _deployer) public initializer {
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __UUPSUpgradeable_init();

        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _admin2);
        _grantRole(DEPLOYER_ROLE, _deployer);
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

    /**
     * @dev Create vault by depositing reserve and specify tab amount to mint. 
     * Required allowance to spend reserve, call `approve` on reserve contract before calling `createVault`.
     * @param _reserveKey Reserve key registered with protocol, refer `ReserveRegistry` contract.
     * @param _reserveAmt Reserve amount to deposit into the new vault. Deduct `_reserveAmt` from vault owner.
     * @param _tabAmt Tab amount received by vault owner.
     * @param sigPrice Signed tab rate authorized by oracle service.
     */
    function createVault(
        bytes32 _reserveKey, 
        uint256 _reserveAmt, 
        uint256 _tabAmt, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) external {
        address _vaultOwner = _msgSender();
        require(_vaultOwner == sigPrice.updater, "INVALID_OWNER");
        require(_reserveKey != 0x00, "INVALID_KEY"); // 0x00 is reserved default not available for vault operation
        require(_vaultOwner != address(0), "UNAUTHORIZED");
        
        bytes3 _tab = sigPrice.tab;
        require(ITabRegistry(tabRegistry).ctrlAltDelTab(_tab) == 0, "CTRL_ALT_DEL_DONE");
        require(!ITabRegistry(tabRegistry).frozenTabs(_tab), "FROZEN_TAB");

        // lock reserve
        (
            address reserveAddr, 
            address reserveSafe,  
            , 
            uint256 reserveAmt
            ,
        ) = reserveRegistry.getReserveByKey(_reserveKey, _reserveAmt);
        require(
            reserveAddr != address(0) && reserveSafe != address(0) && reserveAmt > 0,
            "INVALID_RESERVE"
        );
        SafeTransferLib.safeTransferFrom(reserveAddr, _vaultOwner, reserveSafe, reserveAmt); // Required approve

        // load config
        (, uint256 minReserveRatio,) = config.reserveParams(_reserveKey);
        require(minReserveRatio > 0, "INVALID_CONFIG");

        // validate withdrawal tab amt
        uint256 price = priceOracle.updatePrice(sigPrice);
        require(price > 0, "INVALID_TAB_PRICE");
        require(_maxWithdraw(_reserveValue(price, _reserveAmt), minReserveRatio, 0) >= _tabAmt, "EXCEED_MAX_WITHDRAW");

        // withdraw tab
        address tab = ITabRegistry(tabRegistry).createTab(_tab); // return existing tab's address or create new
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

    /**
     * @dev Withdraw tab from vault. Protocol will mint requested tab amount.
     * @param _vaultId Vault ID.
     * @param _tabAmt Tab amount to withdraw.
     * @param sigPrice Tab rate signed by authorized oracle service.
     */
    function withdrawTab(
        uint256 _vaultId, 
        uint256 _tabAmt, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) external {
        address _vaultOwner = _msgSender();
        require(_vaultOwner != address(0), "UNAUTHORIZED");
        require(_vaultOwner == sigPrice.updater, "INVALID_OWNER");
        require(_tabAmt > 0, "ZERO_VALUE");

        Vault storage v = vaults[_vaultOwner][_vaultId];
        if(v.tabAmt == 0)
            revert InvalidVault(_vaultOwner, _vaultId);
        
        require(!ITabRegistry(tabRegistry).frozenTabs(ITabERC20(v.tab).tabCode()), "FROZEN_TAB");
        require(liquidatedVaults[_vaultId].auctionAddr == address(0), "LIQUIDATED");
        vaultKeeper.pushVaultRiskPenalty(_vaultOwner, _vaultId);

        // update/retrieve price
        uint256 price = priceOracle.updatePrice(sigPrice);
        require(price > 0, "INVALID_TAB_PRICE");

        // config
        (, uint256 minReserveRatio,) = config.reserveParams(reserveRegistry.reserveKey(v.reserveAddr));
        require(minReserveRatio > 0, "INVALID_CONFIG");

        // calculate tab withdrawl fee
        (, uint256 processFeeRate) = config.tabParams(ITabERC20(v.tab).tabCode());
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
    }

    /**
     * @dev Return back Tab to vault. Call `approve` on Tab contract before calling `paybackTab`.
     * @param _vaultId Vault ID.
     * @param _tabAmt Tab amount to pay back. Required allowance to spend the tab amount.
     */
    function paybackTab(
        uint256 _vaultId, 
        uint256 _tabAmt
    ) external {
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
            require(!ITabRegistry(tabRegistry).frozenTabs(ITabERC20(v.tab).tabCode()), "FROZEN_TAB");
            require(liquidatedVaults[_vaultId].auctionAddr == address(0), "LIQUIDATED");
            vaultKeeper.pushVaultRiskPenalty(_vaultOwner, _vaultId);
        }

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

    /**
     * @dev Withdraw reserve from vault. Vault reserve ratio will drop and may be charged risk penalty
     * if reserve ratio dropped below configured threshold.
     * @param _vaultId Vault ID.
     * @param _reserveAmt Withdrawal amount.
     * @param sigPrice Signed Tab rate by authorized oracle service.
     */
    function withdrawReserve(
        uint256 _vaultId, 
        uint256 _reserveAmt, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) external {
        address _vaultOwner = _msgSender();
        require(_vaultOwner != address(0), "UNAUTHORIZED");
        require(_vaultOwner == sigPrice.updater, "INVALID_OWNER");
        require(_reserveAmt > 0, "ZERO_VALUE");

        Vault storage v = vaults[_vaultOwner][_vaultId];
        if (v.reserveAmt == 0)
            revert InvalidVault(_vaultOwner, _vaultId);
    
        require(_reserveAmt <= v.reserveAmt, "EXCEED_RESERVE");
        require(!ITabRegistry(tabRegistry).frozenTabs(ITabERC20(v.tab).tabCode()), "FROZEN_TAB");
        vaultKeeper.pushVaultRiskPenalty(_vaultOwner, _vaultId);
    
        (
            bytes32 reserveKey,
            address reserveSafe,
            ,
            uint256 reserveAmt,
            uint256 reserveAmt18
        ) = reserveRegistry.getReserveByAddr(v.reserveAddr, _reserveAmt);
        require(reserveAmt > 0, "INVALID_RESERVE");

        uint256 price = priceOracle.updatePrice(sigPrice);
        require(price > 0, "INVALID_TAB_PRICE");

        (uint256 processFeeRate, uint256 minReserveRatio,) = config.reserveParams(reserveKey);
        require(minReserveRatio > 0, "INVALID_CONFIG");

        // calculate tab withdrawl fee
        uint256 cf = _calcFee(processFeeRate, reserveAmt18);
        uint256 chargedFee = cf * price; // converted to tab amt

        uint256 totalOs = (v.tabAmt + v.osTabAmt + chargedFee);
        if (totalOs > 0) {
            require(
                reserveAmt18 <= _withdrawableReserveAmt(price, v.reserveAmt, minReserveRatio, totalOs),
                "EXCEED_WITHDRAWABLE_AMT"
            );
        }

        // transfer out requested withdrawal reserve amount
        v.reserveAmt -= reserveAmt18;
        require(IReserveSafe(reserveSafe).unlockReserve(_vaultOwner, reserveAmt), "FAILED_TRF_RESERVE");
        emit ReserveWithdraw(_vaultOwner, _vaultId, reserveAmt18, v.reserveAmt);
    }

    /**
     * @dev Deposit and increase vault reserve.
     * @param _vaultId Vault ID.
     * @param _reserveAmt Reserve amount to deposit.
     */
    function depositReserve(
        uint256 _vaultId, 
        uint256 _reserveAmt
    ) external {
        address _vaultOwner = _msgSender();
        require(_vaultOwner != address(0), "UNAUTHORIZED");
        require(_reserveAmt > 0, "ZERO_VALUE");

        Vault storage v = vaults[_vaultOwner][_vaultId];
        if (v.reserveAmt == 0) {
            if (
                liquidatedVaults[_vaultId].auctionAddr == _vaultOwner
            ) {
                v = vaults[liquidatedVaults[_vaultId].vaultOwner][_vaultId];
            } else {
                revert InvalidVault(_vaultOwner, _vaultId);
            }
        } else {
            require(!ITabRegistry(tabRegistry).frozenTabs(ITabERC20(v.tab).tabCode()), "FROZEN_TAB");
            vaultKeeper.pushVaultRiskPenalty(_vaultOwner, _vaultId);
        }

        (
            ,
            address reserveSafe,
            ,
            uint256 reserveAmt,
            uint256 reserveAmt18
        ) = reserveRegistry.getReserveByAddr(v.reserveAddr, _reserveAmt);

        // deposit more reserve
        v.reserveAmt += reserveAmt18;

        // lock reserve
        require(
            reserveSafe != address(0) && reserveAmt > 0,
            "INVALID_RESERVE"
        );
        SafeTransferLib.safeTransferFrom(v.reserveAddr, _vaultOwner, reserveSafe, reserveAmt); // Required approve

        // mint O/S fee amt to treasury (if any)
        if (v.pendingOsMint > 0) {
            ITabERC20(v.tab).mint(config.treasury(), v.pendingOsMint);
            v.pendingOsMint = 0;
        }

        emit ReserveAdded(_vaultOwner, _vaultId, reserveAmt18, v.reserveAmt);
    }

    /**
     * @dev Called by `VaultKeeper` to charge risk penalty amount into corresponding vault.
     * @param _vaultOwner Vault Owner address.
     * @param _vaultId Vault ID.
     * @param _amt Risk penalty amount.
     */
    function chargeRiskPenalty(address _vaultOwner, uint256 _vaultId, uint256 _amt) external onlyRole(KEEPER_ROLE) {
        Vault storage v = vaults[_vaultOwner][_vaultId];
        require(v.tabAmt > 0, "INVALID_VAULT");

        v.osTabAmt += _amt;
        v.pendingOsMint += _amt;

        emit RiskPenaltyCharged(_vaultOwner, _vaultId, _amt, v.osTabAmt);
    }

    /**
     * @dev Triggered when VaultKeeper confirmed liquidation
     * @param _vaultOwner address of vault owner
     * @param _vaultId unique id of the vault
     * @param _osRiskPenalty Outstanding risk penalty value up to the point of liquidation.
     */
    function liquidateVault(
        address _vaultOwner,
        uint256 _vaultId,
        uint256 _osRiskPenalty,
        IPriceOracle.UpdatePriceData calldata sigPrice
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
            FixedPointMathLib.mulDiv(priceOracle.updatePrice(sigPrice), auctionStartPriceDiscount, 100);

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

        // Park reserve to auction contract.
        // When liquidation auction ended, leftover reserve is transferred back
        (
            ,
            address reserveSafe,
            ,
            uint256 reserveAmt
            ,
        ) = reserveRegistry.getReserveByAddr(v.reserveAddr, v.reserveAmt);
        require(reserveAmt > 0, "INVALID_RESERVE");
        require(IReserveSafe(reserveSafe).unlockReserve(auctionManager, reserveAmt), "RESERVE_APPROVAL");

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
                    (
                        , 
                        uint256 valueInDec18
                    ) = reserveRegistry.getOriReserveAmt(v.reserveAddr, vaultReserve);
                    int256 idx = findMatchedAddr(addrs, v.reserveAddr);

                    if (idx < 0) {
                        data.uniqReserveCount = data.uniqReserveCount + 1;
                        addrs[uint256(data.uniqReserveCount)] = v.reserveAddr;
                        reserves[uint256(data.uniqReserveCount)] = valueInDec18;
                        tabAmts[uint256(data.uniqReserveCount)] += totalOS;
                    } else {
                        reserves[uint256(idx)] += valueInDec18;
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
                    data.totalReserveConso += valueInDec18;

                    v.reserveAmt -= valueInDec18; // excess reserve remained in vault.
                    v.tabAmt = 0;
                    v.osTabAmt = 0;
                }
            }
        }

        if (data.tabToMint > 0) {
            ITabERC20(tabAddr).mint(config.treasury(), data.tabToMint);
        }

        for (uint256 i; i < addrs.length; i = unsafe_inc(i)) {
            if (addrs[i] == address(0))
                break;
            (
                uint256 valueInOriDecimal
                , 
            ) = reserveRegistry.getOriReserveAmt(addrs[i], reserves[i]);
            IProtocolVault(_protocolVaultAddr).initCtrlAltDel(addrs[i], reserves[i], tabAddr, tabAmts[i], _btcTabRate);
            // transfer reserve from Safe to ProtocolVault contract
            IReserveSafe(reserveRegistry.reserveAddrSafe(addrs[i])).unlockReserve(_protocolVaultAddr, valueInOriDecimal);
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

    function findMatchedAddr(address[] memory _addr, address _toMatch) internal pure returns (int256) {
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
