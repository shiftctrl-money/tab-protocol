// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import { Deployer } from "./Deployer.t.sol";
import { TabERC20 } from "../../contracts/token/TabERC20.sol";
import { IGovernanceAction } from "../../contracts/governance/interfaces/IGovernanceAction.sol";
import { IConfig } from "../../contracts/shared/interfaces/IConfig.sol";

contract CoreTest is Test, Deployer {

    // Pausable
    event Paused(address account);
    event Unpaused(address account);

    // VaultManager
    event NewVault(
        uint256 indexed id, address indexed owner, address reserveAddr, uint256 reserveAmt, address tab, uint256 tabAmt
    );
    event TabWithdraw(address indexed proxyOwner, uint256 indexed id, uint256 withdrawAmt, uint256 newAmt);
    event TabReturned(address indexed proxyOwner, uint256 indexed id, uint256 returnedAmt, uint256 newAmt);
    event ReserveWithdraw(address indexed proxyOwner, uint256 indexed id, uint256 withdrawAmt, uint256 newAmt);
    event ReserveAdded(address indexed proxyOwner, uint256 indexed id, uint256 addedAmt, uint256 newAmt);
    event RiskPenaltyCharged(address indexed vaultOwner, uint256 indexed id, uint256 riskPenaltyAmt, uint256 newAmt);
    event UpdatedAuctionParams(
        uint256 auctionStartPriceDiscount,
        uint256 auctionStepPriceDiscount,
        uint256 auctionStepDurationInBlock,
        address auctionManager
    );

    bytes32 private res_cBTC = keccak256("CBTC");

    function setUp() public {
        test_deploy();
    }

    function test_cBTC() public view {
        assertEq(cBTC.name(), "shiftCTRL Wrapped BTC");
        assertEq(cBTC.symbol(), "cBTC");
        assertEq(cBTC.hasRole(cBTC.MINTER_ROLE(), owner), true);
    }

    function test_ctrl() public view {
        assertEq(ctrl.name(), "shiftCTRL");
        assertEq(ctrl.symbol(), "CTRL");
        assertEq(ctrl.hasRole(ctrl.MINTER_ROLE(), owner), true);
    }

    function test_ctrl_max_cap(uint256 _amt) public {
        vm.assume(_amt <= 10 ** 9 * 10 ** 18);
        require(_amt <= 10 ** 9 * 10 ** 18, "Max cap 1 billion token!");
        ctrl.mint(address(this), _amt);

        vm.expectRevert();
        ctrl.mint(address(this), (10 ** 9 * 10 ** 18) + 1);
    }

    function test_ctrl_max_cap_and_burn() public {
        ctrl.mint(address(this), 10 ** 9 * 10 ** 18);

        vm.expectRevert();
        ctrl.mint(address(this), 1);

        vm.startPrank(address(this));
        ctrl.burn(10 ** 9 * 10 ** 18);
        vm.stopPrank();

        ctrl.mint(address(this), 1);
    }

    function test_disableTab() public {
        bytes3 myr = bytes3(abi.encodePacked("MYR"));
        bytes3 jpy = bytes3(abi.encodePacked("JPY"));
        bytes3 aud = bytes3(abi.encodePacked("AUD"));
        vm.startPrank(address(vaultManager));
        tabRegistry.createTab(myr);
        tabRegistry.createTab(jpy);
        tabRegistry.createTab(aud);
        vm.stopPrank();

        IGovernanceAction governanceAction = IGovernanceAction(governanceActionAddr);
        console.log("b4 disableTab");
        governanceAction.disableTab(myr);
        console.log("after disableTab");
        governanceAction.enableTab(myr);

        governanceAction.disableAllTabs();
        governanceAction.enableAllTabs();
    }

    function test_priceOracle() public {
        vm.warp(1694074774);
        bytes3[] memory _tabs = new bytes3[](3);
        _tabs[0] = 0x555344; // USD
        _tabs[1] = 0x4D5952; // MYR
        _tabs[2] = 0x4A5059; // JPY
        uint256[] memory _prices = new uint256[](3);
        _prices[0] = 0x0000000000000000000000000000000000000000000005815e55ed50a7120000; // BTC/USD 25998.26
        _prices[1] = 0x0000000000000000000000000000000000000000000019932eb5d23b0b67d000; // BTC/MYR 120774.199278024
        _prices[2] = 0x0000000000000000000000000000000000000000000327528f703dab9edda000; // BTC/JPY 3812472.7205188
        uint256[] memory _timestamps = new uint256[](3);
        _timestamps[0] = block.timestamp;
        _timestamps[1] = block.timestamp;
        _timestamps[2] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);

        vm.warp(1694074800);
        assertEq(priceOracle.getPrice(0x555344), 25998260000000000000000);
        assertEq(priceOracle.getPrice(0x4D5952), 120774199278024000000000);
        assertEq(priceOracle.getPrice(0x4A5059), 3812472720518800000000000);
    }

    function test_config() public {
        address configAddr = address(config);
        (
            uint256 _auctionStartPriceDiscount,
            uint256 _auctionStepPriceDiscount,
            uint256 _auctionStepDurationInBlock,
            address _auctionManager
        ) = IConfig(configAddr).auctionParams();

        assertEq(_auctionStartPriceDiscount, 90);
        assertEq(_auctionStepPriceDiscount, 97);
        assertEq(_auctionStepDurationInBlock, 60);

        vm.expectRevert("INVALID_STR_PRICE_DISCOUNT");
        config.setAuctionParams(0, 10, 20, auctionManagerAddr);
        vm.expectRevert("INVALID_STP_PRICE_DISCOUNT");
        config.setAuctionParams(10, 0, 20, auctionManagerAddr);
        vm.expectRevert("INVALID_STP_DURATION");
        config.setAuctionParams(10, 20, 0, auctionManagerAddr);

        vm.expectEmit();
        emit UpdatedAuctionParams(10, 20, 30, auctionManagerAddr);
        IConfig(configAddr).setAuctionParams(10, 20, 30, auctionManagerAddr);
        (_auctionStartPriceDiscount, _auctionStepPriceDiscount, _auctionStepDurationInBlock, _auctionManager) =
            IConfig(configAddr).auctionParams();
        assertEq(_auctionStartPriceDiscount, 10);
        assertEq(_auctionStepPriceDiscount, 20);
        assertEq(_auctionStepDurationInBlock, 30);
        assertEq(_auctionManager, auctionManagerAddr);

        config.grantRole(keccak256("MAINTAINER_ROLE"), governanceActionAddr);

        vm.expectEmit();
        emit UpdatedAuctionParams(20, 30, 40, auctionManagerAddr);
        IGovernanceAction(governanceActionAddr).updateAuctionParams(20, 30, 40, auctionManagerAddr);
        (_auctionStartPriceDiscount, _auctionStepPriceDiscount, _auctionStepDurationInBlock, _auctionManager) =
            IConfig(configAddr).auctionParams();
        assertEq(_auctionStartPriceDiscount, 20);
        assertEq(_auctionStepPriceDiscount, 30);
        assertEq(_auctionStepDurationInBlock, 40);
        assertEq(_auctionManager, auctionManagerAddr);
    }

    function test_vaultAndRiskPenalty() public {
        vm.warp(1694074774);
        bytes3[] memory _tabs = new bytes3[](1);
        _tabs[0] = 0x555344; // USD
        uint256[] memory _prices = new uint256[](1);
        _prices[0] = 0x0000000000000000000000000000000000000000000005734280aa3b4be80000; // BTC/USD 25738
        uint256[] memory _timestamps = new uint256[](1);
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);

        vm.warp(1694074775);
        assertEq(priceOracle.getPrice(0x555344), 25738000000000000000000);

        // mint 10 BTC
        cBTC.mint(eoa_accounts[0], 10e18);
        assertEq(cBTC.balanceOf(eoa_accounts[0]), 10e18);

        vm.startPrank(eoa_accounts[0]);

        // approve 10 BTC to vault manager
        cBTC.approve(address(vaultManager), 10e18);
        assertEq(cBTC.allowance(eoa_accounts[0], address(vaultManager)), 10e18);

        // sample row 7 : deposit 1 BTC, mint 10000 sUSD
        vm.expectEmit(true, false, false, false);
        emit NewVault(1, owner, address(cBTC), 1e18, address(0), 10000e18); // tab address is unknown at this point
            // (before createVault)
        vaultManager.createVault(res_cBTC, 1e18, 0x555344, 10000e18);

        address sUSDAddr = tabRegistry.tabs(0x555344);
        TabERC20 sUSD = TabERC20(sUSDAddr);
        assertEq(sUSD.balanceOf(eoa_accounts[0]), 10000e18);
        vm.expectRevert();
        sUSD.mint(eoa_accounts[1], 1e18); // unauthorized
        assertEq(vaultManager.vaultOwners(eoa_accounts[0], 0), 1); // vault id 1
        assertEq(vaultManager.vaultId(), 1);
        assertEq(vaultManager.getAllVaultIDByOwner(eoa_accounts[0])[0], 1);

        (address reserveAddr, uint256 reserveAmt, address tab, uint256 tabAmt, uint256 osTabAmt, uint256 pendingOsMint)
        = vaultManager.vaults(eoa_accounts[0], 1);
        assertEq(reserveAddr, address(cBTC));
        assertEq(reserveAmt, 1e18);
        assertEq(tab, sUSDAddr);
        assertEq(tabAmt, 10000e18);
        assertEq(osTabAmt, 0);
        assertEq(pendingOsMint, 0);

        // sample row 8 : mint additional 3000 sUSD
        vm.expectEmit(true, true, false, true);
        emit TabWithdraw(eoa_accounts[0], 1, 3000e18, 13000e18);
        vaultManager.adjustTab(1, 3000e18, true);
        assertEq(sUSD.balanceOf(eoa_accounts[0]), 13000e18);
        (reserveAddr, reserveAmt, tab, tabAmt, osTabAmt, pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);
        assertEq(tabAmt, 13000e18);

        // sample row 9 : BTC price dropped to 23399
        vm.stopPrank();
        vm.warp(1694074800);
        _prices[0] = 0x0000000000000000000000000000000000000000000004F4765B5EC8E53C0000; // BTC/USD 23399
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        vm.warp(1694074801);
        assertEq(priceOracle.getPrice(0x555344), 23399000000000000000000);

        vaultManager.grantRole(keccak256("KEEPER_ROLE"), address(this));

        // assume keeper calculated Delta off-chain and need to update risk penalty value on-chain
        vm.expectEmit(true, true, false, true);
        emit RiskPenaltyCharged(eoa_accounts[0], 1, 15000000000000000, 15000000000000000);
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, 15000000000000000); // risk penalty 0.015 sUSD, submit by
            // user having KEEPER_ROLE
        (reserveAddr, reserveAmt, tab, tabAmt, osTabAmt, pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);
        assertEq(tabAmt, 13000e18);
        assertEq(osTabAmt, 15000000000000000);
        assertEq(pendingOsMint, 15000000000000000);

        // sample row 10: BTC price dropped to 19999
        vm.warp(1694074900);
        _prices[0] = 0x00000000000000000000000000000000000000000000043C25E0DCC1BD1C0000; // BTC/USD 19999
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        vm.warp(1694074901);
        assertEq(priceOracle.getPrice(0x555344), 19999000000000000000000);

        uint256 min_reserved_value_required = Math.mulDiv(tabAmt + osTabAmt, 180, 100);
        uint256 delta = min_reserved_value_required - 19999e18;
        uint256 risk_penalty = Math.mulDiv(delta, 150, 10000);
        console.log("risk penalty (row 10) : ", risk_penalty); // 51015405000000000000 = 51.015405

        vm.expectEmit(true, true, false, true);
        emit RiskPenaltyCharged(eoa_accounts[0], 1, risk_penalty, 15000000000000000 + risk_penalty);
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, risk_penalty);
        (reserveAddr, reserveAmt, tab, tabAmt, osTabAmt, pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);
        assertEq(tabAmt, 13000e18);
        assertEq(osTabAmt, 15000000000000000 + risk_penalty);
        assertEq(pendingOsMint, 15000000000000000 + risk_penalty);

        // sample row 11: BTC price dropped to 19000
        vm.warp(1694074902);
        _prices[0] = 19000e18; // BTC/USD 19000
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        vm.warp(1694074903);
        assertEq(priceOracle.getPrice(0x555344), 19000e18);

        min_reserved_value_required = Math.mulDiv(tabAmt + osTabAmt, 180, 100);
        delta = min_reserved_value_required - 19000e18;
        risk_penalty = Math.mulDiv(delta, 150, 10000);
        console.log("risk penalty (row 11) : ", risk_penalty); // 67377820935000000000 = 67.377820935000000000

        vm.expectEmit(true, true, false, true);
        emit RiskPenaltyCharged(eoa_accounts[0], 1, risk_penalty, osTabAmt + risk_penalty);
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, risk_penalty);
        (reserveAddr, reserveAmt, tab, tabAmt, osTabAmt, pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);

        // sample row 12: BTC price remained 19000, calc and charge risk penalty
        min_reserved_value_required = Math.mulDiv(tabAmt + osTabAmt, 180, 100);
        delta = min_reserved_value_required - 19000e18;
        risk_penalty = Math.mulDiv(delta, 150, 10000);
        console.log("risk penalty (row 12) : ", risk_penalty); // 69197022100245000000 = 69.197022100245000000

        vm.expectEmit(true, true, false, true);
        emit RiskPenaltyCharged(eoa_accounts[0], 1, risk_penalty, osTabAmt + risk_penalty);
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, risk_penalty);
        (reserveAddr, reserveAmt, tab, tabAmt, osTabAmt, pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);
        uint256 osToBeMinted = pendingOsMint;

        // sample row 13: deposit 0.5 BTC
        vm.warp(1694074904);
        vm.prank(eoa_accounts[0]);
        vm.expectEmit(true, true, false, true);
        emit ReserveAdded(eoa_accounts[0], 1, 5e17, 1e18 + 5e17);
        vaultManager.adjustReserve(1, 5e17, false);
        (reserveAddr, reserveAmt, tab, tabAmt, osTabAmt, pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);
        assertEq(reserveAddr, address(cBTC));
        assertEq(reserveAmt, 15e17);
        assertEq(tab, sUSDAddr);
        assertEq(tabAmt, 13000e18);
        assertEq(osTabAmt, osToBeMinted);
        assertEq(pendingOsMint, 0);

        assertEq(cBTC.balanceOf(address(reserveSafe)), 15e17);
        assertEq(sUSD.balanceOf(config.treasury()), osToBeMinted);
        assertEq(sUSD.totalSupply(), 13000e18 + osToBeMinted);

        // switch to bottom section in excel, reset test case by settle `osTabAmt` (burning equivalent amt) value
        // prepare for test case in row 34 and 35
        vm.prank(eoa_accounts[0]);
        sUSD.approve(address(vaultManager), 10000e18);
        vm.warp(1694074904);
        vm.prank(eoa_accounts[0]);
        vm.expectEmit(true, true, false, true);
        emit TabReturned(eoa_accounts[0], 1, osToBeMinted, 13000e18);
        vaultManager.adjustTab(1, osToBeMinted, false);
        (reserveAddr, reserveAmt, tab, tabAmt, osTabAmt, pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);
        assertEq(tabAmt, 13000e18);
        assertEq(osTabAmt, 0); // no more OS
        assertEq(pendingOsMint, 0);
        assertEq(sUSD.balanceOf(config.treasury()), osToBeMinted);
        assertEq(sUSD.totalSupply(), 13000e18); // burnt `osToBeMinted` value

        console.log("reset condition [done]");

        // sample row 34, directly incur sUSD 187.61 risk penalty (ignore price and delta values)
        vm.expectEmit(true, true, false, true);
        emit RiskPenaltyCharged(eoa_accounts[0], 1, 18761e16, 18761e16);
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, 18761e16);
        (reserveAddr, reserveAmt, tab, tabAmt, osTabAmt, pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);
        assertEq(tabAmt, 13000e18);
        assertEq(osTabAmt, 18761e16);
        assertEq(pendingOsMint, 18761e16);

        // sample row 35, burns tab (return sUSD 5000)
        vm.warp(1694074905);
        vm.prank(eoa_accounts[0]);
        vm.expectEmit(true, true, false, true);
        emit TabReturned(eoa_accounts[0], 1, 5000e18, 13000e18 - (5000e18 - 18761e16));
        vaultManager.adjustTab(1, 5000e18, false);
        (reserveAddr, reserveAmt, tab, tabAmt, osTabAmt, pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);
        assertEq(tabAmt, 13000e18 - (5000e18 - 18761e16));
        assertEq(osTabAmt, 0);
        assertEq(pendingOsMint, 0);

        assertEq(sUSD.balanceOf(config.treasury()), (osToBeMinted + 18761e16));
        assertEq(sUSD.totalSupply(), 13000e18 - (5000e18 - 18761e16)); // minted 13k, then burn in line 245, then burn
            // for test case row 25
    }

    // function test_CannotSubtract43() public {
    //     vm.expectRevert(stdError.arithmeticError);
    //     testNumber -= 43;
    // }

}
