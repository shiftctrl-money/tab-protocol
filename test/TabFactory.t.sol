// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {TabERC20_newImpl} from "./token/TabERC20_newImpl.sol";

/// @dev reference https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment
/// https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment/blob/main/scripts/keyless-deploy-functions.js
contract TabFactoryTest is Deployer {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public {
        deploy();
    }

    function test_permission() public view {
        assertEq(tabFactory.owner(), address(governanceTimelockController));
        assertEq(tabFactory.implementation(), address(tabERC20));
        assertEq(tabFactory.tabRegistry(), address(tabRegistry));
    }

    function test_updateTabRegistry() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        tabFactory.updateTabRegistry(owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(TabFactory.ZeroAddress.selector);
        tabFactory.updateTabRegistry(address(0));

        vm.expectEmit();
        emit TabFactory.UpdatedTabRegistry(address(tabRegistry), owner);
        tabFactory.updateTabRegistry(owner);
        vm.stopPrank();

        assertEq(tabFactory.tabRegistry(), owner);
    }

    function test_createTab() public {
        vm.expectRevert(TabFactory.Unauthorized.selector);
        tabFactory.createTab(owner, address(vaultManager), "Sound USD", "sUSD");

        vm.startPrank(address(tabRegistry));
        vm.expectEmit(false, false, false, false);
        emit TabFactory.NewTabBeaconProxy("sUSD", owner); // owner is placeholder, should be sUSD proxy address
        address sUSDAddr = tabFactory.createTab(owner, address(vaultManager), "Sound USD", "sUSD");
        vm.stopPrank();

        TabERC20 sUSD = TabERC20(sUSDAddr);
        
        assertEq(sUSD.defaultAdmin() , owner);
        assertEq(sUSD.hasRole(MINTER_ROLE, address(vaultManager)), true);
        assertEq(sUSD.hasRole(MINTER_ROLE, owner), false);
        assertEq(sUSD.hasRole(MINTER_ROLE, address(governanceTimelockController)), false);

        assertEq(keccak256(abi.encodePacked(sUSD.tabCode())), keccak256(abi.encodePacked("USD")));
        assertEq(sUSD.tabKey(), keccak256(abi.encodePacked("USD")));
        assertEq(sUSD.name(), string(abi.encodePacked("Sound USD")));
        assertEq(sUSD.symbol(), "sUSD");
        assertEq(sUSD.decimals(), 18);
        assertEq(sUSD.totalSupply(), 0);
        assertEq(sUSD.balanceOf(owner), 0);

        vm.startPrank(address(vaultManager));
        sUSD.mint(owner, 1e18);
        assertEq(sUSD.balanceOf(owner), 1e18);
        vm.stopPrank();
        
        vm.startPrank(owner);
        sUSD.burn(1e18);
        assertEq(sUSD.balanceOf(owner), 0);
        vm.stopPrank();
    }

    function test_upgradeTabERC20() public {
        vm.startPrank(address(tabRegistry));
        address sUSDAddr = tabFactory.createTab(address(governanceTimelockController), address(vaultManager), "Sound USD", "sUSD");
        vm.stopPrank();

        TabERC20 sUSD = TabERC20(sUSDAddr);
        TabERC20_newImpl newImpl = new TabERC20_newImpl();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        tabFactory.upgradeTo(address(newImpl));

        // Tab proxy sUSD should now point to new implementation: TabERC20_newImpl
        vm.startPrank(address(governanceTimelockController));
        tabFactory.upgradeTo(address(newImpl));
        TabERC20_newImpl impl = TabERC20_newImpl(sUSDAddr);
        impl.grantRole(PAUSER_ROLE, address(governanceTimelockController));
        impl.grantRole(PAUSER_ROLE, address(emergencyTimelockController));
        vm.stopPrank();

        assertEq(sUSD.defaultAdmin() , address(governanceTimelockController));
        assertEq(sUSD.hasRole(MINTER_ROLE, address(vaultManager)), true);
        assertEq(sUSD.hasRole(MINTER_ROLE, owner), false);
        assertEq(sUSD.hasRole(MINTER_ROLE, address(governanceTimelockController)), false);

        assertEq(keccak256(abi.encodePacked(sUSD.tabCode())), keccak256(abi.encodePacked("USD")));
        assertEq(sUSD.tabKey(), keccak256(abi.encodePacked("USD")));
        assertEq(sUSD.name(), string(abi.encodePacked("Sound USD")));
        assertEq(sUSD.symbol(), "sUSD");
        assertEq(sUSD.decimals(), 18);
        assertEq(sUSD.totalSupply(), 0);
        assertEq(sUSD.balanceOf(owner), 0);

        vm.startPrank(address(vaultManager));
        sUSD.mint(owner, 1e18);
        assertEq(sUSD.balanceOf(owner), 1e18);
        vm.stopPrank();

        // calling new implementation's functions
        assertEq(keccak256(bytes(impl.symbolAndName())), keccak256(bytes("sUSD: Sound USD")));
        assertEq(impl.paused(), false);

        vm.expectRevert();
        impl.pause(); // unauthorized

        vm.startPrank(address(emergencyTimelockController));
        impl.pause();
        assertEq(impl.paused(), true);
        vm.stopPrank();

        vm.startPrank(address(vaultManager));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        sUSD.mint(owner, 1e18);
        vm.stopPrank();

        vm.startPrank(address(emergencyTimelockController));
        impl.unpause();
        assertEq(impl.paused(), false);
        vm.stopPrank();

        vm.startPrank(address(vaultManager));
        sUSD.mint(owner, 1e18);
        vm.stopPrank();
        
        assertEq(sUSD.balanceOf(owner), 2e18);
    }

}
