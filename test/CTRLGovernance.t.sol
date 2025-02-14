// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {CBBTC} from "../contracts/token/CBBTC.sol";

contract CTRLGovernanceTest is Deployer {

    function setUp() public {
        deploy();

        nextBlock(1 days + 1);
        vm.startPrank(address(governanceTimelockController));
        ctrl.acceptDefaultAdminTransfer();
        vm.stopPrank();
    }

    /**
     * @dev Voting delay = 2 days, Voting period = 3 days, Proposal threshold = 10000
     * Quorum = 5%, Token decimal = 18, Updatable setings = yes, Votes = ERC20Votes,
     * Timelock = TimelockController , 2 days timelock delay
     */
    function testShiftCtrlGovernorConfig() public {
        assertEq(shiftCtrlGovernor.votingDelay(), 2 days);
        assertEq(shiftCtrlGovernor.votingPeriod(), 3 days);
        assertEq(shiftCtrlGovernor.proposalThreshold(), 10000e18);
        assertEq(shiftCtrlGovernor.quorumNumerator(), 5);
        assertEq(shiftCtrlGovernor.quorumDenominator(), 100);

        vm.expectRevert();
        shiftCtrlGovernor.setVotingDelay(1);

        vm.expectRevert();
        shiftCtrlGovernor.setVotingPeriod(1);

        vm.expectRevert();
        shiftCtrlGovernor.setProposalThreshold(1);

        vm.expectRevert();
        shiftCtrlGovernor.updateQuorumNumerator(1);

        vm.startPrank(deployer);
        ctrl.mint(eoa_accounts[3], 10000e18);

        vm.startPrank(eoa_accounts[3]);

        ctrl.delegate(eoa_accounts[3]);
        nextBlock(1);

        address[] memory targets = new address[](5);
        uint256[] memory values = new uint256[](5);
        bytes[] memory calldatas = new bytes[](5);
        bytes32 description = keccak256(bytes("test"));

        address shiftCtrlGovernorAddr = address(shiftCtrlGovernor);
        targets[0] = shiftCtrlGovernorAddr;
        targets[1] = shiftCtrlGovernorAddr;
        targets[2] = shiftCtrlGovernorAddr;
        targets[3] = shiftCtrlGovernorAddr;
        targets[4] = address(governanceAction);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        values[4] = 0;
        calldatas[0] = abi.encodeWithSignature("setVotingDelay(uint48)", 100);
        calldatas[1] = abi.encodeWithSignature("setVotingPeriod(uint32)", 456);
        calldatas[2] = abi.encodeWithSignature("setProposalThreshold(uint256)", 123e18);
        calldatas[3] = abi.encodeWithSignature("updateQuorumNumerator(uint256)", 50);
        calldatas[4] = abi.encodeWithSignature("createNewTab(bytes3)", bytes3(abi.encodePacked("USD")));
        uint256 current = uint256(ctrl.clock());
        uint256 id = shiftCtrlGovernor.propose(targets, values, calldatas, "test");

        console.log("Proposed #", id);
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Pending);
        nextBlock(2 days + 1); // voting delay
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Active);

        // GovernorCountingSimple
        // enum VoteType {
        //     Against,
        //     For,
        //     Abstain
        // }
        shiftCtrlGovernor.castVote(id, 1); // GovernorCountingSimple.VoteType.For

        ctrl.transfer(eoa_accounts[4], 10000e18); // able to transfer token after voting
        
        vm.startPrank(eoa_accounts[4]);
        shiftCtrlGovernor.castVote(id, 1); // weight 0, no effect
        ctrl.delegate(eoa_accounts[4]);
        vm.stopPrank();

        assertEq(shiftCtrlGovernor.quorum(current), 500e18); // 5% of 10k
        assertEq(shiftCtrlGovernor.getVotes(eoa_accounts[3], current), 10000e18);
        assertEq(shiftCtrlGovernor.getVotes(eoa_accounts[4], current), 0);
    
        nextBlock(3 days); // voting period
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Succeeded);

        shiftCtrlGovernor.queue(targets, values, calldatas, description);
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Queued);

        nextBlock(2 days); // timelock delay
        id = shiftCtrlGovernor.execute(targets, values, calldatas, description);
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Executed);

        assertEq(shiftCtrlGovernor.votingDelay(), 100);
        assertEq(shiftCtrlGovernor.votingPeriod(), 456);
        assertEq(shiftCtrlGovernor.proposalThreshold(), 123e18);
        assertEq(shiftCtrlGovernor.quorumNumerator(), 50);
        assertEq(shiftCtrlGovernor.quorumDenominator(), 100);
        assertEq(tabRegistry.activatedTabCount(), 1);
    }

    /**
     * @dev Voting delay = 0, Voting period = 30 minutes, Proposal threshold = 1,000,000
     * Quorum = 5%, Token decimal = 18, Updatable setings = yes, Votes = ERC20Votes,
     * Timelock = TimelockController , 0 timelock delay
     */
    function testShiftCtrlEmergencyGovernorConfig() public {
        assertEq(shiftCtrlEmergencyGovernor.votingDelay(), 0);
        assertEq(shiftCtrlEmergencyGovernor.votingPeriod(), 30 minutes);
        assertEq(shiftCtrlEmergencyGovernor.proposalThreshold(), 1000000e18);
        assertEq(shiftCtrlEmergencyGovernor.quorumNumerator(), 5);
        assertEq(shiftCtrlEmergencyGovernor.quorumDenominator(), 100);

        vm.expectRevert();
        shiftCtrlEmergencyGovernor.setVotingDelay(1);

        vm.expectRevert();
        shiftCtrlEmergencyGovernor.setVotingPeriod(1);

        vm.expectRevert();
        shiftCtrlEmergencyGovernor.setProposalThreshold(1);

        vm.expectRevert();
        shiftCtrlEmergencyGovernor.updateQuorumNumerator(1);

        vm.startPrank(deployer);
        ctrl.mint(eoa_accounts[3], 1000000e18);

        vm.startPrank(eoa_accounts[3]);

        ctrl.delegate(eoa_accounts[3]);
        nextBlock(1);

        address[] memory targets = new address[](5);
        uint256[] memory values = new uint256[](5);
        bytes[] memory calldatas = new bytes[](5);
        bytes32 description = keccak256(bytes("test"));

        address addr = address(shiftCtrlEmergencyGovernor);
        address newReserve = address(new CBBTC(owner));
        assertEq(reserveRegistry.isEnabledReserve(newReserve), address(0));
        targets[0] = addr;
        targets[1] = addr;
        targets[2] = addr;
        targets[3] = addr;
        targets[4] = address(governanceAction);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        values[4] = 0;
        calldatas[0] = abi.encodeWithSignature("setVotingDelay(uint48)", 100);
        calldatas[1] = abi.encodeWithSignature("setVotingPeriod(uint32)", 456);
        calldatas[2] = abi.encodeWithSignature("setProposalThreshold(uint256)", 123e18);
        calldatas[3] = abi.encodeWithSignature("updateQuorumNumerator(uint256)", 50);
        calldatas[4] = abi.encodeWithSignature("addReserve(address,address)", newReserve, address(reserveSafe));
        uint256 current = uint256(ctrl.clock());
        uint256 id = shiftCtrlEmergencyGovernor.propose(targets, values, calldatas, "test");
        nextBlock(1);
        console.log("Proposed #", id);
        // No Pending state on emergency governor, set to 0 proposal delay
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

        nextBlock(10 minutes+ 1); // passed 30 minutes voting period
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
        assertEq(reserveRegistry.isEnabledReserve(newReserve), address(reserveSafe));
    }

    function testUpdateDelay() public {
        vm.startPrank(deployer);
        ctrl.mint(eoa_accounts[3], 1000000e18); // 1M
        assertEq(emergencyTimelockController.getMinDelay(), 0);

        vm.startPrank(eoa_accounts[3]);

        ctrl.delegate(eoa_accounts[3]);
        nextBlock(1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        bytes32 description = keccak256(bytes("update delay"));

        address addr = address(emergencyTimelockController);
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

        assertEq(emergencyTimelockController.getMinDelay(), 100);

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
        vm.expectRevert(); // exec delay 100
        id = shiftCtrlEmergencyGovernor.execute(targets, values, calldatas, description);
        assertEq(emergencyTimelockController.getMinDelay(), 100);

        nextBlock(100); // minDelay of timelock controller applied
        id = shiftCtrlEmergencyGovernor.execute(targets, values, calldatas, description);
        assertEq(emergencyTimelockController.getMinDelay(), 200);
    }

    function testProposeAndMint() public {
        vm.startPrank(deployer);
        ctrl.mint(eoa_accounts[3], 1000000e18); // total supply 1M as of now

        vm.startPrank(eoa_accounts[3]);

        ctrl.delegate(eoa_accounts[3]);
        nextBlock(1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        bytes32 description = keccak256(bytes("update delay"));

        address addr = address(emergencyTimelockController);
        targets[0] = addr;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("updateDelay(uint256)", 100);
        uint256 current = uint256(ctrl.clock());
        uint256 id = shiftCtrlEmergencyGovernor.propose(targets, values, calldatas, "update delay");
        nextBlock(1);

        shiftCtrlEmergencyGovernor.castVote(id, 1); // GovernorCountingSimple.VoteType.For

        vm.stopPrank();

        // increase supply and vote against
        vm.startPrank(deployer);
        ctrl.mint(eoa_accounts[1], 5000000e18);
        
        vm.startPrank(eoa_accounts[1]);
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

        assertEq(emergencyTimelockController.getMinDelay(), 100);
    }

    function testCancelProposal() public {
        vm.startPrank(deployer);
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
        calldatas[0] = abi.encodeWithSignature("setVotingDelay(uint48)", 100);
        calldatas[1] = abi.encodeWithSignature("setVotingPeriod(uint32)", 456);
        calldatas[2] = abi.encodeWithSignature("setProposalThreshold(uint256)", 123e18);
        calldatas[3] = abi.encodeWithSignature("updateQuorumNumerator(uint256)", 50);
        uint256 id = shiftCtrlGovernor.propose(targets, values, calldatas, "test");

        console.log("Proposed #", id);
        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Pending);

        changePrank(address(this));
        vm.expectRevert();
        uint256 cancelId = shiftCtrlGovernor.cancel(targets, values, calldatas, description);

        changePrank(eoa_accounts[3]);
        cancelId = shiftCtrlGovernor.cancel(targets, values, calldatas, description);
        assertEq(id, cancelId);

        assert(shiftCtrlGovernor.state(id) == IGovernor.ProposalState.Canceled);
    }

}
