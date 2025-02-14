// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {VaultKeeper} from "../../contracts/core/VaultKeeper.sol";

contract VaultKeeper_newImpl is VaultKeeper {
    string public version;

    function upgraded(string calldata _version) external onlyRole(UPGRADER_ROLE) {
        version = _version;
    }

    function newFunction() external pure returns(uint256) {
        return 1e18;
    }
}