// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";
import {IZUniTab} from "../contracts/interfaces/IZUniTab.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";

/// @dev UniPaybackTab on supported chains will burn Tabs and call zUniTab. 
/// The zUniTab onCall function will "receive" Tabs to perform payback operation on VaultManager on behalf.
contract ZUniPaybackTabTest is UniDeployer {

    bytes3 usd = bytes3(abi.encodePacked("USD"));
    address sUSD;
    bytes32 tabKey;

    function setUp() public {
        deploy();
        deployUniWrapper();
        sUSD = _createVault(address(888), usd, 1e8, 100e18);
        tabKey = zUniCreateVault.tabKey(usd);
    }

    function _createVault(address vaultOwner, bytes3 vaultTab, uint256 btcAmt, uint256 tabAmt) internal returns(address) {
        vm.startPrank(owner);
        btcBtc.transfer(vaultOwner, 10e8);
        if (btcAmt > 10e8)
            btcAmt = 10e8;
        vm.startPrank(vaultOwner);
        btcBtc.approve(address(vaultManager), btcAmt);
        priceData = signer.getUpdatePriceSignature(vaultTab, 100000e18, block.timestamp, block.chainid);
        return vaultManager.createVault(
            address(btcBtc), 
            zUniWithdrawReserve.scaleUp(btcAmt), 
            tabAmt, 
            priceData
        );
    }

    function test_onCall_reverts(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 100e18 && _amt < 1000e18);
        require(_amt > 100e18 && _amt < 1000e18);
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniPaybackTab)),
            senderEVM: address(uniPaybackTab),
            chainID: block.chainid
        });
        bytes memory callData = abi.encodeWithSignature(
            "paybackTab(address,uint256,uint256)",
            address(888),   // vault Owner
            444,            // vault ID, invalid 444
            _amt            // paybackAmt
        );
        bytes memory message = abi.encode(
            sUSD,           // tabAddress
            tabKey,         // bytes32: tabKey
            zetaZrc20,      // destination
            address(zUniTab),      // receiver: ZUniTab on ZetaChain
            _amt,           // tokenAmount
            address(888),   // sender
            address(vaultManager), // callToAddress: only applicable for ZetaChain destination
            callData,       // callData
            true            // perform ERC-20 approve call on callToAddress
        );

        vm.startPrank(zetaGateway);
        vm.expectRevert(abi.encodeWithSelector(IZUniTab.ExecutionFailed.selector));
        zUniTab.onCall(context, address(0), 0, message);

        callData = abi.encodeWithSignature(
            "paybackTab(address,uint256,uint256)",
            address(888),   // vault Owner
            1,              // vault ID
            _amt            // paybackAmt, invalid excess amount
        );
        vm.expectRevert(abi.encodeWithSelector(IZUniTab.ExecutionFailed.selector));
        zUniTab.onCall(context, address(0), 0, message);
    }

    function test_onCall(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 0 && _amt < 100e18);
        require(_amt > 0 && _amt < 100e18);

        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniPaybackTab)),
            senderEVM: address(uniPaybackTab),
            chainID: block.chainid
        });
        bytes memory callData = abi.encodeWithSignature(
            "paybackTab(address,uint256,uint256)",
            address(888),   // vault Owner
            1,              // vault ID
            _amt            // paybackAmt
        );
        bytes memory message = abi.encode(
            sUSD,           // tabAddress
            tabKey,         // bytes32: tabKey
            zetaZrc20,      // destination
            address(zUniTab),      // receiver: ZUniTab on ZetaChain
            _amt,           // tokenAmount
            address(888),   // sender
            address(vaultManager), // callToAddress: only applicable for ZetaChain destination
            callData,       // callData
            true            // perform ERC-20 approve call on callToAddress
        );

        vm.startPrank(zetaGateway);
        vm.expectEmit();
        emit IZUniTab.TokenTransferToDestination(zetaZrc20, address(888), address(zUniTab), sUSD, _amt);
        zUniTab.onCall(context, address(0), 0, message);
        IVaultManager.Vault memory vault = vaultManager.getVaults(address(888), 1);
        assertEq(vault.tabAmt, 100e18 - _amt);
        assertEq(vault.osTabAmt, 0);
        assertEq(vault.pendingOsMint, 0);
        assertEq(vault.reserveAmt, 1e18);
    }


}