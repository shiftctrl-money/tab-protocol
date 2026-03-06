// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {RevertOptions,RevertContext,Revertable} from "@zetachain/protocol-contracts/contracts/Revert.sol";
import {IGatewayEVM} from "@zetachain/protocol-contracts/contracts/evm/interfaces/IGatewayEVM.sol";

import {UniTabOperation} from "./UniTabOperation.sol";
import {IUniDepositReserve} from "../interfaces/IUniDepositReserve.sol";

/** 
 * @dev ShiftCTRL Tab Protocol's deposit reserve operation on ZetaChain.
 *      `onRevert` is triggered if transaction reverted in ZetaChain.
 */
contract UniDepositReserve is 
    Initializable, 
    UUPSUpgradeable,
    Revertable,
    UniTabOperation,
    IUniDepositReserve
{
    constructor() {
        _disableInitializers();
    }

    /** 
     * @dev Initialization.
     * @param _admin Governance controller address.
     * @param _upgrader Proxy admin contract address.
     * @param _deployer Deployer address.
     * @param _gatewayAddress EVM gateway address.
     * @param _zrc20GasToken ZRC20 gas token address in this chain.
     */
    function initialize(
        address _admin, 
        address _upgrader,
        address _deployer,
        address _gatewayAddress,
        address _zrc20GasToken
    ) 
        public 
        initializer 
    {
        __UUPSUpgradeable_init();
        __UniTabOperation_init(_admin, _upgrader, _deployer, _gatewayAddress, _zrc20GasToken, 1 days);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    /**
     * @notice Deposit reserve into an existing vault.
     * @dev Spend `_sendToken` or native gas as additional reserve to deposit into existing vault.
     * @param _vaultOwner Existing vault owner's address.
     * @param _vaultId Existing vault ID.
     * @param _sendToken Spending ERC20 token in source chain. Indicated spending native gas `msg.value` when zero.
     * @param _sendAmount Spending token amount. Indicated spending native gas `msg.value` when zero.
     * @param _btcOutMin Minimum swapped BTC amount (amountOutMin in uniswap v2)
     */
    function depositReserve(
        address _vaultOwner,
        uint256 _vaultId, 
        address _sendToken,
        uint256 _sendAmount,
        uint256 _btcOutMin
    ) external payable nonReentrant whenNotPaused {
        if ((_sendToken == address(0) && _sendAmount > 0) || 
            (_sendToken != address(0) && _sendAmount == 0)) {
            revert InvalidSendTokenOrAmount();
        }
        
        // Deposit either ERC-20 token or native ETH
        if (_sendToken == address(0) && _sendAmount == 0 && msg.value == 0)
            revert ZeroReserve();

        bytes memory message = abi.encode(
            _vaultOwner,
            _vaultId,
            _sendToken,
            _sendAmount,
            _btcOutMin
        );

        if (msg.value > 0) { // Convert from native gas as vault reserve
            IGatewayEVM(gateway).depositAndCall{value: msg.value}(
                universal,          // calling address
                message,            // payload
                RevertOptions(
                    address(this),  // revertAddress
                    true,           // callOnRevert
                    address(0),     // abortAddress
                    abi.encode(_vaultOwner, _sendAmount, msg.value), // revertMessage
                    revertGasLimit                                   // onRevertGasLimit
                )
            );
        } else { // Convert from ERC20 token (e.g. cbBTC, WBTC, USDC, and USDT) as vault reserve
            SafeERC20.safeTransferFrom(IERC20(_sendToken), msg.sender, address(this), _sendAmount);
            SafeERC20.safeIncreaseAllowance(IERC20(_sendToken), gateway, _sendAmount);
            IGatewayEVM(gateway).depositAndCall(
                universal,          // calling address
                _sendAmount,        // Deposit amount
                _sendToken,         // Deposit token
                message,            // payload
                RevertOptions(
                    address(this),  // revertAddress
                    true,           // callOnRevert
                    address(0),     // abortAddress
                    abi.encode(_vaultOwner, _sendAmount, msg.value), // revertMessage
                    revertGasLimit                                   // onRevertGasLimit
                )
            );
        }

        emit DepositReserve(
            _vaultOwner,
            _vaultId,
            _sendToken,
            _sendAmount,
            msg.value
        );
    }

    /**
     * @notice Failed execution at ZetaChain. Refund tokens to user.
     * @dev Called by the Gateway if a call fails.
     * @param context The revert context containing metadata and revert message.
     */
    function onRevert(
        RevertContext calldata context
    ) external onlyRole(GATEWAY_ROLE) {
        if (context.sender != universal) revert Unauthorized();

        (
            address sender,
            uint256 tokenAmt,
            uint256 gasAmt
        ) = abi.decode(context.revertMessage, (address, uint256, uint256));

        if (context.amount > 0) { // perform refund
            if (context.asset == address(0)) {
                if (address(this).balance >= context.amount) {
                    (bool success, ) = payable(sender).call{value: context.amount}("");
                    if (!success) revert GasRefundFailed();
                }
            } else {
                if (IERC20(context.asset).balanceOf(address(this)) >= context.amount) {
                    SafeERC20.safeTransfer(IERC20(context.asset), sender, context.amount);
                }
            }
        }

        emit TokenOrGasTransferReverted(
            context.asset,  // token
            sender,         // receiver
            tokenAmt,
            gasAmt,
            context.amount  // returnedTokenOrGasAmount
        );
    }

}