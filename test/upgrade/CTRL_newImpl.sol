// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {CTRL} from "../../contracts/token/CTRL.sol";

contract CTRL_newImpl is CTRL {
    string public version;

    function upgraded(string calldata _version) reinitializer(2) external {
        version = _version;
    }

    function newFunction() external pure returns(uint256) {
        return 1e18;
    }
}