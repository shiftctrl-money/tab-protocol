// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {GovernanceAction} from "../../contracts/governance/GovernanceAction.sol";

contract GovernanceAction_newImpl is GovernanceAction {
    string public version;

    function upgraded(string calldata _version) external onlyRole(UPGRADER_ROLE) {
        version = _version;
    }

    function newFunction() external pure returns(uint256) {
        return 1e18;
    }
}