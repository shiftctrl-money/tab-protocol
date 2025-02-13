// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRulesUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITabERC20} from "../interfaces/ITabERC20.sol";
import {IReserveSafe} from "../interfaces/IReserveSafe.sol";
import {IProtocolVault} from "../interfaces/IProtocolVault.sol";

/**
 * @title Manage buy/sell transaction post Ctl-Alt-Del operation.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract ProtocolVault is 
    Initializable, 
    AccessControlDefaultAdminRulesUpgradeable, 
    UUPSUpgradeable, 
    ReentrancyGuardUpgradeable, 
    IProtocolVault 
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant CTRL_ALT_DEL_ROLE = keccak256("CTRL_ALT_DEL_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // reserve_addr: (tab_addr : PVault)
    mapping(address => mapping(address => PVault)) public vaults; 

    address public reserveSafe;

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Need MINTER_ROLE on Tab contract for successful CTRL_ALT_DEL operation.
     * @param _admin Governance controller.
     * @param _vaultManager Vault Manager contract.
     */
    function initialize(
        address _admin, 
        address _upgrader,
        address _vaultManager, 
        address _reserveSafe
    ) 
        public 
        initializer 
    {
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __UUPSUpgradeable_init();

        _grantRole(CTRL_ALT_DEL_ROLE, _admin);
        _grantRole(CTRL_ALT_DEL_ROLE, _vaultManager);

        _grantRole(MANAGER_ROLE, _admin);
        
        _grantRole(UPGRADER_ROLE, _upgrader);

        // Required MINTER_ROLE on TAB contract. Execute grantRole from governance.

        reserveSafe = _reserveSafe;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    /**
     * @dev Set once during depoyment for default `ReserveSafe` contract.
     * @param _reserveSafe Reserve safe contract address.
     */
    function updateReserveSafe(address _reserveSafe) external onlyRole(MANAGER_ROLE) {
        if (_reserveSafe == address(0))
            revert ZeroAddress();
        if (_reserveSafe.code.length == 0)
            revert InvalidReserveSafe();
        emit UpdatedReserveSafe(reserveSafe, _reserveSafe);
        reserveSafe = _reserveSafe;
    }

    /**
     * @dev Called by governance to initialize Ctrl-Alt-Del operation on specified Tab.
     * @param _reserveAddr BTC Token address
     * @param _reserveAmt BTC reserve amount
     * @param _tabAddr Tab contract address
     * @param _tabAmt Tab amount
     * @param _reserveTabPrice BTC to Tab rate
     */
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
        if (vaults[_reserveAddr][_tabAddr].price > 0)
            revert ExistedProtovolVault();
        if (_reserveTabPrice == 0)
            revert ZeroValue();
        vaults[_reserveAddr][_tabAddr] = PVault(_reserveAddr, _reserveAmt, _tabAddr, _tabAmt, _reserveTabPrice);
        emit InitCtrlAltDel(_reserveAddr, _reserveAmt, _tabAddr, _tabAmt, _reserveTabPrice);
    }

    /**
     * 
     * @dev Mint Tabs. Required caller's allowance BTC token.
     * @param _reserveAddr Reserve contract address.
     * @param _tabAddr Tab contract address.
     * @param _reserveAmt Reserve amount to spend to buy Tab.
     */
    function buyTab(
        address _reserveAddr, 
        address _tabAddr, 
        uint256 _reserveAmt
    ) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        PVault storage vault = vaults[_reserveAddr][_tabAddr];
        if (vault.price == 0)
            revert NotExistedProtocolVault();
        if (_reserveAmt == 0)
            revert ZeroValue();
        
        // Transfer reserve from user
        SafeERC20.safeTransferFrom(
            IERC20(_reserveAddr),
            _msgSender(),
            address(this),
            IReserveSafe(reserveSafe).getNativeTransferAmount(_reserveAddr, _reserveAmt)
        );

        uint256 tabAmt = Math.mulDiv(_reserveAmt, vault.price, 1e18);

        vault.reserveAmt += _reserveAmt;
        vault.tabAmt += tabAmt;

        ITabERC20(vault.tab).mint(_msgSender(), tabAmt);
        emit BuyTab(_msgSender(), _reserveAddr, _reserveAmt, _tabAddr, tabAmt);
        return tabAmt;
    }

    /**
     * 
     * @dev Buy BTC Token by selling holding Tabs. Required allowance on Tab to call.
     * @param _reserveAddr Reserve contract address.
     * @param _tabAddr Tab contract address.
     * @param _tabAmt Tab amount to spend to get BTC token.
     */
    function sellTab(
        address _reserveAddr, 
        address _tabAddr, 
        uint256 _tabAmt
    )
        external 
        nonReentrant 
        returns (uint256) 
    {
        PVault storage vault = vaults[_reserveAddr][_tabAddr];
        if (vault.price == 0)
            revert NotExistedProtocolVault();
        if (_tabAmt == 0)
            revert ZeroValue();

        uint256 reserveAmt = Math.mulDiv(_tabAmt, 1e18, vault.price);
        if (reserveAmt == 0)
            revert ZeroValue();
        if (reserveAmt > vault.reserveAmt)
            revert InsufficientReserveBalance();

        ITabERC20(vault.tab).burnFrom(_msgSender(), _tabAmt);

        vault.tabAmt -= _tabAmt;
        vault.reserveAmt -= reserveAmt;

        // From protocol vault, send BTC token to caller
        SafeERC20.safeTransfer(
            IERC20(_reserveAddr),
            _msgSender(),
            IReserveSafe(reserveSafe).getNativeTransferAmount(_reserveAddr, reserveAmt)
        );

        emit SellTab(_msgSender(), _reserveAddr, reserveAmt, _tabAddr, _tabAmt);
        return reserveAmt;
    }

    function _msgSender() internal view override returns (address) {
        return msg.sender;
    }

}
