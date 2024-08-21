// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ITabRegistry {

    function activatedTabCount() external view returns (uint256);

    function tabs(bytes3) external view returns (address);

    function frozenTabs(bytes3) external view returns (bool);

    function tabList(uint256) external view returns (bytes3);

    function peggedTabCount() external view returns (uint256);

    function peggedTabList(uint256) external view returns (bytes3);

    function peggedTabMap(bytes3) external view returns (bytes3);

    function peggedTabPriceRatio(bytes3) external view returns (uint256);

    function ctrlAltDelTab(bytes3) external view returns (uint256);

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

    function getCtrlAltDelTabList() external view returns (bytes3[] memory);

    function ctrlAltDel(bytes3 _tab, uint256 _btcTabRate) external;

}
