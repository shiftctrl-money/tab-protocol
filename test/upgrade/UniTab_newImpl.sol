// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {UniTab} from "../../contracts/token/UniTab.sol";

contract UniTab_newImpl is UniTab {
    string public version;

    function upgraded(string calldata _version) reinitializer(2) external onlyRole(UPGRADER_ROLE) {
        version = _version;
    }

    function newFunction() external pure returns(uint256) {
        return 1e18;
    }
}