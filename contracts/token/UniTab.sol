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

import "@zetachain/protocol-contracts/contracts/evm/GatewayEVM.sol";
import {IUniTab} from "../interfaces/IUniTab.sol";
import {ITabERC20} from "../interfaces/ITabERC20.sol";
import {ITabFactory} from "../interfaces/ITabFactory.sol";

/** 
 * @dev This contract allows for cross-chain Tab token transfers using the ZetaChain protocol.
 *      It will be deployed to Base, Arbitrum, Ethereum, Avalanche chains to connect with
 *      ZUniTab contract on ZetaChain.
 */
contract UniTab is 
    Initializable, 
    AccessControlDefaultAdminRulesUpgradeable, 
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IUniTab
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Zeta token address in ZetaChain
    address public zetaToken;

    // Address of the EVM gateway contract
    GatewayEVM public gateway;

    // The address of the Universal Token contract on ZetaChain. 
    address public universal;

    // Tab factory to create ERC-20 Tab contract
    address public tabFactory;

    // Gas limit to execute onRevert in deployed chain
    uint256 public revertGasLimit; 

    // Refer `burnAndMintNewTab` function.
    mapping(address => address) public oldToNewTabAddresses;

    // Authorized tab contract addresses
    mapping(address => bool) public authorizedTabs;

    // DEBUG ONLY
    bool public onRevertSuccess = true;
    error onRevertDebugError();
    bool public onCallSuccess = true;
    error onCallDebugError();
    bool public onAbortSuccess = true;
    error onAbortDebugError();

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
     * @param _zetaToken Zeta token address in ZetaChain.
     */
    function initialize(
        address _admin, 
        address _admin2, 
        address _upgrader,
        address _deployer,
        address _gatewayAddress,
        address _zetaToken
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
            _zetaToken == address(0)
        )
            revert InvalidAddress();
        
        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _admin2);
        _grantRole(DEPLOYER_ROLE, _deployer);

        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin2);
        _grantRole(PAUSER_ROLE, _deployer);

        _grantRole(UPGRADER_ROLE, _upgrader);

        gateway = GatewayEVM(_gatewayAddress);
        _grantRole(GATEWAY_ROLE, _gatewayAddress);
        _setRoleAdmin(GATEWAY_ROLE, DEPLOYER_ROLE);
        zetaToken = _zetaToken;
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
     * @dev Updated `onRevert` gas limit. 
     * @param _gasLimit onRevert gas limit amount.
     */
    function setRevertGasLimit(uint256 _gasLimit) external onlyRole(DEPLOYER_ROLE) {
        if (_gasLimit == 0)
            revert InvalidGasLimit();
        emit UpdatedGasLimit(revertGasLimit, _gasLimit);
        revertGasLimit = _gasLimit;
    }

    /**
     * @dev Set this if need to support Old Tab to New Tab migration.
     *      Required for `setOldToNewTabAddress` function.
     */
    function setAuthorizedTab(address[] calldata tabAddress, bool[] calldata isAuthorized) external onlyRole(DEPLOYER_ROLE) {
        if (tabAddress.length != isAuthorized.length)
            revert InvalidLength();
        for (uint256 i = 0; i < tabAddress.length; i++) {
            if (tabAddress[i] == address(0))
                revert InvalidAddress();
            if (tabAddress[i].code.length == 0)
                revert InvalidAddress();
            try ITabERC20(tabAddress[i]).tabVersion() returns (bytes32 v1) {
                if (keccak256("v1") != v1)
                    revert InvalidAddress();
            } catch {
                revert InvalidAddress();
            }
            authorizedTabs[tabAddress[i]] = isAuthorized[i];
            emit AuthorizedTab(tabAddress[i], isAuthorized[i]);
        }
    }

    /**
     * @dev Call this to set the ZetaChain universal contract address.
     * @param contractAddress Universal contract address.
     */
    function setUniversal(address contractAddress) external onlyRole(DEPLOYER_ROLE) {
        if (contractAddress == address(0)) revert InvalidAddress();
        emit UpdatedZetaUniversal(universal, contractAddress);
        universal = contractAddress;
    }

    function setTabFactory(address _tabFactory) external onlyRole(DEPLOYER_ROLE) {
        if (_tabFactory == address(0)) revert InvalidAddress();
        emit UpdatedTabFactory(tabFactory, _tabFactory);
        tabFactory = _tabFactory;
    }

    /**
     * @dev Call this to set the EVM gateway contract address.
     * @param gatewayAddress EVM gateway contract address.
     */
    function setGateway(address gatewayAddress) external onlyRole(DEPLOYER_ROLE) {
        if (gatewayAddress == address(0)) revert InvalidAddress();
        emit UpdatedGateway(address(gateway), gatewayAddress);
        _revokeRole(GATEWAY_ROLE, address(gateway));
        _grantRole(GATEWAY_ROLE, gatewayAddress);
        gateway = GatewayEVM(gatewayAddress);
    }

    function setZetaToken(address _zetaToken) external onlyRole(DEPLOYER_ROLE) {
        if (_zetaToken == address(0)) revert InvalidAddress();
        emit UpdatedZetaToken(zetaToken, _zetaToken);
        zetaToken = _zetaToken;
    }

    /**
     * @dev Map old Tab ERC20 token address to new Tab ERC20 token address.
     *      This is used to convert old Tab tokens to new Tab tokens.
     * @param oldTabAddress The old Tab ERC20 token contract address.
     * @param newTabAddress The new Tab ERC20 token contract address.
     */
    function setOldToNewTabAddress(
        address oldTabAddress, 
        address newTabAddress
    ) 
        external 
        onlyRole(DEPLOYER_ROLE) 
    {
        if (oldTabAddress == address(0) || newTabAddress == address(0)) revert InvalidAddress();
        if (!authorizedTabs[newTabAddress]) revert UnauthorizedTab();
        oldToNewTabAddresses[oldTabAddress] = newTabAddress;
        emit MappedOldToNewTab(oldTabAddress, newTabAddress);
    }

    /**
     * @dev Burn old tab tokens in exchange for new tab tokens.
     *      Only applicable when governance approved and set old token address
     *      by calling `setOldToNewTabAddress` function.
     * @param tabAddress The old Tab ERC20 token contract address.
     * @param amount The amount of tokens to burn and mint into new Tab.
     */
    function burnAndMintNewTab(address tabAddress, uint256 amount) external nonReentrant whenNotPaused {
        if (oldToNewTabAddresses[tabAddress] == address(0)) revert UnauthorizedTab();
        if (amount == 0) revert ZeroAmount();
        ITabERC20(tabAddress).burnFrom(msg.sender, amount);
        ITabERC20(oldToNewTabAddresses[tabAddress]).mint(msg.sender, amount);
        emit ConvertedOldToNewTab(tabAddress, oldToNewTabAddresses[tabAddress], msg.sender, amount);
    }

    /**
     * @notice Transfers Tab tokens to another chain.
     * @dev Burns the Tab tokens from source chain, then uses the Gateway to send a message to
     *      mint the same tokens on the destination chain.
     *      Must include minimum gas to execute function in destination chain.
     * @param tabAddress Tab ERC20 token contract address.
     * @param destination ZRC-20 address of the gas token of the destination chain.
     * @param receiver The address on the destination chain that will receive the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function transferCrossChain(
        address tabAddress,
        address destination,
        address receiver,
        uint256 amount
    ) external payable {
        _transferCrossChain(tabAddress, destination, receiver, amount);
    }

    /**
     * @notice Internal function that handles the core logic for cross-chain token transfer.
     * @dev This function can be overridden by child contracts to add custom functionality.
     *      It handles the token burning and cross-chain transfer logic.
     * @param tabAddress Tab ERC20 token contract address.
     * @param destination ZRC-20 address of the gas token of the destination chain.
     * @param receiver The address on the destination chain that will receive the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function _transferCrossChain(
        address tabAddress,
        address destination,
        address receiver,
        uint256 amount
    ) internal nonReentrant whenNotPaused {
        if (receiver == address(0)) revert InvalidAddress();

        if (msg.value == 0 && destination != zetaToken) { // required to pay gas in destination chain
            revert RequiredCrossChainGas();
        }

        bytes32 tabKey = ITabERC20(tabAddress).tabKey();

        bytes memory message = abi.encode(
            tabAddress,
            tabKey,
            destination,
            receiver,
            amount,
            msg.sender,
            address(0), // callToAddress: only applicable for ZetaChain destination
            "",         // callData
            false       // perform ERC-20 approve function on callToAddress  
        );

        ITabERC20(tabAddress).burnFrom(msg.sender, amount);
        emit TokenTransfer(tabAddress, destination, receiver, amount);
  
        if (destination == zetaToken) {
            if (msg.value > 0) {
                gateway.depositAndCall{value: msg.value}(
                    universal,          // receiver
                    message,            // payload
                    RevertOptions(
                        address(this),  // revertAddress
                        true,           // callOnRevert
                        universal,      // abortAddress
                        abi.encode(tabAddress, receiver, amount, msg.sender), // revertMessage
                        revertGasLimit                                        // onRevertGasLimit
                    )
                );
            } else {
                gateway.call(
                    universal,          // receiver
                    message,            // payload
                    RevertOptions(
                        address(this),  // revertAddress
                        false,          // callOnRevert
                        universal,      // abortAddress
                        abi.encode(tabAddress, receiver, amount, msg.sender), // revertMessage
                        0               // onRevertGasLimit
                    )
                );
            }
        } else {
            gateway.depositAndCall{value: msg.value}(
                universal,          // receiver
                message,            // payload
                RevertOptions(
                    address(this),  // revertAddress
                    true,           // callOnRevert
                    universal,      // abortAddress
                    abi.encode(tabAddress, receiver, amount, msg.sender), // revertMessage
                    revertGasLimit                                        // onRevertGasLimit
                )
            );
        }
    }

    /**
     * @notice Mints tokens in response to an incoming cross-chain transfer.
     * @dev Called by the Gateway upon receiving a message.
     * @param context The message context.
     * @param message The encoded message containing information about the tokens.
     * @return A constant indicating the function was successfully handled.
     */
    function onCall(
        MessageContext calldata context,
        bytes calldata message
    ) external payable onlyRole(GATEWAY_ROLE) returns (bytes4) {
        if (context.sender != universal) revert Unauthorized();

        (
            address tabAddress,
            bytes3 tabCode,
            address receiver,
            uint256 amount,
            uint256 gasAmount,
            address sender
        ) = abi.decode(message, (address, bytes3, address, uint256, uint256, address));

        if (tabAddress.code.length == 0) {
            tabAddress = ITabFactory(tabFactory).createTab(
                defaultAdmin(), // admin
                address(this),
                address(this),
                tabCode
            );
            ITabERC20(tabAddress).mint(receiver, amount);
        } else
            ITabERC20(tabAddress).mint(receiver, amount);

        if (gasAmount > 0) {
            if (sender == address(0)) revert InvalidAddress();
            (bool success, ) = payable(receiver).call{value: gasAmount}("");
            if (!success) revert GasTokenTransferFailed();
        }

        if (!onCallSuccess)
            revert onCallDebugError();

        emit TokenTransferReceived(
            tabAddress, 
            receiver, 
            amount, 
            gasAmount
        );
        return "";
    }

    /**
     * @notice Source chain to ZetaChain revert handler.
     * @dev Called by the Gateway if a call fails.
     * @param revertContext The revert context containing metadata and revert message.
     */
    function onRevert(RevertContext calldata revertContext) external onlyRole(GATEWAY_ROLE) {
        if (revertContext.sender != universal) revert Unauthorized();

        (address tabAddress, , uint256 amount, address sender) = abi.decode(
            revertContext.revertMessage,
            (address, address, uint256, address)
        ); 

        ITabERC20(tabAddress).mint(sender, amount);

        if (revertContext.amount > 0) {
            if (revertContext.asset == address(0)) {
                if (address(this).balance >= revertContext.amount) {
                    (bool success, ) = payable(sender).call{value: revertContext.amount}("");
                    if (!success) revert GasTokenRefundFailed();
                }
            } else {
                if (IERC20(revertContext.asset).balanceOf(address(this)) >= revertContext.amount) {
                    SafeERC20.safeTransfer(IERC20(revertContext.asset), sender, revertContext.amount);
                }
            }
        }

        if (!onRevertSuccess)
            revert onRevertDebugError();

        emit TokenTransferReverted(
            tabAddress,
            sender,
            revertContext.asset,
            amount,
            revertContext.amount
        );
    }

    function updateDebugSuccess(bool _onCall, bool _onRevert, bool _onAbort) external onlyRole(DEPLOYER_ROLE) {
        onCallSuccess = _onCall;
        onRevertSuccess = _onRevert;
        onAbortSuccess = _onAbort;
    }

}