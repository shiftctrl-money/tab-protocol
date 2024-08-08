// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
// import "lib/solady/src/utils/FixedPointMathLib.sol";

import "./Deployer.t.sol";
import { IERC20 } from "../../contracts/shared/interfaces/IERC20.sol";
import { DssVestMintable } from "./DssVest.sol";

contract DssVestMintableTest is Test, Deployer {

    DssVestMintable v;

    function setUp() public {
        test_deploy();
        v = new DssVestMintable(address(ctrl));

        ctrl.grantRole(keccak256("MINTER_ROLE"), address(v));

        v.file("cap", ctrl.cap()); // 10**9 * 10**18
        nextBlock(1708672740);
    }

    function nextBlock(uint256 increment) internal {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
    }

    function testVest1() public {
        uint256 startTime = block.timestamp;
        console.log("start vesting: ", startTime);
        uint256 id = v.create(
            eoa_accounts[1], // The recipient of the reward
            360000000e18, // The total amount of the vest
            block.timestamp, // The starting timestamp of the vest
            24 hours * 365 * 30, // The duration of the vest (in seconds) => 30 years linear
            24 hours * 30, // The cliff duration in seconds (i.e. 1 years) => monthly vesting
            address(this) // An optional manager for the contract. Can yank if vesting ends prematurely.
        );

        assertEq(v.usr(id), eoa_accounts[1]);
        assertEq(v.bgn(id), block.timestamp);
        assertEq(v.clf(id), block.timestamp + (24 hours * 30));
        assertEq(v.fin(id), block.timestamp + (24 hours * 365 * 30));
        assertEq(v.mgr(id), address(this));
        assertEq(v.res(id), 0); // restricted
        assertEq(v.tot(id), 36 * 10000000 * 10 ** 18);
        assertEq(v.rxd(id), 0); // claimed

        uint256 start = v.bgn(id);
        uint256 end = v.fin(id);
        uint256 cliff = v.clf(id);
        uint256 total = v.tot(id);
        console.log("start: ", start);
        console.log("end: ", end);
        console.log("cliff: ", cliff);
        console.log("total: ", total);

        vm.startPrank(eoa_accounts[3]);
        vm.expectRevert("DssVest/not-authorized");
        v.file("cap", 123);

        vm.expectRevert("DssVest/not-authorized");
        v.restrict(id);

        vm.expectRevert("DssVest/not-authorized");
        v.unrestrict(id);

        vm.stopPrank();

        // only vest owner or admin can restrict
        v.restrict(id);
        vm.expectRevert("DssVest/only-user-can-claim");
        v.vest(id);
        v.unrestrict(id);

        // expect claimable = 0, not reaching cliff
        console.log("Owner balance: ", ctrl.balanceOf(eoa_accounts[1]));
        vm.startPrank(eoa_accounts[1]);
        v.vest(id);
        assertEq(ctrl.balanceOf(eoa_accounts[1]), 0);
        assertEq(v.unpaid(id), 0);

        nextBlock(24 hours * 29);
        console.log("Passed 29 days...");
        assertEq(v.unpaid(id), 0);

        nextBlock(24 hours); // passed 30 days
        console.log("Passed 30 days...");
        // uint256 amt = unpaid(block.timestamp, _award.bgn, _award.clf, _award.fin, _award.tot, _award.rxd);
        // amt = _time < _clf ? 0 : sub(accrued(_time, _bgn, _fin, _tot), _rxd);
        // accrued = amt = mul(_tot, sub(_time, _bgn)) / sub(_fin, _bgn); // 0 <= amt < _award.tot
        uint256 monthlyVested = (total * (block.timestamp - start)) / (end - start);
        assertEq(v.unpaid(id), monthlyVested);
        v.vest(id);
        assertEq(ctrl.balanceOf(eoa_accounts[1]), monthlyVested);
        assertEq(v.unpaid(id), 0);
        console.log("30 days: ", monthlyVested); // 986301369863013698630136 = 986,301.369863013698630136

        nextBlock(24 hours * 120);
        console.log("Passed next 120 days...");
        uint256 fourMonths = ((total * (block.timestamp - start)) / (end - start)) - (monthlyVested);
        assertEq(v.unpaid(id), fourMonths);
        v.vest(id);
        assertEq(ctrl.balanceOf(eoa_accounts[1]), monthlyVested + fourMonths); // 5 months passed
        console.log("5 * 30: ", monthlyVested + fourMonths);
        console.log("daily avg: ", (monthlyVested + fourMonths) / 150);

        uint256 claimed = monthlyVested + fourMonths;
        for (uint256 i = 0; i < 355; i++) {
            // 360 months = 30 years
            nextBlock(24 hours * 30);
            uint256 claiming = block.timestamp >= end
                ? (total - claimed)
                : ((total * (block.timestamp - start)) / (end - start)) - (claimed);
            v.vest(id);
            claimed += claiming;
            assertEq(ctrl.balanceOf(eoa_accounts[1]), claimed);
        }
        console.log("Total claimed: ", claimed);
        console.log("Leftover: ", total - claimed);

        vm.stopPrank();
    }

    // 30 days cliff
    function testVest2() public {
        uint256 startTime = block.timestamp;
        console.log("start vesting: ", startTime);
        uint256 id = v.create(
            eoa_accounts[1], // The recipient of the reward
            360000000e18, // The total amount of the vest
            block.timestamp, // The starting timestamp of the vest
            24 hours * 365 * 30, // The duration of the vest (in seconds) => 30 years linear
            24 hours * 30, // The cliff duration in seconds (i.e. 1 years) => monthly vesting
            address(this) // An optional manager for the contract. Can yank if vesting ends prematurely.
        );
        uint256 start = v.bgn(id);
        uint256 end = v.fin(id);
        // uint256 cliff = v.clf(id);
        uint256 total = v.tot(id);

        vm.startPrank(eoa_accounts[1]);

        uint256 claimed = 0;
        nextBlock(24 hours * 30 * 360); // fast forward to 30 years
        uint256 claiming = block.timestamp >= end
            ? (total - claimed)
            : ((total * (block.timestamp - start)) / (end - start)) - (claimed);
        v.vest(id);
        claimed += claiming;
        assertEq(ctrl.balanceOf(eoa_accounts[1]), claimed);
        console.log("Total claimed (fast-forward 360 months): ", claimed);
        console.log("Leftover: ", total - claimed);
        // end:2654752741 - now:2641792741 = 12960000

        nextBlock(24 hours * 30 * 5); // 2592000 * 5 : another 5 months
        assertEq(v.unpaid(id), total - claimed);
        claiming = block.timestamp >= end
            ? (total - claimed)
            : ((total * (block.timestamp - start)) / (end - start)) - (claimed);
        v.vest(id);
        claimed += claiming;
        console.log("Total claimed (another 5 months): ", claimed);
        console.log("now: ", block.timestamp);
        console.log("end: ", end);

        vm.stopPrank();
    }

    function testVest_30d() public {
        uint256 startTime = block.timestamp;
        console.log("start vesting: ", startTime);
        uint256 id = v.create(
            eoa_accounts[1], // The recipient of the reward
            360000000e18, // The total amount of the vest
            block.timestamp, // The starting timestamp of the vest
            24 hours * 365 * 30, // The duration of the vest (in seconds) => 30 years linear
            24 hours * 30, // The cliff duration in seconds (i.e. 1 years) => monthly vesting
            address(this) // An optional manager for the contract. Can yank if vesting ends prematurely.
        );
        uint256 start = v.bgn(id);
        uint256 end = v.fin(id);
        // uint256 cliff = v.clf(id);
        uint256 total = v.tot(id);

        vm.startPrank(eoa_accounts[1]);

        uint256 claimed = 0;
        for (uint256 i = 0; i < 370; i++) {
            nextBlock(24 hours * 30);
            uint256 claiming = block.timestamp >= end
                ? (total - claimed)
                : ((total * (block.timestamp - start)) / (end - start)) - (claimed);
            // if (i > 360) {
            //     console.log("round #", i);
            //     console.log("claiming: ", claiming);
            // }
            assertEq(v.unpaid(id), claiming);
            v.vest(id);
            claimed += claiming;
            assertEq(ctrl.balanceOf(eoa_accounts[1]), claimed);
        }
        console.log("Total claimed: ", claimed);

        vm.stopPrank();
    }

    // 31 days cliff
    function testVest_31d() public {
        uint256 startTime = block.timestamp;
        console.log("start vesting: ", startTime);
        uint256 id = v.create(
            eoa_accounts[1], // The recipient of the reward
            360000000e18, // The total amount of the vest
            block.timestamp, // The starting timestamp of the vest
            24 hours * 365 * 30, // The duration of the vest (in seconds) => 30 years linear
            24 hours * 31, // The cliff duration in seconds (i.e. 1 years) => monthly vesting
            address(this) // An optional manager for the contract. Can yank if vesting ends prematurely.
        );
        uint256 start = v.bgn(id);
        uint256 end = v.fin(id);
        // uint256 cliff = v.clf(id);
        uint256 total = v.tot(id);

        vm.startPrank(eoa_accounts[1]);

        uint256 claimed = 0;
        for (uint256 i = 0; i < 354; i++) {
            nextBlock(24 hours * 31);
            uint256 claiming = block.timestamp >= end
                ? (total - claimed)
                : ((total * (block.timestamp - start)) / (end - start)) - (claimed);
            // if (i < 5 || i > 350) {
            //     console.log("round #", i);
            //     console.log("claiming: ", claiming); // 1019178082191780821917809 or 1019178082191780821917808, last
            // 230136986301369863013699
            // }
            assertEq(v.unpaid(id), claiming);
            v.vest(id);
            claimed += claiming;
            assertEq(ctrl.balanceOf(eoa_accounts[1]), claimed);
        }
        console.log("Total claimed: ", claimed);

        vm.stopPrank();
    }

    function testQuarterlyVesting() public {
        uint256 startTime = block.timestamp;
        console.log("start quarterly vesting: ", startTime);
        uint256 id = v.create(
            eoa_accounts[1], // The recipient of the reward
            160000000e18, // The total amount of the vest
            block.timestamp, // The starting timestamp of the vest
            24 hours * 365 * 4, // The duration of the vest (in seconds) => 4 years
            24 hours * 120, // The cliff duration in seconds (i.e. 1 years) => quarterly vesting
            address(this) // An optional manager for the contract. Can yank if vesting ends prematurely.
        );
        uint256 start = v.bgn(id);
        uint256 end = v.fin(id);
        uint256 cliff = v.clf(id);
        uint256 total = v.tot(id);
        console.log("start: ", start);
        console.log("end: ", end);
        console.log("cliff: ", cliff);
        console.log("total: ", total);

        vm.startPrank(eoa_accounts[1]);

        uint256 claimed = 0;
        for (uint256 i = 0; i < 13; i++) {
            // suppose 12, expect +1 so no leftover
            nextBlock(24 hours * 120);
            uint256 claiming = block.timestamp >= end
                ? (total - claimed)
                : ((total * (block.timestamp - start)) / (end - start)) - (claimed);
            // if (i < 5 || i > 9) {
            //     console.log("round #", i);
            //     console.log("claiming: ", claiming); // # 1-12: 13150684931506849315068493, last
            // 2191780821917808219178083
            // }
            assertEq(v.unpaid(id), claiming);
            v.vest(id);
            claimed += claiming;
            assertEq(ctrl.balanceOf(eoa_accounts[1]), claimed);
        }
        console.log("Total claimed: ", claimed);

        vm.stopPrank();
    }

    function testYank() public {
        uint256 startTime = block.timestamp;
        console.log("start quarterly vesting: ", startTime);
        uint256 id = v.create(
            eoa_accounts[1], // The recipient of the reward
            160000000e18, // The total amount of the vest
            block.timestamp, // The starting timestamp of the vest
            24 hours * 365 * 4, // The duration of the vest (in seconds) => 4 years
            24 hours * 120, // The cliff duration in seconds (i.e. 1 years) => quarterly vesting
            address(this) // An optional manager for the contract. Can yank if vesting ends prematurely.
        );
        uint256 start = v.bgn(id);
        uint256 end = v.fin(id);
        // uint256 cliff = v.clf(id);
        uint256 total = v.tot(id);

        vm.startPrank(eoa_accounts[1]);

        uint256 claimed = 0;
        uint256 claiming = 0;
        for (uint256 i = 0; i < 2; i++) {
            // only claims 3 times
            nextBlock(24 hours * 120);
            claiming = block.timestamp >= end
                ? (total - claimed)
                : ((total * (block.timestamp - start)) / (end - start)) - (claimed);
            assertEq(v.unpaid(id), claiming);
            v.vest(id);
            claimed += claiming;
            assertEq(ctrl.balanceOf(eoa_accounts[1]), claimed);
        }
        console.log("Total claimed 3 times: ", claimed);

        vm.stopPrank();

        vm.expectRevert("DssVest/only-user-can-move");
        v.move(id, eoa_accounts[8]);

        vm.startPrank(eoa_accounts[1]);
        vm.expectRevert("DssVest/zero-address-invalid");
        v.move(id, address(0));
        v.move(id, eoa_accounts[8]); // changed recipient
        vm.stopPrank();

        // vest again after changing recipient
        nextBlock(24 hours * 120);
        uint256 prevClaimed = claimed;
        claiming = block.timestamp >= end
            ? (total - claimed)
            : ((total * (block.timestamp - start)) / (end - start)) - (claimed);
        v.vest(id);
        claimed += claiming;
        assertEq(ctrl.balanceOf(eoa_accounts[1]), prevClaimed);
        assertEq(ctrl.balanceOf(eoa_accounts[8]), claiming);

        assertEq(v.valid(id), true);

        v.yank(id); // removed vesting

        assertEq(v.valid(id), false);

        nextBlock(24 hours * 120);
        vm.startPrank(eoa_accounts[1]);

        assertEq(v.unpaid(id), 0);
        v.vest(id);
        assertEq(ctrl.balanceOf(eoa_accounts[1]), prevClaimed); // value remained, do not receive new vesting
        assertEq(ctrl.balanceOf(eoa_accounts[8]), claiming);

        assertEq(ctrl.totalSupply(), prevClaimed + claiming); // total minted amount so far

        vm.stopPrank();
    }

}
