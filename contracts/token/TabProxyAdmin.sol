// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title Manage Tab proxies.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract TabProxyAdmin is ProxyAdmin {
    constructor(address _admin) ProxyAdmin(_admin) {}
}
