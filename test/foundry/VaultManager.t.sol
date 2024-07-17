// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Deployer } from "./Deployer.t.sol";
import { IPriceOracle } from "../../contracts/oracle/interfaces/IPriceOracle.sol";
import { IGovernanceAction } from "../../contracts/governance/interfaces/IGovernanceAction.sol";
import { TabERC20 } from "../../contracts/token/TabERC20.sol";
import { VaultUtils } from "../../contracts/VaultUtils.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract VaultManagerTest is Test, Deployer  {
    bytes32 res_cBTC = keccak256("CBTC"); // decimals() = 18
    bytes32 res_wBTC = keccak256("WBTC"); // decimals() = 8
    bytes3 sUSD = bytes3(abi.encodePacked("USD"));

    VaultUtils vaultUtils;

    function setUp() public {
        test_deploy();
        vaultUtils = new VaultUtils(address(vaultManager), address(reserveRegistry), address(config));
    }

    function nextBlock(uint256 increment) internal {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
    }

    function testCreateVault() public {
        vm.startPrank(owner);

        IGovernanceAction(governanceActionAddr).createNewTab(sUSD);

        cBTC.mint(owner, 100e18);
        cBTC.approve(address(vaultManager), 100e18);

        vaultManager.createVault(res_cBTC, 100e18, 10e18, signer.getUpdatePriceSignature(sUSD, priceOracle.getPrice(sUSD), block.timestamp));
        assertEq(10e18, TabERC20(tabRegistry.tabs(sUSD)).balanceOf(owner));

        vm.stopPrank();
    }

    function testCreateVaultWithSigPrice() public {
        vm.startPrank(owner);

        IGovernanceAction(governanceActionAddr).createNewTab(sUSD);

        cBTC.mint(owner, 100e18);
        cBTC.approve(address(vaultManager), 100e18);

        nextBlock(100);

        IPriceOracle.UpdatePriceData memory priceData = signer.getUpdatePriceSignature(sUSD, 70000e18, block.timestamp);
        vaultManager.createVault(res_cBTC, 10e18, 10e18, priceData);
        assertEq(10e18, TabERC20(tabRegistry.tabs(sUSD)).balanceOf(owner));
        assertEq(70000e18, priceOracle.getPrice(sUSD));

        priceData = IPriceOracle.UpdatePriceData(
            owner,
            owner,
            sUSD,
            70000e18,
            block.timestamp + 1, // invalid timestamp compared to signed digest
            priceData.v,
            priceData.r,
            priceData.s
        );
        vm.expectRevert("INVALID_SIGNATURE");
        vaultManager.createVault(res_cBTC, 10e18, 10e18, priceData);

        vm.stopPrank();
    }

    function testWBTCReserve() public {
        vm.startPrank(owner);
        IGovernanceAction(governanceActionAddr).createNewTab(sUSD);
        address usdAddr = tabRegistry.tabs(sUSD);
        uint256 startBalance = 12345678901;
        wBTC.mint(owner, startBalance); // 123.45678901
        wBTC.approve(address(vaultManager), startBalance);

        IPriceOracle.UpdatePriceData memory priceData = signer.getUpdatePriceSignature(sUSD, 70000e18, block.timestamp);
        vaultManager.createVault(res_wBTC, 123456789010000000000, 100e18, priceData);

        assertEq(wBTC.balanceOf(owner), 0);
        assertEq(wBTC.balanceOf(address(wBTCReserveSafe)), startBalance);
        assertEq(TabERC20(usdAddr).balanceOf(owner), 100e18);

        priceData = signer.getUpdatePriceSignature(sUSD, 70000e18, block.timestamp);
        vaultManager.withdrawTab(1, 10e18, priceData);
        assertEq(TabERC20(usdAddr).balanceOf(owner), 100e18 + 10e18);

        TabERC20(usdAddr).approve(address(vaultManager), 60e18);
        vaultManager.paybackTab(1, 60e18);
        assertEq(TabERC20(usdAddr).balanceOf(owner), 50e18);

        priceData = signer.getUpdatePriceSignature(sUSD, 70000e18, block.timestamp);
        vm.expectRevert("INVALID_RESERVE");
        vaultManager.withdrawReserve(1, 123, priceData); // too small
        
        // Expect 18-decimals input on protocol level, small withdrawal 
        vaultManager.withdrawReserve(1, startBalance, priceData); // only get (12345678901 / 10000000000) / 100000000 = 1
        assertEq(wBTC.balanceOf(owner), 1);

        TabERC20(usdAddr).approve(address(vaultManager), 50e18);
        vaultManager.paybackTab(1, 50e18);
        
        priceData = signer.getUpdatePriceSignature(sUSD, 70000e18, block.timestamp);
        console.log(wBTC.balanceOf(address(wBTCReserveSafe))); // 12345678900

        (
            ,// bytes3 tab,
            ,// bytes32 reserveKey,
            ,// uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            ,// uint256 reserveValue,
            // uint256 minReserveValue
        ) = vaultUtils.getVaultDetails(owner, 1, priceOracle.getPrice(sUSD));
        assertEq(reserveAmt, 12345678900e10);
        assertEq(osTab, 0);

        vaultManager.withdrawReserve(1, 12345678900e10, priceData); // withdraw all remaining
        assertEq(wBTC.balanceOf(owner), startBalance);
        assertEq(wBTC.balanceOf(address(wBTCReserveSafe)), 0);
        vm.stopPrank();
    }


}
