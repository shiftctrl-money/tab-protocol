// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";
import "./shared/interfaces/IVaultManager.sol";
import "./shared/interfaces/ITabERC20.sol";
import "./shared/interfaces/IReserveRegistry.sol";
import "./shared/interfaces/IConfig.sol";

/**
 * @title  Utility contract to retrieve vault information.
 * @notice Refer https://www.shiftctrl.money for details. 
 */
contract VaultUtils is Ownable {
    address vaultManager;

    IReserveRegistry reserveRegistry;
    IConfig config;

    constructor(address _vaultManager, address _reserveRegistry, address _config) {
        vaultManager = _vaultManager;
        reserveRegistry = IReserveRegistry(_reserveRegistry);
        config = IConfig(_config);
    }

    function setContractAddress(
        address _vaultManager, 
        address _reserveRegistry, 
        address _config
    ) external onlyOwner {
        vaultManager = _vaultManager;
        reserveRegistry = IReserveRegistry(_reserveRegistry);
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
            bytes32 reserveKey,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            uint256 reserveValue,
            uint256 minReserveValue
        )
    {
        require(_price > 0, "INVALID_TAB_PRICE");
        IVaultManager.Vault memory v = IVaultManager(vaultManager).vaults(_vaultOwner, _vaultId);
        
        tab = ITabERC20(v.tab).tabCode();
        reserveKey = reserveRegistry.reserveKey(v.reserveAddr);
        (, uint256 minReserveRatio,) = config.reserveParams(reserveKey);
        price = _price;    
        reserveAmt = v.reserveAmt;
        osTab = v.tabAmt + v.osTabAmt;
        reserveValue = FixedPointMathLib.mulWad(_price, v.reserveAmt);
        minReserveValue = FixedPointMathLib.mulDiv(osTab, minReserveRatio, 100);
    }

}