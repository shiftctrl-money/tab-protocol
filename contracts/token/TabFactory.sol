// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {CREATE3} from "lib/solady/src/utils/CREATE3.sol";
import {TabERC20} from "./TabERC20.sol";

/**
 * @dev Dependency on https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment to create fixed contract address.
 * @title  Factory to create new Tab contract.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract TabFactory is UpgradeableBeacon {
    address public tabRegistry;

    event UpdatedTabRegistry(address _from, address _to);
    event NewTabBeaconProxy(string _symbol, address addr);

    error Unauthorized();
    error ZeroAddress();

    modifier onlyTabRegistry() {
        _checkUser();
        _;
    }

    /**
     * @dev Deploy `TabFactory` on same contract address across all Tab-supported EVM chains,
     * so that `BeaconProxy` (Tab) contracts created from the factory having consistent addresses.
     * @param _implementation Implementation of `TabERC20` contract shared by all Tab implementations.
     * On first deployment, use a temp/fixed address (for example, SKYBIT factory contract) 
     * to ensure same `TabFactory` bytecodes are deployed.
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
    function updateTabRegistry(address _newAddr) external onlyOwner {
        if (_newAddr == address(0))
            revert ZeroAddress();
        emit UpdatedTabRegistry(tabRegistry, _newAddr);
        tabRegistry = _newAddr;
    }

    function createTab(
        address _admin,
        address _vaultManager,
        string memory _name,
        string memory _symbol
    )
        external
        onlyTabRegistry
        returns (address)
    {
        bytes memory initData = abi.encodeCall(TabERC20.initialize, (_admin, _vaultManager, _name, _symbol));
        bytes memory beaconProxyInitParams = abi.encode(address(this), initData);
        address beaconProxyAddress = CREATE3.deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.00.000: ", _symbol)),
            abi.encodePacked(type(BeaconProxy).creationCode, beaconProxyInitParams),
            0
        );

        emit NewTabBeaconProxy(_symbol, beaconProxyAddress);
        return beaconProxyAddress;
    }

    function _checkUser() internal view {
        if (msg.sender != tabRegistry) {
            revert Unauthorized();
        }
    }

}
