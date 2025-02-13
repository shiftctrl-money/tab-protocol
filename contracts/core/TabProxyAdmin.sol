// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title Proxy admin contract of Tab Protocol's upgradeable contracts.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract TabProxyAdmin is ProxyAdmin {

    constructor(address _admin) ProxyAdmin(_admin) {
        // _transferOwnership(_admin);
    }

}
