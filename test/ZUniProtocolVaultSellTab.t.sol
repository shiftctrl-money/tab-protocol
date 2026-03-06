// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IZUniTab} from "../contracts/interfaces/IZUniTab.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";

/// @dev UniProtocolVaultSellTab on supported chains will burn Tabs and call zUniTab. 
/// The zUniTab onCall function will "receive" Tabs to sell Tab on ProtocolVault on behalf.
contract ZUniProtocolVaultSellTabTest is UniDeployer {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes3 usd = bytes3(abi.encodePacked("USD"));
    address sUSD;
    bytes32 tabKey;

    function setUp() public {
        deploy();
        deployUniWrapper();
        tabKey = zUniCreateVault.tabKey(usd);
        _createVaultAndCtrlAltDel(address(888));
    }

    function _createVaultAndCtrlAltDel(address vaultOwner) internal {
        uint256 btcAmt = 10e8;
        uint256 tabAmt = 100000e18;
        vm.startPrank(owner);
        btcBtc.transfer(vaultOwner, 10e8);
        
        vm.startPrank(vaultOwner);
        btcBtc.approve(address(vaultManager), btcAmt);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, block.chainid);
        sUSD = vaultManager.createVault(
            address(btcBtc), 
            zUniProtocolVaultBuyTab.scaleUp(btcAmt), 
            tabAmt, 
            priceData
        );
        tabKey = zUniProtocolVaultBuyTab.tabKey(usd);

        vm.startPrank(address(zUniGovernance));
        IAccessControl(sUSD).revokeRole(MINTER_ROLE, address(vaultManager));
        IAccessControl(sUSD).grantRole(MINTER_ROLE, address(protocolVault));
        
        tabRegistry.ctrlAltDel(usd, 50000e18);
    }

    function test_onCall(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 1e18 && _amt < 100000e18);
        require(_amt > 1e18 && _amt < 100000e18);

        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniProtocolVaultSellTab)),
            senderEVM: address(uniProtocolVaultSellTab),
            chainID: block.chainid
        });
        bytes memory callData = abi.encodeWithSignature(
            "sellTab(address,address,uint256,address)",
            address(btcBtc),   // reserveAddr
            sUSD,              // tabAddr
            _amt,              // tabAmt
            address(777)       // receiver
        );
        bytes memory message = abi.encode(
            sUSD,           // tabAddress
            tabKey,         // bytes32: tabKey
            zetaZrc20,      // destination
            address(zUniTab),      // receiver: ZUniTab on ZetaChain
            _amt,           // tokenAmount
            address(888),   // sender
            address(protocolVault), // callToAddress: only applicable for ZetaChain destination
            callData,       // callData
            true            // perform ERC-20 approve call on callToAddress
        );

        vm.startPrank(zetaGateway);

        vm.expectEmit();
        emit IZUniTab.TokenTransferToDestination(zetaZrc20, address(888), address(zUniTab), sUSD, _amt);
        zUniTab.onCall(context, address(0), 0, message);
        assertEq(IERC20(address(btcBtc)).balanceOf(address(777)) > 0, true);

        (
            ,
            ,
            ,
            uint256 tabAmt,
        ) = protocolVault.vaults(address(btcBtc), sUSD);
        assertEq(tabAmt, 100000e18 - _amt);
    }


}