// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ERC-20 implementation for all Tabs contracts.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract TabERC20 is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    ERC20PermitUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin, 
        address minter, 
        string calldata _name, 
        string calldata _symbol
    ) 
        initializer 
        public 
    {
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        __AccessControlDefaultAdminRules_init(1 days, defaultAdmin);
        __ERC20Permit_init(_name);
        
        _grantRole(MINTER_ROLE, minter);
    }

    /// @dev For example, when Tab symbol is sUSD, the function returns 0x555344.
    function tabCode() public view returns (bytes3) {
        bytes memory e = abi.encodePacked(symbol());
        bytes memory r = new bytes(3);
        r[0] = e[1]; // ignored first character(index 0) 's'
        r[1] = e[2];
        r[2] = e[3];
        return bytes3(r);
    }

    /// @dev Apply keccak256 on tab code(bytes3) as tab key.
    /// For example, 0x555344 (USD) returns:
    /// 0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e
    function tabKey() public view returns (bytes32) {
        return keccak256(abi.encodePacked(tabCode()));
    }

    function mint(address to, uint256 amount) public virtual onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable)
    {
        super._update(from, to, value);
    }

}
