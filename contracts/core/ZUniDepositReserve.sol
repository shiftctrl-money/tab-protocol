// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ZUniTabOperation} from "./ZUniTabOperation.sol";
import {IZUniDepositReserve} from "../interfaces/IZUniDepositReserve.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IGatewayZEVMToken} from "../interfaces/IZUniTabOperation.sol";

import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";
import {IWETH9} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IWZETA.sol";
import {IZRC20} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import {SwapHelperLib} from "@zetachain/toolkit/contracts/SwapHelperLib.sol";

contract ZUniDepositReserve is 
    Initializable, 
    UUPSUpgradeable,
    UniversalContract,
    ZUniTabOperation,
    IZUniDepositReserve
{
    bool public constant isUniversal = true;

    // Bitcoin network Chain ID, used to determine if deposit is originated from bitcoin network.
    // 8332  btc_mainnet
    // 10333 btc_signet_testnet
    // 18334 btc_testnet4
    uint256 public BITCOIN_CHAIN_ID;

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
        address _dexRouterAddress,
        uint256 _bitcoinChainID
    ) 
        public 
        initializer 
    {
        __UUPSUpgradeable_init();
        __ZUniTabOperation_init(_admin, _upgrader, _deployer, _gatewayAddress, _btcbtc, 1 days);
        
        dexRouter = _dexRouterAddress;
        BITCOIN_CHAIN_ID = _bitcoinChainID;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function setBitcoinChainID(uint256 _chainID) external onlyRole(DEPLOYER_ROLE) {
        if (_chainID == 0) 
            revert InvalidChainID();
        emit UpdatedBitcoinChainID(BITCOIN_CHAIN_ID, _chainID);
        BITCOIN_CHAIN_ID = _chainID;
    }

    /**
     * @dev Received deposit reserve instruction 
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
        if (context.chainID == BITCOIN_CHAIN_ID && 
            zrc20 == BTC_BTC &&
            amount > 0
        ) {
            _bitcoinDeposit(amount, message);
        } else {
            _evmDeposit(context, zrc20, amount, message);
        }
    }

    /**
     * @dev Deposit additional reserve into existing vault from ZetaChain with supported tokens.
     * @param zrc20 ERC-20 token address. When zero/blank address, msg.value must have non-zero value.
     * @param amount ERC-20 token amount used to deposit into vault.
     * @param vaultOwner Existing vault owner
     * @param vaultId Vault ID
     */
    function zDepositReserve(
        address zrc20,
        uint256 amount,
        address vaultOwner,
        uint256 vaultId,
        uint256 btcOutMin
    ) 
        external
        payable 
    {
        if (msg.value > 0) {
            if (zrc20 != address(0) || amount > 0)
                revert AmbiguousAsset(zrc20, amount, msg.value);
        } else {
            if (zrc20 == address(0))
                revert RequiredAssetAddress();
            if (amount == 0)
                revert RequiredAssetAmount();
        }
        
        if (msg.value > 0) {
            address WZETA = IGatewayZEVMToken(gateway).zetaToken();
            IWETH9(WZETA).deposit{value: msg.value}();
            _depositHandler(
                WZETA,
                msg.value,
                vaultOwner,
                vaultId,
                btcOutMin
            );
            
        } else {
            SafeERC20.safeTransferFrom(
                IERC20(zrc20),
                msg.sender,
                address(this),
                amount
            );
            _depositHandler(
                zrc20,
                amount,
                vaultOwner,
                vaultId,
                btcOutMin
            );
        }
    }

    function _bitcoinDeposit(
        uint256 amount,
        bytes calldata message
    ) internal {
        // (
        //     address vaultOwner,   // receiver/vault owner                   : 20B
        //     uint256 vaultId       // Vault ID                               : 32B
        // ) = abi.decode(message, (address, uint256));

        address vaultOwner;
        uint256 vaultId;
        assembly {
            // Load first 32 bytes, shift right by 96 bits (12 bytes) to get the 20-byte address
            vaultOwner := shr(96, calldataload(message.offset))
            
            // Load 32 bytes starting at offset 20
            vaultId := calldataload(add(message.offset, 20))
        }

        IVaultManager.Vault memory vault = IVaultManager(vaultManager).getVaults(vaultOwner, vaultId);
        if (vault.reserveAmt == 0) {
            revert InvalidVault(vaultOwner, vaultId);
        }

        IERC20(BTC_BTC).approve(vaultManager, amount);
        IVaultManager(vaultManager).depositReserve(
            vaultOwner,
            vaultId,
            scaleUp(amount)
        );

        emit ZDepositReserve(
            vaultOwner,
            vaultId,
            address(0),
            0,
            amount
        );
    }

    function _evmDeposit(
        MessageContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) internal {
        // sender is authorized caller
        if (!authorizedUniCallers[context.senderEVM])
            revert Unauthorized();

        (
            address vaultOwner,
            uint256 vaultId,
            , // address sendToken,
            , // uint256 sendAmount
            uint256 btcOutMin
        ) = abi.decode(message, (address, uint256, address, uint256, uint256));

        _depositHandler(
            zrc20,
            amount,
            vaultOwner,
            vaultId,
            btcOutMin
        );
    }

    function _depositHandler(
        address zrc20,
        uint256 amount,
        address vaultOwner,
        uint256 vaultId,
        uint256 btcOutMin
    ) 
        internal 
    {
        uint256 btcAmount = amount;
        if (zrc20 != BTC_BTC) {
            IERC20(zrc20).approve(dexRouter, amount);
            // Swap deposit of ETH, WBTC, cbBTC, USDC, USDT into BTC.BTC in ZetaChain
            btcAmount = SwapHelperLib.swapExactTokensForTokens(
                dexRouter,
                zrc20,              // Deposit from source chain
                amount,             // swap amount
                BTC_BTC,            // targetZRC20
                btcOutMin           // minAmountOut
            );
        }

        IERC20(BTC_BTC).approve(vaultManager, btcAmount);
        IVaultManager(vaultManager).depositReserve(
            vaultOwner,
            vaultId,
            scaleUp(btcAmount)
        );
        
        emit ZDepositReserve(
            vaultOwner,
            vaultId,
            zrc20,
            amount,
            btcAmount
        );
    }


}