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

import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IWZETA.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import {SwapHelperLib} from "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import {IZUniGovernance} from "../interfaces/IZUniGovernance.sol";

/**
 * @title ZUniGovernance
 * @notice This contract will execute governance actions in ZetaChain,
 * or act as intermiary to call UniGovernance in other chains.
 */
contract ZUniGovernance is 
    Initializable, 
    AccessControlDefaultAdminRulesUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    UniversalContract,
    IZUniGovernance
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

    // Authorized supported chains caller/receiver, ZRC-20 chain gas : UniGovernance address
    mapping(address => address) public connected;

    // Authorized sender addresses (UniTab contract addresses)
    mapping(address => bool) public authorizedSender;

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    /** 
     * @dev Initialization.
     * @param _admin Default admin.
     * @param _upgrader Proxy admin contract address.
     * @param _deployer Deployer address.
     * @param _gatewayAddress EVM gateway address.
     * @param _uniswapRouterAddress Uniswap v2 router address for gas token swaps.
     */
    function initialize(
        address _admin, 
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

        if (_upgrader == address(0) || 
            _deployer == address(0) ||
            _gatewayAddress == address(0) || 
            _uniswapRouterAddress == address(0)
        )
            revert InvalidAddress();
        
        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _deployer);
        
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _deployer);

        _grantRole(UPGRADER_ROLE, _upgrader);

        gateway = GatewayZEVM(payable(_gatewayAddress));
        _grantRole(GATEWAY_ROLE, _gatewayAddress);
        _setRoleAdmin(GATEWAY_ROLE, DEPLOYER_ROLE);
        _setRoleAdmin(UPGRADER_ROLE, DEPLOYER_ROLE);
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
     * @dev Connected UniGovernance contract addresses on supported chains.
     * @param zrc20 The supported chain's ZRC-20 gas token addresses.
     * @param uniGov UniGovernance contract addresses on the supported chains.
     */
    function setConnected(
        address[] calldata zrc20,
        address[] calldata uniGov
    ) external onlyRole(DEPLOYER_ROLE) {
        if (zrc20.length != uniGov.length)
            revert InvalidLength();
        for (uint256 i = 0; i < zrc20.length; i++) {
            if (zrc20[i] == address(0) || uniGov[i] == address(0))
                revert InvalidAddress();
            connected[zrc20[i]] = uniGov[i];
            emit SetConnected(zrc20[i], uniGov[i]);
        }
    }

    /**
     * @dev Set authorized sender addresses.
     * @param uniGov The UniGovernance contract addresses to authorize.
     * @param isAuthorized Whether the UniGovernance contract is authorized or not.
     */
    function setAuthorizedSender(
        address[] calldata uniGov,
        bool[] calldata isAuthorized
    ) external onlyRole(DEPLOYER_ROLE) {
        if (uniGov.length != isAuthorized.length)
            revert InvalidLength();
        for (uint256 i = 0; i < uniGov.length; i++) {
            if (uniGov[i] == address(0))
                revert InvalidAddress();
            authorizedSender[uniGov[i]] = isAuthorized[i];
            emit SetAuthorizedSender(uniGov[i], isAuthorized[i]);
        }
    }

    /**
     * @dev Set the Uniswap v2 Router address for token swaps.
     * @param uniswapRouterAddress Uniswap v2 Router contract address.
     */
    function setUniswapRouter(
        address uniswapRouterAddress
    ) external onlyRole(DEPLOYER_ROLE) {
        if (uniswapRouterAddress == address(0)) revert InvalidAddress();
        emit SetUniswapRouter(uniswapRouter, uniswapRouterAddress);
        uniswapRouter = uniswapRouterAddress;
    }

    /**
     * @dev Execute governance action when called by the gateway.
     * @param context The message context.
     * @param zrc20 Incoming ZRC-20 token address (if any).
     * @param amount Available amount of ZRC-20 token.
     * @param message The encoded message containing information about the tokens.
     */
    function onCall(
        MessageContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external override onlyRole(GATEWAY_ROLE) {
        // Expect sender to be UniGovernance in source chain
        if (!authorizedSender[context.senderEVM])
            revert Unauthorized();

        (
            address destination,
            address target,
            uint256 gasLimitAmount,
            bytes memory data
        ) = abi.decode(message, (address, address, uint256, bytes));

        // destination must be connected chain's UniGovernance contract
        if (connected[destination] == address(0))
            revert UnsupportedDestination();

        if (destination == gateway.zetaToken()) { // Run governance action in ZetaChain
            _execute(target, 0, data);
            emit ExecutedLocalAction(target);
        } else {
            (address gasZRC20, uint256 gasFee) = IZRC20(destination)
                .withdrawGasFeeWithGasLimit(gasLimitAmount);
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
                    abi.encode(destination, target, data), // message
                    CallOptions(gasLimitAmount, false), // isArbitraryCall: false
                    RevertOptions(
                        address(0),
                        false,
                        address(0),
                        "",
                        0
                    )
                );
            } else {
                gateway.call(
                    abi.encodePacked(connected[destination]), // receiver
                    destination,
                    abi.encode(destination, target, data), // message
                    CallOptions(gasLimitAmount, false), // isArbitraryCall: false
                    RevertOptions(
                        address(this),
                        false,
                        address(0),
                        "",
                        0
                    )
                );
            }
            emit ExecutingRemoteAction(destination, target);
        }
    }

    function _execute(address target, uint256 value, bytes memory data) internal {
        (bool success, ) = target.call{value: value}(data);
        if (!success) revert ExecutionFailed();
    }

}