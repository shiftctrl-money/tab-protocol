// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RevertOptions} from "@zetachain/protocol-contracts/contracts/Revert.sol";
import {IGatewayEVM} from "@zetachain/protocol-contracts/contracts/evm/interfaces/IGatewayEVM.sol";

import {UniTabOperation} from "./UniTabOperation.sol";
import {IUniPaybackTab} from "../interfaces/IUniPaybackTab.sol";
import {IUniTab} from "../interfaces/IUniTab.sol";
import {ITabERC20} from "../interfaces/ITabERC20.sol";

/** 
 * @dev ShiftCTRL Tab Protocol's payback Tab operation on ZetaChain.
 *      `onRevert` is triggered if transaction reverted in ZetaChain.
 */
contract UniPaybackTab is 
    Initializable, 
    UUPSUpgradeable,
    UniTabOperation,
    IUniPaybackTab
{
    // ZRC-20 ZETA token address on ZetaChain used to indicate destination chain
    address public zetaToken;

    // VaultManager contract address on ZetaChain
    address public vaultManager;

    constructor() {
        _disableInitializers();
    }

    /** 
     * @dev Initialization.
     * @param _admin Governance controller address.
     * @param _upgrader Proxy admin contract address.
     * @param _deployer Deployer address.
     * @param _gatewayAddress EVM gateway address.
     * @param _zrc20GasToken Current chain ZRC20 gas token address.
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

    function updateZetaToken(address _zetaToken) external onlyRole(DEPLOYER_ROLE) {
        if (_zetaToken == address(0)) revert InvalidAddress();
        emit UpdatedZetaToken(zetaToken, _zetaToken);
        zetaToken = _zetaToken;
    }

    function updateVaultManager(address _vaultManager) external onlyRole(DEPLOYER_ROLE) {
        if (_vaultManager == address(0)) revert InvalidAddress();
        emit UpdatedVaultManager(vaultManager, _vaultManager);
        vaultManager = _vaultManager;
    }

    /**
     * @dev Payback Tab to a vault on ZetaChain.
     * @param _vaultOwner Vault owner address.
     * @param _vaultId Vault ID.
     * @param _paybackTab Tab address to payback into existing vault.
     * @param _paybackAmt Tab amount to payback(burn).
     */
    function paybackTab(
        address _vaultOwner,
        uint256 _vaultId,
        address _paybackTab,
        uint256 _paybackAmt
    ) external nonReentrant whenNotPaused {
        if (_paybackTab == address(0) || _paybackAmt == 0)
            revert ZeroPayback();

        ITabERC20(_paybackTab).burnFrom(msg.sender, _paybackAmt);

        bytes32 tabKey = ITabERC20(_paybackTab).tabKey();

        bytes memory callData = abi.encodeWithSignature(
            "paybackTab(address,uint256,uint256)",
            _vaultOwner,
            _vaultId,
            _paybackAmt
        );

        bytes memory message = abi.encode(
            _paybackTab,    // tabAddress
            tabKey,         // bytes32: tabKey
            zetaToken,      // destination
            universal,      // receiver: ZUniTab on ZetaChain
            _paybackAmt,    // tokenAmount
            msg.sender,     // sender
            vaultManager,   // callToAddress: only applicable for ZetaChain destination
            callData,       // callData
            true            // perform ERC-20 approve call on callToAddress
        );

        IGatewayEVM(gateway).call(
            universal,          // receiver
            message,            // payload
            RevertOptions(
                uniTab,         // revertAddress
                false,          // callOnRevert
                universal,      // abortAddress
                abi.encode(_paybackTab, msg.sender, _paybackAmt, msg.sender), // revertMessage
                IUniTab(uniTab).revertGasLimit()  // onRevertGasLimit
            )
        ); 
        
        emit PaybackTab(
            _vaultOwner,
            _vaultId,
            _paybackTab,
            _paybackAmt
        );
    }

}