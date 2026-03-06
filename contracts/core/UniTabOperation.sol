// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRulesUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {IUniTabOperation, IPriceData} from "../interfaces/IUniTabOperation.sol";

/** 
 * @dev Universal contract logics for Tab Protocol operations.
 */
abstract contract UniTabOperation is 
    AccessControlDefaultAdminRulesUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IUniTabOperation
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    // chain's GatewayEVM address
    address public gateway;

    address public zrc20GasToken;

    // The address of the ZetaChain universal contract to call.
    address public universal;

    // Gas limit to run recovery in case ZetaChain operation reverted
    uint256 public revertGasLimit;

    // UniTab contract address
    address public uniTab;

    receive() external payable {}

    /** 
     * @dev Initialization.
     * @param _admin Governance controller address.
     * @param _upgrader Proxy admin contract address.
     * @param _deployer Deployer address.
     * @param _gatewayAddress EVM gateway address.
     * @param _zrc20GasToken Current chain ZRC-20 gas token, to identify destination chain.
     * @param _delay Delay period to switch default admin.
     */
    function __UniTabOperation_init(
        address _admin, 
        address _upgrader,
        address _deployer,
        address _gatewayAddress,
        address _zrc20GasToken,
        uint48 _delay
    ) 
        internal 
    {
        __AccessControlDefaultAdminRules_init(_delay, _admin);
        __ReentrancyGuard_init();
        __Pausable_init();

        if (_upgrader == address(0) || 
            _deployer == address(0)
        )
            revert InvalidAddress();
        
        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _deployer);

        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _deployer);

        _grantRole(UPGRADER_ROLE, _upgrader);

        gateway = _gatewayAddress;
        _grantRole(GATEWAY_ROLE, _gatewayAddress);
        _setRoleAdmin(GATEWAY_ROLE, DEPLOYER_ROLE);

        zrc20GasToken = _zrc20GasToken;
    }

    /// @notice Pause contract.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause contract.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Update EVM gateway contract address.
     * @param gatewayAddress EVM gateway contract address.
     */
    function setGateway(address gatewayAddress) external onlyRole(DEPLOYER_ROLE) {
        if (gatewayAddress == address(0)) revert InvalidAddress();
        emit UpdatedGateway(gateway, gatewayAddress);
        _revokeRole(GATEWAY_ROLE, gateway);
        _grantRole(GATEWAY_ROLE, gatewayAddress);
        gateway = gatewayAddress;
    }

    /**
     * @dev Update current chain's Zeta ZRC-20 gas token.
     * @param zrc20 ZRC-20 gas token.
     */
    function setZrc20GasToken(address zrc20) external onlyRole(DEPLOYER_ROLE) {
        if (zrc20 == address(0)) revert InvalidAddress();
        emit UpdatedZrc20GasToken(zrc20GasToken, zrc20);
        zrc20GasToken = zrc20;
    }

    /**
     * @dev Update ZetaChain universal contract address.
     * @param contractAddress Universal contract address.
     */
    function setUniversal(address contractAddress) external onlyRole(DEPLOYER_ROLE) {
        if (contractAddress == address(0)) revert InvalidAddress();
        emit UpdatedZetaUniversal(universal, contractAddress);
        universal = contractAddress;
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

    function setUniTab(address _uniTab) external onlyRole(DEPLOYER_ROLE) {
        if (_uniTab == address(0)) revert InvalidAddress();
        emit UpdatedUniTab(uniTab, _uniTab);
        uniTab = _uniTab;
    }

    function tabKey(bytes3 tab) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(tab));
    }

    function _verifyPriceSignature(IPriceData.UpdatePriceData calldata sigPrice) internal pure {
        if (sigPrice.signer == address(0) || 
            sigPrice.updater == address(0) || 
            sigPrice.chainID == 0 || 
            sigPrice.price == 0 || 
            sigPrice.timestamp == 0 || 
            sigPrice.v == 0 || 
            sigPrice.tab == bytes3("") || 
            sigPrice.r == bytes32("") || 
            sigPrice.s == bytes32("")
        )
            revert EmptyPriceSignature();
    }
}