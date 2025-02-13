// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {IConfig} from "../contracts/interfaces/IConfig.sol";
import {ITabRegistry} from "../contracts/interfaces/ITabRegistry.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";

contract TabRegistryTest is Deployer {
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant TAB_PAUSER_ROLE = keccak256("TAB_PAUSER_ROLE");
    bytes32 public constant ALL_TAB_PAUSER_ROLE = keccak256("ALL_TAB_PAUSER_ROLE");

    function setUp() public {
        deploy();
    }

    function test_permission() public {
        assertEq(tabRegistry.defaultAdmin() , address(governanceTimelockController));

        assertEq(tabRegistry.hasRole(USER_ROLE, address(governanceTimelockController)), true);
        assertEq(tabRegistry.hasRole(USER_ROLE, address(emergencyTimelockController)), true);
        assertEq(tabRegistry.hasRole(USER_ROLE, address(governanceAction)), true);
        assertEq(tabRegistry.hasRole(USER_ROLE, address(vaultManager)), true);

        assertEq(tabRegistry.hasRole(MAINTAINER_ROLE, address(governanceTimelockController)), true);
        assertEq(tabRegistry.hasRole(MAINTAINER_ROLE, address(emergencyTimelockController)), true);
        assertEq(tabRegistry.hasRole(MAINTAINER_ROLE, address(governanceAction)), true);
        assertEq(tabRegistry.hasRole(MAINTAINER_ROLE, owner), false);

        assertEq(tabRegistry.hasRole(TAB_PAUSER_ROLE, address(governanceTimelockController)), true);
        assertEq(tabRegistry.hasRole(TAB_PAUSER_ROLE, address(emergencyTimelockController)), true);
        assertEq(tabRegistry.hasRole(TAB_PAUSER_ROLE, address(governanceAction)), true);
        assertEq(tabRegistry.hasRole(TAB_PAUSER_ROLE, signerAuthorizedAddr), true);

        assertEq(tabRegistry.hasRole(ALL_TAB_PAUSER_ROLE, address(governanceTimelockController)), true);
        assertEq(tabRegistry.hasRole(ALL_TAB_PAUSER_ROLE, address(emergencyTimelockController)), true);
        assertEq(tabRegistry.hasRole(ALL_TAB_PAUSER_ROLE, address(governanceAction)), true);

        assertEq(tabRegistry.getRoleAdmin(USER_ROLE), MAINTAINER_ROLE);
        assertEq(tabRegistry.getRoleAdmin(TAB_PAUSER_ROLE), MAINTAINER_ROLE);
        assertEq(tabRegistry.getRoleAdmin(ALL_TAB_PAUSER_ROLE), MAINTAINER_ROLE);
        assertEq(tabRegistry.vaultManager(), address(vaultManager));

        vm.expectRevert();
        tabRegistry.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        tabRegistry.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        tabRegistry.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(tabRegistry.defaultAdmin() , owner);
    }

    function test_setTabFactory() public {
        vm.expectRevert(); // unauthorized
        tabRegistry.setTabFactory(owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(ITabRegistry.ZeroAddress.selector);
        tabRegistry.setTabFactory(address(0));

        vm.expectEmit();
        emit ITabRegistry.UpdatedTabFactoryAddress(address(tabFactory), owner);
        tabRegistry.setTabFactory(owner);
        vm.stopPrank();
    }

    function test_setVaultManagerAddress() public {
        vm.expectRevert(); // unauthorized
        tabRegistry.setVaultManagerAddress(owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(ITabRegistry.ZeroAddress.selector);
        tabRegistry.setVaultManagerAddress(address(0));

        vm.expectEmit();
        emit ITabRegistry.UpdatedVaultManagerAddress(address(vaultManager), owner);
        tabRegistry.setVaultManagerAddress(owner);
        vm.stopPrank();
    }

    function test_setConfigAddress() public {
        vm.expectRevert(); // unauthorized
        tabRegistry.setConfigAddress(owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(ITabRegistry.ZeroAddress.selector);
        tabRegistry.setConfigAddress(address(0));

        vm.expectEmit();
        emit ITabRegistry.UpdatedConfigAddress(address(config), owner);
        tabRegistry.setConfigAddress(owner);
        vm.stopPrank();
    }

    function test_setPriceOracleManagerAddress() public {
        vm.expectRevert(); // unauthorized
        tabRegistry.setPriceOracleManagerAddress(owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(ITabRegistry.ZeroAddress.selector);
        tabRegistry.setPriceOracleManagerAddress(address(0));
        
        vm.expectEmit();
        emit ITabRegistry.UpdatedPriceOracleManagerAddress(address(priceOracleManager), owner);
        tabRegistry.setPriceOracleManagerAddress(owner);
        vm.stopPrank();
    }

    function test_setGovernanceAction() public {
        vm.startPrank(address(emergencyTimelockController));
        vm.expectRevert(); // unauthorized
        tabRegistry.setGovernanceAction(owner);
        vm.stopPrank();

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(ITabRegistry.ZeroAddress.selector);
        tabRegistry.setGovernanceAction(address(0));

        vm.expectEmit();
        emit ITabRegistry.UpdatedGovernanceActionAddress(address(governanceAction), eoa_accounts[4]);
        tabRegistry.setGovernanceAction(eoa_accounts[4]);
        vm.stopPrank();

        assertEq(tabRegistry.hasRole(USER_ROLE, eoa_accounts[4]), true);
        assertEq(tabRegistry.hasRole(TAB_PAUSER_ROLE, eoa_accounts[4]), true);
        assertEq(tabRegistry.hasRole(ALL_TAB_PAUSER_ROLE, eoa_accounts[4]), true);
        assertEq(tabRegistry.hasRole(MAINTAINER_ROLE, eoa_accounts[4]), true);
    }

    function test_setProtocolVaultAddress() public {
        vm.expectRevert(); // unauthorized
        tabRegistry.setProtocolVaultAddress(owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(ITabRegistry.ZeroAddress.selector);
        tabRegistry.setProtocolVaultAddress(address(0));

        vm.expectEmit();
        emit ITabRegistry.UpdatedProtocolVaultAddress(address(protocolVault), owner);
        tabRegistry.setProtocolVaultAddress(owner);
        vm.stopPrank();
    }

    function createTab(bytes3 tab) internal returns(address) {
        vm.startPrank(address(vaultManager));
        address addr = tabRegistry.createTab(tab);
        vm.stopPrank();
        return addr;
    } 

    function test_enableTab_disableTab() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        bytes32 usd32 = tabRegistry.tabCodeToTabKey(usd);
        TabERC20 sUSD = TabERC20(createTab(usd));
        assertEq(tabRegistry.activatedTabCount(), 1);
        assertEq(tabRegistry.tabs(usd32), address(sUSD));

        vm.startPrank(eoa_accounts[5]);
        vm.expectRevert(); // unauthorized
        tabRegistry.enableTab(usd);
        vm.expectRevert();
        tabRegistry.disableTab(usd);
        vm.stopPrank();
        
        vm.startPrank(address(governanceAction));
        vm.expectRevert(ITabRegistry.InvalidTab.selector);
        tabRegistry.enableTab(0x444444);
        vm.expectRevert(ITabRegistry.InvalidTab.selector);
        tabRegistry.disableTab(0x444444);
        vm.stopPrank();

        assertEq(tabRegistry.frozenTabs(usd32), false);

        vm.startPrank(signerAuthorizedAddr);
        vm.expectEmit();
        emit ITabRegistry.FreezeTab(usd);        
        tabRegistry.disableTab(usd);
        assertEq(tabRegistry.frozenTabs(usd32), true);
        assertEq(tabRegistry.activatedTabCount(), 1);

        vm.expectEmit();
        emit ITabRegistry.UnfreezeTab(usd);
        tabRegistry.enableTab(usd);
        assertEq(tabRegistry.frozenTabs(usd32), false);
        vm.stopPrank();
    }

    function test_enableAllTab_disableAllTab() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        bytes32 usd32 = tabRegistry.tabCodeToTabKey(usd);
        createTab(usd);
        bytes3 jpy = bytes3(abi.encodePacked("JPY"));
        bytes32 jpy32 = tabRegistry.tabCodeToTabKey(jpy);
        createTab(jpy);
        bytes3 aud = bytes3(abi.encodePacked("AUD"));
        bytes32 aud32 = tabRegistry.tabCodeToTabKey(aud);
        createTab(aud);
        assertEq(tabRegistry.activatedTabCount(), 3);
        assertEq(keccak256(abi.encodePacked(tabRegistry.tabList(0))), keccak256(abi.encodePacked(usd)));
        assertEq(keccak256(abi.encodePacked(tabRegistry.tabList(1))), keccak256(abi.encodePacked(jpy)));
        assertEq(keccak256(abi.encodePacked(tabRegistry.tabList(2))), keccak256(abi.encodePacked(aud)));
        
        vm.startPrank(eoa_accounts[5]);
        vm.expectRevert(); // unauthorized
        tabRegistry.enableAllTab();
        vm.expectRevert();
        tabRegistry.disableAllTab();
        vm.stopPrank();

        vm.startPrank(address(governanceAction));
        vm.expectEmit();
        emit ITabRegistry.FreezeAllTab();
        tabRegistry.disableAllTab();
        assertEq(tabRegistry.frozenTabs(usd32), true);
        assertEq(tabRegistry.frozenTabs(jpy32), true);
        assertEq(tabRegistry.frozenTabs(aud32), true);
        assertEq(tabRegistry.activatedTabCount(), 3);
        
        vm.expectEmit();
        emit ITabRegistry.UnfreezeAllTab();
        tabRegistry.enableAllTab();
        assertEq(tabRegistry.frozenTabs(usd32), false);
        assertEq(tabRegistry.frozenTabs(jpy32), false);
        assertEq(tabRegistry.frozenTabs(aud32), false);
        vm.stopPrank();
    }

    function test_createTab() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));

        vm.expectRevert(); // unauthorized
        tabRegistry.createTab(usd);

        vm.startPrank(address(vaultManager));
        vm.expectRevert(ITabRegistry.EmptyCharacter.selector);
        tabRegistry.createTab(0x004445);
        vm.expectRevert(ITabRegistry.EmptyCharacter.selector);
        tabRegistry.createTab(0x440045);
        vm.expectRevert(ITabRegistry.EmptyCharacter.selector);
        tabRegistry.createTab(0x444500);
        
        vm.expectEmit(true, false, false, false);
        emit ITabRegistry.TabRegistryAdded("sUSD", owner);
        address addr = tabRegistry.createTab(usd);

        TabERC20 sUSD = TabERC20(addr);
        assertEq(sUSD.tabKey(), keccak256(abi.encodePacked("USD")));
        assertEq(sUSD.name(), string(abi.encodePacked("Sound USD")));
        assertEq(sUSD.symbol(), "sUSD");
        assertEq(sUSD.decimals(), 18);
        assertEq(sUSD.totalSupply(), 0);
        assertEq(sUSD.balanceOf(owner), 0);
        assertEq(tabRegistry.activatedTabCount(), 1);
        assertEq(keccak256(abi.encodePacked(tabRegistry.tabList(0))), keccak256(abi.encodePacked(usd)));

        IConfig.TabParams memory tabParams = config.getTabParams(usd);
        IConfig.TabParams memory defTabParams = config.getTabParams(0x00);
        assertEq(tabParams.riskPenaltyPerFrame, defTabParams.riskPenaltyPerFrame);
        assertEq(tabParams.processFeeRate, defTabParams.processFeeRate);
        assertEq(tabParams.minReserveRatio, defTabParams.minReserveRatio);
        assertEq(tabParams.liquidationRatio, defTabParams.liquidationRatio);

        address addr2 = tabRegistry.createTab(usd); // retrieve address once tab is created already
        assertEq(addr, addr2);

        vm.stopPrank();
    }

    function test_getTabAddress_tabCodeToTabKey() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        TabERC20 sUSD = TabERC20(createTab(usd));
        assertEq(tabRegistry.getTabAddress(usd), address(sUSD));
    }
}
