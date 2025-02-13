// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TabERC20} from "../../contracts/token/TabERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract TabERC20_newImpl is TabERC20, PausableUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor() TabERC20() {}

    // Assumed implementing new function
    function symbolAndName() public view returns (string memory) {
        return string(abi.encodePacked(symbol(), ": ", name()));
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Assumed implementing new feature: pausable
    function mint(address to, uint256 amount) public override whenNotPaused onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}