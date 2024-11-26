// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControlDefaultAdminRules } from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { ITabProxy } from "./interfaces/ITabProxy.sol";
import { ITabMinter } from "./interfaces/ITabMinter.sol";

/**
 * @notice Proxy to call TabMinter.
 */
contract TabProxy is ITabProxy, AccessControlDefaultAdminRules {
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Called by TabGateway contract.
     * @param _admin Administrator, EOA admin account.
     * @param _gateway TabGateway contract address authorized to call this proxy contract.
     */
    constructor(address _admin, address _gateway) AccessControlDefaultAdminRules(1 days, _admin) {
        _grantRole(GATEWAY_ROLE, _gateway);
    }

    function mint(
        address tabMinter,
        address requester,
        bytes3 tabCode, 
        string calldata name, 
        string calldata symbol, 
        address mintTo, 
        uint256 mintAmount
    ) external onlyRole(GATEWAY_ROLE) returns(address) {
        if (!hasRole(MINTER_ROLE, requester))
            revert UnauthorizedRequester();

        return ITabMinter(tabMinter).createAndMint(
            tabCode,
            name,
            symbol,
            mintTo,
            mintAmount
        );
    }

}