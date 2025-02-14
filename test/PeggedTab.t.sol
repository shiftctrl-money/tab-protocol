// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {CBBTC} from "../contracts/token/CBBTC.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {IAuctionManager} from "../contracts/interfaces/IAuctionManager.sol";

contract PeggedTab is Deployer {

    function setUp() public {
        deploy();
    }

    function test_peggedTab() public {
        bytes3 sUSD = bytes3(abi.encodePacked("USD"));
        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(sUSD);
        vm.stopPrank();

        vm.startPrank(deployer);
        cbBTC.approve(address(vaultManager), 2e8);
        priceData = signer.getUpdatePriceSignature(sUSD, 60000e18, block.timestamp); 
        vaultManager.createVault(address(cbBTC), 1e18, 10000e18, priceData);
        
        assertEq(priceOracle.peggedTabCount(), 0);
        bytes3 sPEG = bytes3(abi.encodePacked("PEG"));
        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(sPEG);
        governanceAction.setPeggedTab(sPEG, sUSD, 50); // 50% price of sUSD, so BTC/PEG = 30000
        vm.stopPrank();

        vm.startPrank(deployer);
        priceData = signer.getUpdatePriceSignature(sPEG, 60000e18, block.timestamp);
        vaultManager.createVault(address(cbBTC), 1e18, 10000e18, priceData);
        assertEq(priceOracle.getPrice(sUSD), 120000e18);
        assertEq(priceOracle.getPrice(sPEG), 60000e18);
        assertEq(TabERC20(tabRegistry.getTabAddress(sUSD)).balanceOf(deployer), 10000e18);
        assertEq(TabERC20(tabRegistry.getTabAddress(sPEG)).balanceOf(deployer), 10000e18);
        assertEq(priceOracle.getPrice(sPEG), 60000e18);
        assertEq(priceOracle.getPrice(sUSD), 120000e18);

        priceData = signer.getUpdatePriceSignature(sPEG, 60000e18, block.timestamp);
        vaultManager.withdrawReserve(1, 1e17, priceData);

        cbBTC.approve(address(vaultManager), 1e7);
        vaultManager.depositReserve(deployer, 1, 1e7);

        TabERC20(tabRegistry.getTabAddress(sPEG)).approve(address(vaultManager), 5000e18);
        vaultManager.paybackTab(deployer, 2, 5000e18);

        priceData = signer.getUpdatePriceSignature(sPEG, 60000e18, block.timestamp);
        vaultManager.withdrawTab(2, 6666e18, priceData);

        priceData = signer.getUpdatePriceSignature(sUSD, 10000e18, block.timestamp);
        vm.startPrank(address(vaultKeeper));
        vaultManager.chargeRiskPenalty(deployer, 1, 300e18);
        vaultManager.liquidateVault(1, 5e18, priceData);
        vaultManager.liquidateVault(2, 5e18, priceData); // priceData timestamp not updated, read USD rate only, no update.
        vm.stopPrank();

        IAuctionManager.AuctionDetails memory ad = auctionManager.getAuctionDetails(1);
        assertEq(ad.tab, tabRegistry.getTabAddress(sUSD));

        ad = auctionManager.getAuctionDetails(2);
        assertEq(ad.tab, tabRegistry.getTabAddress(sPEG));

        uint256 price = priceOracle.getPrice(sUSD);
        uint256 oldPrice = priceOracle.getOldPrice(sUSD);
        assertEq(price, oldPrice);
        assertEq(price, 120000e18);

        price = priceOracle.getPrice(sPEG);
        oldPrice = priceOracle.getOldPrice(sPEG);
        assertEq(price, oldPrice);
        assertEq(price, 60000e18);

        assertEq(priceOracle.peggedTabCount(), 1);
        assertEq(keccak256(abi.encodePacked(priceOracle.peggedTabList(0))), keccak256(abi.encodePacked(sPEG)));
        assertEq(keccak256(abi.encodePacked(priceOracle.peggedTabMap(sPEG))), keccak256(abi.encodePacked(sUSD)));
        assertEq(priceOracle.peggedTabPriceRatio(sPEG), 50);

        assertEq(keccak256(abi.encodePacked(tabRegistry.tabList(0))), keccak256(abi.encodePacked(sUSD)));
        assertEq(tabRegistry.peggedTabCount(), 1);
        assertEq(keccak256(abi.encodePacked(tabRegistry.peggedTabList(0))), keccak256(abi.encodePacked(sPEG)));
        assertEq(tabRegistry.peggedTabMap(keccak256(abi.encodePacked(sPEG))), keccak256(abi.encodePacked(sUSD)));
        assertEq(tabRegistry.peggedTabPriceRatio(tabRegistry.tabCodeToTabKey(sPEG)), 50);
    }

}