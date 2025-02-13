// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/** 
 * @dev Simulate CBBTC deployed on 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
 * This is used on local or testnet.
 */
contract CBBTC is ERC20, ERC20Burnable, Ownable {
    constructor(address initialOwner)
        ERC20("TestCBBTC", "CBBTC")
        Ownable(initialOwner)
    {
        _mint(msg.sender, 100 * (10 ** decimals()));
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function decimals() public pure override virtual returns (uint8) {
        return 8;
    }
}