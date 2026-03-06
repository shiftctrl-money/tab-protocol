// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {RevertContext,AbortContext} from "@zetachain/protocol-contracts/contracts/Revert.sol";
import {IWETH9} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IWZETA.sol";
import {ZRC20, ZRC20Errors} from "@zetachain/protocol-contracts/contracts/zevm/ZRC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IZUniTabOperation} from "../contracts/interfaces/IZUniTabOperation.sol";
import {IZUniProtocolVaultBuyTab} from "../contracts/interfaces/IZUniProtocolVaultBuyTab.sol";
import {ZUniProtocolVaultBuyTab} from "../contracts/core/ZUniProtocolVaultBuyTab.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";

contract ZUniProtocolVaultBuyTabTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bytes3 usd = bytes3(abi.encodePacked("USD"));
    address sUSD;
    bytes32 tabKey;

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(zUniProtocolVaultBuyTab.defaultAdmin() , address(zUniGovernance));
        assertEq(zUniProtocolVaultBuyTab.hasRole(DEPLOYER_ROLE, address(zUniGovernance)), true);
        assertEq(zUniProtocolVaultBuyTab.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(zUniProtocolVaultBuyTab.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(zUniProtocolVaultBuyTab.hasRole(GATEWAY_ROLE, zetaGateway), true);
        
        vm.expectRevert();
        zUniProtocolVaultBuyTab.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(zUniGovernance));
        zUniProtocolVaultBuyTab.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        zUniProtocolVaultBuyTab.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(zUniProtocolVaultBuyTab.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        ZUniProtocolVaultBuyTab newContract = new ZUniProtocolVaultBuyTab();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        zUniProtocolVaultBuyTab.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        zUniProtocolVaultBuyTab.upgradeToAndCall(address(newContract), "");
    }

    function test_updateProtocolVault() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniProtocolVaultBuyTab.updateProtocolVault(address(555));

        vm.startPrank(deployer);

        vm.expectRevert(abi.encodeWithSelector(
                            IZUniTabOperation.InvalidAddress.selector));
        zUniProtocolVaultBuyTab.updateProtocolVault(address(0));

        vm.expectEmit();
        emit IZUniProtocolVaultBuyTab.UpdatedProtocolVault(zUniProtocolVaultBuyTab.protocolVault(), address(555));
        zUniProtocolVaultBuyTab.updateProtocolVault(address(555));
        assertEq(zUniProtocolVaultBuyTab.protocolVault(), address(555));
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

    function test_onCall_reverts() public {
        if (zetaGateway.code.length == 0)
            return;
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(444)),
            senderEVM: address(444),
            chainID: block.chainid
        });
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            GATEWAY_ROLE));
        zUniProtocolVaultBuyTab.onCall(context, address(0), 0, "");

        vm.startPrank(zetaGateway);
        vm.expectRevert(abi.encodeWithSelector(IZUniTabOperation.Unauthorized.selector));
        zUniProtocolVaultBuyTab.onCall(context, address(0), 0, "");
    }

    function test_onCall_nativeGas(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 10 ether && _amt < 100 ether);
        require(_amt > 10 ether && _amt < 100 ether);
        
        _createVaultAndCtrlAltDel(address(888));
        vm.startPrank(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        IERC20(ethereumZrc20).transfer(address(zUniProtocolVaultBuyTab), _amt * 2);
        (
            ,
            ,
            ,
            uint256 tabAmt,
        ) = protocolVault.vaults(address(btcBtc), sUSD);

        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniProtocolVaultBuyTab)),
            senderEVM: address(uniProtocolVaultBuyTab),
            chainID: block.chainid
        });

        // ZetaChain destination
        bytes memory message = abi.encode(
            zetaZrc20,      // destination
            address(777),   // receiver
            address(0),     // sendToken
            0,              // sendAmount
            0,              // receiveGasAmt
            tabKey,         // receiveTabKey
            0               // btcOutMin
        );
        
        vm.startPrank(zetaGateway);
        vm.expectEmit(false, false, false, false);
        emit IZUniProtocolVaultBuyTab.ZBuyTab(
            address(777),
            block.chainid,
            _amt, // reserveAmount 
            0,    // btcAmount
            0,    // receiveGasWithFee,
            tabKey,
            0     // receiveTabAmount
        );
        zUniProtocolVaultBuyTab.onCall(context, ethereumZrc20, _amt, message);
        assertEq(IERC20(sUSD).balanceOf(address(777)) > 0, true);
        assertEq(IERC20(btcBtc).balanceOf(address(zUniProtocolVaultBuyTab)), 0);
        (
            ,
            uint256 updReserveAmt,
            ,
            uint256 updTabAmt,            
        ) = protocolVault.vaults(address(btcBtc), sUSD);
        assertEq(updReserveAmt, zUniProtocolVaultBuyTab.scaleUp(IERC20(btcBtc).balanceOf(address(protocolVault))));
        assertEq(updTabAmt, tabAmt + IERC20(sUSD).balanceOf(address(777)));

        // Supported chains destination
        message = abi.encode(
            ethereumZrc20,  // destination: non-zetachain
            address(999),   // receiver
            ethereumZrc20,  // sendToken
            _amt,           // sendAmount
            0.0001 ether,   // receiveGasAmt
            tabKey,         // receiveTabKey
            0
        );
        zUniProtocolVaultBuyTab.onCall(context, ethereumZrc20, _amt, message);
        assertEq(IERC20(sUSD).balanceOf(address(zUniProtocolVaultBuyTab)), 0);
        (
            ,
            updReserveAmt,
            ,
            updTabAmt,
        ) = protocolVault.vaults(address(btcBtc), sUSD);
        assertEq(updReserveAmt, zUniProtocolVaultBuyTab.scaleUp(IERC20(btcBtc).balanceOf(address(protocolVault))));   
        assertEq(updTabAmt > (tabAmt + IERC20(sUSD).balanceOf(address(777))), true);
    }

    function test_onCall_Token(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 10 ether && _amt < 100 ether);
        require(_amt > 10 ether && _amt < 100 ether);
        
        _createVaultAndCtrlAltDel(address(888));
        vm.startPrank(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        IERC20(zetaEthereumUsdc).transfer(address(zUniProtocolVaultBuyTab), _amt * 2);

        (
            ,
            ,
            ,
            uint256 tabAmt,
        ) = protocolVault.vaults(address(btcBtc), sUSD);

        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniProtocolVaultBuyTab)),
            senderEVM: address(uniProtocolVaultBuyTab),
            chainID: block.chainid
        });

        // ZetaChain destination
        bytes memory message = abi.encode(
            zetaZrc20,      // destination
            address(777),   // receiver
            zetaEthereumUsdc, // sendToken
            _amt,                  // sendAmount
            0.001 ether,           // receiveGasAmt
            tabKey,         // receiveTabKey
            0
        );
        assertEq(IERC20(sUSD).balanceOf(address(777)), 0);
        vm.startPrank(zetaGateway);
        vm.expectEmit(false, false, false, false);
        emit IZUniProtocolVaultBuyTab.ZBuyTab(
            address(777),
            block.chainid,
            _amt, // reserveAmount 
            0,    // btcAmount
            0,    // receiveGasWithFee,
            tabKey,
            0     // receiveTabAmount
        );
        zUniProtocolVaultBuyTab.onCall(context, zetaEthereumUsdc, _amt, message);
        assertEq(IERC20(sUSD).balanceOf(address(777)) > 0, true);
        assertEq(IERC20(btcBtc).balanceOf(address(zUniProtocolVaultBuyTab)), 0);
        (
            ,
            uint256 updReserveAmt,
            ,
            uint256 updTabAmt,            
        ) = protocolVault.vaults(address(btcBtc), sUSD);
        assertEq(updReserveAmt, zUniProtocolVaultBuyTab.scaleUp(IERC20(btcBtc).balanceOf(address(protocolVault))));
        assertEq(updTabAmt, tabAmt + IERC20(sUSD).balanceOf(address(777)));

        // Supported chains destination
        message = abi.encode(
            ethereumZrc20,  // destination: non-zetachain
            address(999),   // receiver
            zetaEthereumUsdc,  // sendToken
            _amt,           // sendAmount
            0.0001 ether,   // receiveGasAmt
            tabKey,         // receiveTabKey
            0
        );
        zUniProtocolVaultBuyTab.onCall(context, zetaEthereumUsdc, _amt, message);
        assertEq(IERC20(sUSD).balanceOf(address(zUniProtocolVaultBuyTab)), 0);
        (
            ,
            updReserveAmt,
            ,
            updTabAmt,
        ) = protocolVault.vaults(address(btcBtc), sUSD);
        assertEq(updReserveAmt, zUniProtocolVaultBuyTab.scaleUp(IERC20(btcBtc).balanceOf(address(protocolVault))));   
        assertEq(updTabAmt > (tabAmt + IERC20(sUSD).balanceOf(address(777))), true);
    }

}