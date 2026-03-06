// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IZUniGovernance} from "../contracts/interfaces/IZUniGovernance.sol";
import {ZUniGovernance} from "../contracts/governance/ZUniGovernance.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";

/**
 * Test assumptions, refer UniDeployer.t.sol:
 * zUniGovernance: set isGovSourceChain = true
 * uniGovernance2: supported chain's remote governance proxy. isGovSourceChain = false
 * zUniGovernance: deployed in ZetaChain, capable to manage all protocol contracts in ZetaChain
 */
contract ZUniGovernanceTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");
    bytes32 public constant UNIVERSAL_ROLE = keccak256("UNIVERSAL_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public {
        deploy();

    }

    function test_permission() public {
        assertEq(zUniGovernance.defaultAdmin() , deployer);

        assertEq(zUniGovernance.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(zUniGovernance.hasRole(PAUSER_ROLE, deployer), true);
        assertEq(zUniGovernance.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(zUniGovernance.hasRole(UPGRADER_ROLE, address(zUniGovernance)), true);
        assertEq(zUniGovernance.hasRole(GATEWAY_ROLE, zetaGateway), true);
        
        vm.startPrank(owner);
        zUniGovernance.beginDefaultAdminTransfer(address(666));
        nextBlock(1 days + 1);
        
        vm.startPrank(address(666));
        zUniGovernance.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(zUniGovernance.defaultAdmin() , address(666));
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        ZUniGovernance newGov = new ZUniGovernance();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        zUniGovernance.upgradeToAndCall(address(newGov), "");

        vm.startPrank(address(deployer));
        zUniGovernance.upgradeToAndCall(address(newGov), "");

        vm.startPrank(address(zUniGovernance));
        zUniGovernance.upgradeToAndCall(address(newGov), "");
        vm.stopPrank();
    }

    function test_pause_unpause() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        zUniGovernance.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        zUniGovernance.unpause();

        vm.startPrank(address(deployer));
        zUniGovernance.pause();
        assertEq(zUniGovernance.paused(), true);
        zUniGovernance.unpause();
        assertEq(zUniGovernance.paused(), false);

        vm.stopPrank();
    }

    function test_setGateway() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniGovernance.setGateway(address(666));

        vm.startPrank(address(deployer));
        vm.expectRevert(abi.encodeWithSelector(
                            IZUniGovernance.InvalidAddress.selector));
        zUniGovernance.setGateway(address(0));

        vm.expectEmit();
        emit IZUniGovernance.SetGateway(address(zUniGovernance.gateway()), address(666));
        zUniGovernance.setGateway(address(666));
        assertEq(zUniGovernance.hasRole(GATEWAY_ROLE, zetaGateway), false);
        assertEq(zUniGovernance.hasRole(GATEWAY_ROLE, address(666)), true);
    }

    function test_setConnected() public {
        address[] memory zrc20 = new address[](2);
        zrc20[0] = address(111);
        zrc20[1] = address(222);
        address[] memory uniGov = new address[](2);
        uniGov[0] = address(333);
        uniGov[1] = address(444);

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniGovernance.setConnected(zrc20, uniGov);

        vm.startPrank(address(deployer));
        vm.expectRevert(abi.encodeWithSelector(
                            IZUniGovernance.InvalidLength.selector));
        zUniGovernance.setConnected(zrc20, new address[](1));

        zrc20[0] = address(0);
        vm.expectRevert(abi.encodeWithSelector(
                            IZUniGovernance.InvalidAddress.selector));
        zUniGovernance.setConnected(zrc20, uniGov);

        zrc20[0] = address(111);
        vm.expectEmit();
        emit IZUniGovernance.SetConnected(address(111), address(333));
        emit IZUniGovernance.SetConnected(address(222), address(444));
        zUniGovernance.setConnected(zrc20, uniGov);
    }

    function test_setAuthorizedSender() public {
        address[] memory uniGov = new address[](2);
        uniGov[0] = address(333);
        uniGov[1] = address(444);
        bool[] memory isAuthorized = new bool[](2);
        isAuthorized[0] = true;
        isAuthorized[1] = false;

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniGovernance.setAuthorizedSender(uniGov, isAuthorized);

        vm.startPrank(address(deployer));
        vm.expectRevert(abi.encodeWithSelector(
                            IZUniGovernance.InvalidLength.selector));
        zUniGovernance.setAuthorizedSender(uniGov, new bool[](1));

        uniGov[0] = address(0);
        vm.expectRevert(abi.encodeWithSelector(
                            IZUniGovernance.InvalidAddress.selector));
        zUniGovernance.setAuthorizedSender(uniGov, isAuthorized);

        uniGov[0] = address(333);
        vm.expectEmit();
        emit IZUniGovernance.SetAuthorizedSender(address(333), true);
        emit IZUniGovernance.SetAuthorizedSender(address(444), false);
        zUniGovernance.setAuthorizedSender(uniGov, isAuthorized);
    }

    function test_setUniswapRouter() public {
        assertEq(zUniGovernance.uniswapRouter(), uniswapV2Router);
        address uniswapV2Router = address(888);

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniGovernance.setUniswapRouter(uniswapV2Router);

        vm.startPrank(address(deployer));
        vm.expectEmit();
        emit IZUniGovernance.SetUniswapRouter(
            address(zUniGovernance.uniswapRouter()), 
            uniswapV2Router
        );
        zUniGovernance.setUniswapRouter(uniswapV2Router);
        assertEq(zUniGovernance.uniswapRouter(), uniswapV2Router);
    }

    function test_onCall() public {
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(444)),
            senderEVM: address(444),
            chainID: block.chainid
        });
        bytes memory message = abi.encode(
            address(444), // invalid
            address(tabRegistry),
            120000,
            abi.encodeWithSignature("setConfigAddress(address)", address(666))
        );

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            GATEWAY_ROLE));
        zUniGovernance.onCall(context, address(0), 0, message);

        vm.startPrank(address(zetaGateway));
        vm.expectRevert(abi.encodeWithSelector(
                            IZUniGovernance.Unauthorized.selector));
        zUniGovernance.onCall(context, address(0), 0, message);

        context.sender = abi.encode(address(uniGovernance1));
        context.senderEVM = address(uniGovernance1);
        vm.expectRevert(abi.encodeWithSelector(
                            IZUniGovernance.UnsupportedDestination.selector));
        zUniGovernance.onCall(context, address(0), 0, message);

        if (zetaGateway.code.length > 0) {
            message = abi.encode(
                zetaZrc20,
                address(tabRegistry),
                120000,
                abi.encodeWithSignature("setConfigAddress(address)", address(666))
            );
            vm.expectEmit();
            emit IZUniGovernance.ExecutedLocalAction(
                address(tabRegistry)
            );
            zUniGovernance.onCall(context, address(0), 0, message);
            assertEq(tabRegistry.config(), address(666));

            vm.deal(address(zetaGateway), 1e18);
            vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
            TabERC20(ethereumZrc20).transfer(address(zUniGovernance), 1e18);

            vm.startPrank(address(zetaGateway));
            message = abi.encode( // call remote governance
                bnbZrc20,
                address(uniTab2),
                120000,
                abi.encodeWithSignature("setRevertGasLimit(uint256)", 123456)
            );
            vm.expectRevert(IZUniGovernance.InsufficientGasFee.selector);
            zUniGovernance.onCall(context, ethereumZrc20, 10, message); // insufficient ethereumZrc20

            vm.expectEmit();
            emit IZUniGovernance.ExecutingRemoteAction(bnbZrc20, address(uniTab2));
            zUniGovernance.onCall(context, ethereumZrc20, 1e18, message);
        }
    }


}
