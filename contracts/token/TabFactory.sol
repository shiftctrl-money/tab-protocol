// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {CREATE3} from "lib/solady/src/utils/CREATE3.sol";
import {TabERC20} from "./TabERC20.sol";
import {ITabFactory} from "../interfaces/ITabFactory.sol";

/**
 * @dev Dependency on https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment to create fixed contract address.
 * @title  Factory to create new Tab contract.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract TabFactory is UpgradeableBeacon, ITabFactory {
    address public creator;     // Can call createTab function, e.g. TabRegistry, UniTab, ZUniTab
    address public zUniTab;     // UniTab or ZUniTab

    mapping(bytes32 => address) public tabs;
    bytes3[] public tabList; 

    modifier onlyTabCreator() {
        _onlyTabCreator();
        _;
    }

    /**
     * @dev Deploy `TabFactory` on same contract address across all Tab-supported EVM chains,
     * so that `BeaconProxy` (Tab) contracts created from the factory having consistent addresses.
     * @param _implementation Implementation of `TabERC20` contract shared by all Tab implementations.
     * Call `upgradeTo` to update implementation once TabERC20 contract is deployed.
     * @param _initialOwner Expect governance controller. Authorized to update implementation contract.
     */
    constructor(
        address _implementation, 
        address _initialOwner
    ) UpgradeableBeacon(_implementation, _initialOwner) {}

    /**
     * @dev Call this to set tab registry contract address.
     * @param _newAddr Tab registry address.
     */
    function updateCreator(address _newAddr) external onlyOwner {
        if (_newAddr == address(0))
            revert ZeroAddress();
        emit UpdatedCreator(creator, _newAddr);
        creator = _newAddr;
    }

    function updateZUniTab(address _newAddr) external onlyOwner {
        if (_newAddr == address(0))
            revert ZeroAddress();
        zUniTab = _newAddr;
    }

    function getTabListLength() external view returns (uint256) {
        return tabList.length;
    }

    function createTab(
        address _admin,
        address _minter1,
        address _minter2,
        bytes3 _tab        
    ) 
        external 
        onlyTabCreator 
        returns (address beaconProxyAddress)
    {
        bytes32 tabKey = keccak256(abi.encodePacked(_tab));
        if (tabs[tabKey] != address(0))
            return tabs[tabKey];

        string memory symbol = _addTabCodePrefix(_tab);
        string memory name = string(abi.encodePacked("Sound ", _tab));
        beaconProxyAddress = _createTab(_admin, _minter1, _minter2, name, symbol, _tab, tabKey);
        emit NewTabBeaconProxy(symbol, beaconProxyAddress);   
    }

    function createTab(
        address _admin,
        address _vaultManager,
        string calldata _name,
        string calldata _symbol,
        bytes3 _tab
    )
        external
        onlyTabCreator
        returns (address beaconProxyAddress)
    {
        beaconProxyAddress = _createTab(_admin, zUniTab, _vaultManager, _name, _symbol, _tab, keccak256(abi.encodePacked(_tab)));
        emit NewTabBeaconProxy(_symbol, beaconProxyAddress);   
    }

    function _createTab(
        address _admin,
        address _minter1,
        address _minter2,
        string memory _name,
        string memory _symbol,
        bytes3 _tab,
        bytes32 _tabKey
    ) internal returns(address) {
        bytes memory initData = abi.encodeCall(TabERC20.initialize, (_admin, _minter1, _minter2, _name, _symbol));
        bytes memory beaconProxyInitParams = abi.encode(address(this), initData);
        address beaconProxyAddress = CREATE3.deployDeterministic(
            abi.encodePacked(type(BeaconProxy).creationCode, beaconProxyInitParams),
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ", _symbol))
        );
        tabs[_tabKey] = beaconProxyAddress;
        tabList.push(_tab); // list of bytes3 tabs
        return beaconProxyAddress;
    }

    function _onlyTabCreator() internal view {
        if (msg.sender != creator) {
            revert Unauthorized();
        }
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
