// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { ReserveSafe } from "../../contracts/ReserveSafe.sol";
import { MockERC20 } from "./helper/MockERC20.sol";

contract ReserveSafeTest is Test {

    ReserveSafe public reserveSafe;
    MockERC20 public mockReserve;
    address public dummyAdmin = address(1);
    address public dummyManager = address(2);

    function setUp() public {
        mockReserve = new MockERC20();
        reserveSafe = new ReserveSafe(dummyAdmin, dummyManager, address(mockReserve));
    }

    function testUnlockReserve() public {
        uint256 initialAmount = 1000;
        uint256 unlockAmount = 500;
        mockReserve.mint(address(reserveSafe), initialAmount);

        vm.startPrank(dummyManager);
        bool success = reserveSafe.unlockReserve(address(this), unlockAmount);
        assert(success);
        assertEq(mockReserve.balanceOf(address(this)), unlockAmount);
        vm.stopPrank();
    }

    function testInitialBalances() public view {
        assertEq(mockReserve.balanceOf(address(reserveSafe)), 0);
        assertEq(mockReserve.balanceOf(address(this)), 0);
    }

    function testUnlockMoreThanAvailable() public {
        uint256 initialAmount = 1000;
        uint256 unlockAmount = 1500;

        mockReserve.mint(address(reserveSafe), initialAmount);

        vm.startPrank(dummyManager);
        vm.expectRevert("Insufficient balance");

        bool success = reserveSafe.unlockReserve(address(this), unlockAmount);

        assert(!success); // This should not succeed
        assertEq(mockReserve.balanceOf(address(this)), 0); // No reserve should be unlocked

        vm.stopPrank();
    }

    function testUnlockByNonManager() public {
        uint256 initialAmount = 1000;
        uint256 unlockAmount = 500;

        mockReserve.mint(address(reserveSafe), initialAmount);
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0xc806897caf4fd5068191157e44d3988e43139a37e0b97b6793e1ed1184140604"
        );
        bool success = reserveSafe.unlockReserve(address(this), unlockAmount);
        assert(!success); // This should not succeed
        assertEq(mockReserve.balanceOf(address(this)), 0); // No reserve should be unlocked
    }

    function testMultipleUnlocks() public {
        uint256 initialAmount = 1000;
        uint256 unlockAmount1 = 300;
        uint256 unlockAmount2 = 400;
        mockReserve.mint(address(reserveSafe), initialAmount);

        vm.startPrank(dummyManager);
        bool success1 = reserveSafe.unlockReserve(address(this), unlockAmount1);
        assert(success1);
        assertEq(mockReserve.balanceOf(address(this)), unlockAmount1);

        bool success2 = reserveSafe.unlockReserve(address(this), unlockAmount2);
        assert(success2);
        assertEq(mockReserve.balanceOf(address(this)), unlockAmount1 + unlockAmount2);
        vm.stopPrank();
    }

}
