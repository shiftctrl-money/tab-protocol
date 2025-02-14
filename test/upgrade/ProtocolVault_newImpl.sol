// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ProtocolVault} from "../../contracts/core/ProtocolVault.sol";

contract ProtocolVault_newImpl is ProtocolVault {
    string public version;

    function upgraded(string calldata _version) external onlyRole(UPGRADER_ROLE) {
        version = _version;
    }

    function newFunction() external pure returns(uint256) {
        return 1e18;
    }
}