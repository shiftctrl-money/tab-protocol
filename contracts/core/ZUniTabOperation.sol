// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRulesUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {IZUniTabOperation} from "../interfaces/IZUniTabOperation.sol";

abstract contract ZUniTabOperation is 
    AccessControlDefaultAdminRulesUpgradeable, 
    IZUniTabOperation
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");
    uint256 internal immutable SCALE_UP = 10000000000;

    // Address of the ZetaChain gateway contract
    address public gateway;

    // VaultManager contract address: execute tab operations
    address public vaultManager;

    // ZUniTab contract address: mint tab in destination chain
    address public zUniTab;

    // DEX contract address to swap required tokens
    address public dexRouter;

    // ZRC-20 BTC.BTC in ZetaChain used as default reserve on Tab Protocol
    address public BTC_BTC;

    // Authorized Universal callers from supported chains
    mapping(address => bool) public authorizedUniCallers; 

    receive() external payable {}

    /** 
     * @dev Initialization.
     * @param _admin Governance controller address.
     * @param _upgrader Proxy admin contract address.
     * @param _deployer Deployer address.
     * @param _gatewayAddress EVM gateway address.
     * @param _btcbtc BTC.BTC ZRC-20 token address.
     * @param _delay delay on switching admin.
     */
    function __ZUniTabOperation_init(
        address _admin, 
        address _upgrader,
        address _deployer,
        address _gatewayAddress,
        address _btcbtc,
        uint48 _delay
    ) 
        internal 
    {
        __AccessControlDefaultAdminRules_init(_delay, _admin);

        if (_upgrader == address(0) || 
            _deployer == address(0) ||
            _gatewayAddress == address(0)
        )
            revert InvalidAddress();
        
        _grantRole(DEPLOYER_ROLE, _admin);
        _grantRole(DEPLOYER_ROLE, _deployer);

        _grantRole(UPGRADER_ROLE, _upgrader);

        _grantRole(GATEWAY_ROLE, _gatewayAddress);
        _setRoleAdmin(GATEWAY_ROLE, DEPLOYER_ROLE);
        gateway = _gatewayAddress;
        BTC_BTC = _btcbtc;
    }
    
    /**
     * @dev Set the Zeta gateway contract address.
     * @param gatewayAddress Zeta gateway contract address.
     */
    function setGateway(address gatewayAddress) external onlyRole(DEPLOYER_ROLE) {
        if (gatewayAddress == address(0)) revert InvalidAddress();
        emit UpdatedGateway(gateway, gatewayAddress);
        _revokeRole(GATEWAY_ROLE, gateway);
        _grantRole(GATEWAY_ROLE, gatewayAddress);
        gateway = gatewayAddress;
    }

    function setVaultManager(address vmanager) external onlyRole(DEPLOYER_ROLE) {
        if (vmanager == address(0)) revert InvalidAddress();
        emit UpdatedVaultManager(vaultManager, vmanager);
        vaultManager = vmanager;
    }

    function setZUniTab(address uniTab) external onlyRole(DEPLOYER_ROLE) {
        if (uniTab == address(0)) revert InvalidAddress();
        emit UpdatedZUniTab(zUniTab, uniTab);
        zUniTab = uniTab;
    }

    function setDexRouter(address dex) external onlyRole(DEPLOYER_ROLE) {
        if (dex == address(0)) revert InvalidAddress();
        emit UpdatedDexRouter(dexRouter, dex);
        dexRouter = dex;
    }

    function setBTCBTC(address btc) external onlyRole(DEPLOYER_ROLE) {
        if (btc == address(0)) revert InvalidAddress();
        emit UpdatedBTCBTC(BTC_BTC, btc);
        BTC_BTC = btc;
    }

    function setAuthorizedUniCaller(address[] calldata caller, bool[] calldata authorized) external onlyRole(DEPLOYER_ROLE) {
        if (caller.length != authorized.length) revert InvalidLength();
        for (uint256 i = 0; i < caller.length; i++) {
            if (caller[i] == address(0))
                revert InvalidAddress();
            authorizedUniCallers[caller[i]] = authorized[i];
            emit UpdatedAuthorizedUniCaller(caller[i], authorized[i]);
        }
    }

    function tabKey(bytes3 tab) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(tab));
    }

    /// @dev Convert 8-decimal `_value` to 18-decimal value.
    function scaleUp(uint256 _value) public pure returns(uint256) {
        return _value * SCALE_UP;
    }

}