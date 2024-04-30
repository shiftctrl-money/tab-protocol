// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract CTRL is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ERC20CappedUpgradeable,
    UUPSUpgradeable
{

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _deployer) public initializer {
        __ERC20_init("shiftCTRL", "CTRL");
        __ERC20Burnable_init();
        __AccessControlDefaultAdminRules_init(1 days, _deployer);
        __ERC20Permit_init("shiftCTRL");
        __ERC20Votes_init();
        __ERC20Capped_init(10 ** 9 * 10 ** 18); // value 1000000000000000000000000000
        // CAP = 1 billion = 1,000,000,000
        __UUPSUpgradeable_init();

        _grantRole(UPGRADER_ROLE, _deployer);

        _grantRole(MINTER_ROLE, _deployer);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(
        address to,
        uint256 amount
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable, ERC20CappedUpgradeable)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._burn(account, amount);
    }

}
