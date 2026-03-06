// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IUniGovernance} from "../contracts/interfaces/IUniGovernance.sol";
import {UniGovernance} from "../contracts/governance/UniGovernance.sol";
import "@zetachain/protocol-contracts/contracts/evm/GatewayEVM.sol";

/**
 * Test assumptions, refer UniDeployer.t.sol:
 * uniGovernance1: set isGovSourceChain = true
 * uniGovernance2: supported chain's remote governance proxy. isGovSourceChain = false
 * zUniGovernance: deployed in ZetaChain, capable to manage all protocol contracts in ZetaChain
 */
contract UniGovernanceTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    function setUp() public {
        deploy();

    }

    function test_permission() public {
        assertEq(uniGovernance1.defaultAdmin() , address(governanceTimelockController));
        assertEq(uniGovernance1.hasRole(DEPLOYER_ROLE, address(governanceTimelockController)), true);
        assertEq(uniGovernance1.hasRole(DEPLOYER_ROLE, address(emergencyTimelockController)), true);
        assertEq(uniGovernance1.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(uniGovernance1.hasRole(GOVERNANCE_ROLE, address(governanceTimelockController)), true);
        assertEq(uniGovernance1.hasRole(GOVERNANCE_ROLE, address(emergencyTimelockController)), true);
        assertEq(uniGovernance1.hasRole(PAUSER_ROLE, address(governanceTimelockController)), true);
        assertEq(uniGovernance1.hasRole(PAUSER_ROLE, address(emergencyTimelockController)), true);
        assertEq(uniGovernance1.hasRole(PAUSER_ROLE, owner), true);
        assertEq(uniGovernance1.hasRole(UPGRADER_ROLE, address(governanceTimelockController)), true);
        assertEq(uniGovernance1.hasRole(GATEWAY_ROLE, ethereumGateway), true);
        assertEq(uniGovernance1.isGovSourceChain(), true);
        
        address zUniGovernanceAddr = address(zUniGovernance);
        assertEq(uniGovernance2.defaultAdmin() , zUniGovernanceAddr);
        assertEq(uniGovernance2.hasRole(DEPLOYER_ROLE, zUniGovernanceAddr), true);
        assertEq(uniGovernance2.hasRole(GOVERNANCE_ROLE, zUniGovernanceAddr), true);        
        assertEq(uniGovernance2.hasRole(PAUSER_ROLE, zUniGovernanceAddr), true);
        assertEq(uniGovernance2.hasRole(UPGRADER_ROLE, zUniGovernanceAddr), true);
        assertEq(uniGovernance2.hasRole(GATEWAY_ROLE, bnbGateway), true);
        assertEq(uniGovernance2.isGovSourceChain(), false);

        assertEq(uniGovernance1.universal(), zUniGovernanceAddr);
        assertEq(uniGovernance2.universal(), zUniGovernanceAddr);

        vm.startPrank(zUniGovernanceAddr);
        uniGovernance2.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        
        vm.startPrank(owner);
        uniGovernance2.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(uniGovernance2.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        UniGovernance newGov = new UniGovernance();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        uniGovernance1.upgradeToAndCall(address(newGov), "");
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        uniGovernance2.upgradeToAndCall(address(newGov), "");

        vm.startPrank(address(governanceTimelockController));
        uniGovernance1.upgradeToAndCall(address(newGov), "");

        vm.startPrank(address(zUniGovernance));
        uniGovernance2.upgradeToAndCall(address(newGov), "");
        vm.stopPrank();
    }

    function test_pause_unpause() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniGovernance1.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniGovernance1.unpause();

        vm.startPrank(address(governanceTimelockController));
        uniGovernance1.pause();
        assertEq(uniGovernance1.paused(), true);
        uniGovernance1.unpause();
        assertEq(uniGovernance1.paused(), false);

        vm.stopPrank();
    }

    function test_setUniversal() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniGovernance1.setUniversal(address(555));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniGovernance2.setUniversal(address(555));

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(abi.encodeWithSelector(
                            IUniGovernance.InvalidAddress.selector));
        uniGovernance1.setUniversal(address(0));

        vm.expectEmit();
        emit IUniGovernance.UpdatedZetaUniversal(address(zUniGovernance), address(666));
        uniGovernance1.setUniversal(address(666));
        assertEq(uniGovernance1.universal(), address(666));
    }

    function test_setGateway() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniGovernance1.setGateway(address(555));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniGovernance2.setGateway(address(555));

        vm.startPrank(address(zUniGovernance));
        vm.expectRevert(abi.encodeWithSelector(
                            IUniGovernance.InvalidAddress.selector));
        uniGovernance2.setGateway(address(0));
        vm.expectEmit();
        emit IUniGovernance.UpdatedGateway(address(uniGovernance2.gateway()), address(666));
        uniGovernance2.setGateway(address(666));
        assertEq(address(uniGovernance2.gateway()), address(666));
    }

    function test_execute() public {
        address targetContract = address(uniTab1);
        bytes memory callData = abi.encodeWithSignature("setRevertGasLimit(uint256)", 123456);
        assertEq(uniTab1.revertGasLimit(), 120000);

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            GOVERNANCE_ROLE));
        uniGovernance1.execute(targetContract, callData);
        
        vm.startPrank(address(governanceTimelockController));
        uniGovernance1.pause();
        vm.expectRevert(abi.encodeWithSelector(
                            PausableUpgradeable.EnforcedPause.selector));
        uniGovernance1.execute(targetContract, callData);

        uniGovernance1.unpause();
        vm.expectEmit();
        emit IUniGovernance.ExecutedLocalAction(targetContract);
        uniGovernance1.execute(targetContract, callData);
        assertEq(uniTab1.revertGasLimit(), 123456);
    }

    function test_executeRemote() public {
        address targetContract = address(tabRegistry);
        bytes memory callData = abi.encodeWithSignature("setConfigAddress(address)", address(777));
        assertEq(tabRegistry.config(), address(config));

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            GOVERNANCE_ROLE));
        uniGovernance1.executeRemote(bnbZrc20, targetContract, callData, 0);

        vm.startPrank(address(governanceTimelockController));
        uniGovernance1.pause();
        vm.expectRevert(abi.encodeWithSelector(
                            PausableUpgradeable.EnforcedPause.selector));
        uniGovernance1.executeRemote(bnbZrc20, targetContract, callData, 0);

        if (ethereumGateway.code.length > 0) {
            uniGovernance1.unpause();
            vm.expectEmit();
            emit IUniGovernance.CalledRemoteAction(
                bnbZrc20, 
                targetContract
            );
            uniGovernance1.executeRemote(bnbZrc20, targetContract, callData, 0);

            vm.deal(address(governanceTimelockController), 1 ether);
            uniGovernance1.executeRemote{value: 1 ether}(bnbZrc20, targetContract, callData, 0);
        }
    }

    function test_onCall() public {
        MessageContext memory context = MessageContext({
            sender: address(444)
        });
        bytes memory message = abi.encode(
            bnbZrc20,
            address(uniTab2),
            abi.encodeWithSignature("setRevertGasLimit(uint256)", 123456)
        );

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            GATEWAY_ROLE));
        uniGovernance2.onCall(context, message);

        vm.startPrank(address(bnbGateway));
        vm.expectRevert(abi.encodeWithSelector(
                            IUniGovernance.Unauthorized.selector));
        uniGovernance2.onCall(context, message);

        context.sender = address(zUniGovernance);
        assertEq(uniTab2.revertGasLimit(), 120000);
        vm.expectEmit();
        emit IUniGovernance.ExecutedRemoteAction(
            bnbZrc20,
            address(uniTab2)
        );
        uniGovernance2.onCall(context, message);
        assertEq(uniTab2.revertGasLimit(), 123456);
    }


}
