// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControlDefaultAdminRules } from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ITabFactory } from "./interfaces/ITabFactory.sol";
import { IERC20Mint } from "./interfaces/IERC20Mint.sol";

contract TabMinter is AccessControlDefaultAdminRules {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    
    uint256 public createdTabCount;
    mapping(bytes3 => address) public tabs;
    bytes3[] public tabList; // list of all activated tab currrencies

    address public tabFactory;
    address public tabProxyAdmin;

    event UpdatedAddress(address oldTabFactory, address newTabFactory, address oldTabProxyAdmin, address newTabProxyAdmin);
    event CreatedTab(address indexed addr, string indexed symbol, string name);
    error ZeroAddress();

    /**
     * @param admin Admin user.
     * @param caller Authorized minter.
     */
    constructor(address admin, address caller) AccessControlDefaultAdminRules(1 days, admin) {
        _grantRole(MAINTAINER_ROLE, admin);
        _grantRole(MINTER_ROLE, caller);
    }

    function updateAddress(address _tabFactory, address _tabProxyAdmin) external onlyRole(MAINTAINER_ROLE) {
        if (_tabFactory == address(0))
            revert ZeroAddress();
        if (_tabProxyAdmin == address(0))
            revert ZeroAddress();
        emit UpdatedAddress(tabFactory, _tabFactory, tabProxyAdmin, _tabProxyAdmin);
        tabFactory = _tabFactory;
        tabProxyAdmin = _tabProxyAdmin;
    }

    /**
     * @dev Create the tab contract if it is not existed. Mint 
     * @param tabCode Tab code in 3 bytes XXX.
     * @param name Tab name, e.g. Sound USD.
     * @param symbol Tab symbol in sXXX.
     * @param mintTo Mint to this address.
     * @param mintAmount Amount to be minted.
     */
    function createAndMint(
        bytes3 tabCode,
        string calldata name,
        string calldata symbol,
        address mintTo,
        uint256 mintAmount
    ) external onlyRole(MINTER_ROLE) returns(address) {
        address tabAddress = tabs[tabCode];
        if (tabAddress == address(0)) { // tab is not created before
            tabAddress = ITabFactory(tabFactory).createTab(
                name,
                symbol,
                defaultAdmin(),
                address(this),
                tabProxyAdmin
            );
            createdTabCount += 1;
            tabs[tabCode] = tabAddress;
            tabList.push(tabCode);
            emit CreatedTab(tabAddress, symbol, name);
        }
        IERC20Mint(tabAddress).mint(mintTo, mintAmount);
        return tabAddress;
    }


}