// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {RevertOptions,RevertContext,Revertable} from "@zetachain/protocol-contracts/contracts/Revert.sol";
import {IGatewayEVM} from "@zetachain/protocol-contracts/contracts/evm/interfaces/IGatewayEVM.sol";

import {IPriceData} from "../interfaces/IUniTabOperation.sol";
import {UniTabOperation} from "./UniTabOperation.sol";
import {IUniProtocolVaultBuyTab} from "../interfaces/IUniProtocolVaultBuyTab.sol";

/** 
 * @dev ShiftCTRL Tab Protocol's operation to buy Tab from Protocol Vault after Ctl-Alt-Del operation.
 *      `onRevert` is triggered if transaction reverted in ZetaChain.
 */
contract UniProtocolVaultBuyTab is 
    Initializable, 
    UUPSUpgradeable,
    Revertable,
    UniTabOperation,
    IUniProtocolVaultBuyTab
{

    mapping(address => bool) public authorizedDestinations;

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

    function setAuthorizedDestinations(address[] calldata addrs, bool[] calldata isAuthorized) external onlyRole(DEPLOYER_ROLE) {
        if (addrs.length != isAuthorized.length) revert InvalidLength();
        for (uint256 i = 0; i < addrs.length; i++) {
            if (addrs[i] == address(0))
                revert InvalidAddress();
            authorizedDestinations[addrs[i]] = isAuthorized[i];
            emit AuthorizedDestination(addrs[i], isAuthorized[i]);
        }
    }

    /**
     * @notice Spend supported tokens or native gas to buy Tabs from Protocol Vault.
     * @dev Spend `_sendToken` or native gas to buy tabs from Protocol Vault.
     * @param _destination Deliver Tabs to target chain. When zero, set destination as source chain.
     * @param _receiver Deliver Tabs to this address on destination chain.
     * @param _sendToken Spending ERC20 token in source chain. Indicated spending native gas `msg.value` when zero.
     * @param _sendAmount Spending token amount. Indicated spending native gas `msg.value` when zero.
     * @param _receiveGasAmt Optional. Allow zero value. Specify value to fund the receiving address with native gas amount.
     * @param _receiveTabKey Receiving Tab Token.
     * @param _btcOutMin Minimum swapped BTC amount (amountOutMin in uniswap v2)
     */
    function buyTab(
        address _destination,
        address _receiver,
        address _sendToken, 
        uint256 _sendAmount, 
        uint256 _receiveGasAmt,
        bytes32 _receiveTabKey,
        uint256 _btcOutMin
    ) external payable nonReentrant whenNotPaused {
        if (_destination == address(0))
            _destination = zrc20GasToken;

        if (!authorizedDestinations[_destination])
            revert InvalidDestination();

        if (_receiver == address(0))
            revert InvalidAddress();

        if ((_sendToken == address(0) && _sendAmount > 0) || 
            (_sendToken != address(0) && _sendAmount == 0)) {
            revert InvalidSendTokenOrAmount();
        }
        
        // Deposit either ERC-20 token or native ETH
        if (_sendToken == address(0) && _sendAmount == 0 && msg.value == 0)
            revert ZeroReserve();

        if (_receiveTabKey == bytes32(0))
            revert ZeroTabKey();

        bytes memory message = abi.encode(
            _destination,
            _receiver,
            _sendToken,
            _sendAmount,
            _receiveGasAmt,
            _receiveTabKey,
            _btcOutMin
        );

        if (_sendToken == address(0)) { // Buy Tab from native gas 
            IGatewayEVM(gateway).depositAndCall{value: msg.value}(
                universal,          // calling address
                message,            // payload
                RevertOptions(
                    address(this),  // revertAddress
                    true,           // callOnRevert
                    address(0),     // abortAddress
                    abi.encode(msg.sender, _sendAmount, msg.value), // revertMessage
                    revertGasLimit          // onRevertGasLimit
                )
            );
        } else { // Buy Tab from ERC20 token (e.g. cbBTC, WBTC, USDC, and USDT)
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
                    abi.encode(msg.sender, _sendAmount, msg.value), // revertMessage
                    revertGasLimit          // onRevertGasLimit
                )
            );
        }

        emit BuyTab(
            msg.sender,
            _receiver,
            _destination,
            _sendToken,
            _sendAmount,
            msg.value,
            _receiveGasAmt,
            _receiveTabKey
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