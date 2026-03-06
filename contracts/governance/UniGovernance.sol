// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "@zetachain/protocol-contracts/contracts/evm/GatewayEVM.sol";
import {IUniGovernance} from "../interfaces/IUniGovernance.sol";

/**
 * @notice All governance related actions (such as propose, delegate, vote, and execution) are triggered 
 * on BASE chain. Refer `ShiftCTRLGovernor` and `ShiftCTRLEmergencyGovernor` settings.
 * Governance controller in BASE chain should call `UniGovernance` contract to execute governance actions 
 * in local chain or remote chain (e.g. ZetaChain).
 * 
 * For most governance actions, it will use `executeRemote` function to call 
 * ZetaChain contracts since most of the Protocol contracts are deployed in ZetaChain.
 * On rare case of executing cross-chain actions, ZUniGovernance contract in ZetaChain
 * will calll `UniGovernance` contract in destination (target) chain. The flow is:
 * BASE (UniGovernance:executeRemote) -> 
 *      ZetaChain (ZUniGovernance:onCall) -> 
 *           Destination chain (UniGovernance:onCall)
 *
 */
contract UniGovernance is 
    Initializable, 
    AccessControlDefaultAdminRulesUpgradeable, 
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IUniGovernance
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // Address of the EVM gateway contract
    GatewayEVM public gateway;

    // The address of the Universal Token contract on ZetaChain. 
    address public universal;

    // true on BASE chain only: 
    // disable execute() and executeRemote() functions on non-BASE chain
    bool public isGovSourceChain;

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
     * @param _isGovSourceChain true for BASE chain deployment only.
     */
    function initialize(
        address _admin, 
        address _admin2, 
        address _upgrader,
        address _deployer,
        address _gatewayAddress,
        bool _isGovSourceChain
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
            _gatewayAddress == address(0)
        )
            revert InvalidAddress();
        
        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _admin2);
        _grantRole(DEPLOYER_ROLE, _deployer);

        _grantRole(GOVERNANCE_ROLE, _admin);
        _grantRole(GOVERNANCE_ROLE, _admin2);
        
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin2);
        _grantRole(PAUSER_ROLE, _deployer);

        _grantRole(UPGRADER_ROLE, _upgrader);

        gateway = GatewayEVM(_gatewayAddress);
        _grantRole(GATEWAY_ROLE, _gatewayAddress);
        _setRoleAdmin(GATEWAY_ROLE, DEPLOYER_ROLE);
        isGovSourceChain = _isGovSourceChain;
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
     * @dev Call this to set the ZetaChain universal contract address.
     * @param contractAddress Universal contract address.
     */
    function setUniversal(address contractAddress) external onlyRole(DEPLOYER_ROLE) {
        if (contractAddress == address(0)) revert InvalidAddress();
        emit UpdatedZetaUniversal(universal, contractAddress);
        universal = contractAddress;
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

    /**
     * @dev Local chain's governance to execute governance action.
     * @param target Smart contract address to call.
     * @param data ABI encoded calling function and data.
     */    
    function execute(
        address target, 
        bytes calldata data
    ) 
        external  
        nonReentrant 
        whenNotPaused 
        onlyRole(GOVERNANCE_ROLE) 
    {
        if (target == address(0)) revert InvalidAddress();
        if (!isGovSourceChain) revert RequiredGovSourceChain();
        _executedLocalAction(target, data);
        emit ExecutedLocalAction(target);
    }

    /**
     * @dev Local chain's governance to execute governance action in remote chain.
     * @param destination The destination chain's ZRC20 gas address where the governance action will be executed.
     * @param target Smart contract address to call in the destination chain.
     * @param data ABI encoded calling function and data.
     */
    function executeRemote(
        address destination, 
        address target, 
        bytes calldata data,
        uint256 gasLimitAmount
    ) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        onlyRole(GOVERNANCE_ROLE) 
    {
        if (destination == address(0) || target == address(0))
            revert InvalidAddress();
        if (!isGovSourceChain) 
            revert RequiredGovSourceChain();

        bytes memory message = abi.encode(
            destination,
            target,
            gasLimitAmount,
            data
        );
        if (msg.value > 0) {
            gateway.depositAndCall{value: msg.value}(
                universal,          // receiver
                message,            // payload
                RevertOptions(
                    address(0),     // revertAddress
                    false,          // callOnRevert
                    address(0),     // abortAddress
                    "",             // revertMessage
                    0               // onRevertGasLimit
                )
            );
        } else {
            gateway.call(
                universal,          // receiver
                message,            // payload
                RevertOptions(
                    address(0),     // revertAddress
                    false,          // callOnRevert
                    address(0),     // abortAddress
                    "",             // revertMessage
                    0               // onRevertGasLimit
                )
            );
        }
        emit CalledRemoteAction(destination, target);
    }

    /**
     * @notice Receiving instructions from Zeta gateway to call governance functions.
     * @dev Called by `executeRemote` function in source chain. Passing through ZetaChain to reach destination chain.
     * @param context The message context.
     * @param message Execution instructions.
     * @return A constant indicating the function was successfully handled.
     */
    function onCall(
        MessageContext calldata context,
        bytes calldata message
    ) 
        external 
        payable 
        onlyRole(GATEWAY_ROLE) 
        returns (bytes4) 
    {
        if (context.sender != universal) revert Unauthorized();
        
        (
            address destination,
            address target,
            bytes memory data
        ) = abi.decode(message, (address, address, bytes));

        _executedLocalAction(target, data);

        emit ExecutedRemoteAction(destination, target);
        return "";
    }

    function _executedLocalAction(address target, bytes memory data) internal {
        (bool success, ) = target.call(data);
        if(!success)
            revert GovExecutionFailed();
    }

}