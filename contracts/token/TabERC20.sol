// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TabERC20 is
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

    function initialize(
        string memory _name,
        string memory _symbol,
        address _admin,
        address _vaultManager
    )
        public
        initializer
    {
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __ERC20Permit_init(_name);
        __UUPSUpgradeable_init();

        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(MINTER_ROLE, _vaultManager);
    }

    function tabCode() external view returns (bytes3) {
        bytes memory e = abi.encodePacked(symbol());
        bytes memory r = new bytes(3);
        r[0] = e[1]; // ignored first character(index 0) 's'
        r[1] = e[2];
        r[2] = e[3];
        return bytes3(r);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

}
