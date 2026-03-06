// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {ITabERC20} from "../interfaces/ITabERC20.sol";
import {IConfig} from "../interfaces/IConfig.sol";
import {IZUniTab} from "../interfaces/IZUniTab.sol";
import {IZRC20} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
    function getAmountsIn(uint amountOut, address[] memory path) external view returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
}

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
            uint256 minReserveValue,
            uint256 chainID
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
        chainID = v.chainID;
    }

    /**
     * @notice Get the output amount (quote) for a given input amount swapping from zrc20 to target token.
     * Return the larger value from 2 paths and expect to apply slippage in UI.
     * Refer `SwapHealperLib.getMinOutAmount`.
     * @param router The address of the UniswapV2Router02
     * @param zrc20 The address of the input token
     * @param target The address of the output token
     * @param amountIn The input amount
     */
    function getAmountsOut(
        address router,
        address zrc20,
        address target,
        uint256 amountIn
    ) public view returns (uint256 amountOut) {
        address wzeta = IUniswapV2Router02(router).WETH();
        address[] memory path;
        path = new address[](2);
        path[0] = zrc20;
        path[1] = target;
        
        uint256[] memory amounts1 = IUniswapV2Router02(router).getAmountsOut(amountIn, path);
        if (zrc20 == wzeta || target == wzeta)
            amountOut = amounts1[amounts1.length - 1];
        else {
            path = new address[](3);
            path[0] = zrc20;
            path[1] = wzeta;
            path[2] = target;
            uint256[] memory amounts2 = IUniswapV2Router02(router).getAmountsOut(amountIn, path);

            amountOut = amounts1[amounts1.length - 1] > amounts2[amounts2.length - 1] ? 
                        amounts1[amounts1.length - 1] :
                        amounts2[amounts2.length - 1];
        }
    }

    /**
     * @notice Get the required input amount to receive the specified output (mandatory gas fee + optional additinoal gas amount)
     * @param router The address of the UniswapV2Router02
     * @param zrc20 The address of the input token
     * @param destination The ZRC20 address of the target chain
     * @param receiveGasAmt The additional gas amount to be received at the destination chain
     * @param zUniTab The address of the ZUniTab contract
     */
    function getAmountsIn(
        address router,
        address zrc20,
        address destination,
        uint256 receiveGasAmt,
        address zUniTab
    ) public view returns(uint256 amountIn) {
        address wzeta = IUniswapV2Router02(router).WETH();
        uint256 receiveGasWithFee = receiveGasAmt;
        address gasZRC20;
        uint256 gasFee;
        if (destination != wzeta) {
            (gasZRC20, gasFee) = IZRC20(destination)
                    .withdrawGasFeeWithGasLimit(IZUniTab(zUniTab).gasLimitAmounts(destination));
            receiveGasWithFee = gasFee + receiveGasAmt;
        }

        if (zrc20 == destination)
            return receiveGasWithFee;
        
        address[] memory path;

        path = new address[](2);
        path[0] = zrc20;
        path[1] = destination == wzeta? destination: gasZRC20;
        uint256[] memory amounts1 = IUniswapV2Router02(router).getAmountsIn(receiveGasWithFee, path);

        if (zrc20 != wzeta && gasZRC20 != address(0)) {
            path = new address[](3);
            path[0] = zrc20;
            path[1] = wzeta;
            path[2] = gasZRC20;
            uint256[] memory amounts2 = IUniswapV2Router02(router).getAmountsIn(receiveGasWithFee, path);

            // return smaller amountIn
            amountIn = amounts1[0] > amounts2[0]? amounts2[0]: amounts1[0];
        } else {
            amountIn = amounts1[0];
        }
    }

}