// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {ITabERC20} from "../interfaces/ITabERC20.sol";
import {IConfig} from "../interfaces/IConfig.sol";

/**
 * @title  Utility contract to retrieve vault information.
 * @notice Refer https://www.shiftctrl.money for details. 
 */
contract VaultUtils is Ownable {
    address public vaultManager;
    IConfig config;

    error ZeroValue();

    constructor(
        address _admin, 
        address _vaultManager, 
        address _config
    ) 
        Ownable(_admin) 
    {
        vaultManager = _vaultManager;
        config = IConfig(_config);
    }

    function setContractAddress(
        address _vaultManager, 
        address _config
    ) external onlyOwner {
        vaultManager = _vaultManager;
        config = IConfig(_config);
    }

    function getVaultDetails(
        address _vaultOwner,
        uint256 _vaultId,
        uint256 _price
    )
        external
        view
        returns (
            bytes3 tab,
            address reserveAddr,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            uint256 reserveValue,
            uint256 minReserveValue
        )
    {
        if (_price == 0)
            revert ZeroValue();
        IVaultManager.Vault memory v = IVaultManager(vaultManager).getVaults(_vaultOwner, _vaultId);
        
        tab = ITabERC20(v.tab).tabCode();
        reserveAddr = v.reserveAddr;
        IConfig.TabParams memory tabParams = config.getTabParams(tab);
        price = _price;    
        reserveAmt = v.reserveAmt;
        osTab = v.tabAmt + v.osTabAmt;
        reserveValue = Math.mulDiv(_price, v.reserveAmt, 1e18);
        minReserveValue = Math.mulDiv(osTab, tabParams.minReserveRatio, 100);
    }

}