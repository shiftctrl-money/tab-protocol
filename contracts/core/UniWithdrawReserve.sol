// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IGatewayEVM} from "@zetachain/protocol-contracts/contracts/evm/interfaces/IGatewayEVM.sol";
import {RevertOptions} from "@zetachain/protocol-contracts/contracts/Revert.sol";
import {IPriceData} from "../interfaces/IUniTabOperation.sol";
import {UniTabOperation} from "./UniTabOperation.sol";
import {IUniWithdrawReserve} from "../interfaces/IUniWithdrawReserve.sol";

/** 
 * @dev ShiftCTRL Tab Protocol's withdraw reserve from existing vault in ZetaChain.
 *      `onRevert` is triggered if transaction reverted in ZetaChain.
 */
contract UniWithdrawReserve is 
    Initializable, 
    UUPSUpgradeable,
    UniTabOperation,
    IUniWithdrawReserve
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
     * @dev Specify BTC amount to withdraw from existing vault, and receive specified token or native gas in destination chain.
     * @param _vaultId Vault ID by user (vault owner).
     * @param _withdrawAmt Reserve amount to withdraw from existing vault.
     * @param _destination ZRC-20 gas address of target chain of withdrawal. When blank, default to current/requesting chain.
     * @param _receiver Transfer to this address on destination chain.
     * @param _receiveToken Specify ZRC-20 token on destination chain. When blank, withdraw as native gas on destination chain.
     * @param _minAmountOut Minimum swapped token amount (amountOutMin in uniswap v2)
     * @param sigPrice Signed price.
     */
    function withdrawReserve(
        uint256 _vaultId,
        uint256 _withdrawAmt,
        address _destination,
        address _receiver,
        address _receiveToken,
        uint256 _minAmountOut,
        IPriceData.UpdatePriceData calldata sigPrice
    ) external nonReentrant whenNotPaused {
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
            _withdrawAmt,
            _destination,
            _receiver,
            _receiveToken,
            _minAmountOut,
            sigPrice
        );

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

        emit WithdrawReserve(
            sigPrice.updater,
            _vaultId,
            _withdrawAmt,
            _destination,
            _receiver,
            _receiveToken
        );
    }
}