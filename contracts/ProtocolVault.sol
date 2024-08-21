// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import "./shared/interfaces/ITabERC20.sol";
import "./shared/interfaces/IReserveRegistry.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";
import "lib/solady/src/utils/SafeTransferLib.sol";

/**
 * @title  Manage buy/sell transaction on post Ctl-Alt-Del Tab.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract ProtocolVault is Initializable, AccessControlDefaultAdminRulesUpgradeable, UUPSUpgradeable {

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant CTRL_ALT_DEL_ROLE = keccak256("CTRL_ALT_DEL_ROLE");

    struct PVault {
        address reserve; // locked reserve address, e.g. WBTC, cBTC
        uint256 reserveAmt; // reserve value (18 decimals)
        address tab; // Tab currency
        uint256 tabAmt; // Tab currency reserve (18 decimals)
        uint256 price; // RESERVE/TAB price rate
    }

    mapping(address => mapping(address => PVault)) public vaults; // reserve_addr: (tab_addr : PVault)

    address tabRegistry;
    address reserveRegistry;

    event UpdatedReserveRegistryAddr(address addrB4, address addrAfter);
    event InitCtrlAltDel(address reserveAddr, uint256 reserveAmt, address tabAddr, uint256 tabAmt, uint256 price);
    event BuyTab(address indexed buyer, address reserveAddr, uint256 reserveAmt, address tabAddr, uint256 tabAmt);
    event SellTab(address indexed seller, address reserveAddr, uint256 reserveAmt, address tabAddr, uint256 tabAmt);

    constructor() {
        _disableInitializers();
    }

    /// @dev When deploying ProtocolVault, need governance to grant MINTER_ROLE on corresponding Tab contract.
    function initialize(address _admin, address _vaultManager, address _reserveRegistry) public initializer {
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __UUPSUpgradeable_init();

        _grantRole(CTRL_ALT_DEL_ROLE, _admin);
        _grantRole(CTRL_ALT_DEL_ROLE, _vaultManager);

        reserveRegistry = _reserveRegistry;

        // Required MINTER_ROLE on TAB contract. Execute grantRole from governance.
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function initCtrlAltDel(
        address _reserveAddr,
        uint256 _reserveAmt,
        address _tabAddr,
        uint256 _tabAmt,
        uint256 _reserveTabPrice
    )
        external
        onlyRole(CTRL_ALT_DEL_ROLE)
    {
        require(vaults[_reserveAddr][_tabAddr].price == 0, "initCtrlAltDel/EXISTED_VAULT");

        vaults[_reserveAddr][_tabAddr] = PVault(_reserveAddr, _reserveAmt, _tabAddr, _tabAmt, _reserveTabPrice);

        emit InitCtrlAltDel(_reserveAddr, _reserveAmt, _tabAddr, _tabAmt, _reserveTabPrice);
    }

    function updateReserveRegistry(address _reserveRegistry) external onlyRole(CTRL_ALT_DEL_ROLE) {
        require(_reserveRegistry != address(0), "EMPTY_ADDR");
        emit UpdatedReserveRegistryAddr(reserveRegistry, _reserveRegistry);
        reserveRegistry = _reserveRegistry;
    }

    /**
     * 
     * @dev Mint Tabs. Required allowance on user's BTC reserve. User pays BTC `_reserveAmt` to buy Tab.
     * @param _reserveAddr Reserve contract address.
     * @param _tabAddr Tab contract address.
     * @param _reserveAmt Reserve amount to spend to buy Tab. Required allowance on reserve before calling `buyTab`.
     */
    function buyTab(address _reserveAddr, address _tabAddr, uint256 _reserveAmt) external returns (uint256) {
        PVault storage vault = vaults[_reserveAddr][_tabAddr];
        require(vault.price > 0, "INVALID_VAULT");
        require(_reserveAmt > 0, "INVALID_AMT");

        uint256 tabAmt = FixedPointMathLib.mulWad(_reserveAmt, vault.price);
        (uint256 valueInOriDecimal, uint256 valueInDec18) = IReserveRegistry(reserveRegistry).getOriReserveAmt(_reserveAddr, _reserveAmt);

        vault.reserveAmt += valueInDec18;
        vault.tabAmt += tabAmt;

        // Transfer reserve from user
        SafeTransferLib.safeTransferFrom(_reserveAddr, _msgSender(), address(this), valueInOriDecimal);

        ITabERC20(vault.tab).mint(_msgSender(), tabAmt);

        emit BuyTab(_msgSender(), _reserveAddr, valueInDec18, _tabAddr, tabAmt);
        return tabAmt;
    }

    /**
     * 
     * @dev Withdraw reserves. Required allowance on Tab. User gets BTC from selling(burning) tab `_tabAmt`
     * @param _reserveAddr Reserve contract address.
     * @param _tabAddr Tab contract address.
     * @param _tabAmt Tab amount to spend to get BTC. Required allowance on Tab before calling `sellTab`.
     */
    function sellTab(address _reserveAddr, address _tabAddr, uint256 _tabAmt) external returns (uint256) {
        PVault storage vault = vaults[_reserveAddr][_tabAddr];
        require(vault.price > 0, "INVALID_VAULT");
        require(_tabAmt > 0 && _tabAmt <= vault.tabAmt, "INVALID_AMT");

        uint256 reserveAmt = FixedPointMathLib.divWad(_tabAmt, vault.price);
        require(reserveAmt > 0, "ZERO_RESERVE_AMT");
        (uint256 valueInOriDecimal, uint256 valueInDec18) = IReserveRegistry(reserveRegistry).getOriReserveAmt(_reserveAddr, reserveAmt);

        vault.tabAmt -= _tabAmt;
        vault.reserveAmt -= valueInDec18;

        ITabERC20(vault.tab).burnFrom(_msgSender(), _tabAmt);

        SafeTransferLib.safeTransfer(_reserveAddr, _msgSender(), valueInOriDecimal);

        emit SellTab(_msgSender(), _reserveAddr, valueInDec18, _tabAddr, _tabAmt);
        return valueInDec18;
    }

    function _msgSender() internal view override returns (address) {
        return msg.sender;
    }

}
