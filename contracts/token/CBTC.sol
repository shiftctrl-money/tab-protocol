// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ShiftCTRL Protocol's Wrapped BTC contract to replace WBTC.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract CBTC is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable
{

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, address _admin2, address _deployer) public initializer {
        __ERC20_init("shiftCTRL Wrapped BTC", "cBTC");
        __ERC20Burnable_init();
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __ERC20Permit_init("shiftCTRL Wrapped BTC");
        __UUPSUpgradeable_init();

        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin2);

        _grantRole(MINTER_ROLE, _deployer);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

}
