// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRulesUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IConfig} from "../interfaces/IConfig.sol";
import {ITabRegistry} from "../interfaces/ITabRegistry.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IVaultKeeper} from "../interfaces/IVaultKeeper.sol";
import {IReserveRegistry} from "../interfaces/IReserveRegistry.sol";
import {ITabERC20} from "../interfaces/ITabERC20.sol";
import {IReserveSafe} from "../interfaces/IReserveSafe.sol";
import {IProtocolVault} from "../interfaces/IProtocolVault.sol";
import {IAuctionManager} from "../interfaces/IAuctionManager.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

/**
 * @title  Manage vault to deposit/withdraw reserve and mint/burn Tabs.
 * @notice Refer https://www.shiftctrl.money for details. 
 */
contract VaultManager is 
    Initializable, 
    AccessControlDefaultAdminRulesUpgradeable, 
    UUPSUpgradeable, 
    IVaultManager 
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant CTRL_ALT_DEL_ROLE = keccak256("CTRL_ALT_DEL_ROLE");

    IConfig public config;
    IReserveRegistry public reserveRegistry;
    IPriceOracle public priceOracle;
    IVaultKeeper public vaultKeeper;
    ITabRegistry public tabRegistry;

    address[] public ownerList;

    mapping(address => uint256[]) public vaultOwners; // vault_owner: array of id

    mapping(address => mapping(uint256 => Vault)) public vaults; // vault_owner: (id : vault)

    uint256 public vaultId; // running vault id
    
    mapping(uint256 => LiquidatedVault) public liquidatedVaults; // vaultId : LiquidatedVault

    constructor() {
        _disableInitializers();
    }

    /**
     * @param _admin Governance controller.
     * @param _admin2 Emergency governance controller.
     * @param _deployer Deployer account.
     */
    function initialize(
        address _admin, 
        address _admin2, 
        address _upgrader,
        address _deployer
    ) 
        public 
        initializer 
    {
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __UUPSUpgradeable_init();

        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _admin2);
        _grantRole(DEPLOYER_ROLE, _deployer);

        _grantRole(UPGRADER_ROLE, _upgrader);

        _grantRole(CTRL_ALT_DEL_ROLE, _admin);
        _grantRole(CTRL_ALT_DEL_ROLE, _admin2);

        _setRoleAdmin(KEEPER_ROLE, DEPLOYER_ROLE);
        _setRoleAdmin(DEPLOYER_ROLE, CTRL_ALT_DEL_ROLE);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    /**
     * @dev Called once upon deployment. 
     * Governance to change contract implementation if needed.
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
        tabRegistry = ITabRegistry(_tabRegistry);
        priceOracle = IPriceOracle(_priceOracle);
        vaultKeeper = IVaultKeeper(_keeper);

        _grantRole(KEEPER_ROLE, _keeper);
        _grantRole(CTRL_ALT_DEL_ROLE, _tabRegistry);
        emit UpdatedContract(_config, _reserveRegistry, _tabRegistry, _priceOracle, _keeper);
    }

    function getOwnerList() external view returns (address[] memory) {
        return ownerList;
    }

    function getAllVaultIDByOwner(address _owner) external view returns (uint256[] memory) {
        return vaultOwners[_owner];
    }

    function getVaults(
        address _vaultOwner, 
        uint256 _vaultId
    ) 
        external 
        view 
        returns(Vault memory)
    {
        return vaults[_vaultOwner][_vaultId];
    }

    function getLiquidatedVault(
        uint256 _vaultId
    ) 
        external 
        view 
        returns(LiquidatedVault memory)
    {
        return liquidatedVaults[_vaultId];
    }

    /**
     * @dev Create vault by depositing BTC reserve token and specify tab amount to mint. 
     * Required allowance to spend reserve, call `approve` on reserve contract before calling `createVault`.
     * @param _reserveAddr Whitelisted BTC token address. Refer `ReserveRegistry` to add new reserve token.
     * @param _reserveAmt 18-decimals reserve amount to deposit into the new vault. 
     * Required `_reserveAmt` allowance as spender from vault owner.
     * @param _tabAmt Tab amount to be received by vault owner.
     * @param sigPrice Signed tab rate authorized by Tab-Oracle module.
     */
    function createVault(
        address _reserveAddr, 
        uint256 _reserveAmt, 
        uint256 _tabAmt, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) 
        external 
    {
        if (_reserveAddr == address(0))
            revert ZeroAddress();
        if (_reserveAmt == 0 || _tabAmt == 0)
            revert ZeroValue();
        address reserveSafe = reserveRegistry.isEnabledReserve(_reserveAddr);
        if (reserveSafe == address(0))
            revert InvalidReserve(_reserveAddr);
        bytes32 tabKey = tabCodeToTabKey(sigPrice.tab);
        if (tabRegistry.ctrlAltDelTab(tabKey) > 0)
            revert CtrlAltDelTab(sigPrice.tab);
        if (tabRegistry.frozenTabs(tabKey))
            revert DisabledTab(sigPrice.tab);

        // Required allowance on reserve token, transfer reserve to Safe
        SafeERC20.safeTransferFrom(
            IERC20(_reserveAddr), 
            sigPrice.updater, 
            reserveSafe, 
            IReserveSafe(reserveSafe).getNativeTransferAmount(_reserveAddr, _reserveAmt)
        );

        // Get existed tab's address or create new
        address tabAddr = tabRegistry.createTab(sigPrice.tab); 

        // Load config
        IConfig.TabParams memory tabParams = config.getTabParams(sigPrice.tab);

        // Withdrawal tab amt should be less than max. withdrawable amount
        uint256 price = priceOracle.updatePrice(sigPrice);
        uint256 withdrawable = _maxWithdraw(_reserveValue(price, _reserveAmt), tabParams.minReserveRatio, 0);
        if (_tabAmt > withdrawable)
            revert ExceededWithdrawable(withdrawable);

        ++vaultId;
        
        // Maintain unique vault owner list
        if (vaultOwners[sigPrice.updater].length == 0 )
            ownerList.push(sigPrice.updater);

        vaultOwners[sigPrice.updater].push(vaultId);
        vaults[sigPrice.updater][vaultId] = Vault(_reserveAddr, _reserveAmt, tabAddr, _tabAmt, 0, 0);
        ITabERC20(tabAddr).mint(sigPrice.updater, _tabAmt);

        emit NewVault(sigPrice.updater, vaultId, _reserveAddr, _reserveAmt, tabAddr, _tabAmt);
    }

    /**
     * @dev Withdraw tab from vault as long as vault remained below min. reserve ratio.
     * @param _vaultId Vault ID.
     * @param _tabAmt Tab amount to withdraw.
     * @param sigPrice Tab rate signed by authorized oracle service.
     */
    function withdrawTab(
        uint256 _vaultId, 
        uint256 _tabAmt, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) 
        external 
    {
        if (_tabAmt == 0)
            revert ZeroValue();

        bytes32 tabKey = tabCodeToTabKey(sigPrice.tab);
        if (tabRegistry.frozenTabs(tabKey))
            revert DisabledTab(sigPrice.tab);
        if (liquidatedVaults[_vaultId].auctionAddr != address(0))
            revert InvalidLiquidatedVault(_vaultId);
        if (tabRegistry.ctrlAltDelTab(tabKey) > 0)
            revert CtrlAltDelTab(sigPrice.tab);

        Vault storage v = vaults[sigPrice.updater][_vaultId];
        if(v.reserveAmt == 0)
            revert InvalidVault(sigPrice.updater, _vaultId);
        
        vaultKeeper.pushVaultRiskPenalty(sigPrice.updater, _vaultId);

        // Update/retrieve price
        uint256 price = priceOracle.updatePrice(sigPrice);

        // Load config
        IConfig.TabParams memory tabParams = config.getTabParams(sigPrice.tab);

        // Calculate tab withdrawl fee
        uint256 chargedFee = _calcFee(tabParams.processFeeRate, _tabAmt);

        // Mint additional tab as per withdraw request
        uint256 withdrawable = _maxWithdraw(
            _reserveValue(price, v.reserveAmt), 
            tabParams.minReserveRatio, 
            v.tabAmt + v.osTabAmt + chargedFee
        );
        if (_tabAmt > withdrawable)
            revert ExceededWithdrawable(withdrawable);
        
        v.tabAmt += _tabAmt;
        v.osTabAmt += chargedFee;
        v.pendingOsMint += chargedFee;
        ITabERC20(v.tab).mint(sigPrice.updater, _tabAmt);

        emit TabWithdraw(sigPrice.updater, _vaultId, _tabAmt, v.tabAmt);
    }

    /**
     * @dev Return Tab to vault. Reduce the vault's outstanding Tab amount to improve its reserve ratio.
     * Required allowance, call `approve` on Tab contract before calling this.
     * @param _vaultId Vault ID.
     * @param _tabAmt Tab amount to pay back. Required allowance to spend the tab amount.
     */
    function paybackTab(
        address _vaultOwner,
        uint256 _vaultId, 
        uint256 _tabAmt
    ) 
        external 
    {
        if (_tabAmt == 0)
            revert ZeroValue();
        Vault storage v = vaults[_vaultOwner][_vaultId];
        if (v.tabAmt == 0) {
            if (liquidatedVaults[_vaultId].auctionAddr == _vaultOwner)
                v = vaults[liquidatedVaults[_vaultId].vaultOwner][_vaultId];
            else
                revert InvalidVault(_vaultOwner, _vaultId);
        } else {
            if (tabRegistry.frozenTabs(ITabERC20(v.tab).tabKey()))
                revert DisabledTab(ITabERC20(v.tab).tabCode());
            if (liquidatedVaults[_vaultId].auctionAddr != address(0))
                revert InvalidLiquidatedVault(_vaultId);
            vaultKeeper.pushVaultRiskPenalty(_vaultOwner, _vaultId);
        }

        // Payback tab amount exceeded vault outstanding amount
        if (_tabAmt > (v.tabAmt + v.osTabAmt))
            revert ExcessAmount();

        // Send payback tab (partial or full amount) to treasury if applicable
        uint256 treasuryAmt = (_tabAmt >= v.pendingOsMint) ? v.pendingOsMint : _tabAmt;
        if (treasuryAmt > 0) {
            v.pendingOsMint -= treasuryAmt;
            SafeERC20.safeTransferFrom(IERC20(v.tab), _vaultOwner, config.treasury(), treasuryAmt);
        }

        if (v.osTabAmt >= _tabAmt) {
            v.osTabAmt -= _tabAmt;
        } else {
            v.tabAmt -= (_tabAmt - v.osTabAmt);
            v.osTabAmt = 0;
        }

        uint256 amtToBurn = _tabAmt >= treasuryAmt ? (_tabAmt - treasuryAmt) : 0;
        if (amtToBurn > 0)
            ITabERC20(v.tab).burnFrom(_vaultOwner, amtToBurn);

        emit TabReturned(_vaultOwner, _vaultId, _tabAmt, v.tabAmt);
    }

    /**
     * @dev Withdraw BTC reserve from vault. Be careful on vault reserve ratio post withdrawal.
     * @param _vaultId Vault ID.
     * @param _reserveAmt Withdrawal amount.
     * @param sigPrice Signed Tab rate by authorized oracle service.
     */
    function withdrawReserve(
        uint256 _vaultId, 
        uint256 _reserveAmt, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) 
        external 
    {
        if (_reserveAmt == 0)
            revert ZeroValue();

        Vault storage v = vaults[sigPrice.updater][_vaultId];
        if (v.reserveAmt == 0)
            revert InvalidVault(sigPrice.updater, _vaultId);
        if (_reserveAmt > v.reserveAmt)
            revert ExcessAmount();
        if (tabRegistry.frozenTabs(tabCodeToTabKey(sigPrice.tab)))
            revert DisabledTab(sigPrice.tab);

        address reserveSafe = reserveRegistry.isEnabledReserve(v.reserveAddr);
        if (reserveSafe == address(0))
            revert InvalidReserve(v.reserveAddr);

        vaultKeeper.pushVaultRiskPenalty(sigPrice.updater, _vaultId);
      
        // Load config
        IConfig.TabParams memory tabParams = config.getTabParams(sigPrice.tab);

        uint256 price = priceOracle.updatePrice(sigPrice);
        
        // Calculate withdrawl fee (if applicable)
        uint256 chargedFee = _calcFee(tabParams.processFeeRate, _reserveAmt) * price;

        uint256 totalOs = (v.tabAmt + v.osTabAmt + chargedFee);
        if (totalOs > 0) {
            uint256 withdrawable = _withdrawableReserveAmt(
                price, 
                v.reserveAmt, 
                tabParams.minReserveRatio, 
                totalOs
            );
            if (_reserveAmt > withdrawable)
                revert ExceededWithdrawable(withdrawable);
        }

        v.reserveAmt -= _reserveAmt;
        if (chargedFee > 0) {
            v.osTabAmt += chargedFee;
            v.pendingOsMint += chargedFee;
        }
        IReserveSafe(reserveSafe).unlockReserve(v.reserveAddr, sigPrice.updater, _reserveAmt);
        emit ReserveWithdraw(sigPrice.updater, _vaultId, _reserveAmt, v.reserveAmt);
    }

    /**
     * @dev Add BTC reserve into vault and increase reserve ratio.
     * Required allowance (call `approve`) on user BTC token.
     * @param _vaultOwner Vault owner address.
     * @param _vaultId Vault ID.
     * @param _reserveAmt Reserve amount to deposit in 18 decimals.
     */
    function depositReserve(
        address _vaultOwner,
        uint256 _vaultId, 
        uint256 _reserveAmt
    )
        external 
    {
        if (_reserveAmt == 0)
            revert ZeroValue();

        Vault storage v = vaults[_vaultOwner][_vaultId];
        if (v.reserveAmt == 0) {
            if (liquidatedVaults[_vaultId].auctionAddr == _vaultOwner)
                v = vaults[liquidatedVaults[_vaultId].vaultOwner][_vaultId];
            else
                revert InvalidVault(_vaultOwner, _vaultId);
        } else {
            if (tabRegistry.frozenTabs(ITabERC20(v.tab).tabKey()))
                revert DisabledTab(ITabERC20(v.tab).tabCode());
            vaultKeeper.pushVaultRiskPenalty(_vaultOwner, _vaultId);
        }

        address reserveSafe = reserveRegistry.isEnabledReserve(v.reserveAddr);
        if (reserveSafe == address(0))
            revert InvalidReserve(v.reserveAddr);

        // Add deposit
        v.reserveAmt += _reserveAmt;

        // Required approve(allowance)
        SafeERC20.safeTransferFrom(
            IERC20(v.reserveAddr), 
            _vaultOwner, 
            reserveSafe, 
            IReserveSafe(reserveSafe).getNativeTransferAmount(v.reserveAddr, _reserveAmt)
        );

        // Mint O/S fee amt to treasury (if any)
        if (v.pendingOsMint > 0) {
            ITabERC20(v.tab).mint(config.treasury(), v.pendingOsMint);
            v.pendingOsMint = 0;
        }

        emit ReserveAdded(_vaultOwner, _vaultId, _reserveAmt, v.reserveAmt);
    }

    /**
     * @dev Called by `VaultKeeper` to charge risk penalty on low reserve ratio vault.
     * @param _vaultOwner Vault owner address.
     * @param _vaultId Vault ID.
     * @param _amt Risk penalty amount.
     */
    function chargeRiskPenalty(
        address _vaultOwner, 
        uint256 _vaultId, 
        uint256 _amt
    ) 
        external 
        onlyRole(KEEPER_ROLE) 
    {
        Vault storage v = vaults[_vaultOwner][_vaultId];
        if (v.tabAmt == 0)
            revert InvalidVault(_vaultOwner, _vaultId);
        if (_amt == 0)
            revert ZeroValue();

        v.osTabAmt += _amt;
        v.pendingOsMint += _amt;

        emit RiskPenaltyCharged(_vaultOwner, _vaultId, _amt, v.osTabAmt);
    }

    /**
     * @dev Triggered when VaultKeeper confirmed vault liquidation.
     * @param _vaultId Vault ID.
     * @param _osRiskPenalty O/S risk penalty amount up to the point of liquidation.
     */
    function liquidateVault(
        uint256 _vaultId,
        uint256 _osRiskPenalty,
        IPriceOracle.UpdatePriceData calldata sigPrice
    )
        external
        onlyRole(KEEPER_ROLE)
    {
        Vault storage v = vaults[sigPrice.updater][_vaultId];
        if (v.tabAmt == 0)
            revert InvalidVault(sigPrice.updater, _vaultId);

        v.osTabAmt += _osRiskPenalty;
        v.pendingOsMint += _osRiskPenalty;
        emit RiskPenaltyCharged(sigPrice.updater, _vaultId, _osRiskPenalty, v.osTabAmt);

        IConfig.AuctionParams memory auctionParams = config.getAuctionParams();

        liquidatedVaults[_vaultId] = LiquidatedVault(
            sigPrice.updater, 
            auctionParams.auctionManager
        );
        uint256 startPrice = Math.mulDiv(
            priceOracle.updatePrice(sigPrice), 
            auctionParams.auctionStartPriceDiscount, 
            100
        );

        IAuctionManager(auctionParams.auctionManager).createAuction(
            _vaultId,
            v.reserveAddr,
            v.reserveAmt,
            v.tab,
            (v.tabAmt + v.osTabAmt),
            startPrice,
            auctionParams.auctionStepPriceDiscount,
            auctionParams.auctionStepDurationInSec
        );
        emit LiquidatedVaultAuction(_vaultId, v.reserveAddr, v.reserveAmt, v.tab, startPrice);

        // Park reserve to auction contract.
        // When auction ended, any leftover reserve is sent back & claimable by vault owner.
        address reserveSafe = reserveRegistry.reserveAddrSafe(v.reserveAddr);
        IReserveSafe(reserveSafe).unlockReserve(
            v.reserveAddr, 
            auctionParams.auctionManager, 
            v.reserveAmt
        );
        v.reserveAmt = 0;
    }

    /**
     * @dev Governance starts CTRL-ALT-DEL operation on specified Tab.
     * Upon completion, Tab is having fixed price. Refer `ProtocolVault` to buy/sell.
     * @param _tab Tab to perform CTRL-ALT-DEL operation.
     * @param _btcTabRate BTC to Tab rate.
     * @param _protocolVaultAddr Lock Tab and BTC into specified `ProtocolVault` contract.
     */
    function ctrlAltDel(
        bytes3 _tab, 
        uint256 _btcTabRate, 
        address _protocolVaultAddr
    )
        external 
        onlyRole(CTRL_ALT_DEL_ROLE) 
    {
        address tabAddr = tabRegistry.tabs(tabCodeToTabKey(_tab));
        if (tabAddr == address(0))
            revert ZeroAddress();

        address[] memory addrs = new address[](vaultId);
        uint256[] memory reserves = new uint256[](vaultId);
        uint256[] memory tabAmts = new uint256[](vaultId);
        CtrlAltDelData memory data = CtrlAltDelData(-1, 0, 0, 0, 0);

        // Iterate all vaults of the Tab type
        for (uint256 i; i < ownerList.length; i++) {
            uint256[] memory ownerVaultIds = vaultOwners[ownerList[i]];

            for (uint256 n; n < ownerVaultIds.length; n++) {
                Vault storage v = vaults[ownerList[i]][ownerVaultIds[n]];

                // Vault Tab = CtrlAltDel's Tab && Vault is not liquidated
                if (v.tab == tabAddr && liquidatedVaults[ownerVaultIds[n]].auctionAddr == address(0)) {
                    // update risk penalty value (if any)
                    vaultKeeper.pushVaultRiskPenalty(ownerList[i], ownerVaultIds[n]);

                    uint256 totalOS = v.tabAmt + v.osTabAmt;

                    // Revert if any vault breaches liquidation ratio with supplied _btcTabRate
                    if (vaultKeeper.isLiquidatingVault(
                        _tab, 
                        _reserveValue(_btcTabRate, v.reserveAmt), 
                        totalOS
                    )) {
                        revert LiquidatingVault(ownerList[i], ownerVaultIds[n]);
                    }

                    // Calc. reserve amount based on reserve type
                    uint256 vaultReserve = Math.mulDiv(totalOS, 1e18, _btcTabRate);

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

                    // Accumulate total tab amount
                    data.totalTabAmt += totalOS;
                    if (v.pendingOsMint > 0) {
                        // clear un-minted amount
                        data.tabToMint += v.pendingOsMint;
                        v.pendingOsMint = 0;
                    }

                    // Reserve to be consolidated
                    data.totalReserveConso += vaultReserve;

                    v.reserveAmt -= vaultReserve; // excess reserve remained in vault.
                    v.tabAmt = 0;
                    v.osTabAmt = 0;
                }
            }
        }

        if (data.tabToMint > 0)
            ITabERC20(tabAddr).mint(config.treasury(), data.tabToMint);

        for (uint256 i; i < addrs.length; i++) {
            if (addrs[i] == address(0))
                break;
            IProtocolVault(_protocolVaultAddr).initCtrlAltDel(addrs[i], reserves[i], tabAddr, tabAmts[i], _btcTabRate);
            // Unlock reserve from Safe, send to ProtocolVault contract
            IReserveSafe(reserveRegistry.reserveAddrSafe(addrs[i])).unlockReserve(
                addrs[i], 
                _protocolVaultAddr, 
                reserves[i]
            );
        }

        emit CtrlAltDel(_tab, _btcTabRate, data.totalTabAmt, data.totalReserve, data.totalReserveConso);
    }


    function tabCodeToTabKey(bytes3 code) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(code));
    }

    function _reserveValue(uint256 price, uint256 _reserveAmt) internal pure returns (uint256) {
        return Math.mulDiv(price, _reserveAmt, 1e18);
    }

    function _maxWithdraw(
        uint256 reserveValue, 
        uint256 mrr, 
        uint256 osTab
    ) 
        internal 
        pure 
        returns (uint256) 
    {
        (, uint256 mw) = Math.trySub(Math.mulDiv(reserveValue, 100, mrr), osTab);
        return mw;
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
        return Math.mulDiv((rv - Math.mulDiv(osTab, mrr, 100)), 1e18, price);
    }

    function _calcFee(uint256 processFeeRate, uint256 amt) internal pure returns (uint256) {
        return Math.mulDiv(processFeeRate, amt, 100);
    }

    function findMatchedAddr(
        address[] memory _addr, 
        address _toMatch
    ) 
        internal 
        pure 
        returns (int256) 
    {
        for (uint256 j; j < _addr.length; j++) {
            if (_addr[j] == _toMatch) {
                return int256(j);
            }
        }
        return -1;
    }

    function _msgSender() internal view override returns (address) {
        return msg.sender;
    }

}
