// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ZUniTabOperation} from "./ZUniTabOperation.sol";
import {IZUniProtocolVaultBuyTab} from "../interfaces/IZUniProtocolVaultBuyTab.sol";
import {IGatewayZEVMToken} from "../interfaces/IZUniTabOperation.sol";
import {IProtocolVault} from "../interfaces/IProtocolVault.sol";
import {IZUniTab} from "../interfaces/IZUniTab.sol";

import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";
import {IWETH9} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IWZETA.sol";
import {IZRC20} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import {SwapHelperLib} from "@zetachain/toolkit/contracts/SwapHelperLib.sol";

contract ZUniProtocolVaultBuyTab is 
    Initializable, 
    UUPSUpgradeable,
    UniversalContract,
    ZUniTabOperation,
    IZUniProtocolVaultBuyTab
{
    bool public constant isUniversal = true;

    // Protocol Vault address to buy/sell Tab
    address public protocolVault;

    constructor() {
        _disableInitializers();
    }

    /** 
     * @dev Initialization.
     * @param _admin Governance controller address.
     * @param _upgrader Proxy admin contract address.
     * @param _deployer Deployer address.
     * @param _gatewayAddress EVM gateway address.
     * @param _dexRouterAddress Uniswap v2 router address for gas token swaps.
     */
    function initialize(
        address _admin, 
        address _upgrader,
        address _deployer,
        address _gatewayAddress,
        address _btcbtc,
        address _dexRouterAddress
    ) 
        public 
        initializer 
    {
        __UUPSUpgradeable_init();
        __ZUniTabOperation_init(_admin, _upgrader, _deployer, _gatewayAddress, _btcbtc, 1 days);
        
        dexRouter = _dexRouterAddress;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function updateProtocolVault(address _protocolVault) external onlyRole(DEPLOYER_ROLE) {
        if (_protocolVault == address(0))
            revert InvalidAddress();
        emit UpdatedProtocolVault(protocolVault, _protocolVault);
        protocolVault = _protocolVault;
    }

    /**
     * @dev Received Protocol Vault's buy Tab request from authorized caller.
     * @param context The message context.
     * @param zrc20 Incoming ZRC-20 token address (e.g. ETH.BASE, ETH.ETH, and etc).
     * @param amount Available amount of ZRC-20 token.
     * @param message The encoded message containing information about the tokens.
     */
    function onCall(
        MessageContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external override onlyRole(GATEWAY_ROLE) {
        // sender is authorized caller
        if (!authorizedUniCallers[context.senderEVM])
            revert Unauthorized();

        (
            address destination,
            address receiver,
            ,// address sendToken,
            ,// uint256 sendAmount,
            uint256 receiveGasAmt,
            bytes32 receiveTabKey,
            uint256 btcOutMin
        ) = abi.decode(message, (address, address, address, uint256, uint256, bytes32, uint256));

        // Swap incoming ZRC20 token into BTC.BTC
        (
            address gasZRC20, 
            uint256 receiveGasWithFee, 
            uint256 reserveAmount, 
            uint256 btcAmount
        ) = _swapZRC20ToBTC(
            zrc20,
            amount,
            destination,
            receiveGasAmt,
            receiver,
            btcOutMin
        );
        
        // Spend BTC.BTC to buy Tab from Protocol Vault
        address tabAddress = IZUniTab(zUniTab).tabAddresses(
            IGatewayZEVMToken(gateway).zetaToken(), receiveTabKey);
        IERC20(BTC_BTC).approve(protocolVault, btcAmount);
        
        uint256 receiveTabAmount;

        if (gasZRC20 == address(0)) { // Deliver Tab into ZetaChain
            receiveTabAmount = IProtocolVault(protocolVault).buyTab(
                BTC_BTC,
                scaleUp(btcAmount),
                tabAddress,
                receiver
            );
        } else {         
            receiveTabAmount = IProtocolVault(protocolVault).buyTab(
                BTC_BTC,
                scaleUp(btcAmount),
                tabAddress,
                address(this)
            );   
            // Transfer Tab to destination chain
            IERC20(tabAddress).approve(zUniTab, receiveTabAmount); // approved transfer Tab
            IZUniTab(zUniTab).transferCrossChain(
                tabAddress,
                destination,
                gasZRC20,
                receiveGasWithFee,
                receiver,
                receiveTabAmount
            );
        }

        emit ZBuyTab(
            receiver,
            context.chainID,
            reserveAmount,
            btcAmount,
            receiveGasWithFee,
            receiveTabKey,
            receiveTabAmount
        );
    }

    function _swapZRC20ToBTC(
        address zrc20,
        uint256 amount,
        address destination,
        uint256 receiveGasAmt,
        address receiver,
        uint256 btcOutMin
    ) 
        internal 
        returns(
            address gasZRC20, 
            uint256 receiveGasWithFee, 
            uint256 reserveAmount, 
            uint256 btcAmount
        )
    {
        if (destination == IGatewayZEVMToken(gateway).zetaToken()) {
            reserveAmount = amount;
            IZRC20(zrc20).approve(dexRouter, amount);

            // Deduct user-assigned gas amount to deliver from incoming ETH or Token 
            if (receiveGasAmt > 0) {
                receiveGasWithFee = receiveGasAmt;
                uint256 deductedReserve = SwapHelperLib.swapTokensForExactTokens(
                    dexRouter,      // router
                    zrc20,          // swap from
                    receiveGasAmt,  // amountOut
                    destination,    // targetZRC20
                    amount          // amountInMax
                );
                reserveAmount = amount - deductedReserve;

                IWETH9(destination).withdraw(receiveGasAmt); // WZETA to ZETA
                (bool success, ) = payable(receiver).call{value: receiveGasAmt}("");
                if (!success) revert GasTransferFailed();
            }

            // Swap deposit of ETH, WBTC, cbBTC, USDC, USDT into BTC.BTC in ZetaChain
            btcAmount = SwapHelperLib.swapExactTokensForTokens(
                dexRouter,
                zrc20,              // Deposit from source chain
                reserveAmount,      // swap amount
                BTC_BTC,            // targetZRC20
                btcOutMin           // minAmountOut
            );
        } else {
            // Required gas fee to deliver Tab on destination chain
            (address gZRC20, uint256 gasFee) = IZRC20(destination).withdrawGasFeeWithGasLimit(IZUniTab(zUniTab).gasLimitAmounts(destination));
            gasZRC20 = gZRC20;
            receiveGasWithFee = gasFee + receiveGasAmt;
            
            IZRC20(zrc20).approve(dexRouter, amount);
            // Deduct required gas fee and `receiveGasAmt` from incoming ZRC20 ETH or Token
            if (gasZRC20 == zrc20) { 
                reserveAmount = amount - receiveGasWithFee;
            } else {
                uint256 deductedReserve = SwapHelperLib.swapTokensForExactTokens(
                    dexRouter,      // router
                    zrc20,          // swap from
                    receiveGasWithFee, // amountOut
                    gasZRC20,       // targetZRC20
                    amount          // amountInMax
                );
                reserveAmount = amount - deductedReserve;
            }
            IERC20(gasZRC20).approve(zUniTab, receiveGasWithFee); // approved spending gas

            // Swap deposit of ETH, WBTC, cbBTC, USDC, USDT into BTC.BTC in ZetaChain
            btcAmount = SwapHelperLib.swapExactTokensForTokens(
                dexRouter,
                zrc20,              // Deposit from source chain
                reserveAmount,      // swap amount
                BTC_BTC,            // targetZRC20
                btcOutMin           // minAmountOut
            );
        }
    }

}