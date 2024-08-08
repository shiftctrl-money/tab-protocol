// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Simulate WBTC for testing purpose. 
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract WBTC is
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
        // Refer https://etherscan.io/token/0x2260fac5e5542a773aa44fbcfedf7c193bc2c599
        // Create this in testnet for testing purpose only - mint and lock as vault reserve
        __ERC20_init("Token Wrapped BTC", "WBTC");
        __ERC20Burnable_init();
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __ERC20Permit_init("Token Wrapped BTC");
        __UUPSUpgradeable_init();

        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin2);

        _grantRole(MINTER_ROLE, _deployer);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    // @dev Follow actual WBTC decimal value
    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

}
