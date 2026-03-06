// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {TabERC20_newImpl} from "./token/TabERC20_newImpl.sol";
import {ITabFactory} from "../contracts/interfaces/ITabFactory.sol";

/// @dev https://github.com/ZeframLou/create3-factory
contract TabFactoryTest is UniDeployer {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public {
        deploy();
    }

    function test_permission() public view {
        assertEq(tabFactory.owner(), address(zUniGovernance));
        assertEq(tabFactory.implementation(), address(tabERC20));
        assertEq(tabFactory.creator(), address(tabRegistry));
    }

    function test_updateCreator() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        tabFactory.updateCreator(owner);

        vm.startPrank(address(zUniGovernance));
        vm.expectRevert(ITabFactory.ZeroAddress.selector);
        tabFactory.updateCreator(address(0));

        vm.expectEmit();
        emit ITabFactory.UpdatedCreator(address(tabRegistry), owner);
        tabFactory.updateCreator(owner);
        vm.stopPrank();

        assertEq(tabFactory.creator(), owner);
    }

    function test_createTab() public {
        vm.expectRevert(ITabFactory.Unauthorized.selector);
        tabFactory.createTab(owner, address(vaultManager), "Sound USD", "sUSD", bytes3(abi.encodePacked("USD")));

        vm.startPrank(address(tabRegistry));
        vm.expectEmit(false, false, false, false);
        emit ITabFactory.NewTabBeaconProxy("sHKD", owner); // owner is placeholder, should be sHKD proxy address
        address sHKDAddr = tabFactory.createTab(owner, address(vaultManager), "Sound HKD", "sHKD", bytes3(abi.encodePacked("HKD")));
        vm.stopPrank();

        TabERC20 sHKD = TabERC20(sHKDAddr);
        
        assertEq(sHKD.defaultAdmin() , owner);
        assertEq(sHKD.hasRole(MINTER_ROLE, address(vaultManager)), true);
        assertEq(sHKD.hasRole(MINTER_ROLE, owner), false);
        assertEq(sHKD.hasRole(MINTER_ROLE, address(zUniGovernance)), false);

        assertEq(keccak256(abi.encodePacked(sHKD.tabCode())), keccak256(abi.encodePacked("HKD")));
        assertEq(sHKD.tabKey(), keccak256(abi.encodePacked("HKD")));
        assertEq(sHKD.name(), string(abi.encodePacked("Sound HKD")));
        assertEq(sHKD.symbol(), "sHKD");
        assertEq(sHKD.decimals(), 18);
        assertEq(sHKD.totalSupply(), 0);
        assertEq(sHKD.balanceOf(owner), 0);

        vm.startPrank(address(vaultManager));
        sHKD.mint(owner, 1e18);
        assertEq(sHKD.balanceOf(owner), 1e18);
        vm.stopPrank();
        
        vm.startPrank(owner);
        sHKD.burn(1e18);
        assertEq(sHKD.balanceOf(owner), 0);
        vm.stopPrank();
    }

    function test_upgradeTabERC20() public {
        vm.startPrank(address(tabRegistry));
        address sHKDAddr = tabFactory.createTab(address(zUniGovernance), address(vaultManager), "Sound HKD", "sHKD", bytes3(abi.encodePacked("HKD")));
        vm.stopPrank();

        TabERC20 sHKD = TabERC20(sHKDAddr);
        TabERC20_newImpl newImpl = new TabERC20_newImpl();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        tabFactory.upgradeTo(address(newImpl));

        // Tab proxy sHKD should now point to new implementation: TabERC20_newImpl
        vm.startPrank(address(zUniGovernance));
        tabFactory.upgradeTo(address(newImpl));
        TabERC20_newImpl impl = TabERC20_newImpl(sHKDAddr);
        impl.grantRole(PAUSER_ROLE, address(zUniGovernance));
        // impl.grantRole(PAUSER_ROLE, address(emergencyTimelockController));
        vm.stopPrank();

        assertEq(sHKD.defaultAdmin() , address(zUniGovernance));
        assertEq(sHKD.hasRole(MINTER_ROLE, address(vaultManager)), true);
        assertEq(sHKD.hasRole(MINTER_ROLE, owner), false);
        assertEq(sHKD.hasRole(MINTER_ROLE, address(zUniGovernance)), false);

        assertEq(keccak256(abi.encodePacked(sHKD.tabCode())), keccak256(abi.encodePacked("HKD")));
        assertEq(sHKD.tabKey(), keccak256(abi.encodePacked("HKD")));
        assertEq(sHKD.name(), string(abi.encodePacked("Sound HKD")));
        assertEq(sHKD.symbol(), "sHKD");
        assertEq(sHKD.decimals(), 18);
        assertEq(sHKD.totalSupply(), 0);
        assertEq(sHKD.balanceOf(owner), 0);

        vm.startPrank(address(vaultManager));
        sHKD.mint(owner, 1e18);
        assertEq(sHKD.balanceOf(owner), 1e18);
        vm.stopPrank();

        // calling new implementation's functions
        assertEq(keccak256(bytes(impl.symbolAndName())), keccak256(bytes("sHKD: Sound HKD")));
        assertEq(impl.paused(), false);

        vm.expectRevert();
        impl.pause(); // unauthorized

        vm.startPrank(address(zUniGovernance));
        impl.pause();
        assertEq(impl.paused(), true);
        vm.stopPrank();

        vm.startPrank(address(vaultManager));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        sHKD.mint(owner, 1e18);
        vm.stopPrank();

        vm.startPrank(address(zUniGovernance));
        impl.unpause();
        assertEq(impl.paused(), false);
        vm.stopPrank();

        vm.startPrank(address(vaultManager));
        sHKD.mint(owner, 1e18);
        vm.stopPrank();
        
        assertEq(sHKD.balanceOf(owner), 2e18);
    }

}
