// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./Deployer.t.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { DssVestMintable } from "./DssVest.sol";

contract GovernanceTest is Test, Deployer {

    DssVestMintable vestingWallet;

    function nextBlock(uint256 increment) internal {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
    }

    function setUp() public {
        test_deploy();
        vestingWallet = new DssVestMintable(address(ctrl));

        ctrl.grantRole(keccak256("MINTER_ROLE"), address(vestingWallet));

        vestingWallet.file("cap", ctrl.cap()); // 10**9 * 10**18
        nextBlock(1708672740);
    }

    /**
     * ShiftCtrlGovernor default settings:
     * uint256 initialVotingDelay: 300 (1 hour), 1 hour = 60/12 * 60
     * uint256 initialVotingPeriod: 50400 blocks (12 seconds per block, 1 week = 60/12 * 60 * 24 * 7)
     * uint256 initialProposalThreshold: 100e18
     * uint256 quorumNumeratorValue: 10 (by default numerator / denominator, with denominator is 100),
     *  value 10 represents quorum being 10% of total supply
     */
    function testShiftCtrlGovernorConfig() public {
        assertEq(shiftCtrlGovernor.votingDelay(), 2 days);
        assertEq(shiftCtrlGovernor.votingPeriod(), 3 days);
        assertEq(shiftCtrlGovernor.proposalThreshold(), 10000e18);
        assertEq(shiftCtrlGovernor.quorumNumerator(), 5);
        assertEq(shiftCtrlGovernor.quorumDenominator(), 100);

        vm.expectRevert("Governor: onlyGovernance");
        shiftCtrlGovernor.setVotingDelay(1);

        vm.expectRevert("Governor: onlyGovernance");
        shiftCtrlGovernor.setVotingPeriod(1);

        vm.expectRevert("Governor: onlyGovernance");
        shiftCtrlGovernor.setProposalThreshold(1);

        vm.expectRevert("Governor: onlyGovernance");
        shiftCtrlGovernor.updateQuorumNumerator(1);

        ctrl.mint(eoa_accounts[3], 10000e18);

        vm.startPrank(eoa_accounts[3]);

        ctrl.delegate(eoa_accounts[3]);
        nextBlock(1);

        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory calldatas = new bytes[](4);
        bytes32 description = keccak256(bytes("test"));

        address shiftCtrlGovernorAddr = address(shiftCtrlGovernor);
        targets[0] = shiftCtrlGovernorAddr;
        targets[1] = shiftCtrlGovernorAddr;
        targets[2] = shiftCtrlGovernorAddr;
        targets[3] = shiftCtrlGovernorAddr;
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        calldatas[0] = abi.encodeWithSignature("setVotingDelay(uint256)", 100);
        calldatas[1] = abi.encodeWithSignature("setVotingPeriod(uint256)", 456);
        calldatas[2] = abi.encodeWithSignature("setProposalThreshold(uint256)", 123e18);
        calldatas[3] = abi.encodeWithSignature("updateQuorumNumerator(uint256)", 50);
        uint256 current = uint256(ctrl.clock());
        uint256 id = shiftCtrlGovernor.propose(targets, values, calldatas, "test");

        console.log("Proposed #", id);
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Pending);
        nextBlock(2 days + 1);
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Active);

        // GovernorCountingSimple
        // enum VoteType {
        //     Against,
        //     For,
        //     Abstain
        // }
        shiftCtrlGovernor.castVote(id, 1); // GovernorCountingSimple.VoteType.For
        vm.stopPrank();

        assertEq(shiftCtrlGovernor.quorum(current), 500e18); // 5% of 10k
        assertEq(shiftCtrlGovernor.getVotes(eoa_accounts[3], current), 10000e18);

        nextBlock(3 days);
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Succeeded);

        shiftCtrlGovernor.queue(targets, values, calldatas, description);
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Queued);

        id = shiftCtrlGovernor.execute(targets, values, calldatas, description);
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Executed);

        assertEq(shiftCtrlGovernor.votingDelay(), 100);
        assertEq(shiftCtrlGovernor.votingPeriod(), 456);
        assertEq(shiftCtrlGovernor.proposalThreshold(), 123e18);
        assertEq(shiftCtrlGovernor.quorumNumerator(), 50);
        assertEq(shiftCtrlGovernor.quorumDenominator(), 100);
    }

    /**
     * ShiftCtrlEmergencyGovernor default settings:
     * uint256 initialVotingDelay: 0
     * uint256 initialVotingPeriod: 300 blocks (12 seconds per block, 1 hour = 60/12 * 60)
     * uint256 initialProposalThreshold: 1000e18
     * uint256 quorumNumeratorValue: 51 (by default numerator / denominator, with denominator is 100),
     *  value 51 represents quorum being 51% of total supply
     *
     */
    function testShiftCtrlEmergencyGovernorConfig() public {
        assertEq(shiftCtrlEmergencyGovernor.votingDelay(), 0);
        assertEq(shiftCtrlEmergencyGovernor.votingPeriod(), 30 minutes);
        assertEq(shiftCtrlEmergencyGovernor.proposalThreshold(), 1000000e18);
        assertEq(shiftCtrlEmergencyGovernor.quorumNumerator(), 5);
        assertEq(shiftCtrlEmergencyGovernor.quorumDenominator(), 100);

        vm.expectRevert("Governor: onlyGovernance");
        shiftCtrlEmergencyGovernor.setVotingDelay(1);

        vm.expectRevert("Governor: onlyGovernance");
        shiftCtrlEmergencyGovernor.setVotingPeriod(1);

        vm.expectRevert("Governor: onlyGovernance");
        shiftCtrlEmergencyGovernor.setProposalThreshold(1);

        vm.expectRevert("Governor: onlyGovernance");
        shiftCtrlEmergencyGovernor.updateQuorumNumerator(1);

        ctrl.mint(eoa_accounts[3], 1000000e18);

        vm.startPrank(eoa_accounts[3]);

        ctrl.delegate(eoa_accounts[3]);
        nextBlock(1);

        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory calldatas = new bytes[](4);
        bytes32 description = keccak256(bytes("test"));

        address addr = address(shiftCtrlEmergencyGovernor);
        targets[0] = addr;
        targets[1] = addr;
        targets[2] = addr;
        targets[3] = addr;
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        calldatas[0] = abi.encodeWithSignature("setVotingDelay(uint256)", 100);
        calldatas[1] = abi.encodeWithSignature("setVotingPeriod(uint256)", 456);
        calldatas[2] = abi.encodeWithSignature("setProposalThreshold(uint256)", 123e18);
        calldatas[3] = abi.encodeWithSignature("updateQuorumNumerator(uint256)", 50);
        uint256 current = uint256(ctrl.clock());
        uint256 id = shiftCtrlEmergencyGovernor.propose(targets, values, calldatas, "test");
        nextBlock(1);
        console.log("Proposed #", id);
        // No Pending state on emergency governor, due to 0 proposal delay
        assert(shiftCtrlEmergencyGovernor.state(id) == IGovernor.ProposalState.Active);
        nextBlock(20 minutes); // within 30 minutes voting period, remained Active
        assert(shiftCtrlEmergencyGovernor.state(id) == IGovernor.ProposalState.Active);

        // GovernorCountingSimple
        // enum VoteType {
        //     Against,
        //     For,
        //     Abstain
        // }
        shiftCtrlEmergencyGovernor.castVote(id, 1); // GovernorCountingSimple.VoteType.For
        vm.stopPrank();

        assertEq(shiftCtrlEmergencyGovernor.quorum(current), 50000e18); // 5% of 1M
        assertEq(shiftCtrlEmergencyGovernor.getVotes(eoa_accounts[3], current), 1000000e18);

        nextBlock(10 minutes + 1); // passed 30 minutes voting period
        assert(shiftCtrlEmergencyGovernor.state(id) == IGovernor.ProposalState.Succeeded);

        shiftCtrlEmergencyGovernor.queue(targets, values, calldatas, description);
        assert(shiftCtrlEmergencyGovernor.state(id) == IGovernor.ProposalState.Queued);

        id = shiftCtrlEmergencyGovernor.execute(targets, values, calldatas, description);
        assert(shiftCtrlEmergencyGovernor.state(id) == IGovernor.ProposalState.Executed);

        assertEq(shiftCtrlEmergencyGovernor.votingDelay(), 100);
        assertEq(shiftCtrlEmergencyGovernor.votingPeriod(), 456);
        assertEq(shiftCtrlEmergencyGovernor.proposalThreshold(), 123e18);
        assertEq(shiftCtrlEmergencyGovernor.quorumNumerator(), 50);
        assertEq(shiftCtrlEmergencyGovernor.quorumDenominator(), 100);
    }

    function testUpdateDelay() public {
        ctrl.mint(eoa_accounts[3], 1000000e18); // 1M
        assertEq(timelockController.getMinDelay(), 0);

        vm.startPrank(eoa_accounts[3]);

        ctrl.delegate(eoa_accounts[3]);
        nextBlock(1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        bytes32 description = keccak256(bytes("update delay"));

        address addr = address(timelockController);
        targets[0] = addr;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("updateDelay(uint256)", 100);
        uint256 current = uint256(ctrl.clock());
        uint256 id = shiftCtrlEmergencyGovernor.propose(targets, values, calldatas, "update delay");
        nextBlock(1);
        console.log("Update delay Proposed #", id);
        assert(shiftCtrlEmergencyGovernor.state(id) == IGovernor.ProposalState.Active);
        shiftCtrlEmergencyGovernor.castVote(id, 1); // GovernorCountingSimple.VoteType.For

        vm.stopPrank();

        assertEq(shiftCtrlEmergencyGovernor.quorum(current), 5e22);
        assertEq(shiftCtrlEmergencyGovernor.getVotes(eoa_accounts[3], current), 1000000e18);
        nextBlock(30 minutes); // passed voting period
        shiftCtrlEmergencyGovernor.queue(targets, values, calldatas, description);
        id = shiftCtrlEmergencyGovernor.execute(targets, values, calldatas, description);
        assert(shiftCtrlEmergencyGovernor.state(id) == IGovernor.ProposalState.Executed);

        assertEq(timelockController.getMinDelay(), 100);

        // another new proposal
        vm.startPrank(eoa_accounts[3]);
        description = keccak256(bytes("update delay again"));
        calldatas[0] = abi.encodeWithSignature("updateDelay(uint256)", 200);
        current = uint256(ctrl.clock());
        id = shiftCtrlEmergencyGovernor.propose(targets, values, calldatas, "update delay again");
        nextBlock(1);
        console.log("Update delay again Proposed #", id);
        assert(shiftCtrlEmergencyGovernor.state(id) == IGovernor.ProposalState.Active);
        shiftCtrlEmergencyGovernor.castVote(id, 1); // GovernorCountingSimple.VoteType.For
        vm.stopPrank();

        nextBlock(30 minutes); // passed voting period
        shiftCtrlEmergencyGovernor.queue(targets, values, calldatas, description);
        vm.expectRevert("TimelockController: operation is not ready"); // exec delay 100
        id = shiftCtrlEmergencyGovernor.execute(targets, values, calldatas, description);
        assertEq(timelockController.getMinDelay(), 100);

        nextBlock(100); // minDelay of timelock controller applied
        id = shiftCtrlEmergencyGovernor.execute(targets, values, calldatas, description);
        assertEq(timelockController.getMinDelay(), 200);
    }

    function testProposeAndVest() public {
        uint256 vestId = vestingWallet.create(
            eoa_accounts[1], // The recipient of the reward
            360000000e18, // The total amount of the vest
            block.timestamp, // The starting timestamp of the vest
            24 hours * 365, // The duration of the vest (in seconds) => 1 year linear
            1 hours, // The cliff duration in seconds (i.e. 1 years) => hourly
            address(this) // An optional manager for the contract. Can yank if vesting ends prematurely.
        );
        nextBlock(10000);

        ctrl.mint(eoa_accounts[3], 1000000e18); // total supply 1M as of now

        vm.startPrank(eoa_accounts[3]);

        ctrl.delegate(eoa_accounts[3]);
        nextBlock(1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        bytes32 description = keccak256(bytes("update delay"));

        address addr = address(timelockController);
        targets[0] = addr;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("updateDelay(uint256)", 100);
        uint256 current = uint256(ctrl.clock());
        uint256 id = shiftCtrlEmergencyGovernor.propose(targets, values, calldatas, "update delay");
        nextBlock(1);

        shiftCtrlEmergencyGovernor.castVote(id, 1); // GovernorCountingSimple.VoteType.For

        vm.stopPrank();

        // vesting holder votes Against
        vm.startPrank(eoa_accounts[1]);
        vestingWallet.vest(vestId);
        console.log("EOA 1 holding: ", ctrl.balanceOf(eoa_accounts[1]));
        ctrl.delegate(eoa_accounts[1]);
        nextBlock(1);
        shiftCtrlEmergencyGovernor.castVote(id, 0); // 0: Against
        vm.stopPrank();

        assertEq(shiftCtrlEmergencyGovernor.quorum(current), 50000e18); // 5% of 1M
        assertEq(shiftCtrlEmergencyGovernor.getVotes(eoa_accounts[3], current), 1000000e18);
        assertEq(shiftCtrlEmergencyGovernor.getVotes(eoa_accounts[1], current), 0);
        nextBlock(30 minutes);
        shiftCtrlEmergencyGovernor.queue(targets, values, calldatas, description);
        id = shiftCtrlEmergencyGovernor.execute(targets, values, calldatas, description);
        assert(shiftCtrlEmergencyGovernor.state(id) == IGovernor.ProposalState.Executed);

        assertEq(timelockController.getMinDelay(), 100);
    }

    function testCancelProposal() public {
        ctrl.mint(eoa_accounts[3], 10000e18);

        vm.startPrank(eoa_accounts[3]);

        ctrl.delegate(eoa_accounts[3]);
        nextBlock(1);

        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory calldatas = new bytes[](4);
        bytes32 description = keccak256(bytes("test"));

        address shiftCtrlGovernorAddr = address(shiftCtrlGovernor);
        targets[0] = shiftCtrlGovernorAddr;
        targets[1] = shiftCtrlGovernorAddr;
        targets[2] = shiftCtrlGovernorAddr;
        targets[3] = shiftCtrlGovernorAddr;
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        calldatas[0] = abi.encodeWithSignature("setVotingDelay(uint256)", 100);
        calldatas[1] = abi.encodeWithSignature("setVotingPeriod(uint256)", 456);
        calldatas[2] = abi.encodeWithSignature("setProposalThreshold(uint256)", 123e18);
        calldatas[3] = abi.encodeWithSignature("updateQuorumNumerator(uint256)", 50);
        uint256 id = shiftCtrlGovernor.propose(targets, values, calldatas, "test");

        console.log("Proposed #", id);
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Pending);

        changePrank(address(this));
        vm.expectRevert("Governor: only proposer can cancel");
        uint256 cancelId = shiftCtrlGovernor.cancel(targets, values, calldatas, description);

        changePrank(eoa_accounts[3]);
        cancelId = shiftCtrlGovernor.cancel(targets, values, calldatas, description);
        assertEq(id, cancelId);

        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Canceled);
    }

}
