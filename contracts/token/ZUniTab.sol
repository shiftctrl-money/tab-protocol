// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ITabERC20} from "../interfaces/ITabERC20.sol";
import {IZUniTab} from "../interfaces/IZUniTab.sol";

import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IGatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IWZETA.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import {SwapHelperLib} from "@zetachain/toolkit/contracts/SwapHelperLib.sol";


contract ZUniTab is 
    Initializable, 
    AccessControlDefaultAdminRulesUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    UniversalContract,
    IZUniTab
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");
    bytes32 public constant UNIVERSAL_ROLE = keccak256("UNIVERSAL_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    bool public constant isUniversal = true;

    // Address of the ZetaChain gateway contract
    GatewayZEVM public gateway;

    // Address of the Uniswap v2 Router for token swaps
    address public uniswapRouter;

    // Authorized supported chains caller/receiver, ZRC-20 chain gas : UniTab address
    mapping(address => address) public connected;

    // Authorized sender addresses (UniTab contract addresses)
    mapping(address => bool) public authorizedSender;

    // Address of ZRC-20 gas token : gas limit to mint on destination chain
    mapping(address => uint256) public gasLimitAmounts; 

    // ZRC-20 destination gas address (chain id): (Tab key : Destination Tab Address)
    mapping(address => mapping(bytes32 => address)) public tabAddresses;

    // DEBUG ONLY
    bool public onRevertSuccess = true;
    error onRevertDebugError();
    bool public onAbortSuccess = true;
    error onAbortDebugError();
    bool public onCallSuccess = true;
    error onCallDebugError();

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    /** 
     * @dev Initialization.
     * @param _admin Governance controller address.
     * @param _admin2 Emergency governance controller address.
     * @param _upgrader Proxy admin contract address.
     * @param _deployer Deployer address.
     * @param _gatewayAddress EVM gateway address.
     * @param _uniswapRouterAddress Uniswap v2 router address for gas token swaps.
     */
    function initialize(
        address _admin, 
        address _admin2, 
        address _upgrader,
        address _deployer,
        address _gatewayAddress,
        address _uniswapRouterAddress
    ) 
        public 
        initializer 
    {
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        if (_admin2 == address(0) || 
            _upgrader == address(0) || 
            _deployer == address(0) ||
            _gatewayAddress == address(0) || 
            _uniswapRouterAddress == address(0)
        )
            revert InvalidAddress();
        
        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _admin2);
        _grantRole(DEPLOYER_ROLE, _deployer);

        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin2);
        _grantRole(PAUSER_ROLE, _deployer);

        _grantRole(UPGRADER_ROLE, _upgrader);

        gateway = GatewayZEVM(payable(_gatewayAddress));
        _grantRole(GATEWAY_ROLE, _gatewayAddress);
        _setRoleAdmin(GATEWAY_ROLE, DEPLOYER_ROLE);
        uniswapRouter = _uniswapRouterAddress;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    /// @notice Pause contract.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause contract.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Set connected chains' UniTab addresses.
     * @param zrc20 The supported chain's ZRC-20 gas token addresses.
     * @param uniTab UniTab contract addresses on the supported chains.
     */
    function setConnected(
        address[] calldata zrc20,
        address[] calldata uniTab
    ) external onlyRole(DEPLOYER_ROLE) {
        if (zrc20.length != uniTab.length)
            revert InvalidLength();
        for (uint256 i = 0; i < zrc20.length; i++) {
            if (zrc20[i] == address(0) || uniTab[i] == address(0))
                revert InvalidAddress();
            connected[zrc20[i]] = uniTab[i];
            emit SetConnected(zrc20[i], uniTab[i]);
        }
    }

    /**
     * @dev Set authorized sender addresses.
     * @param uniTab The UniTab contract addresses to authorize.
     * @param isAuthorized Whether the UniTab contract is authorized or not.
     */
    function setAuthorizedSender(
        address[] calldata uniTab,
        bool[] calldata isAuthorized
    ) external onlyRole(DEPLOYER_ROLE) {
        if (uniTab.length != isAuthorized.length)
            revert InvalidLength();
        for (uint256 i = 0; i < uniTab.length; i++) {
            if (uniTab[i] == address(0))
                revert InvalidAddress();
            authorizedSender[uniTab[i]] = isAuthorized[i];
            emit SetAuthorizedSender(uniTab[i], isAuthorized[i]);
        }
    }
       
    /**
     * @dev Call this to set gas limit for a destination chain.
     * @param destination Destination ZRC-20 gas token address.
     * @param gasLimit Gas limit for the destination chain.
     */
    function setGasLimit(address[] calldata destination, uint256[] calldata gasLimit) external onlyRole(DEPLOYER_ROLE) {
        if (destination.length != gasLimit.length)
            revert InvalidLength();
        for(uint256 i = 0; i < destination.length; i++) {
            if (destination[i] == address(0))
                revert InvalidAddress();
            if (gasLimit[i] == 0)
                revert InvalidGasLimit();
            gasLimitAmounts[destination[i]] = gasLimit[i];
            emit UpdatedGasLimit(destination[i], gasLimit[i]);
        }
    }

    /**
     * @dev Set the Tab address for a specific destination gas token and source ERC-20 Tab address.
     * @param zrc20GasToken Destination ZRC-20 gas token address.
     * @param tabKeys Tab contract tabKey(), `keccak256(abi.encodePacked(tabCode()))`
     * @param destToken Destination Tab Address.
     */
    function setTabAddress(
        address zrc20GasToken, 
        bytes32[] calldata tabKeys, 
        address[] calldata destToken
    ) external onlyRole(DEPLOYER_ROLE) {
        if (zrc20GasToken == address(0))
            revert InvalidAddress();
        if (tabKeys.length != destToken.length)
            revert InvalidLength();
        for(uint256 i = 0; i < tabKeys.length; i++) {
            if (tabKeys[i] == bytes32(0) || destToken[i] == address(0))
                revert InvalidAddress();
            tabAddresses[zrc20GasToken][tabKeys[i]] = destToken[i];
        }
        emit UpdatedTabAddress(zrc20GasToken, tabKeys.length);
    }
    
    /**
     * @dev Set the Zeta gateway contract address.
     * @param gatewayAddress Zeta gateway contract address.
     */
    function setGateway(address gatewayAddress) external onlyRole(DEPLOYER_ROLE) {
        if (gatewayAddress == address(0)) revert InvalidAddress();
        emit SetGateway(address(gateway), gatewayAddress);
        _revokeRole(GATEWAY_ROLE, address(gateway));
        _grantRole(GATEWAY_ROLE, gatewayAddress);
        gateway = GatewayZEVM(payable(gatewayAddress));
    }

    /**
     * @dev Set the Uniswap v2 Router address for token swaps.
     * @param uniswapRouterAddress Uniswap v2 Router contract address.
     */
    function setUniswapRouter(address uniswapRouterAddress) external onlyRole(DEPLOYER_ROLE) {
        if (uniswapRouterAddress == address(0)) revert InvalidAddress();
        emit SetUniswapRouter(uniswapRouter, uniswapRouterAddress);
        uniswapRouter = uniswapRouterAddress;
    }

    /**
     * @notice Transfers tokens to another chain.
     * @dev Burns the tokens in ZetaChain, then uses the Gateway to send a message to
     *      mint the same tokens on the destination chain. 
     *      All ZETA in the transfer will be converted to destination gas token.
     * @param tabAddress The address of the Tab ERC20 token.
     * @param destination The ZRC-20 address of the gas token of the destination chain.
     * @param payingTokenAsGas Paying ZRC-20 token as gas. When zero, paying with native ZETA.
     * @param payingTokenAmount Paying token amount as gas.
     * @param receiver The address on the destination chain that will receive the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function transferCrossChain(
        address tabAddress,
        address destination,
        address payingTokenAsGas,
        uint256 payingTokenAmount,
        address receiver,
        uint256 amount
    ) external payable {
        _transferCrossChain(tabAddress, destination, payingTokenAsGas, payingTokenAmount, receiver, amount);
    }

    function _transferCrossChain(
        address tabAddress,
        address destination,
        address payingTokenAsGas,
        uint256 payingTokenAmount,
        address receiver,
        uint256 amount
    ) internal nonReentrant whenNotPaused {
        // must pay zeta gas and converted to destination gas
        if (payingTokenAsGas == address(0) && msg.value == 0) revert ZeroMsgValue();
        if (receiver == address(0)) revert InvalidAddress();
        if (gasLimitAmounts[destination] == 0) revert InvalidGasLimit();

        ITabERC20(tabAddress).burnFrom(msg.sender, amount);
        emit TokenTransfer(tabAddress, destination, receiver, amount);

        (address gasZRC20, uint256 gasFee) = IZRC20(destination)
            .withdrawGasFeeWithGasLimit(gasLimitAmounts[destination]);
        if (destination != gasZRC20) revert InvalidAddress();

        uint256 out;
        address WZETA = gateway.zetaToken();
        if (payingTokenAsGas == address(0)) {
            IWETH9(WZETA).deposit{value: msg.value}();
            if (!IWETH9(WZETA).approve(uniswapRouter, msg.value)) {
                revert ApproveFailed();
            }
            out = SwapHelperLib.swapExactTokensForTokens(
                uniswapRouter,
                WZETA,      // convert from, WZETA
                msg.value,  // swap amount
                gasZRC20,   // targetZRC20
                0           // minAmountOut
            );
        } else {
            SafeERC20.safeTransferFrom(IERC20(payingTokenAsGas), msg.sender, address(this), payingTokenAmount);
            if (payingTokenAsGas == gasZRC20) {
                out = payingTokenAmount;
            } else {
                SafeERC20.safeIncreaseAllowance(IERC20(payingTokenAsGas), uniswapRouter, payingTokenAmount);
                out = SwapHelperLib.swapExactTokensForTokens(
                    uniswapRouter,
                    payingTokenAsGas,   // convert from
                    payingTokenAmount,  // swap amount
                    gasZRC20,           // targetZRC20
                    0                   // minAmountOut
                );
            }
        }

        if (out < gasFee) {
            revert InsufficientGasFee();
        }
        if (!IZRC20(gasZRC20).approve(address(gateway), out)) {
            revert ApproveFailed();
        }

        uint256 remaining = out - gasFee;
        bytes32 tabKey = ITabERC20(tabAddress).tabKey();
        if (tabAddresses[destination][tabKey] == address(0))
            revert UnsupportedTabAddress();

        if (remaining > 0) {
            gateway.withdrawAndCall(
                abi.encodePacked(connected[destination]), // receiver
                remaining, // amount
                destination, // zrc20
                abi.encode(tabAddresses[destination][tabKey], ITabERC20(tabAddress).tabCode(), receiver, amount, remaining, msg.sender), // message
                CallOptions(gasLimitAmounts[destination], false),
                RevertOptions(
                    address(this),
                    true,
                    address(this),
                    abi.encode(tabAddress, receiver, amount, receiver),
                    gasLimitAmounts[destination]
                )
            );
        } else {
            gateway.call(
                abi.encodePacked(connected[destination]), // receiver
                destination, // zrc20
                abi.encode(tabAddresses[destination][tabKey], ITabERC20(tabAddress).tabCode(), receiver, amount, remaining, msg.sender), // message
                CallOptions(gasLimitAmounts[destination], false),
                RevertOptions(
                    address(this),
                    true,
                    address(this),
                    abi.encode(tabAddress, receiver, amount, receiver),
                    gasLimitAmounts[destination]
                )
            );
        }
    }

    /**
     * @notice Mints tokens in response to an incoming cross-chain transfer.
     * @dev Called by the Gateway upon receiving a depositAndCall from UniTab's `transferCrossChain` function.
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
        // sender must be authorized UniTab
        if (!authorizedSender[context.senderEVM])
            revert Unauthorized();

        (
            , //address tabAddress,
            bytes32 tabKey,
            address destination,
            address receiver,
            uint256 tokenAmount,
            address sender,
            address callToAddress,
            bytes memory callData,
            bool performERC20Approve
        ) = abi.decode(message, (address, bytes32, address, address, uint256, address, address, bytes, bool));

        // destination must be connected chain's UniTab contract
        if (connected[destination] == address(0))
            revert UnsupportedDestination();
        if (tabAddresses[destination][tabKey] == address(0))
            revert UnsupportedTabAddress();

        address zetaAddr = gateway.zetaToken();
        
        if (destination == zetaAddr) {
            ITabERC20(tabAddresses[destination][tabKey]).mint(receiver, tokenAmount);
            emit TokenMinted(receiver, tabAddresses[destination][tabKey], tokenAmount);

            if (amount > 0) {
                SafeERC20.safeIncreaseAllowance(IERC20(zrc20), uniswapRouter, amount);
                uint256 out = SwapHelperLib.swapExactTokensForTokens(
                    uniswapRouter,
                    zrc20,
                    amount,
                    destination,
                    0
                );
                IWETH9(destination).withdraw(out); // WZETA to ZETA
                (bool success, ) = payable(receiver).call{value: out}("");
                if (!success) revert GasTransferFailed();
            }

            if (callToAddress != address(0)) {
                if (performERC20Approve)
                    SafeERC20.safeIncreaseAllowance(IERC20(tabAddresses[destination][tabKey]), callToAddress, tokenAmount);
                _execute(callToAddress, 0, callData);
            }
        } else {
            bytes3 tabCode = ITabERC20(tabAddresses[zetaAddr][tabKey]).tabCode();
            (address gasZRC20, uint256 gasFee) = IZRC20(destination)
                .withdrawGasFeeWithGasLimit(gasLimitAmounts[destination]);
            if (destination != gasZRC20) revert InvalidAddress();
            SafeERC20.safeIncreaseAllowance(IERC20(zrc20), uniswapRouter, amount);
            uint256 out = SwapHelperLib.swapExactTokensForTokens(
                uniswapRouter,
                zrc20,
                amount,
                destination,
                0
            );

            if (out < gasFee) {
                revert InsufficientGasFee();
            }
            if (!IZRC20(destination).approve(address(gateway), out)) {
                revert ApproveFailed();
            }

            uint256 remaining = out - gasFee;
            
            if (remaining > 0) {
                gateway.withdrawAndCall(
                    abi.encodePacked(connected[destination]), // receiver
                    remaining, // amount
                    destination, // zrc20
                    abi.encode(tabAddresses[destination][tabKey], tabCode, receiver, tokenAmount, remaining, sender), // message
                    CallOptions(gasLimitAmounts[destination], false), // isArbitraryCall: false
                    RevertOptions(
                        address(this),
                        true,
                        address(this),
                        abi.encode(tabAddresses[zetaAddr][tabKey], receiver, tokenAmount, sender),
                        gasLimitAmounts[destination]
                    )
                );
            } else {
                gateway.call(
                    abi.encodePacked(connected[destination]), // receiver
                    destination,
                    abi.encode(tabAddresses[destination][tabKey], tabCode, receiver, tokenAmount, remaining, sender), // message
                    CallOptions(gasLimitAmounts[destination], false), // isArbitraryCall: false
                    RevertOptions(
                        address(this),
                        true,
                        address(this),
                        abi.encode(tabAddresses[zetaAddr][tabKey], receiver, tokenAmount, sender),
                        gasLimitAmounts[destination]
                    )
                );
            }
        }

        if (!onCallSuccess)
            revert onCallDebugError();

        emit TokenTransferToDestination(destination, sender, receiver, tabAddresses[destination][tabKey], tokenAmount);
    }

    /**
     * @notice Mint(recover) asset in ZetaChain if cross-chain transfer fails.
     *         Connected Chain To ZetaChain failed: revert in connected source chain, onAbort in ZetaChain if failed.
     *         ZetaChain To Connected Chain failed: revert in ZetaChain.
     * @param context Revert context to pass to onRevert.
     */
    function onRevert(RevertContext calldata context) external onlyRole(GATEWAY_ROLE) {
        if (context.sender != address(this)) revert Unauthorized();

        (address tabAddress, , uint256 amount, address sender) = abi.decode(
            context.revertMessage,
            (address, address, uint256, address)
        );

        ITabERC20(tabAddress).mint(sender, amount);
        
        if (context.amount > 0) {
            if (context.asset == address(0)) {
                if (address(this).balance >= context.amount) {
                    (bool success, ) = payable(sender).call{value: context.amount}("");
                    if (!success) revert GasTransferFailed();
                }
            } else {
                if (IZRC20(context.asset).balanceOf(address(this)) >= context.amount) {
                    if (!IZRC20(context.asset).transfer(sender, context.amount))
                        revert GasTransferFailed();
                }
            }
        }

        if (!onRevertSuccess)
            revert onRevertDebugError();

        emit TokenTransferReverted(
            tabAddress,
            sender,
            context.asset,
            amount,
            context.amount
        );
    }

    /* @notice Triggered when ZetaChain to Destination failed and onRevert failed too.
    *  @param context The abort context containing metadata and revert message.
    * `context.outgoing` is true when the call was made from ZetaChain, false when called from connected chain.
    */
    function onAbort(AbortContext calldata context) external onlyRole(GATEWAY_ROLE) {
        address contextSender = address(uint160(bytes20(context.sender)));
        if (contextSender != address(this))
            revert Unauthorized();

        (address tabAddress, , uint256 amount, address sender) = abi.decode(
            context.revertMessage,
            (address, address, uint256, address)
        );

        ITabERC20(tabAddress).mint(sender, amount);

        if (context.amount > 0) {
            if (context.asset == address(0)) {
                if (address(this).balance >= context.amount) {
                    (bool success, ) = payable(sender).call{value: context.amount}("");
                    if (!success) revert GasTransferFailed();
                }
            } else {
                if (IZRC20(context.asset).balanceOf(address(this)) >= context.amount) {
                    if (!IZRC20(context.asset).transfer(sender, context.amount))
                        revert GasTransferFailed();
                }
            }
        }

        if (!onAbortSuccess)
            revert onAbortDebugError();

        emit TokenTransferAborted(
            tabAddress,
            sender,
            context.asset,
            amount,
            context.amount
        );
    }

    function _execute(address target, uint256 value, bytes memory data) internal {
        (bool success, ) = target.call{value: value}(data);
        if (!success) revert ExecutionFailed();
    }

    function updateDebugSuccess(bool _onCall, bool _onRevert, bool _onAbort) external onlyRole(DEPLOYER_ROLE) {
        onCallSuccess = _onCall;
        onRevertSuccess = _onRevert;
        onAbortSuccess = _onAbort;
    }
}