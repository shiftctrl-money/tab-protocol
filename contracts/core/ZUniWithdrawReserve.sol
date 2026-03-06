// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ZUniTabOperation} from "./ZUniTabOperation.sol";
import {IZUniWithdrawReserve} from "../interfaces/IZUniWithdrawReserve.sol";
import {IGatewayZEVMToken} from "../interfaces/IZUniTabOperation.sol";
import {IPriceData} from "../interfaces/IUniTabOperation.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";
import {IZRC20} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import {IGatewayZEVM} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IGatewayZEVM.sol";
import {RevertContext, RevertOptions} from "@zetachain/protocol-contracts/contracts/Revert.sol";
import {SwapHelperLib} from "@zetachain/toolkit/contracts/SwapHelperLib.sol";

contract ZUniWithdrawReserve is 
    Initializable, 
    UUPSUpgradeable,
    UniversalContract,
    ZUniTabOperation,
    IZUniWithdrawReserve
{
    bool public constant isUniversal = true;

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

    /**
     * @dev Received withdraw reserve instruction 
     * @param context The message context.
     * @param message The encoded message containing information about the tokens.
     */
    function onCall(
        MessageContext calldata context,
        address /*zrc20*/,
        uint256 /*amount*/,
        bytes calldata message
    ) external override onlyRole(GATEWAY_ROLE) {
        // sender is authorized caller
        if (!authorizedUniCallers[context.senderEVM])
            revert Unauthorized();

        (
            uint256 vaultId,
            uint256 withdrawAmt,
            address destination,
            address receiver,
            address receiveToken,
            uint256 minAmountOut,
            IPriceData.UpdatePriceData memory sigPrice
        ) = abi.decode(message, (uint256, uint256, address, address, address, uint256, IPriceData.UpdatePriceData));

        IVaultManager(vaultManager).withdrawReserve(
            vaultId,
            scaleUp(withdrawAmt),
            address(this),
            sigPrice
        );

        uint256 reserveBal = withdrawAmt;

        if (destination == IGatewayZEVMToken(gateway).zetaToken()) {
            if (receiveToken == BTC_BTC) {
                IZRC20(BTC_BTC).transfer(receiver, reserveBal);
                emit ZWithdrawReserve(
                    sigPrice.updater,
                    receiver,
                    vaultId,
                    context.chainID,
                    withdrawAmt,
                    reserveBal,
                    receiveToken,
                    reserveBal
                );
            } else {
                // swap BTC.BTC to receiveToken
                uint256 receiveAmt = SwapHelperLib.swapExactTokensForTokens(
                    dexRouter,
                    BTC_BTC,       // swap from
                    reserveBal,    // amountIn
                    receiveToken,  // targetZRC20
                    minAmountOut   // minAmountOut
                );
                IZRC20(receiveToken).transfer(receiver, receiveAmt);
                emit ZWithdrawReserve(
                    sigPrice.updater,
                    receiver,
                    vaultId,
                    context.chainID,
                    withdrawAmt,
                    reserveBal,
                    receiveToken,
                    receiveAmt
                );
            }
        } else {
            if (receiveToken == BTC_BTC)
                revert UnsupportedReceiveToken(); // BTC_BTC is only supported on ZetaChain

            uint256 receiveAmt;
            IZRC20(BTC_BTC).approve(dexRouter, reserveBal);

            // Required gas to call destination chain
            (address gasZRC20, uint256 gasFee) = IZRC20(destination).withdrawGasFee();
            if (gasZRC20 == receiveToken) {
                // Convert all BTC to receiveToken
                receiveAmt = SwapHelperLib.swapExactTokensForTokens(
                    dexRouter,
                    BTC_BTC,            // swap from
                    reserveBal,         // swap amount
                    receiveToken,       // swap to
                    minAmountOut        // minAmountOut
                );
                if (receiveAmt < gasFee)
                    revert InsufficientGasFee(receiveAmt, gasFee);

                uint256 transferAmt = receiveAmt - gasFee;
                IZRC20(receiveToken).approve(gateway, receiveAmt);
                IGatewayZEVM(gateway).withdraw(
                    abi.encodePacked(receiver),
                    transferAmt,
                    receiveToken,
                    RevertOptions(
                        address(this),     // revertAddress
                        true,              // callOnRevert
                        address(0),        // abortAddress
                        abi.encode(sigPrice.updater, vaultId, context.chainID, withdrawAmt, receiver, receiveToken, transferAmt), // revertMessage
                        0                  // onRevertGasLimit
                    )
                );
                emit ZWithdrawReserve(
                    sigPrice.updater,
                    receiver,
                    vaultId,
                    context.chainID,
                    withdrawAmt,
                    reserveBal,
                    receiveToken,
                    transferAmt
                );
            } else {
                uint256 deductedReserve = SwapHelperLib.swapTokensForExactTokens(
                    dexRouter,      // router
                    BTC_BTC,        // swap from
                    gasFee,         // amountOut
                    gasZRC20,       // targetZRC20
                    reserveBal      // amountInMax
                );
                reserveBal = reserveBal - deductedReserve;
                if (reserveBal == 0)
                    revert InsufficientReserveAmt();
                IZRC20(gasZRC20).approve(gateway, gasFee); // Prepared required destination gas

                receiveAmt = SwapHelperLib.swapExactTokensForTokens(
                    dexRouter,
                    BTC_BTC,            // swap from
                    reserveBal,         // swap amount
                    receiveToken,       // swap to
                    minAmountOut        // minAmountOut
                );
                IZRC20(receiveToken).approve(gateway, receiveAmt);

                IGatewayZEVM(gateway).withdraw(
                    abi.encodePacked(receiver),
                    receiveAmt,
                    receiveToken,
                    RevertOptions(
                        address(this),     // revertAddress
                        true,              // callOnRevert
                        address(0),        // abortAddress
                        abi.encode(sigPrice.updater, vaultId, context.chainID, withdrawAmt, receiver, receiveToken, receiveAmt), // revertMessage
                        0                  // onRevertGasLimit
                    )
                );
                emit ZWithdrawReserve(
                    sigPrice.updater,
                    receiver,
                    vaultId,
                    context.chainID,
                    withdrawAmt,
                    reserveBal,
                    receiveToken,
                    receiveAmt
                );
            }
        }
    }

    /**
     * @notice Failed to withdraw reserve into destination chain receiver,
     *         send reserve to receiver in ZetaChain instead.
     * @param context Revert context to pass to onRevert.
     */
    function onRevert(RevertContext calldata context) external onlyRole(GATEWAY_ROLE) {
        if (context.sender != address(this)) revert Unauthorized();

        (
            address vaultOwner, 
            uint256 vaultId,
            uint256 chainId,
            uint256 withdrawAmt,
            address receiver, 
            address receiveToken, 
            uint256 receiveAmt
        ) = abi.decode(
            context.revertMessage,
            (address, uint256, uint256, uint256, address, address, uint256)
        );        

        if (context.asset != address(0) && context.amount > 0) {
            if (IZRC20(context.asset).balanceOf(address(this)) >= context.amount) {
                if (!IZRC20(context.asset).transfer(receiver, context.amount)) {
                    revert RevertTransferFailed(
                        receiver,
                        context.asset,
                        context.amount
                    );
                }
            }
        }

        emit RevertedWithdrawReserve(
            vaultOwner,
            vaultId,
            chainId,
            withdrawAmt,
            receiver,
            receiveToken,
            receiveAmt
        );
    }

}