// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./token/TabERC20.sol";

/// @dev Must deploy TabFactory to same address so that all TAB created to have same address
contract TabFactory is AccessControlDefaultAdminRules {

    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    TabERC20 tabERC20;

    constructor(address _admin, address _tabRegistry) AccessControlDefaultAdminRules(1 days, _admin) {
        _grantRole(USER_ROLE, _admin);
        _grantRole(USER_ROLE, _tabRegistry);
        tabERC20 = new TabERC20();
    }

    function createTab(bytes3 _tabName) external onlyRole(USER_ROLE) returns (address) {
        return Clones.cloneDeterministic(address(tabERC20), keccak256(abi.encodePacked("shiftCTRL TAB_v1: ", _tabName)));
    }

}
