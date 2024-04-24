// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ReserveRegistry is AccessControlDefaultAdminRules {

    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    mapping(bytes32 => address) public reserveAddr; // keccak256(unique_identifier) : ERC-20 contract
    mapping(address => bytes32) public reserveKey;
    mapping(bytes32 => address) public reserveSafeAddr; // contract to store/lock reserve
    mapping(address => address) public reserveAddrSafe; // contract address: safe address
    mapping(bytes32 => bool) public enabledReserve; // when false, the reserve is no longer accepted to create vault

    event AddedReserve(bytes32 key, address _addr, address _safe);
    event RemovedReserve(bytes32 key);

    /**
     * @param _admin governance
     * @param _admin2 governance action
     * @param _deployer deployment
     */
    constructor(address _admin, address _admin2, address _deployer) AccessControlDefaultAdminRules(1 days, _admin) {
        _grantRole(MAINTAINER_ROLE, _admin);
        _grantRole(MAINTAINER_ROLE, _admin2);
        _grantRole(MAINTAINER_ROLE, _deployer);
    }

    function addReserve(bytes32 key, address _token, address _safe) external onlyRole(MAINTAINER_ROLE) {
        try IERC20(_token).totalSupply() returns (uint256) {
            reserveAddr[key] = _token;
            reserveKey[_token] = key;
            reserveSafeAddr[key] = _safe;
            reserveAddrSafe[_token] = _safe;
            enabledReserve[key] = true;
            emit AddedReserve(key, _token, _safe);
        } catch {
            revert("INVALID_ADDRESS");
        }
    }

    function removeReserve(bytes32 key) external onlyRole(MAINTAINER_ROLE) {
        enabledReserve[key] = false;
        emit RemovedReserve(key);
    }

    function isEnabledReserve(address _reserveAddr) external view returns (bool) {
        return enabledReserve[reserveKey[_reserveAddr]];
    }

}
