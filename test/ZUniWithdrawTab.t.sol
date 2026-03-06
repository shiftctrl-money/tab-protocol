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
import {IZUniWithdrawTab} from "../contracts/interfaces/IZUniWithdrawTab.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";
import {ZUniWithdrawTab} from "../contracts/core/ZUniWithdrawTab.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";

contract ZUniWithdrawTabTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    bytes3 usd = bytes3(abi.encodePacked("USD"));
    address sUSD;
    bytes32 tabKey;

    function setUp() public {
        deploy();
        deployUniWrapper();
        sUSD = _createVault(address(888), usd, 1e8, 100e18);
        tabKey = zUniWithdrawTab.tabKey(usd);
    }

    function test_permission() public {
        assertEq(zUniWithdrawTab.defaultAdmin() , address(zUniGovernance));
        assertEq(zUniWithdrawTab.hasRole(DEPLOYER_ROLE, address(zUniGovernance)), true);
        assertEq(zUniWithdrawTab.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(zUniWithdrawTab.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(zUniWithdrawTab.hasRole(GATEWAY_ROLE, zetaGateway), true);
        
        vm.expectRevert();
        zUniWithdrawTab.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(zUniGovernance));
        zUniWithdrawTab.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        zUniWithdrawTab.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(zUniWithdrawTab.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        ZUniWithdrawTab newContract = new ZUniWithdrawTab();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        zUniWithdrawTab.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        zUniWithdrawTab.upgradeToAndCall(address(newContract), "");
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
            zUniWithdrawTab.scaleUp(btcAmt), 
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
        zUniWithdrawTab.onCall(context, address(0), 0, "");

        vm.startPrank(address(888));
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, block.chainid);

        vm.startPrank(zetaGateway);
        vm.expectRevert(abi.encodeWithSelector(IZUniTabOperation.Unauthorized.selector));
        zUniWithdrawTab.onCall(context, address(0), 0, "");

        context.senderEVM = address(uniWithdrawTab);
        bytes memory message = abi.encode(
            44444,   // invalid
            10e18,
            zetaZrc20,
            address(888),
            priceData
        );
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, address(888), 44444));
        zUniWithdrawTab.onCall(context, address(0), 0, message);

        message = abi.encode(
            1,   
            10e22, // invalid
            zetaZrc20,
            address(888),
            priceData
        );
        vm.expectRevert();
        zUniWithdrawTab.onCall(context, address(0), 0, message);

        // Calling ZUniWithdrawTab.withdrawTab

        vm.expectRevert(abi.encodeWithSelector(IZUniWithdrawTab.ZeroValue.selector));
        zUniWithdrawTab.withdrawTab(
            0,
            123,
            zetaZrc20,
            address(888),
            priceData
        );

        vm.expectRevert(abi.encodeWithSelector(IZUniWithdrawTab.ZeroValue.selector));
        zUniWithdrawTab.withdrawTab(
            1,
            0,
            zetaZrc20,
            address(888),
            priceData
        );

        vm.expectRevert(abi.encodeWithSelector(IZUniWithdrawTab.ZeroAddress.selector));
        zUniWithdrawTab.withdrawTab(
            1,
            123,
            address(0),
            address(888),
            priceData
        );

        vm.expectRevert(abi.encodeWithSelector(IZUniWithdrawTab.ZeroAddress.selector));
        zUniWithdrawTab.withdrawTab(
            1,
            123,
            zetaZrc20,
            address(0),
            priceData
        );

        vm.expectRevert(abi.encodeWithSelector(IZUniWithdrawTab.ZeroDestinationGas.selector));
        zUniWithdrawTab.withdrawTab(
            1,
            123,
            ethereumZrc20,
            address(888),
            priceData
        );
    }

    function test_onCall(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 1e18 && _amt < 10e18);
        require(_amt > 1e18 && _amt < 10e18);
        
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniWithdrawTab)),
            senderEVM: address(uniWithdrawTab),
            chainID: block.chainid
        });
        vm.startPrank(address(888));
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, block.chainid);

        vm.startPrank(zetaGateway);
        uint256 bal = IERC20(sUSD).balanceOf(address(888));

        // Withdraw Tab to ZetaChain
        bytes memory message = abi.encode(
            1,
            _amt,
            zetaZrc20,
            address(888),
            priceData
        );
        vm.expectEmit();
        emit IZUniWithdrawTab.ZWithdrawTab(
            address(888),
            address(888),
            1,
            block.chainid,
            tabKey,
            _amt,
            zetaZrc20
        );
        zUniWithdrawTab.onCall(context, address(0), 0, message);
        assertEq(IERC20(address(sUSD)).balanceOf(address(888)), bal + _amt);

        // Withdraw Tab to supported chains

        // prep works
        vm.startPrank(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        IERC20(ethereumZrc20).transfer(address(zUniWithdrawTab), 0.001 ether);

        vm.startPrank(zetaGateway);
        message = abi.encode(
            1,
            _amt,
            ethereumZrc20,
            address(888),
            priceData
        );
        vm.expectEmit();
        emit IZUniWithdrawTab.ZWithdrawTab(
            address(888),
            address(888),
            1,
            block.chainid,
            tabKey,
            _amt,
            ethereumZrc20
        );
        zUniWithdrawTab.onCall(context, address(ethereumZrc20), 0.001 ether, message);

        IVaultManager.Vault memory vault = vaultManager.getVaults(address(888), 1);
        assertEq(vault.tabAmt, 100e18 + _amt + _amt);

        vm.deal(address(888), 1e18);
        vm.startPrank(address(888));
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, block.chainid);

        // withdraw to zeta
        vm.expectEmit();
        emit IZUniWithdrawTab.ZWithdrawTab(
            address(888),
            address(777),
            1,
            block.chainid,
            tabKey,
            _amt,
            zetaZrc20
        );
        zUniWithdrawTab.withdrawTab{value: 1e17}(
            1,
            _amt,
            zetaZrc20,
            address(777),
            priceData
        );
        assertEq(IERC20(sUSD).balanceOf(address(777)), _amt);

        // withdraw to non-zeta (pay gas fee)
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, block.chainid);
        vm.expectEmit();
        emit IZUniWithdrawTab.ZWithdrawTab(
            address(888),
            address(777),
            1,
            block.chainid,
            tabKey,
            _amt,
            ethereumZrc20
        );
        zUniWithdrawTab.withdrawTab{value: 1e17}(
            1,
            _amt,
            ethereumZrc20,
            address(777),
            priceData
        );
        vault = vaultManager.getVaults(address(888), 1);
        assertEq(vault.tabAmt, 100e18 + _amt + _amt + _amt +_amt);
    }

}