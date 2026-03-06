// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IGatewayEVM} from "@zetachain/protocol-contracts/contracts/evm/interfaces/IGatewayEVM.sol";
import {RevertOptions,RevertContext,Revertable} from "@zetachain/protocol-contracts/contracts/Revert.sol";

import {IPriceData} from "../interfaces/IUniTabOperation.sol";
import {UniTabOperation} from "./UniTabOperation.sol";
import {IUniWithdrawTab} from "../interfaces/IUniWithdrawTab.sol";


/** 
 * @dev ShiftCTRL Tab Protocol's withdraw Tab from existing vault in ZetaChain.
 *      `onRevert` is triggered if transaction reverted in ZetaChain.
 */
contract UniWithdrawTab is 
    Initializable, 
    UUPSUpgradeable,
    UniTabOperation,
    Revertable,
    IUniWithdrawTab
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
     * @param _zrc20GasToken Current chain's ZRC-20 gas token address in ZetaChain.
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
     * @notice Only vault owner (`sigPrice.updater`) from original chain id can send request to withdraw reserve or tabs.
     * @dev Specify Tab amount to withdraw from existing vault, and receive it in specified destination chain.
     * @param _vaultId Vault ID by user (vault owner).
     * @param _withdrawTabAmt Tab amount to withdraw from existing vault.
     * @param _destination ZRC-20 gas address of target chain of withdrawal. When blank, default to current/requesting chain.
     * @param _receiver Deliver Tabs to this address on destination chain.
     * @param sigPrice Signed price.
     */
    function withdrawTab(
        uint256 _vaultId,
        uint256 _withdrawTabAmt,
        address _destination,
        address _receiver,
        IPriceData.UpdatePriceData calldata sigPrice
    ) external payable nonReentrant whenNotPaused {
        if (_vaultId == 0)
            revert InvalidVault();

        // When leave blank, default set to current chain (withdraw to current chain that sent the request)
        if (_destination == address(0))
            _destination = zrc20GasToken;

        if (!authorizedDestinations[_destination])
            revert InvalidDestination();

        if (_receiver == address(0))
            revert InvalidAddress();

        _verifyPriceSignature(sigPrice);

        bytes memory message = abi.encode(
            _vaultId,
            _withdrawTabAmt,
            _destination,
            _receiver,
            sigPrice
        );

        // msg.value is required to pay destination chain gas, excess amount will be sent to recipient too.
        if (msg.value > 0) {
            IGatewayEVM(gateway).depositAndCall{value: msg.value}(
                universal,          // receiver
                message,            // payload
                RevertOptions(
                    address(this),  // revertAddress
                    true,           // callOnRevert
                    address(0),     // abortAddress
                    abi.encode(sigPrice.updater, _vaultId, _withdrawTabAmt),  // revertMessage
                    0               // onRevertGasLimit
                )
            );
        } else { // Expect withdraw Tab to ZetaChain
            IGatewayEVM(gateway).call(
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

        emit WithdrawTab(
            sigPrice.updater,
            _vaultId,
            _withdrawTabAmt,
            _destination,
            _receiver,
            msg.value
        );
    }

    /**
     * @dev `onRevert` is triggered if transaction reverted in ZetaChain.
     * Refund msg.value when making `withdrawTab` call.
     */
    function onRevert(
        RevertContext calldata revertContext
    ) external onlyRole(GATEWAY_ROLE) {
        if (revertContext.sender != universal)
            revert Unauthorized();

        (
            address sender,
            uint256 vaultId,
            uint256 withdrawTabAmt
        ) = abi.decode(revertContext.revertMessage, (address, uint256, uint256));

        if (revertContext.amount > 0) {
            if (revertContext.asset == address(0)) {
                if (address(this).balance >= revertContext.amount) {
                    (bool success, ) = payable(sender).call{value: revertContext.amount}("");
                    if (!success)
                        revert ReversalGasFailed(sender, revertContext.amount);
                }
            } 
        }

        emit RevertWithdrawTab(
            sender,
            vaultId,
            withdrawTabAmt,
            revertContext.amount
        );
    }

}