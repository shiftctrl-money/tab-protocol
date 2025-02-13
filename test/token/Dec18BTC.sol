// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {CBBTC} from "../../contracts/token/CBBTC.sol";

contract Dec18BTC is CBBTC {
    constructor(address _initialOwner) CBBTC(_initialOwner) {}

    // Set value > 18 purposely to hit validation check.
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}