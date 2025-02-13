// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {IReserveSafe} from "../contracts/interfaces/IReserveSafe.sol";

contract ReserveSafeTest is Deployer {
    bytes32 public constant UNLOCKER_ROLE = keccak256("UNLOCKER_ROLE");
    bytes32 public constant RESERVE_REGISTRY_ROLE = keccak256("RESERVE_REGISTRY_ROLE");

    function setUp() public {
        deploy();
    }

    function test_permission() public {
        assertEq(reserveSafe.defaultAdmin() , address(governanceTimelockController));
        assertEq(reserveSafe.hasRole(UNLOCKER_ROLE, address(governanceTimelockController)), true);
        assertEq(reserveSafe.hasRole(UNLOCKER_ROLE, address(emergencyTimelockController)), true);
        assertEq(reserveSafe.hasRole(UNLOCKER_ROLE, address(vaultManager)), true);
        assertEq(reserveSafe.hasRole(RESERVE_REGISTRY_ROLE, address(governanceTimelockController)), true);
        assertEq(reserveSafe.hasRole(RESERVE_REGISTRY_ROLE, address(reserveRegistry)), true);

        vm.expectRevert();
        reserveSafe.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        reserveSafe.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        reserveSafe.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(reserveSafe.defaultAdmin() , owner);
    }

    function test_setReserveDecimal(uint256 dec) public {
        dec = bound(dec, 0, 18);
        require(dec >= 0 && dec < 19);
        if (dec == 0) {
            vm.startPrank(address(reserveRegistry));
            vm.expectRevert(IReserveSafe.ZeroValue.selector);
            reserveSafe.setReserveDecimal(address(cbBTC), dec);
            vm.stopPrank();
        } else {
            vm.expectRevert();
            reserveSafe.setReserveDecimal(address(cbBTC), dec);
            vm.startPrank(address(reserveRegistry));
            reserveSafe.setReserveDecimal(address(cbBTC), dec);
            vm.stopPrank();
            assertEq(reserveSafe.reserveDecimal(address(cbBTC)), dec);
        }
    }

    function test_unlockReserve() public {
        uint256 initBalance = 100e8;
        uint256 trfAmt = 10e8;
        assertEq(cbBTC.balanceOf(deployer), initBalance);
        vm.startPrank(deployer);
        cbBTC.transfer(address(reserveSafe), trfAmt);
        assertEq(cbBTC.balanceOf(deployer), initBalance - trfAmt);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), trfAmt);

        vm.expectRevert(); // unauthorized
        reserveSafe.unlockReserve(address(cbBTC), eoa_accounts[1], 9e18);
        
        vm.startPrank(address(vaultManager));
        vm.expectEmit(address(reserveSafe));
        emit IReserveSafe.UnlockedReserve(address(vaultManager), eoa_accounts[1], 9e8);
        reserveSafe.unlockReserve(address(cbBTC), eoa_accounts[1], 9e18);
        assertEq(cbBTC.balanceOf(eoa_accounts[1]), 9e8);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 1e8);
        vm.stopPrank();

        vm.startPrank(deployer);
        bytes3 sUSD = bytes3(abi.encodePacked("USD"));
        cbBTC.approve(address(vaultManager), 2e8);
        priceData = signer.getUpdatePriceSignature(sUSD, 60000e18, block.timestamp); 
        vaultManager.createVault(address(cbBTC), 1e18, 10000e18, priceData);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 2e8);

        vm.startPrank(address(vaultManager));
        vm.expectRevert();
        reserveSafe.unlockReserve(address(cbBTC), eoa_accounts[1], 3e18);
        reserveSafe.unlockReserve(address(cbBTC), eoa_accounts[1], 2e18);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 0);
        vm.stopPrank();
    }

    function test_approveSpendFromSafe(uint256 amt) public {
        amt = bound(amt, 1e18, 100e18);
        require(amt > 0 && amt <= 100e18);
        uint256 trfAmt = reserveSafe.getNativeTransferAmount(address(cbBTC), amt);
        vm.startPrank(deployer);
        cbBTC.transfer(address(reserveSafe), trfAmt);

        vm.expectRevert();
        reserveSafe.approveSpendFromSafe(address(cbBTC), owner, trfAmt);

        vm.startPrank(address(emergencyTimelockController));
        vm.expectEmit();
        emit IReserveSafe.ApprovedSpender(owner, trfAmt);
        reserveSafe.approveSpendFromSafe(address(cbBTC), owner, amt);
        vm.stopPrank();

        // obtained allowance to transfer out funds in Safe contract
        cbBTC.transferFrom(address(reserveSafe), eoa_accounts[2], trfAmt);
    }

    function test_getNativeTransferAmount(uint256 dec, uint256 value) public {
        dec = bound(dec, 1, 18);
        require(dec > 0 && dec < 19);
        vm.startPrank(address(reserveRegistry));
        reserveSafe.setReserveDecimal(address(cbBTC), dec); // decimal 1 to 18
        vm.stopPrank();
        uint256 v = value == 0? (value + 1) : value;
        uint256 converted = v;
        if (dec != 18)
            converted = v / (10 ** (18-dec));
        assertEq(reserveSafe.getNativeTransferAmount(address(cbBTC), v), converted);
    }

}
