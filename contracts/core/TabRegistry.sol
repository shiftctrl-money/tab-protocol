// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRules} 
    from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {IConfig} from "../interfaces/IConfig.sol";
import {ITabFactory} from "../interfaces/ITabFactory.sol";
import {ITabRegistry} from "../interfaces/ITabRegistry.sol";
import {IPriceOracleManager} from "../interfaces/IPriceOracleManager.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

/**
 * @title  Manage Tab contracts.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract TabRegistry is ITabRegistry, AccessControlDefaultAdminRules {
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant TAB_PAUSER_ROLE = keccak256("TAB_PAUSER_ROLE");
    bytes32 public constant ALL_TAB_PAUSER_ROLE = keccak256("ALL_TAB_PAUSER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    uint256 public activatedTabCount;

    // activated tab, e.g. keccak256(abi.encodePacked("USD")) : address(sUSD_Token)
    mapping(bytes32 => address) public tabs;

    // true when the tab is frozen, blocked tab operation
    mapping(bytes32 => bool) public frozenTabs; 

    // list of all activated tab currrencies
    bytes3[] public tabList; 

    // pegged tabs
    uint256 public peggedTabCount;
    bytes3[] public peggedTabList;
    // e.g. XXX pegged to USD
    mapping(bytes32 => bytes32) public peggedTabMap; 
    // e.g. when pegged to half price of USD, store value 50
    // divide by 100 to get ratio 0.5
    mapping(bytes32 => uint256) public peggedTabPriceRatio; 
        
    // ctrl-alt-del
    mapping(bytes32 => uint256) public ctrlAltDelTab; // >0 when the tab(key) is now set to fixed price

    address public tabFactory;
    address public vaultManager;
    address public config;
    address public priceOracleManager;
    address public governanceAction;
    address public protocolVault;

    /**
     * @param _admin Governance controller.
     * @param _admin2 Emergency governance controller.
     * @param _governanceAction Governance action contract.
     * @param _deployer Deployer to setup contract address.
     * @param _oracleRelayer Oracle relayer to freeze/unfreeze tab.
     * @param _vaultManager vault manager contract
     */
    constructor(
        address _admin,
        address _admin2,
        address _governanceAction,
        address _deployer,
        address _oracleRelayer,
        address _vaultManager
    )
        AccessControlDefaultAdminRules(1 days, _admin)
    {
        // Can create tab or initialize ctrl-alt-del operation
        _grantRole(USER_ROLE, _admin);
        _grantRole(USER_ROLE, _admin2);
        _grantRole(USER_ROLE, _governanceAction);
        _grantRole(USER_ROLE, _vaultManager);

        // Can maintain associated protocol contract addresses
        _grantRole(MAINTAINER_ROLE, _admin);
        _grantRole(MAINTAINER_ROLE, _admin2);
        _grantRole(MAINTAINER_ROLE, _governanceAction);
        _grantRole(MAINTAINER_ROLE, _deployer);

        // Can freeze/unfreeze selected tab
        _grantRole(TAB_PAUSER_ROLE, _admin);
        _grantRole(TAB_PAUSER_ROLE, _admin2);
        _grantRole(TAB_PAUSER_ROLE, _governanceAction);
        _grantRole(TAB_PAUSER_ROLE, _oracleRelayer);

        // Can freeze/unfreeze All tabs
        _grantRole(ALL_TAB_PAUSER_ROLE, _admin);
        _grantRole(ALL_TAB_PAUSER_ROLE, _admin2);
        _grantRole(ALL_TAB_PAUSER_ROLE, _governanceAction);

        _setRoleAdmin(USER_ROLE, MAINTAINER_ROLE);
        _setRoleAdmin(TAB_PAUSER_ROLE, MAINTAINER_ROLE);
        _setRoleAdmin(ALL_TAB_PAUSER_ROLE, MAINTAINER_ROLE);
        governanceAction = _governanceAction;
        vaultManager = _vaultManager;
    }

    function setTabFactory(address _tabFactory) external onlyRole(MAINTAINER_ROLE) {
        _validAddress(_tabFactory);
        emit UpdatedTabFactoryAddress(tabFactory, _tabFactory);
        tabFactory = _tabFactory;
    }

    function setVaultManagerAddress(address _vaultManager) external onlyRole(MAINTAINER_ROLE) {
        _validAddress(_vaultManager);
        emit UpdatedVaultManagerAddress(vaultManager, _vaultManager);
        vaultManager = _vaultManager;
    }

    function setConfigAddress(address _config) external onlyRole(MAINTAINER_ROLE) {
        _validAddress(_config);
        emit UpdatedConfigAddress(config, _config);
        config = _config;
    }

    function setPriceOracleManagerAddress(address _priceOracleManager) external onlyRole(MAINTAINER_ROLE) {
        _validAddress(_priceOracleManager);
        emit UpdatedPriceOracleManagerAddress(priceOracleManager, _priceOracleManager);
        priceOracleManager = _priceOracleManager;
    }

    function setGovernanceAction(address _governanceAction) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _validAddress(_governanceAction);
        _grantRole(USER_ROLE, _governanceAction);
        _grantRole(TAB_PAUSER_ROLE, _governanceAction);
        _grantRole(ALL_TAB_PAUSER_ROLE, _governanceAction);
        _grantRole(MAINTAINER_ROLE, _governanceAction);
        emit UpdatedGovernanceActionAddress(governanceAction, _governanceAction);
        governanceAction = _governanceAction;
    }

    /// @dev Create ProtocolVault contract and call this before executing CtrlAltDel from governance.
    function setProtocolVaultAddress(address _protocolVault) external onlyRole(MAINTAINER_ROLE) {
        _validAddress(_protocolVault);
        emit UpdatedProtocolVaultAddress(protocolVault, _protocolVault);
        protocolVault = _protocolVault;
    }

    /**
     * @dev Call `createTab` from governance first, then followed by calling this.
     * @param _ptab Pegged Tab Code
     * @param _tab Pegging to this tab (existing TAB)
     * @param _priceRatio Value 100 represents 100% value of the pegged price. 
     * E.g store 50 if ABC is 50% value of USD
     */
    function setPeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio) external onlyRole(MAINTAINER_ROLE) {
        if (_ptab == _tab)
            revert InvalidPeggedTab();
        
        bytes32 tabKey = tabCodeToTabKey(_tab);
        if (tabs[tabKey] == address(0))
            revert InvalidTab();
        
        if (_priceRatio == 0)
            revert ZeroValue();

        bytes32 ptabKey = tabCodeToTabKey(_ptab);
        if (peggedTabMap[ptabKey] == 0x0) {
            // new pegged tab
            peggedTabCount = peggedTabCount + 1;
            peggedTabList.push(_ptab);
        }

        peggedTabMap[ptabKey] = tabKey;
        peggedTabPriceRatio[ptabKey] = _priceRatio;

        IPriceOracle(IPriceOracleManager(priceOracleManager).priceOracle()).setPeggedTab(
            _ptab, 
            _tab, 
            _priceRatio
        );
        emit PeggedTab(_ptab, _tab, _priceRatio);
    }

    /// @dev Set the tab as active regardless of its current state.
    function enableTab(bytes3 _tab) external onlyRole(TAB_PAUSER_ROLE) {
        bytes32 tabKey = tabCodeToTabKey(_tab);
        if (tabs[tabKey] == address(0))
            revert InvalidTab();
        emit UnfreezeTab(_tab);
        frozenTabs[tabKey] = false;
    }

    /// @dev Block operation on the tab untl it is enabled back.
    function disableTab(bytes3 _tab) external onlyRole(TAB_PAUSER_ROLE) {
        bytes32 tabKey = tabCodeToTabKey(_tab);
        if (tabs[tabKey] == address(0))
            revert InvalidTab();
        emit FreezeTab(_tab);
        frozenTabs[tabKey] = true;
    }

    /// @dev Unfreeze all tabs.
    function enableAllTab() external onlyRole(ALL_TAB_PAUSER_ROLE) {
        for (uint256 i; i < activatedTabCount; ++i) {
            frozenTabs[ tabCodeToTabKey(tabList[i]) ] = false;
        }
        emit UnfreezeAllTab();
    }

    /// @dev Freeze all tabs.
    function disableAllTab() external onlyRole(ALL_TAB_PAUSER_ROLE) {
        for (uint256 i; i < activatedTabCount; ++i) {
            frozenTabs[ tabCodeToTabKey(tabList[i]) ] = true;
        }
        emit FreezeAllTab();
    }

    /**
     * @dev Register and create new Tab.
     * @param _tab Tab code in bytes3.
     */
    function createTab(bytes3 _tab) external onlyRole(USER_ROLE) returns (address) {
        bytes32 tabKey = tabCodeToTabKey(_tab);
        if (tabs[tabKey] != address(0)) {
            return tabs[tabKey];
        }
        string memory _symbol = _addTabCodePrefix(_tab);
        string memory _name = string(abi.encodePacked("Sound ", _tab));
        address createdAddr =
            ITabFactory(tabFactory).createTab(defaultAdmin(), vaultManager, _name, _symbol);
        tabs[tabKey] = createdAddr;
        tabList.push(_tab); // list of bytes3
        activatedTabCount = activatedTabCount + 1;

        // set default tab params for the new tab
        IConfig(config).setDefTabParams(_tab);

        emit TabRegistryAdded(_symbol, createdAddr);
        return createdAddr;
    }

    /// @dev Retrieve list of tab codes which are already clrl-alt-del/depeg in protocol.
    function getCtrlAltDelTabList() external view returns (bytes3[] memory ctrlAltDelTabList) {
        ctrlAltDelTabList = new bytes3[](activatedTabCount);
        uint256 count;
        for (uint256 i; i < activatedTabCount; ++i) {
            if (ctrlAltDelTab[ tabCodeToTabKey(tabList[i]) ] > 0) {
                ctrlAltDelTabList[count] = tabList[i];
                count += 1;
            }
        }
    }

    /**
     * @dev Triggered by governance to set a Tab token as depegged state.
     * @param _tab Tab Code (bytes3) to be depegged.
     * @param _btcTabRate BTC/TAB price rate to be fixed.
     */
    function ctrlAltDel(bytes3 _tab, uint256 _btcTabRate) external onlyRole(USER_ROLE) {
        bytes32 tabKey = tabCodeToTabKey(_tab);
        if (tabs[tabKey] == address(0))
            revert InvalidTab();
        if (_btcTabRate == 0)
            revert ZeroValue();
        if (ctrlAltDelTab[tabKey] > 0)
            revert ExecutedDepeg();
        
        IVaultManager(vaultManager).ctrlAltDel(_tab, _btcTabRate, protocolVault);

        IPriceOracle(IPriceOracleManager(priceOracleManager).priceOracle()).ctrlAltDel(_tab, _btcTabRate);

        ctrlAltDelTab[tabKey] = _btcTabRate;

        emit TriggeredCtrlAltDelTab(_tab, _btcTabRate);
    }

    function getTabAddress(bytes3 _tab) public view returns(address) {
        return tabs[tabCodeToTabKey(_tab)];
    }

    function tabCodeToTabKey(bytes3 code) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(code));
    }

    function _validAddress(address _addr) internal pure {
        if (_addr == address(0))
            revert ZeroAddress();
    }

    function _addTabCodePrefix(bytes3 _tab) internal pure returns (string memory) {
        bytes memory b = new bytes(4);
        b[0] = hex"73"; // prefix s
        if (_tab[0] == 0x0)
            revert EmptyCharacter();
        b[1] = _tab[0];
        if (_tab[1] == 0x0)
            revert EmptyCharacter();
        b[2] = _tab[1];
        if (_tab[2] == 0x0)
            revert EmptyCharacter();
        b[3] = _tab[2];
        return string(b);
    }

}
