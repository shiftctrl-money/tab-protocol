// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControlDefaultAdminRules } from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IERC20Burn } from "./interfaces/IERC20Burn.sol";
import { ITabProxy } from "./interfaces/ITabProxy.sol";
import { ITabMinter } from "./interfaces/ITabMinter.sol";

/**
 * @notice Main entrance contract to perform mint and burn tab operations in all supported chains.
 */
contract TabGateway is AccessControlDefaultAdminRules {
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    address public proxy;
    address public tabMinter;

    event UpdatedProxy(address _old, address _new);
    event UpdatedTabMinter(address _old, address _new);
    
    event MintedTab(address indexed mintTo, bytes3 tabCode, address tabAddress, uint256 value);
    event BurntTab(address indexed account, bytes3 tabCode, address tabAddress, uint256 value);

    error ZeroAddress();
    error ZeroValue();
    error InvalidTabCode();

    constructor(address _admin) AccessControlDefaultAdminRules(1 days, _admin) {
        _grantRole(MAINTAINER_ROLE, _admin);
    }

    function updateProxy(address _proxy) external onlyRole(MAINTAINER_ROLE) {
        if (_proxy == address(0))
            revert ZeroAddress();
        emit UpdatedProxy(proxy, _proxy);
        proxy = _proxy;
    }

    function updateTabMinter(address _tabMinter) external onlyRole(MAINTAINER_ROLE) {
        if (_tabMinter == address(0))
            revert ZeroAddress();
        emit UpdatedTabMinter(tabMinter, _tabMinter);
        tabMinter = _tabMinter;
    }

    function mint(
        bytes3 tabCode, 
        string calldata name, 
        string calldata symbol, 
        address mintTo, 
        uint256 mintAmount
    ) external returns(address tabAddress) {
        tabAddress = ITabProxy(proxy).mint(
            tabMinter,
            msg.sender,
            tabCode,
            name,
            symbol,
            mintTo,
            mintAmount
        );
        emit MintedTab(mintTo, tabCode, tabAddress, mintAmount);
    }

    /**
     * @dev Expect TabGateway to have sufficient allowance to burn specified tab amount.
     * @param tabCode Any supported 3-bytes tab code. E.g. USD, JPY, EUR, or AUD.
     * @param account Tab holder account address.
     * @param value Burn amount.
     */
    function burn(bytes3 tabCode, address account, uint256 value) external {
        if (account == address(0))
            revert ZeroAddress();
        if (value == 0)
            revert ZeroValue();
        address tabAddress = ITabMinter(tabMinter).tabs(tabCode);
        if (tabAddress == address(0))
            revert InvalidTabCode();
        IERC20Burn(tabAddress).burnFrom(account, value);
        emit BurntTab(account, tabCode, tabAddress, value);
    }

}