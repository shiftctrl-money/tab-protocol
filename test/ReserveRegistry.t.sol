// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {Dec19BTC} from "./token/Dec19BTC.sol";
import {Dec18BTC} from "./token/Dec18BTC.sol";
import {IReserveRegistry} from "../contracts/interfaces/IReserveRegistry.sol";
import {IGovernanceAction} from "../contracts/interfaces/IGovernanceAction.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";

contract ReserveRegistryTest is Deployer {

    function setUp() public {
        deploy();
    }

    function test_permission() public {
        assertEq(reserveRegistry.defaultAdmin() , address(governanceTimelockController));
        assertEq(reserveRegistry.hasRole(MAINTAINER_ROLE, address(governanceTimelockController)), true);
        assertEq(reserveRegistry.hasRole(MAINTAINER_ROLE, address(emergencyTimelockController)), true);
        assertEq(reserveRegistry.hasRole(MAINTAINER_ROLE, address(governanceAction)), true);
        assertEq(reserveRegistry.hasRole(MAINTAINER_ROLE, owner), false);

        vm.expectRevert();
        reserveRegistry.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        reserveRegistry.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        reserveRegistry.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(reserveRegistry.defaultAdmin() , owner);
    }

    function test_updateReserveSafe() public {
        vm.expectRevert();
        reserveRegistry.updateReserveSafe(address(reserveSafe)); // unauthorized

        vm.startPrank(address(governanceAction));

        vm.expectRevert(IReserveRegistry.ZeroAddress.selector);
        reserveRegistry.updateReserveSafe(address(0));

        vm.expectRevert(IReserveRegistry.InvalidReserveSafe.selector);
        reserveRegistry.updateReserveSafe(eoa_accounts[1]);
        
        vm.expectEmit(address(reserveRegistry));
        emit IReserveRegistry.UpdatedReserveSafe(address(reserveSafe), address(vaultManager));
        reserveRegistry.updateReserveSafe(address(vaultManager));

        assertEq(reserveRegistry.reserveSafe(), address(vaultManager));

        vm.stopPrank();
    }

    function test_addReserve() public {
        Dec18BTC anotherSupportedBTCToken = new Dec18BTC(owner);

        vm.startPrank(owner); // unauthorized
        vm.expectRevert();
        governanceAction.addReserve(address(anotherSupportedBTCToken), address(reserveSafe));
        vm.expectRevert();
        reserveRegistry.addReserve(address(anotherSupportedBTCToken), address(reserveSafe));
        vm.stopPrank();

        vm.startPrank(address(governanceTimelockController));
        
        vm.expectRevert(IReserveRegistry.ZeroAddress.selector);
        governanceAction.addReserve(address(0), address(reserveSafe));
        vm.expectRevert(IReserveRegistry.ZeroAddress.selector);
        governanceAction.addReserve(address(anotherSupportedBTCToken), address(0));

        vm.expectRevert(IReserveRegistry.InvalidReserveSafe.selector);
        reserveRegistry.addReserve(address(anotherSupportedBTCToken), eoa_accounts[1]);

        vm.expectRevert(IReserveRegistry.ExistedReserveToken.selector);
        reserveRegistry.addReserve(address(cbBTC), address(reserveSafe));

        Dec19BTC dec19BTC = new Dec19BTC(owner);
        vm.expectRevert(abi.encodeWithSelector(IReserveRegistry.InvalidDecimals.selector, 19));
        reserveRegistry.addReserve(address(dec19BTC), address(reserveSafe));

        // try to add reserve token likely not compatible with ERC-20
        vm.expectRevert(IReserveRegistry.InvalidReserveToken.selector);
        reserveRegistry.addReserve(address(reserveSafe), address(reserveSafe));

        vm.expectEmit(address(reserveRegistry));
        emit IReserveRegistry.AddedReserve(address(anotherSupportedBTCToken), address(reserveSafe), 18);
        vm.expectEmit(address(governanceAction));
        emit IGovernanceAction.AddedReserve(address(anotherSupportedBTCToken), address(reserveSafe));
        governanceAction.addReserve(address(anotherSupportedBTCToken), address(reserveSafe));

        vm.stopPrank();

        assertEq(reserveRegistry.reserveAddrSafe(address(cbBTC)), address(reserveSafe));
        assertEq(reserveRegistry.reserveAddrSafe(address(anotherSupportedBTCToken)), address(reserveSafe));
        
        assertEq(reserveRegistry.enabledReserve(address(cbBTC)), true);
        assertEq(reserveRegistry.enabledReserve(address(anotherSupportedBTCToken)), true);
    }

    function test_disableReserve() public {
        vm.startPrank(owner); // unauthorized
        vm.expectRevert();
        governanceAction.disableReserve(address(cbBTC));
        vm.expectRevert();
        reserveRegistry.removeReserve(address(cbBTC));
        vm.stopPrank();

        // able to use active cbBTC to create new vault
        vm.startPrank(deployer);
        bytes3 sUSD = bytes3(abi.encodePacked("USD"));
        cbBTC.approve(address(vaultManager), 2e8);
        priceData = signer.getUpdatePriceSignature(sUSD, 60000e18, block.timestamp); 
        vaultManager.createVault(address(cbBTC), 1e18, 10000e18, priceData);

        vm.startPrank(address(governanceTimelockController));

        vm.expectRevert(IReserveRegistry.InvalidReserveToken.selector);
        governanceAction.disableReserve(address(0));

        assertEq(reserveRegistry.enabledReserve(address(cbBTC)), true);
        assertEq(reserveRegistry.isEnabledReserve(address(cbBTC)), address(reserveSafe));

        vm.expectEmit(address(reserveRegistry));
        emit IReserveRegistry.RemovedReserve(address(cbBTC));
        vm.expectEmit(address(governanceAction));
        emit IGovernanceAction.RemovedReserve(address(cbBTC));
        governanceAction.disableReserve(address(cbBTC));

        vm.expectRevert(IReserveRegistry.InvalidReserveToken.selector);
        governanceAction.disableReserve(address(cbBTC)); // already disabled

        assertEq(reserveRegistry.enabledReserve(address(cbBTC)), false);
        assertEq(reserveRegistry.isEnabledReserve(address(cbBTC)), address(0));

        vm.startPrank(deployer);
        // failed to make trx with cbBTC, the reserve token is disabled
        priceData = signer.getUpdatePriceSignature(sUSD, 60000e18, block.timestamp); 
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidReserve.selector, address(cbBTC)));
        vaultManager.createVault(address(cbBTC), 1e18, 10000e18, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidReserve.selector, address(cbBTC)));
        vaultManager.withdrawReserve(1, 1e6, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidReserve.selector, address(cbBTC)));
        vaultManager.depositReserve(deployer, 1, 1e6);
    }
}
