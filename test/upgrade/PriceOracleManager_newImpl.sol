// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PriceOracleManager} from "../../contracts/oracle/PriceOracleManager.sol";

contract PriceOracleManager_newImpl is PriceOracleManager {
    string public version;

    function upgraded(string calldata _version) external onlyRole(UPGRADER_ROLE) {
        version = _version;
    }

    function newFunction() external pure returns(uint256) {
        return 1e18;
    }
}