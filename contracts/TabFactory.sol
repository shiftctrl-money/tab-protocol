// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AccessControlDefaultAdminRules } from "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { CREATE3 } from "lib/solady/src/utils/CREATE3.sol";
import { TabERC20 } from "./token/TabERC20.sol";

/// @dev to deploy with https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment
contract TabFactory is AccessControlDefaultAdminRules {

    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    TabERC20 tabERC20;

    constructor(address _admin, address _tabRegistry) AccessControlDefaultAdminRules(1 days, _admin) {
        _grantRole(USER_ROLE, _admin);
        _grantRole(USER_ROLE, _tabRegistry);
        tabERC20 = new TabERC20();
    }

    function changeTabERC20Addr(address _newTabAddr) external onlyRole(USER_ROLE) {
        require(_newTabAddr != address(0), "INVALID_ADDR");
        tabERC20 = TabERC20(_newTabAddr);
    }

    function createTab(
        bytes3 _tabName,
        string memory _name,
        string memory _symbol,
        address _admin,
        address _vaultManager,
        address _tabProxyAdmin
    )
        external
        onlyRole(USER_ROLE)
        returns (address)
    {
        bytes memory deployCode = type(TransparentUpgradeableProxy).creationCode;
        bytes memory initData =
            abi.encodeWithSignature("initialize(string,string,address,address)", _name, _symbol, _admin, _vaultManager);
        bytes memory params = abi.encode(address(tabERC20), _tabProxyAdmin, initData);

        // CREATE3.deploy(
        //  bytes32 salt, 
        //  bytes memory creationCode, 
        //  uint256 value)
        return CREATE3.deploy(
            keccak256(abi.encodePacked("shiftCTRL TAB_v1: ", _tabName)), abi.encodePacked(deployCode, params), 0
        );
    }

}
