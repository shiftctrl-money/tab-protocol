// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ReserveRegistry is AccessControlDefaultAdminRules {

    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    mapping(bytes32 => address) public reserveAddr; // keccak256(unique_identifier) : ERC-20 contract
    mapping(address => bytes32) public reserveKey;
    mapping(bytes32 => address) public reserveSafeAddr; // contract to store/lock reserve
    mapping(address => address) public reserveAddrSafe; // contract address: safe address
    mapping(address => uint256) public reserveDecimals; // store ERC20.decimals()
    mapping(bytes32 => bool) public enabledReserve; // when false, the reserve is no longer accepted to create vault

    event AddedReserve(bytes32 key, address _addr, address _safe);
    event RemovedReserve(bytes32 key);

    /**
     * @param _admin governance
     * @param _admin2 emergency governance
     * @param _governanceAction governance action
     * @param _deployer deployment
     */
    constructor(
        address _admin,
        address _admin2,
        address _governanceAction,
        address _deployer
    )
        AccessControlDefaultAdminRules(1 days, _admin)
    {
        _grantRole(MAINTAINER_ROLE, _admin);
        _grantRole(MAINTAINER_ROLE, _admin2);
        _grantRole(MAINTAINER_ROLE, _governanceAction);
        _grantRole(MAINTAINER_ROLE, _deployer);
    }

    function addReserve(bytes32 key, address _token, address _safe) external onlyRole(MAINTAINER_ROLE) {
        try IERC20(_token).totalSupply() returns (uint256) {
            reserveAddr[key] = _token;
            reserveKey[_token] = key;
            reserveSafeAddr[key] = _safe;
            reserveAddrSafe[_token] = _safe;
            reserveDecimals[_token] = IERC20Metadata(_token).decimals();
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

    function getReserveByKey(bytes32 _key, uint256 _amt) external view returns(address, address, uint256, uint256, uint256) {
        require(enabledReserve[_key], "DISABLED_RESERVE");
        (uint256 valueInOriDecimal, uint256 valueInDec18) = getOriReserveAmt(reserveAddr[_key], _amt);
        return (
            reserveAddr[_key],
            reserveSafeAddr[_key],
            reserveDecimals[reserveAddr[_key]],
            valueInOriDecimal,
            valueInDec18
        );
    }

    function getReserveByAddr(address _reserveContractAddr, uint256 _amt) external view returns(bytes32, address, uint256, uint256, uint256) {
        require(enabledReserve[reserveKey[_reserveContractAddr]], "DISABLED_RESERVE");
        (uint256 valueInOriDecimal, uint256 valueInDec18) = getOriReserveAmt(_reserveContractAddr, _amt);
        return (
            reserveKey[_reserveContractAddr],
            reserveAddrSafe[_reserveContractAddr],
            reserveDecimals[_reserveContractAddr],
            valueInOriDecimal,
            valueInDec18
        );
    }

    /// @dev Get reserve amount(quantity) in the reserve token's decimal value
    function getOriReserveAmt(address _reserveContractAddr, uint256 _amt) public view returns(uint256 valueInOriDecimal, uint256 valueInDec18) {
        require(enabledReserve[reserveKey[_reserveContractAddr]], "DISABLED_RESERVE");
        valueInOriDecimal = _amt;
        valueInDec18 = _amt;
        if (_amt > 0 && reserveDecimals[_reserveContractAddr] < 18) {
            valueInOriDecimal = _amt / ((18 - reserveDecimals[_reserveContractAddr]) ** 10);
            valueInDec18 = valueInOriDecimal * ((18 - reserveDecimals[_reserveContractAddr]) ** 10);
        }
    }
}
