// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title  Manage Tab proxies.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract TabProxyAdmin is ProxyAdmin {

    constructor(address _admin) {
        _transferOwnership(_admin);
    }

}
