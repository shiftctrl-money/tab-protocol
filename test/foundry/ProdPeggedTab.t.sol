// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ITransparentUpgradeableProxy, TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import { ProdDeployer } from "./ProdDeployer.t.sol";
import { CTRL } from "../../contracts/token/CTRL.sol";
import { CBTC } from "../../contracts/token/CBTC.sol";
import { WBTC } from "../../contracts/token/WBTC.sol";
import { TabERC20 } from "../../contracts/token/TabERC20.sol";
import { IPriceOracle } from "../../contracts/oracle/interfaces/IPriceOracle.sol";

contract ProdPeggedTab is Test, ProdDeployer {
    IPriceOracle.UpdatePriceData priceData;

    function setUp() public {
        deploy();
    }

    function test_peggedTab() public {
        bytes3 sUSD = bytes3(abi.encodePacked("USD"));
        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(sUSD);
        vm.stopPrank();

        vm.startPrank(deployer);
        wBTC.mint(deployer, 3e8);
        wBTC.approve(address(vaultManager), 2e8);
        priceData = signer.getUpdatePriceSignature(sUSD, 60000e18, block.timestamp);
        vaultManager.createVault(reserve_wBTC, 1e18, 10000e18, priceData);
        vm.stopPrank();

        bytes3 sPEG = bytes3(abi.encodePacked("PEG"));
        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(sPEG);
        governanceAction.setPeggedTab(sPEG, sUSD, 50); // 50% price of sUSD, so BTC/PEG = 30000
        vm.stopPrank();

        vm.startPrank(deployer);
        priceData = signer.getUpdatePriceSignature(sPEG, 60000e18, block.timestamp);
        vaultManager.createVault(reserve_wBTC, 1e18, 10000e18, priceData);
        assertEq(TabERC20(tabRegistry.tabs(sUSD)).balanceOf(deployer), 10000e18);
        assertEq(TabERC20(tabRegistry.tabs(sPEG)).balanceOf(deployer), 10000e18);
        assertEq(priceOracle.getPrice(sPEG), 60000e18);
        assertEq(priceOracle.getPrice(sUSD), 120000e18);

        priceData = signer.getUpdatePriceSignature(sPEG, 60000e18, block.timestamp);
        vaultManager.withdrawReserve(2, 1e17, priceData);

        wBTC.approve(address(vaultManager), 1e7);
        vaultManager.depositReserve(2, 1e17);

        TabERC20(tabRegistry.tabs(sPEG)).approve(address(vaultManager), 5000e18);
        vaultManager.paybackTab(2, 5000e18);

        priceData = signer.getUpdatePriceSignature(sPEG, 60000e18, block.timestamp);
        vaultManager.withdrawTab(2, 6666e18, priceData);

        vm.stopPrank();
        vm.startPrank(address(vaultKeeper));
        vaultManager.chargeRiskPenalty(deployer, 2, 30000e18);
        priceData = signer.getUpdatePriceSignature(sPEG, 10000e18, block.timestamp);
        vaultManager.liquidateVault(deployer, 2, 500e18, priceData);
        vm.stopPrank();

    }

}