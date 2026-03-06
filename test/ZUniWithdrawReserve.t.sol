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
import {IZUniWithdrawReserve} from "../contracts/interfaces/IZUniWithdrawReserve.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";
import {ZUniWithdrawReserve} from "../contracts/core/ZUniWithdrawReserve.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";

contract ZUniWithdrawReserveTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    bytes3 usd = bytes3(abi.encodePacked("USD"));

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(zUniWithdrawReserve.defaultAdmin() , address(zUniGovernance));
        assertEq(zUniWithdrawReserve.hasRole(DEPLOYER_ROLE, address(zUniGovernance)), true);
        assertEq(zUniWithdrawReserve.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(zUniWithdrawReserve.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(zUniWithdrawReserve.hasRole(GATEWAY_ROLE, zetaGateway), true);
        
        vm.expectRevert();
        zUniWithdrawReserve.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(zUniGovernance));
        zUniWithdrawReserve.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        zUniWithdrawReserve.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(zUniWithdrawReserve.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        ZUniWithdrawReserve newContract = new ZUniWithdrawReserve();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        zUniWithdrawReserve.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        zUniWithdrawReserve.upgradeToAndCall(address(newContract), "");
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
        zUniWithdrawReserve.onCall(context, address(0), 0, "");

        _createVault(address(888), usd, 1e8, 100e18);

        vm.startPrank(address(888));
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, block.chainid);

        vm.startPrank(zetaGateway);
        vm.expectRevert(abi.encodeWithSelector(IZUniTabOperation.Unauthorized.selector));
        zUniWithdrawReserve.onCall(context, address(0), 0, "");

        context.senderEVM = address(uniWithdrawReserve);
        bytes memory message = abi.encode(
            1,
            2e4,
            ethereumZrc20,
            address(888),
            address(btcBtc), // invalid
            0,
            priceData
        );
        vm.expectRevert(abi.encodeWithSelector(IZUniWithdrawReserve.UnsupportedReceiveToken.selector));
        zUniWithdrawReserve.onCall(context, address(0), 0, message);

        message = abi.encode(
            1,
            1, // too low
            ethereumZrc20,
            address(888),
            zetaEthereumUsdc, // need to swap BTC/ethereumZrc20 for gas fee, and BTC/zetaEthereumUsdc to pay receiver
            0,
            priceData
        );
        vm.expectRevert(abi.encodeWithSelector(IZUniWithdrawReserve.InsufficientReserveAmt.selector));
        zUniWithdrawReserve.onCall(context, address(0), 0, message);

        message = abi.encode(
            4444,   // invalid vault id
            10000,
            ethereumZrc20,
            address(888),
            zetaEthereumUsdc,
            0,
            priceData
        );
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, address(888), 4444));
        zUniWithdrawReserve.onCall(context, address(0), 0, message);
    }

    function test_onCall(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 1000 && _amt < 1e7);
        require(_amt > 1000 && _amt < 1e7);
        _createVault(address(888), usd, 1567e5, 100e18);
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniWithdrawReserve)),
            senderEVM: address(uniWithdrawReserve),
            chainID: block.chainid
        });
        vm.startPrank(address(888));
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, block.chainid);

        vm.startPrank(zetaGateway);
        uint256 bal = IERC20(address(btcBtc)).balanceOf(address(888));

        // Withdraw BTC.BTC directly into ZetaChain
        bytes memory message = abi.encode(
            1,
            _amt,
            zetaZrc20,
            address(888),
            address(btcBtc),
            0,
            priceData
        );
        vm.expectEmit();
        emit IZUniWithdrawReserve.ZWithdrawReserve(
            address(888),
            address(888),
            1,
            block.chainid,
            _amt,
            _amt,
            address(btcBtc),
            _amt
        );
        zUniWithdrawReserve.onCall(context, address(0), 0, message);
        assertEq(IERC20(address(btcBtc)).balanceOf(address(888)), bal + _amt);

        // Withdraw supported ZRC-20 tokens into ZetaChain
        message = abi.encode(
            1,
            _amt,
            zetaZrc20,
            address(888),
            zetaEthereumUsdc,
            0,
            priceData
        );
        vm.expectEmit(false, false, false, false);
        emit IZUniWithdrawReserve.ZWithdrawReserve(
            address(888),
            address(888),
            1,
            block.chainid,
            _amt,
            _amt,
            zetaEthereumUsdc,
            _amt // invalid value, placeholder only
        );
        zUniWithdrawReserve.onCall(context, address(0), 0, message);
        assertEq(IERC20(address(zetaEthereumUsdc)).balanceOf(address(888)) > 0, true);

        // Withdraw Native gas into supported chains
        message = abi.encode(
            1,
            _amt,
            ethereumZrc20,
            address(888),
            ethereumZrc20,
            0,
            priceData
        );
        vm.expectEmit(false, false, false, false);
        emit IZUniWithdrawReserve.ZWithdrawReserve(
            address(888),
            address(888),
            1,
            block.chainid,
            _amt,
            _amt,
            ethereumZrc20,
            _amt // invalid value, placeholder only
        );
        zUniWithdrawReserve.onCall(context, address(0), 0, message);

        // Withdraw ZRC-20 tokens into supported chains
        message = abi.encode(
            1,
            _amt,
            ethereumZrc20,
            address(888),
            zetaEthereumUsdc,
            0,
            priceData
        );
        vm.expectEmit(false, false, false, false);
        emit IZUniWithdrawReserve.ZWithdrawReserve(
            address(888),
            address(888),
            1,
            block.chainid,
            _amt,
            _amt,
            zetaEthereumUsdc,
            _amt // invalid value, placeholder only
        );
        zUniWithdrawReserve.onCall(context, address(0), 0, message);

        IVaultManager.Vault memory vault = vaultManager.getVaults(address(888), 1);
        assertEq(vault.reserveAmt, zUniWithdrawReserve.scaleUp(1567e5) - zUniWithdrawReserve.scaleUp(_amt * 4));
    }

    function test_onRevert(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 0 && _amt < 100e18);
        require(_amt > 0 && _amt < 100e18);
        
        RevertContext memory revertContext = RevertContext({
            sender: address(444),
            asset: zetaEthereumUsdc, // asset
            amount: _amt,            // gasAmount
            revertMessage: abi.encode(
                address(888),
                123,
                block.chainid,
                5e5,                 // withdrawAmt   
                address(888),
                zetaEthereumUsdc,
                _amt
            )
        });
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        IERC20(zetaEthereumUsdc).transfer(address(zUniWithdrawReserve), _amt);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(this), 
                            GATEWAY_ROLE));
        zUniWithdrawReserve.onRevert(revertContext);

        vm.startPrank(zetaGateway);
        
        vm.expectRevert(IZUniTabOperation.Unauthorized.selector);
        zUniWithdrawReserve.onRevert(revertContext);

        revertContext.sender = address(zUniWithdrawReserve);
        vm.expectEmit();
        emit IZUniWithdrawReserve.RevertedWithdrawReserve(
            address(888),
            123,
            block.chainid,
            5e5,
            address(888),
            zetaEthereumUsdc,
            _amt
        );
        zUniWithdrawReserve.onRevert(revertContext);
        assertEq(IERC20(zetaEthereumUsdc).balanceOf(address(888)), _amt);
        assertEq(IERC20(zetaEthereumUsdc).balanceOf(address(zUniWithdrawReserve)), 0);
    }


}