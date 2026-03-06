// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IUniTabOperation} from "../contracts/interfaces/IUniTabOperation.sol";
import {IUniWithdrawTab} from "../contracts/interfaces/IUniWithdrawTab.sol";
import {UniWithdrawTab} from "../contracts/core/UniWithdrawTab.sol";
import "@zetachain/protocol-contracts/contracts/evm/GatewayEVM.sol";

contract UniWithdrawTabTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(uniWithdrawTab.defaultAdmin() , address(uniGovernance1));
        assertEq(uniWithdrawTab.hasRole(DEPLOYER_ROLE, address(uniGovernance1)), true);
        assertEq(uniWithdrawTab.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(uniWithdrawTab.hasRole(PAUSER_ROLE, address(uniGovernance1)), true);
        assertEq(uniWithdrawTab.hasRole(PAUSER_ROLE, deployer), true);
        assertEq(uniWithdrawTab.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(uniWithdrawTab.hasRole(GATEWAY_ROLE, ethereumGateway), true);
        
        vm.expectRevert();
        uniWithdrawTab.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(uniGovernance1));
        uniWithdrawTab.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        uniWithdrawTab.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(uniWithdrawTab.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        UniWithdrawTab newContract = new UniWithdrawTab();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        uniWithdrawTab.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        uniWithdrawTab.upgradeToAndCall(address(newContract), "");
    }

    function test_pause_unpause() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniWithdrawTab.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniWithdrawTab.unpause();

        vm.startPrank(address(uniGovernance1));
        uniWithdrawTab.pause();
        assertEq(uniWithdrawTab.paused(), true);
        uniWithdrawTab.unpause();
        assertEq(uniWithdrawTab.paused(), false);
    }

    function test_setAuthorizedDestinations() public {
        assertEq(uniWithdrawTab.authorizedDestinations(ethereumZrc20), true);
        assertEq(uniWithdrawTab.authorizedDestinations(bnbZrc20), true);
        assertEq(uniWithdrawTab.authorizedDestinations(zetaZrc20), true);
        address[] memory addrs = new address[](2);
        addrs[0] = ethereumZrc20;
        addrs[1] = address(123);
        bool[] memory isAuthorized = new bool[](2);
        isAuthorized[0] = false;
        isAuthorized[1] = true;

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniWithdrawTab.setAuthorizedDestinations(addrs, isAuthorized);

        vm.startPrank(deployer);

        bool[] memory invalidIsAuthorized = new bool[](1);
        invalidIsAuthorized[0] = true;
        vm.expectRevert(IUniWithdrawTab.InvalidLength.selector);
        uniWithdrawTab.setAuthorizedDestinations(addrs, invalidIsAuthorized);

        addrs[1] = address(0);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniWithdrawTab.setAuthorizedDestinations(addrs, isAuthorized);
        
        addrs[1] = address(123);
        uniWithdrawTab.setAuthorizedDestinations(addrs, isAuthorized);
        assertEq(uniWithdrawTab.authorizedDestinations(ethereumZrc20), false);
        assertEq(uniWithdrawTab.authorizedDestinations(address(123)), true);
    }

    function test_withdrawTab_revert() public {
        vm.startPrank(address(uniGovernance1));
        uniWithdrawTab.pause();
        vm.expectRevert(abi.encodeWithSelector(
                            PausableUpgradeable.EnforcedPause.selector));
        uniWithdrawTab.withdrawTab(0, 1e18, ethereumZrc20, address(888), priceData);
        uniWithdrawTab.unpause();

        vm.expectRevert(IUniWithdrawTab.InvalidVault.selector);
        uniWithdrawTab.withdrawTab(0, 1e18, ethereumZrc20, address(888), priceData);

        vm.expectRevert(IUniWithdrawTab.InvalidDestination.selector);
        uniWithdrawTab.withdrawTab(123, 1e18, address(444), address(888), priceData);

        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniWithdrawTab.withdrawTab(123, 1e18, ethereumZrc20, address(0), priceData);

        vm.deal(address(uniGovernance1), 1 ether);
        vm.expectRevert(IUniTabOperation.EmptyPriceSignature.selector);
        uniWithdrawTab.withdrawTab{value: 1 ether}(123, 1e18, ethereumZrc20, address(888), priceData);
    }

    function test_withdrawTab(uint256 _amt) public {
        if (ethereumGateway.code.length == 0)
            return;
        vm.assume(_amt > 0.00001 ether && _amt < 0.1 ether);
        require(_amt > 0.00001 ether && _amt < 0.1 ether);
        vm.deal(owner, _amt);
        
        vm.startPrank(owner);
        priceData = signer.getUpdatePriceSignature(bytes3(abi.encodePacked("USD")), 100000e18, block.timestamp, 11155112);

        vm.expectEmit();
        emit IUniWithdrawTab.WithdrawTab(
            owner,
            123,
            1e18,
            ethereumZrc20,
            address(888),
            _amt
        );
        uniWithdrawTab.withdrawTab{value: _amt}(123, 1e18, ethereumZrc20, address(888), priceData);

        vm.expectEmit();
        emit IUniWithdrawTab.WithdrawTab(
            owner,
            123,
            1e18,
            zetaZrc20,
            address(888),
            0
        );
        uniWithdrawTab.withdrawTab(123, 1e18, zetaZrc20, address(888), priceData);
    }

    function test_onRevert() public {
        bytes memory message = abi.encode(
            address(888),     // sender
            123,              // vault id
            100e18            // withdraw tab amount
        );
        RevertContext memory context = RevertContext({
            sender: address(zUniWithdrawTab),
            asset: address(0), // asset
            amount: 1 ether,   // gasAmount
            revertMessage: message
        });

        // Revert native gas
        vm.startPrank(ethereumGateway);
        vm.deal(address(uniWithdrawTab), 1 ether);
        
        assertEq(address(888).balance, 0);
        vm.expectEmit();
        emit IUniWithdrawTab.RevertWithdrawTab(
            address(888),
            123,
            100e18,
            1 ether
        );
        uniWithdrawTab.onRevert(context);
        assertEq(address(888).balance, 1 ether);

        // Failed cases
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                        IAccessControl.AccessControlUnauthorizedAccount.selector, 
                        address(444), 
                        GATEWAY_ROLE));
        uniWithdrawTab.onRevert(context);

        vm.startPrank(ethereumGateway);
        context.sender = address(444);
        vm.expectRevert(IUniTabOperation.Unauthorized.selector);
        uniWithdrawTab.onRevert(context);
    }
}
