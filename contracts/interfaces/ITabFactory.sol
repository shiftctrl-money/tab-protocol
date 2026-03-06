// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ITabFactory {
    function tabs(bytes32 tabKey) external view returns (address);

    function tabList(uint256 index) external view returns (bytes3);

    function getTabListLength() external view returns (uint256);

    function updateCreator(address _newAddr) external;

    function updateZUniTab(address _newAddr) external;

    function createTab(
        address _admin,
        address _minter1,
        address _minter2,
        bytes3 _tab        
    ) 
        external 
        returns (address beaconProxyAddress);

    function createTab(
        address _admin,
        address _vaultManager,
        string calldata _name,
        string calldata _symbol,
        bytes3 _tab
    )
        external
        returns (address beaconProxyAddress);

    event UpdatedCreator(address _from, address _to);
    event NewTabBeaconProxy(string indexed _symbol, address indexed addr);

    error Unauthorized();
    error ZeroAddress();
    error EmptyCharacter();
}