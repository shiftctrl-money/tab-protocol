// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ZUniTabOperation} from "./ZUniTabOperation.sol";
import {IZUniCreateVault} from "../interfaces/IZUniCreateVault.sol";
import {IGatewayZEVMToken} from "../interfaces/IZUniTabOperation.sol";
import {IPriceData} from "../interfaces/IUniTabOperation.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IZUniTab} from "../interfaces/IZUniTab.sol";

import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";
import {IWETH9} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IWZETA.sol";
import {IZRC20} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import {SwapHelperLib} from "@zetachain/toolkit/contracts/SwapHelperLib.sol";

contract ZUniCreateVault is 
    Initializable, 
    UUPSUpgradeable,
    UniversalContract,
    ZUniTabOperation,
    IZUniCreateVault
{
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bool public constant isUniversal = true;

    // Bitcoin network Chain ID, used to determine if deposit is originated from bitcoin network.
    // 8332  btc_mainnet
    // 10333 btc_signet_testnet
    // 18334 btc_testnet4
    uint256 public BITCOIN_CHAIN_ID;

    mapping(uint32 => address) public chainIdToZrc20; // destination chain ID => zrc20 gas token address

    // keccak256 of (context.sender) : keccak256 of (owner, tabKey, gasAmt, block.timestamp) : NativeCreateVaultRequest 
    mapping(bytes32 => mapping(bytes32 => NativeCreateVaultRequest)) public createVaultRequests;

    constructor() {
        _disableInitializers();
    }

    /** 
     * @dev Initialization.
     * @param _admin Governance controller address.
     * @param _upgrader Proxy admin contract address.
     * @param _deployer Deployer address.
     * @param _gatewayAddress EVM gateway address.
     * @param _btcbtc BTC.BTC zrc20 address in ZetaChain.
     * @param _executor Off-chain module address with EXECUTOR_ROLE permission to process create vault request.
     * @param _dexRouterAddress Uniswap v2 router address for gas token swaps.
     * @param _bitcoinChainID Chain ID of Bitcoin network.
     */
    function initialize(
        address _admin, 
        address _upgrader,
        address _deployer,
        address _gatewayAddress,
        address _btcbtc,
        address _executor,
        address _dexRouterAddress,
        uint256 _bitcoinChainID
    ) 
        public 
        initializer 
    {
        __UUPSUpgradeable_init();
        __ZUniTabOperation_init(_admin, _upgrader, _deployer, _gatewayAddress, _btcbtc, 1 days);
        
        _grantRole(EXECUTOR_ROLE, _executor);
        _setRoleAdmin(EXECUTOR_ROLE, DEPLOYER_ROLE);

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

    function setChainIdToZrc20(uint32[] calldata chainId, address[] calldata zrc20) external onlyRole(DEPLOYER_ROLE) {
        if (chainId.length != zrc20.length)
            revert InvalidLength();
        for (uint256 i = 0; i < chainId.length; i++) {
            if (zrc20[i] == address(0))
                revert InvalidAddress();
            emit UpdatedChainIdToZrc20(chainId[i], chainIdToZrc20[chainId[i]], zrc20[i]);
            chainIdToZrc20[chainId[i]] = zrc20[i];
        }
    }

    /**
     * @dev Received create vault instruction from supported chains.
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
            _bitcoinDeposit(context, zrc20, amount, message);
        } else {
            _evmDeposit(context, zrc20, amount, message);
        }
    }

    /**
     * @dev Handle bitcoin deposit to create vault and mint Tab.
     */
    function _bitcoinDeposit(
        MessageContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) internal {
        // (
        //     address vaultOwner,   // receiver/vault owner                   : 20B
        //     uint32 chainId,       // destination chain ID                   :  4B
        //     bytes32 tabKey,       // Tab currency to be minted              : 32B
        //     uint16 reserveRatio   // Desired reserve ratio when minting Tab :  2B
        // ) = abi.decode(message, (address, uint32, bytes32, uint16));

        address vaultOwner;
        uint32 chainId;
        bytes32 tabKey;
        uint16 reserveRatio;
        assembly {
            // Read address (20 bytes)
            vaultOwner := shr(96, calldataload(message.offset))
            
            // Read uint32 (4 bytes) starting at offset 20
            chainId := shr(224, calldataload(add(message.offset, 20)))
            
            // Read bytes32 (32 bytes) starting at offset 24
            tabKey := calldataload(add(message.offset, 24))
            
            // Read uint16 (2 bytes) starting at offset 56
            reserveRatio := shr(240, calldataload(add(message.offset, 56)))
        }

        if (vaultOwner == address(0))
            revert InvalidReceiver();
        
        address destination = chainIdToZrc20[chainId];
        if (tabKey == bytes32(0) || reserveRatio < 180 || destination == address(0)) {
            emit InvalidCreateVaultRequest(vaultOwner, chainId, tabKey, reserveRatio, amount);
            IZRC20(zrc20).transfer(vaultOwner, amount); // refund full amount
            return;
        }

        bytes32 senderKey = keccak256(context.sender);
        bytes32 requestKey = keccak256(abi.encode(vaultOwner, destination, tabKey, reserveRatio, block.timestamp));

        createVaultRequests[senderKey][requestKey] = 
            NativeCreateVaultRequest(
                context.sender,         // Bitcoin sender
                chainId,                // same with destination chainId 
                vaultOwner,             // Vault owner / receiver
                destination,            // Destination gas zrc20 address
                reserveRatio,           // max 65,535
                tabKey,                 // Tab currency
                amount,                 // BTC reserve amount BTC.BTC received from bitcoin network
                block.timestamp,        // block.timestamp when request is recorded
                0                       // block.timestamp when vault is created successfully
            );

        // Off-chain module with EXECUTOR_ROLE permission will monitor this event and submit `processCreateVaultRequest`
        emit NativeCreateVaultReq(
            senderKey,
            requestKey,
            vaultOwner, // sender & receiver
            destination,
            tabKey,
            reserveRatio,
            amount
        );
    }

    /**
     * @dev Process create vault request originated from bitcoin network.
     * By default, it tries to use supplied ETH or contract balance to pay for gas fee on destination chain.
     * In the case of insufficient balance, gas fee is deducted from deposit BTC amount.
     * If the process failed, BTC amount is refunded to designated receiver (vaultOwner) in ZetaChain.
     * @param senderKey keccak256 of (bitcoin sender)
     * @param requestKey hash key to identify bitcoin deposit of the sender
     * @param sigPrice Signed price data. Expect sigPrice.chainID assigned with same 
     * user specified chainID value.
     */
    function processCreateVaultRequest(
        bytes32 senderKey,
        bytes32 requestKey,
        IPriceData.UpdatePriceData calldata sigPrice
    ) 
        external  
        payable 
        onlyRole(EXECUTOR_ROLE)
    {
        NativeCreateVaultRequest storage req = createVaultRequests[senderKey][requestKey];
        if (req.receiver == address(0) || req.depositAmt == 0 || req.createdTimestamp > 0)
            revert InvalidRequest();

        if (sigPrice.updater != req.receiver)
            revert InvalidSigUpdater(sigPrice.updater, req.receiver);
        if (sigPrice.chainID != req.chainID)
            revert InvalidSigChainID(sigPrice.chainID, req.chainID);

        uint256 depositAmt = req.depositAmt;
        address gasZRC20;
        uint256 gasFee;
        if (msg.value == 0) { // Pay destination chain gas from depositAmt
            (gasZRC20, gasFee) = 
                IZRC20(req.destination).withdrawGasFeeWithGasLimit(IZUniTab(zUniTab).gasLimitAmounts(req.destination));

            if (IZRC20(gasZRC20).balanceOf(address(this)) < gasFee) {
                // Swap part of depositAmt to gasZRC20 for gas fee
                IZRC20(BTC_BTC).approve(dexRouter, depositAmt);
                uint256 deductedForGas = SwapHelperLib.swapTokensForExactTokens(
                    dexRouter,         // router
                    BTC_BTC,           // swap from
                    gasFee,            // amountOut
                    gasZRC20,          // targetZRC20
                    depositAmt         // amountInMax
                );
                depositAmt = depositAmt - deductedForGas;
            }
        }
        uint256 scaledUpDepositAmt = scaleUp(depositAmt);

        uint256 tabAmt = Math.mulDiv(
            Math.mulDiv(sigPrice.price, scaledUpDepositAmt, 1e18), 
            100, 
            req.reserveRatio
        );
        if (tabAmt == 0)
            revert ZeroTabAmount(sigPrice.price, scaledUpDepositAmt, req.reserveRatio);

        IERC20(BTC_BTC).approve(vaultManager, depositAmt);
        address tabAddress = IVaultManager(vaultManager).createVault(
            BTC_BTC,
            scaledUpDepositAmt,
            tabAmt,
            sigPrice
        );

        // Processed. Mark timestamp.
        req.createdTimestamp = block.timestamp; 

        IERC20(tabAddress).approve(zUniTab, tabAmt); // approved transfer Tab
        if (msg.value == 0) {
            IZRC20(gasZRC20).approve(zUniTab, gasFee);
            IZUniTab(zUniTab).transferCrossChain(
                tabAddress,
                req.destination,
                gasZRC20,
                gasFee,
                req.receiver,
                tabAmt
            );
        } else {
            IZUniTab(zUniTab).transferCrossChain{value: msg.value}(
                tabAddress,
                req.destination,
                address(0),
                0,
                req.receiver,
                tabAmt
            );
        }

        emit NativeCreatedVault(
            senderKey,
            requestKey,
            req.receiver,
            req.destination,
            req.tabKey,
            tabAmt,
            depositAmt
        );
    }

    /**
     * @dev Transfer deposited BTC to receiver when create vault request failed.
     */
    function refundCreateVaultRequest(
        bytes32 senderKey,
        bytes32 requestKey
    ) 
        external  
        onlyRole(EXECUTOR_ROLE)
    {
        NativeCreateVaultRequest storage req = createVaultRequests[senderKey][requestKey];
        if (req.receiver == address(0) || req.depositAmt == 0 || req.createdTimestamp > 0)
            revert InvalidRequest();

        // Processed. Mark timestamp.
        req.createdTimestamp = block.timestamp; 

        IERC20(BTC_BTC).transfer(req.receiver, req.depositAmt); // refund full amount

        emit NativeCreateVaultRefund(
            senderKey,
            requestKey,
            req.receiver,
            BTC_BTC,
            req.depositAmt
        );
    }

    /**
     * @dev Create vault in ZetaChain using supported tokens that will be swapped into BTC.BTC.
     * @param zrc20 Token to be used as vault reserve. Use zero address when sending Zeta as reserve.
     * @param amount Token amount. Can be zero value when sending Zeta as reserve.
     * @param destination Target chain for Tabs to be minted.
     * @param receiver Tabs receiver.
     * @param receiveTabAmount Tab amount to be minted.
     * @param receiveGasAmt Optional destination native gas amount to be transferred.
     * @param btcOutMin Minimum swapped BTC amount (amountOutMin in uniswap v2)
     * @param sigPrice Authorized signed market price.
     */
    function zCreateVault(
        address zrc20,
        uint256 amount,
        address destination,
        address receiver,
        uint256 receiveTabAmount,
        uint256 receiveGasAmt,
        uint256 btcOutMin,
        IPriceData.UpdatePriceData memory sigPrice
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
        if (destination == address(0))
            revert RequiredDestination();
        if (receiver == address(0))
            revert RequiredReceiver();
        if (receiveTabAmount == 0)
            revert ZeroMintTabAmount();

        address WZETA = IGatewayZEVMToken(gateway).zetaToken();
        address reserveToken = zrc20;
        uint256 reserveAmount = amount;
        
        // Wrap ZETA and approve swap, keep 'receiveGasAmt' if destination is ZetaChain
        if (msg.value > 0) {
            reserveToken = WZETA;
            reserveAmount = msg.value;
            IWETH9(WZETA).deposit{value: msg.value}();
        } else {
            SafeERC20.safeTransferFrom(
                IERC20(zrc20),
                msg.sender,
                address(this),
                amount
            );
        }

        if (destination == WZETA) {
            _zetaChainHandler(
                reserveToken,
                reserveAmount,
                destination,
                receiver,
                receiveTabAmount,
                receiveGasAmt,
                btcOutMin,
                sigPrice
            );
        } else {
            _nonZetaHandler(
                reserveToken,
                reserveAmount,
                destination,
                receiver,
                receiveTabAmount,
                receiveGasAmt,
                btcOutMin,
                sigPrice
            );
        }
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
            address destination,
            address receiver,
            ,// address sendToken,
            ,// uint256 sendAmount,
            uint256 receiveTabAmount,
            uint256 receiveGasAmt,
            uint256 btcOutMin,
            IPriceData.UpdatePriceData memory sigPrice
        ) = abi.decode(message, (address, address, address, uint256, uint256, uint256, uint256, IPriceData.UpdatePriceData));

        if (destination == IGatewayZEVMToken(gateway).zetaToken()) {
            _zetaChainHandler(
                zrc20,
                amount,
                destination,
                receiver,
                receiveTabAmount,
                receiveGasAmt,
                btcOutMin,
                sigPrice
            );
        } else {
            _nonZetaHandler(
                zrc20,
                amount,
                destination,
                receiver,
                receiveTabAmount,
                receiveGasAmt,
                btcOutMin,
                sigPrice
            );
        }
    }

    function _zetaChainHandler(
        address zrc20,
        uint256 amount,
        address destination,
        address receiver,
        uint256 receiveTabAmount,
        uint256 receiveGasAmt,
        uint256 btcOutMin,
        IPriceData.UpdatePriceData memory sigPrice
    ) internal {
        uint256 reserveAmount = amount;
        IZRC20(zrc20).approve(dexRouter, amount);

        // Deduct user-assigned gas amount from incoming native coin or Token 
        if (receiveGasAmt > 0) {
            if (zrc20 == destination) {
                reserveAmount = amount - receiveGasAmt;
            } else {
                uint256 deductedReserve = SwapHelperLib.swapTokensForExactTokens(
                    dexRouter,      // router
                    zrc20,          // swap from
                    receiveGasAmt,  // amountOut
                    destination,    // targetZRC20
                    amount          // amountInMax
                );
                reserveAmount = amount - deductedReserve;
            }

            IWETH9(destination).withdraw(receiveGasAmt); // WZETA to ZETA
            (bool success, ) = payable(receiver).call{value: receiveGasAmt}("");
            if (!success) revert GasTransferFailed();
        }

        uint256 btcAmount = amount;
        if (zrc20 != BTC_BTC) {
            // Swap deposit of ETH, WBTC, cbBTC, USDC, USDT into BTC.BTC in ZetaChain
            btcAmount = SwapHelperLib.swapExactTokensForTokens(
                dexRouter,
                zrc20,              // Deposit from source chain
                reserveAmount,      // swap amount
                BTC_BTC,            // targetZRC20
                btcOutMin           // minAmountOut
            );
        }

        // Deposit BTC as reserve, create vault and mint Tabs
        IERC20(BTC_BTC).approve(vaultManager, btcAmount);
        address tabAddress = IVaultManager(vaultManager).createVault(
            BTC_BTC,
            scaleUp(btcAmount),
            receiveTabAmount,
            sigPrice
        );
        IERC20(tabAddress).transfer(receiver, receiveTabAmount);

        emit ZCreateVault(
            sigPrice.updater,
            receiver,
            sigPrice.chainID,
            zrc20,
            reserveAmount,
            btcAmount,
            receiveGasAmt,
            tabKey(sigPrice.tab),
            receiveTabAmount
        );
    }

    function _nonZetaHandler(
        address zrc20,
        uint256 amount,
        address destination,
        address receiver,
        uint256 receiveTabAmount,
        uint256 receiveGasAmt,
        uint256 btcOutMin,
        IPriceData.UpdatePriceData memory sigPrice
    ) internal {
        // Required gas fee to deliver Tab on destination chain
        (address gasZRC20, uint256 gasFee) = IZRC20(destination)
                .withdrawGasFeeWithGasLimit(IZUniTab(zUniTab).gasLimitAmounts(destination));
        
        uint256 reserveAmount;
        uint256 receiveGasWithFee = gasFee + receiveGasAmt;
        
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

        uint256 btcAmount = reserveAmount;
        if (zrc20 != BTC_BTC) {
            // Swap deposit of ETH, WBTC, cbBTC, USDC, USDT into BTC.BTC in ZetaChain
            btcAmount = SwapHelperLib.swapExactTokensForTokens(
                dexRouter,
                zrc20,              // Deposit from source chain
                reserveAmount,      // swap amount
                BTC_BTC,            // targetZRC20
                btcOutMin           // minAmountOut
            );
        }

        // Deposit BTC as reserve, create vault and mint Tabs
        IERC20(BTC_BTC).approve(vaultManager, btcAmount);
        address tabAddress = IVaultManager(vaultManager).createVault(
            BTC_BTC,
            scaleUp(btcAmount),
            receiveTabAmount,
            sigPrice
        );
        
        IERC20(gasZRC20).approve(zUniTab, receiveGasWithFee); // approved spending gas
        IERC20(tabAddress).approve(zUniTab, receiveTabAmount); // approved transfer Tab

        IZUniTab(zUniTab).transferCrossChain(
            tabAddress,
            destination,
            gasZRC20,
            receiveGasWithFee,
            receiver,
            receiveTabAmount
        );

        emit ZCreateVault(
            sigPrice.updater,
            receiver,
            sigPrice.chainID,
            zrc20,
            reserveAmount,
            btcAmount,
            receiveGasAmt,
            tabKey(sigPrice.tab),
            receiveTabAmount
        );
        
    }

}