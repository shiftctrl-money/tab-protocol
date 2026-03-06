// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IUniTabOperation} from "../contracts/interfaces/IUniTabOperation.sol";
import {IUniWithdrawReserve} from "../contracts/interfaces/IUniWithdrawReserve.sol";
import {UniWithdrawReserve} from "../contracts/core/UniWithdrawReserve.sol";
import "@zetachain/protocol-contracts/contracts/evm/GatewayEVM.sol";

contract UniWithdrawReserveTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(uniWithdrawReserve.defaultAdmin() , address(uniGovernance1));
        assertEq(uniWithdrawReserve.hasRole(DEPLOYER_ROLE, address(uniGovernance1)), true);
        assertEq(uniWithdrawReserve.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(uniWithdrawReserve.hasRole(PAUSER_ROLE, address(uniGovernance1)), true);
        assertEq(uniWithdrawReserve.hasRole(PAUSER_ROLE, deployer), true);
        assertEq(uniWithdrawReserve.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(uniWithdrawReserve.hasRole(GATEWAY_ROLE, ethereumGateway), true);
        
        vm.expectRevert();
        uniWithdrawReserve.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(uniGovernance1));
        uniWithdrawReserve.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        uniWithdrawReserve.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(uniWithdrawReserve.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        UniWithdrawReserve newContract = new UniWithdrawReserve();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        uniWithdrawReserve.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        uniWithdrawReserve.upgradeToAndCall(address(newContract), "");
    }

    function test_pause_unpause() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniWithdrawReserve.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniWithdrawReserve.unpause();

        vm.startPrank(address(uniGovernance1));
        uniWithdrawReserve.pause();
        assertEq(uniWithdrawReserve.paused(), true);
        uniWithdrawReserve.unpause();
        assertEq(uniWithdrawReserve.paused(), false);
    }

    function test_setAuthorizedDestinations() public {
        assertEq(uniWithdrawReserve.authorizedDestinations(ethereumZrc20), true);
        assertEq(uniWithdrawReserve.authorizedDestinations(bnbZrc20), true);
        assertEq(uniWithdrawReserve.authorizedDestinations(zetaZrc20), true);
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
        uniWithdrawReserve.setAuthorizedDestinations(addrs, isAuthorized);

        vm.startPrank(deployer);

        bool[] memory invalidIsAuthorized = new bool[](1);
        invalidIsAuthorized[0] = true;
        vm.expectRevert(IUniWithdrawReserve.InvalidLength.selector);
        uniWithdrawReserve.setAuthorizedDestinations(addrs, invalidIsAuthorized);

        addrs[1] = address(0);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniWithdrawReserve.setAuthorizedDestinations(addrs, isAuthorized);
        
        addrs[1] = address(123);
        uniWithdrawReserve.setAuthorizedDestinations(addrs, isAuthorized);
        assertEq(uniWithdrawReserve.authorizedDestinations(ethereumZrc20), false);
        assertEq(uniWithdrawReserve.authorizedDestinations(address(123)), true);
    }

    function test_withdrawReserve_revert() public {
        vm.startPrank(address(uniGovernance1));
        uniWithdrawReserve.pause();
        vm.expectRevert(abi.encodeWithSelector(
                            PausableUpgradeable.EnforcedPause.selector));
        uniWithdrawReserve.withdrawReserve(
            1,
            1e18,
            ethereumZrc20,
            address(888),
            address(0),
            0,
            priceData
        );
        uniWithdrawReserve.unpause();

        vm.expectRevert(IUniWithdrawReserve.InvalidVault.selector);
        uniWithdrawReserve.withdrawReserve(
            0,
            1e18,
            ethereumZrc20,
            address(888),
            address(0),
            0,
            priceData
        );

        vm.expectRevert(IUniWithdrawReserve.InvalidDestination.selector);
        uniWithdrawReserve.withdrawReserve(
            1,
            1e18,
            address(444),
            address(888),
            address(0),
            0,
            priceData
        );

        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniWithdrawReserve.withdrawReserve(
            1,
            1e18,
            ethereumZrc20,
            address(0), // invalid receiver
            address(0),
            0,
            priceData
        );

        vm.expectRevert(IUniTabOperation.EmptyPriceSignature.selector);
        uniWithdrawReserve.withdrawReserve(
            1,
            1e18,
            ethereumZrc20,
            address(888),
            address(0),
            0,
            priceData
        );
    }

    function test_withdrawReserve() public {
        if (ethereumGateway.code.length == 0)
            return;

        vm.startPrank(owner);
        priceData = signer.getUpdatePriceSignature(bytes3(abi.encodePacked("USD")), 100000e18, block.timestamp, 11155112);
        
        vm.expectEmit();
        emit IUniWithdrawReserve.WithdrawReserve(
            owner,
            1,
            1e18,
            ethereumZrc20,
            address(888),
            address(0)
        );
        uniWithdrawReserve.withdrawReserve(
            1,
            1e18,
            address(0), // destination default to ethereumZrc20
            address(888),
            address(0),
            0,
            priceData
        );

        vm.expectEmit();
        emit IUniWithdrawReserve.WithdrawReserve(
            owner,
            999,
            100e18,
            ethereumZrc20,
            address(888),
            zetaEthereumUsdc
        );
        uniWithdrawReserve.withdrawReserve(
            999,
            100e18,
            ethereumZrc20,
            address(888),
            zetaEthereumUsdc,
            0,
            priceData
        );
    }

}
