// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPriceOracleManager } from "./oracle/interfaces/IPriceOracleManager.sol";
import { IPriceOracle } from "./oracle/interfaces/IPriceOracle.sol";
import { IConfig } from "./shared/interfaces/IConfig.sol";
import { ITabFactory } from "./shared/interfaces/ITabFactory.sol";
import { IVaultManager } from "./shared/interfaces/IVaultManager.sol";
import { AccessControlDefaultAdminRules } from "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";

/**
 * @title  Manage authorized Tab contracts.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract TabRegistry is AccessControlDefaultAdminRules {

    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant TAB_PAUSER_ROLE = keccak256("TAB_PAUSER_ROLE");
    bytes32 public constant ALL_TAB_PAUSER_ROLE = keccak256("ALL_TAB_PAUSER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    uint256 public activatedTabCount;
    mapping(bytes3 => address) public tabs; // activated tab, "USD" : address(token)
    mapping(bytes3 => bool) public frozenTabs; // true when the tab is frozen, no operation is allowed
    bytes3[] public tabList; // list of all activated tab currrencies

    // pegged tabs
    uint256 public peggedTabCount;
    bytes3[] public peggedTabList;
    mapping(bytes3 => bytes3) public peggedTabMap; // e.g. XXX pegged to USD
    mapping(bytes3 => uint256) public peggedTabPriceRatio; // e.g. when pegged to half price of USD, store value 50
        // (divide by 100 to get ratio 0.5)

    // ctrl-alt-del
    mapping(bytes3 => uint256) public ctrlAltDelTab; // >0 when the tab(key) is now set to fixed price

    address public tabFactory;
    address public vaultManager;
    address public tabProxyAdmin;
    address public config;
    address public priceOracleManager;
    address public governanceAction;
    address public protocolVault;

    event TabRegistryAdded(string tab, address addr);
    event UpdatedTabFactoryAddress(address b4, address _after);
    event UpdatedVaultManagerAddress(address b4, address _after);
    event UpdatedConfigAddress(address b4, address _after);
    event UpdatedPriceOracleManagerAddress(address b4, address _after);
    event PeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio);
    event FreezeTab(bytes3 indexed tab);
    event UnfreezeTab(bytes3 indexed tab);
    event UpdatedGovernanceActionAddress(address b4, address _after);
    event UpdatedProtocolVaultAddress(address b4, address _after);
    event CtrlAltDelTab(bytes3 indexed _tab, uint256 fixedPrice);

    /**
     * @param _admin governance contract
     * @param _admin2 governanceAction
     * @param _deployer tech deployer
     * @param _authorizedRelayer relayer
     * @param _vaultManager vault manager contract
     * @param _tabProxyAdmin proxy admin of all tab proxies
     */
    constructor(
        address _admin,
        address _admin2,
        address _governanceAction,
        address _deployer,
        address _authorizedRelayer,
        address _vaultManager,
        address _tabProxyAdmin
    )
        AccessControlDefaultAdminRules(1 days, _admin)
    {
        _grantRole(USER_ROLE, _admin); // createTab: governance voted to create custom tab (with oracle price)
        _grantRole(USER_ROLE, _admin2);
        _grantRole(USER_ROLE, _governanceAction);
        _grantRole(USER_ROLE, _vaultManager);
        _grantRole(MAINTAINER_ROLE, _admin);
        _grantRole(MAINTAINER_ROLE, _admin2);
        _grantRole(MAINTAINER_ROLE, _governanceAction);
        _grantRole(MAINTAINER_ROLE, _deployer);
        _grantRole(TAB_PAUSER_ROLE, _admin);
        _grantRole(TAB_PAUSER_ROLE, _admin2);
        _grantRole(TAB_PAUSER_ROLE, _governanceAction);
        _grantRole(TAB_PAUSER_ROLE, _authorizedRelayer);
        _grantRole(ALL_TAB_PAUSER_ROLE, _admin);
        _grantRole(ALL_TAB_PAUSER_ROLE, _admin2);
        _grantRole(ALL_TAB_PAUSER_ROLE, _governanceAction);
        _setRoleAdmin(MAINTAINER_ROLE, MAINTAINER_ROLE);
        _setRoleAdmin(USER_ROLE, MAINTAINER_ROLE);
        _setRoleAdmin(TAB_PAUSER_ROLE, MAINTAINER_ROLE);
        _setRoleAdmin(ALL_TAB_PAUSER_ROLE, MAINTAINER_ROLE);
        vaultManager = _vaultManager;
        tabProxyAdmin = _tabProxyAdmin;
        peggedTabCount = 0;
        activatedTabCount = 0;
    }

    function setTabFactory(address _tabFactory) external onlyRole(MAINTAINER_ROLE) {
        require(_tabFactory != address(0), "INVALID_ADDR");
        emit UpdatedTabFactoryAddress(tabFactory, _tabFactory);
        tabFactory = _tabFactory;
    }

    function setVaultManagerAddress(address _vaultManager) external onlyRole(MAINTAINER_ROLE) {
        require(_vaultManager != address(0), "INVALID_ADDR");
        emit UpdatedVaultManagerAddress(vaultManager, _vaultManager);
        vaultManager = _vaultManager;
    }

    function setConfigAddress(address _config) external onlyRole(MAINTAINER_ROLE) {
        require(_config != address(0), "INVALID_ADDR");
        emit UpdatedConfigAddress(config, _config);
        config = _config;
    }

    function setPriceOracleManagerAddress(address _priceOracleManager) external onlyRole(MAINTAINER_ROLE) {
        require(_priceOracleManager != address(0), "INVALID_ADDR");
        emit UpdatedPriceOracleManagerAddress(priceOracleManager, _priceOracleManager);
        priceOracleManager = _priceOracleManager;
    }

    function setGovernanceAction(address _governanceAction) external onlyRole(MAINTAINER_ROLE) {
        require(_governanceAction != address(0), "INVALID_ADDR");
        _grantRole(USER_ROLE, _governanceAction);
        _grantRole(TAB_PAUSER_ROLE, _governanceAction);
        _grantRole(ALL_TAB_PAUSER_ROLE, _governanceAction);
        _grantRole(MAINTAINER_ROLE, _governanceAction);
        emit UpdatedGovernanceActionAddress(governanceAction, _governanceAction);
        governanceAction = _governanceAction;
    }

    /// @dev Create ProtocolVault contract and call this before calling CtrlAltDel in governance
    function setProtocolVaultAddress(address _protocolVault) external onlyRole(MAINTAINER_ROLE) {
        require(_protocolVault != address(0), "INVALID_ADDR");
        emit UpdatedProtocolVaultAddress(protocolVault, _protocolVault);
        protocolVault = _protocolVault;
    }

    /**
     *
     * @param _ptab Pegged Tab Code
     * @param _tab Pegging to this tab (existing TAB)
     * @param _priceRatio Value 100 represents 100% value of the pegged price. E.g store 50 if ABC is 50% value of USD
     */
    function setPeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio) external onlyRole(MAINTAINER_ROLE) {
        require(_ptab != _tab, "INVALID_SAME_TAB");
        require(tabs[_tab] != address(0), "INACTIVE_TAB"); // only can peg to existing TAB, not pegged tab
        require(_priceRatio > 0, "INVALID_PRICE_RATIO");

        if (peggedTabMap[_ptab] == 0x0) {
            // new pegged tab
            peggedTabCount = peggedTabCount + 1;
            peggedTabList.push(_ptab);
        }

        peggedTabMap[_ptab] = _tab;
        peggedTabPriceRatio[_ptab] = _priceRatio;

        IPriceOracle(IPriceOracleManager(priceOracleManager).priceOracle()).setPeggedTab(_ptab, _tab, _priceRatio);
        emit PeggedTab(_ptab, _tab, _priceRatio);
    }

    function enableTab(bytes3 _tab) external onlyRole(TAB_PAUSER_ROLE) {
        require(tabs[_tab] != address(0), "INVALID_TAB");
        require(frozenTabs[_tab], "TAB_ACTIVE");

        emit UnfreezeTab(_tab);
        frozenTabs[_tab] = false;
    }

    function disableTab(bytes3 _tab) external onlyRole(TAB_PAUSER_ROLE) {
        require(tabs[_tab] != address(0), "INVALID_TAB");
        require(!frozenTabs[_tab], "TAB_FROZEN");

        emit FreezeTab(_tab);
        frozenTabs[_tab] = true;
    }

    function enableAllTab() external onlyRole(ALL_TAB_PAUSER_ROLE) {
        for (uint256 i = 0; i < activatedTabCount; ++i) {
            bytes3 _tab = tabList[i];
            emit UnfreezeTab(_tab);
            frozenTabs[_tab] = false;
        }
    }

    function disableAllTab() external onlyRole(ALL_TAB_PAUSER_ROLE) {
        for (uint256 i = 0; i < activatedTabCount; ++i) {
            bytes3 _tab = tabList[i];
            emit FreezeTab(_tab);
            frozenTabs[_tab] = true;
        }
    }

    /**
     * @dev Register and create new Tab.
     * @param _tab New tab code.
     */
    function createTab(bytes3 _tab) external onlyRole(USER_ROLE) returns (address) {
        if (tabs[_tab] != address(0)) {
            return tabs[_tab];
        }
        string memory _symbol = toTabCode(_tab);
        string memory _name = string(abi.encodePacked("Sound ", _tab));
        address createdAddr =
            ITabFactory(tabFactory).createTab(_tab, _name, _symbol, defaultAdmin(), vaultManager, tabProxyAdmin);
        tabs[_tab] = createdAddr;
        tabList.push(_tab);
        activatedTabCount = activatedTabCount + 1;

        IPriceOracleManager(priceOracleManager).addNewTab(_tab);

        // default tab params
        IConfig(config).setDefTabParams(_tab);

        emit TabRegistryAdded(_symbol, createdAddr);
        return createdAddr;
    }

    /// @dev Retrieve list of tab codes that are already clrl-alt-del/depeg
    function getCtrlAltDelTabList() external view returns (bytes3[] memory ctrlAltDelTabList) {
        ctrlAltDelTabList = new bytes3[](activatedTabCount);
        uint256 count = 0;
        for (uint256 i = 0; i < activatedTabCount; ++i) {
            if (ctrlAltDelTab[tabList[i]] > 0) {
                ctrlAltDelTabList[count] = tabList[i];
                count += 1;
            }
        }
    }

    /// @dev triggered by governance
    function ctrlAltDel(bytes3 _tab, uint256 _btcTabRate) external onlyRole(USER_ROLE) {
        require(tabs[_tab] != address(0), "INVALID_TAB");
        require(_btcTabRate > 0, "INVALID_RATE");
        require(ctrlAltDelTab[_tab] == 0, "CTRL_ALT_DEL_DONE");

        IVaultManager(vaultManager).ctrlAltDel(_tab, _btcTabRate, protocolVault);

        IPriceOracle(IPriceOracleManager(priceOracleManager).priceOracle()).ctrlAltDel(_tab, _btcTabRate);

        ctrlAltDelTab[_tab] = _btcTabRate;

        emit CtrlAltDelTab(_tab, _btcTabRate);
    }

    function toTabCode(bytes3 _tab) internal pure returns (string memory) {
        bytes memory b = new bytes(4);
        b[0] = hex"73"; // prefix s
        require(_tab[0] != 0x0, "INVALID_FIRST_TAB_CHAR");
        b[1] = _tab[0];
        require(_tab[1] != 0x0, "INVALID_SEC_TAB_CHAR");
        b[2] = _tab[1];
        require(_tab[2] != 0x0, "INVALID_3RD_TAB_CHAR");
        b[3] = _tab[2];
        return string(b);
    }

}
