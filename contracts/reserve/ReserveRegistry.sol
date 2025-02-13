// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRules} 
    from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IReserveRegistry} from "../interfaces/IReserveRegistry.sol";
import {IReserveSafe} from "../interfaces/IReserveSafe.sol";

/**
 * @title Manage reserve contract used by protocol.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract ReserveRegistry is IReserveRegistry, AccessControlDefaultAdminRules {
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    // ERC20 reserve contract address: safe address
    mapping(address => address) public reserveAddrSafe; 
    
    // when false, the reserve is no longer accepted
    mapping(address => bool) public enabledReserve; 

    // Store default reserve safe address
    address public reserveSafe;

    /**
     * @param _admin Governance controller.
     * @param _admin2 Emergency governance controller.
     * @param _governanceAction Governance action contract.
     * @param _deployer Deployer EOA.
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

    /**
     * @dev Set once during depoyment for default `ReserveSafe` contract.
     * @param _reserveSafe Reserve safe contract address.
     */
    function updateReserveSafe(address _reserveSafe) external onlyRole(MAINTAINER_ROLE) {
        if (_reserveSafe == address(0))
            revert ZeroAddress();
        if (_reserveSafe.code.length == 0)
            revert InvalidReserveSafe();
        emit UpdatedReserveSafe(reserveSafe, _reserveSafe);
        reserveSafe = _reserveSafe;
    }

    /**
     * @dev Authorized by governance to accept a new reserve token.
     * @param _token ERC20 contract address of the new reserve token.
     * @param _safe Pass in same `ReserveSafe` address by default. 
     * Deploy more `ReserveSafe`contract if certain reserve type needs to
     * be stored in different contract.
     */
    function addReserve(address _token, address _safe) external onlyRole(MAINTAINER_ROLE) {
        if (_token == address(0) || _safe == address(0))
            revert ZeroAddress();
        if (_safe.code.length == 0)
            revert InvalidReserveSafe();
        if (reserveAddrSafe[_token] != address(0))
            revert ExistedReserveToken();
        try IERC20(_token).totalSupply() returns (uint256) {
            uint256 decimals = IERC20Metadata(_token).decimals();
            if (decimals > 18)
                revert InvalidDecimals(decimals);
            IReserveSafe(_safe).setReserveDecimal(_token, decimals);
            reserveAddrSafe[_token] = _safe;
            enabledReserve[_token] = true;            
            emit AddedReserve(_token, _safe, decimals);
        } catch {
            revert InvalidReserveToken();
        }
    }

    /**
     * @dev Protocol stops accepting specified reserve token as reserve.
     * @param _token ERC20 Reserve token contract to be disabled.
     */
    function removeReserve(address _token) external onlyRole(MAINTAINER_ROLE) {
        if (reserveAddrSafe[_token] == address(0))
            revert InvalidReserveToken();
        if (enabledReserve[_token] == false)
            revert InvalidReserveToken();
        enabledReserve[_token] = false;
        emit RemovedReserve(_token);
    }

    /**
     * @dev Check if specified reserve contract is currently accepted by protocol as reserve.
     * @param _reserveAddr ERC20 Reserve token contract.
     * @return `ReserveSafe` address associated with the active reserve type.
     */
    function isEnabledReserve(address _reserveAddr) external view returns (address) {
        if (!enabledReserve[_reserveAddr])
            return address(0); 
        return reserveAddrSafe[_reserveAddr];
    }
}
