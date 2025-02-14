// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ITabRegistry {
    function activatedTabCount() external view returns(uint256);
    function tabs(bytes32) external view returns(address);
    function frozenTabs(bytes32) external view returns(bool);
    function tabList(uint256) external view returns(bytes3);
    function peggedTabCount() external view returns(uint256);
    function peggedTabList(uint256) external view returns(bytes3);
    function peggedTabMap(bytes32) external view returns(bytes32);
    function peggedTabPriceRatio(bytes32) external view returns(uint256); 
    function ctrlAltDelTab(bytes32) external view returns(uint256);
    function tabFactory() external view returns(address);
    function vaultManager() external view returns(address);
    function config() external view returns(address);
    function priceOracleManager() external view returns(address);
    function governanceAction() external view returns(address);
    function protocolVault() external view returns(address);

    function setTabFactory(address _tabFactory) external;
    function setVaultManagerAddress(address _vaultManager) external;
    function setConfigAddress(address _config) external;
    function setPriceOracleManagerAddress(address _priceOracleManager) external;
    function setGovernanceAction(address _governanceAction) external;
    function setProtocolVaultAddress(address _protocolVault) external;
    function setPeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio) external;
    function enableTab(bytes3 _tab) external;
    function disableTab(bytes3 _tab) external;
    function enableAllTab() external;
    function disableAllTab() external;
    function createTab(bytes3 _tab) external returns (address);
    function getCtrlAltDelTabList() external view returns (bytes3[] memory ctrlAltDelTabList);
    function ctrlAltDel(bytes3 _tab, uint256 _btcTabRate) external;
    function getTabAddress(bytes3 _tab) external view returns(address);
    function tabCodeToTabKey(bytes3 code) external pure returns(bytes32);

    event UpdatedTabFactoryAddress(address b4, address _after);
    event UpdatedVaultManagerAddress(address b4, address _after);
    event UpdatedConfigAddress(address b4, address _after);
    event UpdatedPriceOracleManagerAddress(address b4, address _after);
    event UpdatedGovernanceActionAddress(address b4, address _after);
    event UpdatedProtocolVaultAddress(address b4, address _after);
    event PeggedTab(bytes3 ptab, bytes3 tab, uint256 priceRatio);
    event UnfreezeTab(bytes3 indexed tab);
    event FreezeTab(bytes3 indexed tab);
    event FreezeAllTab();
    event UnfreezeAllTab();
    event TabRegistryAdded(string tab, address addr);
    event TriggeredCtrlAltDelTab(bytes3 indexed tab, uint256 fixedPrice);

    error ZeroAddress();
    error InvalidPeggedTab();
    error InvalidTab();
    error ZeroValue();
    error ExecutedDepeg();
    error EmptyCharacter();
}
