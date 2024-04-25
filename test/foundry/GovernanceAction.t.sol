// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";

import "./Deployer.t.sol";
import "./helper/RateSimulator.sol";
import { IERC20 } from "../../contracts/shared/interfaces/IERC20.sol";
import { IGovernanceAction } from "../../contracts/governance/interfaces/IGovernanceAction.sol";

contract GovernanceActionTest is Test, Deployer {

    bytes32 private reserve_cBTC = keccak256("CBTC");
    bytes3[] _tabs;
    uint256[] _prices;
    uint256[] _timestamps;

    event FreezeTab(bytes3 indexed tab);
    event UnfreezeTab(bytes3 indexed tab);

    function setUp() public {
        test_deploy();

        RateSimulator rs = new RateSimulator();
        (_tabs, _prices) = rs.retrieveX(168, 100);

        _timestamps = new uint256[](168);
        uint256 currentLastUpdated = priceOracle.lastUpdated(bytes3(abi.encodePacked("USD")));
        for (uint256 i = 0; i < 168; i++) {
            _timestamps[i] = currentLastUpdated + 1 + i;
        }
    }

    function testFreezeTab() public {
        // USD, MYR, JPY are already activated from test_deploy()
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        bytes3 myr = bytes3(abi.encodePacked("MYR"));
        bytes3 jpy = bytes3(abi.encodePacked("JPY"));
        vaultManager.initNewTab(usd);
        vaultManager.initNewTab(myr);
        vaultManager.initNewTab(jpy);

        _tabs = new bytes3[](1);
        _tabs[0] = usd;
        _prices = new uint256[](1);
        _prices[0] = 10000e18;
        _timestamps = new uint256[](1);
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        assertEq(priceOracle.getPrice(usd), 10000e18);

        // mint BTC
        cBTC.mint(eoa_accounts[0], 3e18);
        assertEq(cBTC.balanceOf(eoa_accounts[0]), 3e18);

        vm.startPrank(eoa_accounts[0]);

        cBTC.approve(address(vaultManager), 3e18);
        assertEq(cBTC.allowance(eoa_accounts[0], address(vaultManager)), 3e18);

        // create vault
        vaultManager.createVault(reserve_cBTC, 1e18, usd, 5000e18); // RR 200%

        vm.stopPrank();

        vm.expectEmit(address(tabRegistry));
        emit FreezeTab(usd);
        IGovernanceAction(governanceActionAddr).disableTab(usd);

        vm.startPrank(eoa_accounts[0]);
        vm.expectRevert("FROZEN_TAB");
        vaultManager.createVault(reserve_cBTC, 1e18, usd, 5000e18);

        vm.expectRevert("FROZEN_TAB");
        vaultManager.adjustTab(1, 10e18, true);

        vm.expectRevert("FROZEN_TAB");
        vaultManager.adjustReserve(1, 1e17, false);
        vm.stopPrank();

        vm.expectRevert("INVALID_TAB");
        IGovernanceAction(governanceActionAddr).enableTab(bytes3(abi.encodePacked("ABC")));
        vm.expectRevert("TAB_ACTIVE");
        IGovernanceAction(governanceActionAddr).enableTab(myr);

        vm.expectRevert("INVALID_TAB");
        IGovernanceAction(governanceActionAddr).disableTab(bytes3(abi.encodePacked("ABC")));
        vm.expectRevert("TAB_FROZEN");
        IGovernanceAction(governanceActionAddr).disableTab(usd);

        vm.expectEmit(address(tabRegistry));
        emit UnfreezeTab(usd);
        IGovernanceAction(governanceActionAddr).enableTab(usd);

        vm.startPrank(eoa_accounts[0]);
        vaultManager.adjustTab(1, 10e18, true);
        vaultManager.adjustReserve(1, 1e17, false);
        vm.stopPrank();

        IGovernanceAction(governanceActionAddr).disableAllTabs();
        vm.startPrank(eoa_accounts[0]);
        vm.expectRevert("FROZEN_TAB");
        vaultManager.createVault(reserve_cBTC, 1e18, usd, 5000e18);

        assertEq(tabRegistry.frozenTabs(usd), true);
        assertEq(tabRegistry.frozenTabs(myr), true);
        assertEq(tabRegistry.frozenTabs(jpy), true);

        // can perform regular transfer in froze state
        IERC20(tabRegistry.tabs(usd)).approve(eoa_accounts[1], 1e18);
        vm.stopPrank();
        vm.startPrank(eoa_accounts[1]);
        IERC20(tabRegistry.tabs(usd)).transferFrom(eoa_accounts[0], eoa_accounts[2], 1e18);
        vm.stopPrank();
        vm.startPrank(eoa_accounts[0]);
        IERC20(tabRegistry.tabs(usd)).transfer(eoa_accounts[1], 1e18);

        assertEq(IERC20(tabRegistry.tabs(usd)).balanceOf(eoa_accounts[1]), 1e18);
        assertEq(IERC20(tabRegistry.tabs(usd)).balanceOf(eoa_accounts[2]), 1e18);
        assertEq(IERC20(tabRegistry.tabs(usd)).allowance(eoa_accounts[0], eoa_accounts[1]), 0);

        vm.stopPrank();

        IGovernanceAction(governanceActionAddr).enableAllTabs();
        vm.startPrank(eoa_accounts[0]);
        vaultManager.createVault(reserve_cBTC, 1e18, usd, 5000e18);
        vm.stopPrank();

        assertEq(tabRegistry.frozenTabs(usd), false);
        assertEq(tabRegistry.frozenTabs(myr), false);
        assertEq(tabRegistry.frozenTabs(jpy), false);
    }

}
