// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";
import {IVaultKeeper} from "../contracts/interfaces/IVaultKeeper.sol";
import {IAuctionManager} from "../contracts/interfaces/IAuctionManager.sol";
import {IZUniTab} from "../contracts/interfaces/IZUniTab.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";

/// @dev UniAuctionBid on supported chains will burn Tabs and call zUniTab. 
/// The zUniTab onCall function will "receive" Tabs to bid on active auction.
contract ZUniAuctionBidTest is UniDeployer {

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
            sender: abi.encode(address(uniAuctionBid)),
            senderEVM: address(uniAuctionBid),
            chainID: block.chainid
        });
        bytes memory callData = abi.encodeWithSignature(
            "bidWithTab(uint256,address,uint256,address,address)",
            1,              // Auction ID
            sUSD,           // Tab Token
            _amt,           // Tab Amount
            address(777),   // Bidder
            address(777)    // Receiver
        );
        bytes memory message = abi.encode(
            sUSD,           // tabAddress
            tabKey,         // bytes32: tabKey
            zetaZrc20,      // destination
            address(zUniTab),      // receiver: ZUniTab on ZetaChain
            _amt,           // tokenAmount
            address(777),   // sender
            address(auctionManager), // callToAddress: only applicable for ZetaChain destination
            callData,       // callData
            true            // perform ERC-20 approve call on callToAddress
        );

        // Failed: no auction
        vm.startPrank(zetaGateway);
        vm.expectRevert(abi.encodeWithSelector(IZUniTab.ExecutionFailed.selector)); 
        zUniTab.onCall(context, address(0), 0, message);
    }

    function test_onCall(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 10e18 && _amt < 1000e18);
        require(_amt > 10e18 && _amt < 1000e18);

        // start auction
        vm.startPrank(address(888));
        priceData = signer.getUpdatePriceSignature(usd, 10e18, block.timestamp, block.chainid);
        IVaultKeeper.VaultDetails memory vaultDetails = IVaultKeeper.VaultDetails({
            vaultOwner: address(888),
            vaultId: 1,
            tab: usd,
            reserveAddr: address(btcBtc),
            osTab: 100e18,
            reserveValue: 1e18,
            minReserveValue: 180e18
        });
        vm.startPrank(keeperAddr);
        vaultKeeper.checkVault(block.timestamp, vaultDetails, priceData); 
        IAuctionManager.AuctionDetails memory auctionDetails = auctionManager.getAuctionDetails(1);
        uint256 osTabAmt = auctionDetails.osTabAmt;
        assertEq(osTabAmt > 100e18, true); // 100e18 + risk penalty charged
        assertEq(IERC20(btcBtc).balanceOf(address(777)), 0);

        vm.startPrank(zetaGateway);
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniAuctionBid)),
            senderEVM: address(uniAuctionBid),
            chainID: block.chainid
        });
        bytes memory callData = abi.encodeWithSignature(
            "bidWithTab(uint256,address,uint256,address,address)",
            1,              // Auction ID
            sUSD,           // Tab Token
            _amt,           // Tab Amount
            address(777),   // Bidder
            address(777)    // Receiver
        );
        bytes memory message = abi.encode(
            sUSD,           // tabAddress
            tabKey,         // bytes32: tabKey
            zetaZrc20,      // destination
            address(zUniTab),      // receiver: ZUniTab on ZetaChain
            _amt,           // tokenAmount
            address(777),   // sender
            address(auctionManager), // callToAddress: only applicable for ZetaChain destination
            callData,       // callData
            true            // perform ERC-20 approve call on callToAddress
        );

        vm.expectEmit();
        emit IZUniTab.TokenTransferToDestination(zetaZrc20, address(777), address(zUniTab), sUSD, _amt);
        zUniTab.onCall(context, address(0), 0, message);

        IAuctionManager.AuctionState memory state = auctionManager.getAuctionState(1);
        if (_amt > osTabAmt) {
            assertEq(IERC20(sUSD).balanceOf(address(777)), _amt - osTabAmt); // Bid amount > OS, refunded excess Tab
            assertEq(state.osTabAmt, 0);
        } else {
            assertEq(IERC20(sUSD).balanceOf(address(777)), 0);
            assertEq(state.osTabAmt, osTabAmt - _amt);
        }
        assertEq(IERC20(btcBtc).balanceOf(address(777)) > 0, true); // receiver has bidded BTC

    }
}