// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IUniTabOperation} from "../contracts/interfaces/IUniTabOperation.sol";
import {IUniDepositReserve} from "../contracts/interfaces/IUniDepositReserve.sol";
import {UniDepositReserve} from "../contracts/core/UniDepositReserve.sol";
import "@zetachain/protocol-contracts/contracts/evm/GatewayEVM.sol";

contract UniDepositReserveTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(uniDepositReserve.defaultAdmin() , address(uniGovernance1));
        assertEq(uniDepositReserve.hasRole(DEPLOYER_ROLE, address(uniGovernance1)), true);
        assertEq(uniDepositReserve.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(uniDepositReserve.hasRole(PAUSER_ROLE, address(uniGovernance1)), true);
        assertEq(uniDepositReserve.hasRole(PAUSER_ROLE, deployer), true);
        assertEq(uniDepositReserve.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(uniDepositReserve.hasRole(GATEWAY_ROLE, ethereumGateway), true);
        
        vm.expectRevert();
        uniDepositReserve.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(uniGovernance1));
        uniDepositReserve.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        uniDepositReserve.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(uniDepositReserve.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        UniDepositReserve newContract = new UniDepositReserve();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        uniDepositReserve.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        uniDepositReserve.upgradeToAndCall(address(newContract), "");
    }

    function test_pause_unpause() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniDepositReserve.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniDepositReserve.unpause();

        vm.startPrank(address(uniGovernance1));
        uniDepositReserve.pause();
        assertEq(uniDepositReserve.paused(), true);
        uniDepositReserve.unpause();
        assertEq(uniDepositReserve.paused(), false);
    }

    function test_depositReserve_revert() public {
        vm.expectRevert(IUniDepositReserve.InvalidSendTokenOrAmount.selector);
        uniDepositReserve.depositReserve(owner, 1, address(0), 1e18, 0);
        vm.expectRevert(IUniDepositReserve.InvalidSendTokenOrAmount.selector);
        uniDepositReserve.depositReserve(owner, 1, ethereumUsdc, 0, 0);

        vm.expectRevert(IUniDepositReserve.ZeroReserve.selector);
        uniDepositReserve.depositReserve(owner, 1, address(0), 0, 0);

        vm.expectRevert(); // no funds
        uniDepositReserve.depositReserve(owner, 1, ethereumUsdc, 1e30, 0);

        vm.startPrank(address(uniGovernance1));
        uniDepositReserve.pause();
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(
                            PausableUpgradeable.EnforcedPause.selector));
        uniDepositReserve.depositReserve{value: 1 ether}(owner, 1, address(0), 0, 0);
    }

    function test_depositReserve_token(uint256 _amt) public {
        if (ethereumGateway.code.length == 0)
            return;
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        uint256 bal = IERC20(ethereumUsdc).balanceOf(owner);
        vm.assume(_amt > 10 ether && _amt <= bal);
        require(_amt > 10 ether && _amt <= bal);

        vm.startPrank(owner);
        IERC20(ethereumUsdc).approve(address(uniDepositReserve), _amt);
        vm.expectEmit();
        emit IUniDepositReserve.DepositReserve(
            owner,
            1,
            ethereumUsdc,
            _amt,
            0
        );
        uniDepositReserve.depositReserve(owner, 1, ethereumUsdc, _amt, 0);
        assertEq(IERC20(ethereumUsdc).balanceOf(owner), bal - _amt);
    }

    function test_depositReserve_gas(uint256 _amt) public {
        if (ethereumGateway.code.length == 0)
            return;
        vm.assume(_amt > 1 ether && _amt < 10 ether);
        require(_amt > 1 ether && _amt < 10 ether);
        vm.deal(address(888), _amt);

        uint256 bal = address(888).balance;
        vm.startPrank(address(888));
        vm.expectEmit();
        emit IUniDepositReserve.DepositReserve(
            owner,
            1,
            address(0),
            0,
            _amt
        );
        uniDepositReserve.depositReserve{value: _amt}(owner, 1, address(0), 0, 0);
        assertEq(address(888).balance, bal - _amt);
    }

    function test_onRevert() public {
        bytes memory message = abi.encode(
            address(888),        // sender
            100e18,              // token amount
            0                    // native gas amount
        );
        RevertContext memory context = RevertContext({
            sender: address(zUniDepositReserve),
            asset: ethereumUsdc,      // asset
            amount: 100e18,           // token / gasAmount
            revertMessage: message
        });
        if (ethereumGateway.code.length == 0)
            return;

        // Revert ERC-20 USDC
        if (IERC20(ethereumUsdc).balanceOf(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) > 100e18) {
            vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
            IERC20(ethereumUsdc).transfer(address(uniDepositReserve), 100e18);

            assertEq(IERC20(ethereumUsdc).balanceOf(address(888)), 0);
            vm.startPrank(ethereumGateway);
            vm.expectEmit();
            emit IUniDepositReserve.TokenOrGasTransferReverted(
                ethereumUsdc,
                address(888),
                100e18,
                0,
                100e18
            );
            uniDepositReserve.onRevert(context);
            assertEq(IERC20(ethereumUsdc).balanceOf(address(888)), 100e18);
        }

        // Revert native gas
        vm.startPrank(ethereumGateway);
        vm.deal(address(uniDepositReserve), 100e18);
        message = abi.encode(
            address(888),        // sender
            0,                   // token amount
            100e18               // native gas amount
        );
        context.asset = address(0);
        context.revertMessage = message;
        assertEq(address(888).balance, 0);
        vm.expectEmit();
        emit IUniDepositReserve.TokenOrGasTransferReverted(
            address(0),
            address(888),
            0,
            100e18,
            100e18
        );
        uniDepositReserve.onRevert(context);
        assertEq(address(888).balance, 100e18);

        // Failed cases
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                        IAccessControl.AccessControlUnauthorizedAccount.selector, 
                        address(444), 
                        GATEWAY_ROLE));
        uniDepositReserve.onRevert(context);

        vm.startPrank(ethereumGateway);
        context.sender = address(444);
        vm.expectRevert(IUniTabOperation.Unauthorized.selector);
        uniDepositReserve.onRevert(context);
    }
}
