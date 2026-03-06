// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IZUniTabOperation} from "../contracts/interfaces/IZUniTabOperation.sol";
import {IZUniDepositReserve} from "../contracts/interfaces/IZUniDepositReserve.sol";
import {ZUniDepositReserve} from "../contracts/core/ZUniDepositReserve.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";

contract ZUniDepositReserveTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    bytes3 usd = bytes3(abi.encodePacked("USD"));
    bytes3 aud = bytes3(abi.encodePacked("AUD"));

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(zUniDepositReserve.defaultAdmin() , address(zUniGovernance));
        assertEq(zUniDepositReserve.hasRole(DEPLOYER_ROLE, address(zUniGovernance)), true);
        assertEq(zUniDepositReserve.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(zUniDepositReserve.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(zUniDepositReserve.hasRole(GATEWAY_ROLE, zetaGateway), true);
        
        vm.expectRevert();
        zUniDepositReserve.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(zUniGovernance));
        zUniDepositReserve.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        zUniDepositReserve.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(zUniDepositReserve.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        ZUniDepositReserve newContract = new ZUniDepositReserve();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        zUniDepositReserve.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        zUniDepositReserve.upgradeToAndCall(address(newContract), "");
    }

    function test_onCall_reverts() public {
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(444)),
            senderEVM: address(444),
            chainID: 10333
        });
        bytes memory messageBTC = abi.encodePacked(
            address(888),     // vault owner
            uint256(123)      // vault id
        );
        // BTC deposit
        vm.startPrank(owner);
        btcBtc.transfer(address(zUniDepositReserve), 10e8);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            GATEWAY_ROLE));
        zUniDepositReserve.onCall(context, address(0), 0, "");

        vm.startPrank(zetaGateway);
        vm.expectRevert(abi.encodeWithSelector(IZUniDepositReserve.InvalidVault.selector, address(888), 123));
        zUniDepositReserve.onCall(context, address(btcBtc), 1e8, messageBTC);

        // EVM deposit
        bytes memory message = abi.encode(
            address(888),
            123,
            ethereumUsdc,
            1000e18,
            0
        );
        vm.expectRevert(IZUniTabOperation.Unauthorized.selector);
        zUniDepositReserve.onCall(context, address(zetaEthereumUsdc), 1000e18, message);
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
            zUniDepositReserve.scaleUp(btcAmt), 
            tabAmt, 
            priceData
        );
    }

    function test_onCall_bitcoinDeposit(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 1e6 && _amt < 5e8);
        require(_amt > 1e6 && _amt < 5e8);
        
        address sUSD = _createVault(address(888), usd, 1e8, 10e18);
        
        MessageContext memory context = MessageContext({
            sender: abi.encode(deployer),
            senderEVM: address(0),
            chainID: 10333 // BITCOIN_CHAIN_ID
        });
        bytes memory message = abi.encodePacked(
            address(888),     // vault owner
            uint256(1)        // vault id
        );
        vm.startPrank(owner);
        btcBtc.transfer(address(zUniDepositReserve), _amt);
        assertEq(IERC20(btcBtc).balanceOf(address(reserveSafe)), 1e8);

        vm.startPrank(zetaGateway);
        vm.expectEmit();
        emit IZUniDepositReserve.ZDepositReserve(
            address(888),
            1,
            address(0),
            0,
            _amt
        );
        zUniDepositReserve.onCall(context, address(btcBtc), _amt, message);

        (
            bytes3 tab,
            address reserveAddr,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            ,,
        ) = vaultUtils.getVaultDetails(address(888), 1, 100000e18);
        assertEq(tab == usd, true);
        assertEq(reserveAddr, address(btcBtc));
        assertEq(price, 100000e18);
        assertEq(osTab, 10e18);
        assertEq(IERC20(btcBtc).balanceOf(address(reserveSafe)), reserveSafe.getNativeTransferAmount(address(btcBtc), reserveAmt));
        assertEq(IERC20(btcBtc).balanceOf(address(reserveSafe)), 1e8 + _amt);
        assertEq(IERC20(btcBtc).balanceOf(address(zUniDepositReserve)), 0);
        assertEq(IERC20(sUSD).balanceOf(address(888)), 10e18);
    }

    function test_evmDeposit(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 5 ether && _amt < 100 ether);
        require(_amt > 5 ether && _amt < 100 ether);

        address sUSD = _createVault(address(888), usd, 1e8, 10e18);

        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniDepositReserve)),
            senderEVM: address(uniDepositReserve),
            chainID: 11155112
        });
        bytes memory message = abi.encode(
            address(888),
            1,
            ethereumUsdc,
            _amt,
            0
        );
        vm.startPrank(address(888));
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, block.chainid);
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        IERC20(zetaEthereumUsdc).transfer(address(zUniDepositReserve), _amt);
        assertEq(IERC20(btcBtc).balanceOf(address(reserveSafe)), 1e8);

        vm.startPrank(zetaGateway);
        vm.expectEmit(false, false, false, false);
        emit IZUniDepositReserve.ZDepositReserve(
            address(888),
            1,
            ethereumUsdc,
            _amt,
            1e18 // unchecked
        );
        zUniDepositReserve.onCall(context, zetaEthereumUsdc, _amt, message);

        (
            bytes3 tab,
            address reserveAddr,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            ,,
        ) = vaultUtils.getVaultDetails(address(888), 1, 100000e18);
        assertEq(tab == usd, true);
        assertEq(reserveAddr, address(btcBtc));
        assertEq(price, 100000e18);
        assertEq(osTab, 10e18);
        assertEq(IERC20(btcBtc).balanceOf(address(reserveSafe)), reserveSafe.getNativeTransferAmount(address(btcBtc), reserveAmt));
        assertEq(IERC20(btcBtc).balanceOf(address(reserveSafe)) > 1e8, true);
        assertEq(IERC20(btcBtc).balanceOf(address(zUniDepositReserve)), 0);
        assertEq(IERC20(zetaEthereumUsdc).balanceOf(address(zUniDepositReserve)), 0);
        assertEq(IERC20(sUSD).balanceOf(address(888)), 10e18);
    }

    function test_zDepositReserve_revert() public {
        vm.expectRevert(abi.encodeWithSelector(IZUniDepositReserve.AmbiguousAsset.selector, zetaEthereumUsdc, 0, 1 ether));
        zUniDepositReserve.zDepositReserve{value: 1 ether}(zetaEthereumUsdc, 0, deployer, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(IZUniDepositReserve.AmbiguousAsset.selector, address(0), 1 ether, 1 ether));
        zUniDepositReserve.zDepositReserve{value: 1 ether}(address(0), 1 ether, deployer, 1, 0);

        vm.expectRevert(IZUniDepositReserve.RequiredAssetAddress.selector);
        zUniDepositReserve.zDepositReserve(address(0), 1 ether, deployer, 1, 0);

        vm.expectRevert(IZUniDepositReserve.RequiredAssetAmount.selector);
        zUniDepositReserve.zDepositReserve(zetaEthereumUsdc, 0, deployer, 1, 0);
    }

    function test_zDepositReserve(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 10000 && _amt < 100 ether);
        require(_amt > 10000 && _amt < 100 ether);

        _createVault(address(888), usd, 1e8, 10e18);
        (
            ,
            ,
            ,
            uint256 reserveAmt,
            ,
            ,
            ,
        ) = vaultUtils.getVaultDetails(address(888), 1, 100000e18);

        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        IERC20(zetaEthereumUsdc).transfer(address(888), _amt);
        vm.deal(address(888), _amt);

        vm.startPrank(address(888));
        IERC20(zetaEthereumUsdc).approve(address(zUniDepositReserve), _amt);
        uint256 sid = vm.snapshot();

        uint256 minOutAmount = vaultUtils.getAmountsOut(
            zUniDepositReserve.dexRouter(),
            zetaZrc20,
            address(btcBtc),
            _amt
        );

        // (1) Native token
        if (minOutAmount > 0) {
            vm.expectEmit();
            emit IZUniDepositReserve.ZDepositReserve(
                address(888),
                1,
                zetaZrc20,
                _amt,
                minOutAmount
            );
            zUniDepositReserve.zDepositReserve{value: _amt}(address(0), 0, address(888), 1, 0);

            (
                ,
                ,
                ,
                uint256 reserveAmt2,
                ,
                ,
                ,
            ) = vaultUtils.getVaultDetails(address(888), 1, 100000e18);
            assertEq(reserveSafe.getNativeTransferAmount(address(btcBtc), reserveAmt2 - reserveAmt), minOutAmount);
            
        } else {
            vm.expectRevert();
            zUniDepositReserve.zDepositReserve{value: _amt}(address(0), 0, address(888), 1, 0);
        }

        // (2) Asset token
        vm.revertTo(sid);
        minOutAmount = vaultUtils.getAmountsOut(
            zUniDepositReserve.dexRouter(),
            zetaEthereumUsdc,
            address(btcBtc),
            _amt
        );
        if (minOutAmount > 0) {
            vm.expectEmit();
            emit IZUniDepositReserve.ZDepositReserve(
                address(888),
                1,
                zetaEthereumUsdc,
                _amt,
                minOutAmount
            );
            zUniDepositReserve.zDepositReserve(zetaEthereumUsdc, _amt, address(888), 1, 0);

            (
                ,
                ,
                ,
                uint256 reserveAmt3,
                ,
                ,
                ,
            ) = vaultUtils.getVaultDetails(address(888), 1, 100000e18);
            assertEq(reserveSafe.getNativeTransferAmount(address(btcBtc), reserveAmt3 - reserveAmt), minOutAmount);
        } else {
            vm.expectRevert();
            zUniDepositReserve.zDepositReserve(zetaEthereumUsdc, _amt, address(888), 1, 0);
        }
        
    }


}
