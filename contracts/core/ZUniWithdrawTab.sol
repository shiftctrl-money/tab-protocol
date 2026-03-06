// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ZUniTabOperation} from "./ZUniTabOperation.sol";
import {IZUniWithdrawTab} from "../interfaces/IZUniWithdrawTab.sol";
import {IGatewayZEVMToken} from "../interfaces/IZUniTabOperation.sol";
import {IPriceData} from "../interfaces/IUniTabOperation.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IZUniTab} from "../interfaces/IZUniTab.sol";

import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";

contract ZUniWithdrawTab is 
    Initializable, 
    UUPSUpgradeable,
    UniversalContract,
    ZUniTabOperation,
    IZUniWithdrawTab
{
    bool public constant isUniversal = true;

    constructor() {
        _disableInitializers();
    }

    /** 
     * @dev Initialization.
     * @param _admin Governance controller address.
     * @param _upgrader Proxy admin contract address.
     * @param _deployer Deployer address.
     * @param _gatewayAddress EVM gateway address.
     * @param _dexRouterAddress Uniswap v2 router address for gas token swaps.
     */
    function initialize(
        address _admin, 
        address _upgrader,
        address _deployer,
        address _gatewayAddress,
        address _btcbtc,
        address _dexRouterAddress
    ) 
        public 
        initializer 
    {
        __UUPSUpgradeable_init();
        __ZUniTabOperation_init(_admin, _upgrader, _deployer, _gatewayAddress, _btcbtc, 1 days);
        
        dexRouter = _dexRouterAddress;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function withdrawTab(
        uint256 _vaultId,
        uint256 _withdrawTabAmt,
        address _destination,
        address _receiver,
        IPriceData.UpdatePriceData calldata sigPrice
    ) external payable {
        if (_vaultId == 0 || _withdrawTabAmt == 0)
            revert ZeroValue();
        if (_destination == address(0) || _receiver == address(0))
            revert ZeroAddress();

        address zetaToken = IGatewayZEVMToken(gateway).zetaToken();

        if (_destination == zetaToken) {
            IVaultManager(vaultManager).withdrawTab(
                _vaultId,
                _withdrawTabAmt,
                _receiver,
                sigPrice
            );
        } else {
            if (msg.value == 0)
                revert ZeroDestinationGas();

            IVaultManager(vaultManager).withdrawTab(
                _vaultId,
                _withdrawTabAmt,
                address(this),
                sigPrice
            );
            address tabToken = IZUniTab(zUniTab).tabAddresses(zetaToken, tabKey(sigPrice.tab));
            IERC20(tabToken).approve(zUniTab, _withdrawTabAmt);
            IZUniTab(zUniTab).transferCrossChain{value: msg.value}(
                tabToken,
                _destination,
                address(0),
                0,
                _receiver,
                _withdrawTabAmt
            );
        }
        emit ZWithdrawTab(
            sigPrice.updater,
            _receiver,
            _vaultId,
            block.chainid, // ZetaChain expected
            tabKey(sigPrice.tab),
            _withdrawTabAmt,
            _destination
        );
    }

    /**
     * @dev Received withdraw Tab instruction.
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
        // sender is authorized caller
        if (!authorizedUniCallers[context.senderEVM])
            revert Unauthorized();

        (
            uint256 vaultId,
            uint256 withdrawTabAmt,
            address destination,
            address receiver,
            IPriceData.UpdatePriceData memory sigPrice
        ) = abi.decode(message, (uint256, uint256, address, address, IPriceData.UpdatePriceData));

        address zetaToken = IGatewayZEVMToken(gateway).zetaToken();

        if (destination == zetaToken) {
            IVaultManager(vaultManager).withdrawTab(
                vaultId,
                withdrawTabAmt,
                receiver,
                sigPrice
            );
        } else {
            IVaultManager(vaultManager).withdrawTab(
                vaultId,
                withdrawTabAmt,
                address(this),
                sigPrice
            );    
            address tabToken = IZUniTab(zUniTab).tabAddresses(zetaToken, tabKey(sigPrice.tab));
            IERC20(tabToken).approve(zUniTab, withdrawTabAmt);
            IERC20(zrc20).approve(zUniTab, amount);
            IZUniTab(zUniTab).transferCrossChain(
                tabToken,
                destination,
                zrc20,
                amount,
                receiver,
                withdrawTabAmt
            );
        }
        emit ZWithdrawTab(
            sigPrice.updater,
            receiver,
            vaultId,
            context.chainID,
            tabKey(sigPrice.tab),
            withdrawTabAmt,
            destination
        );
    }
}