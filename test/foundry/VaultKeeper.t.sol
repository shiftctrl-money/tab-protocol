// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Deployer } from "./Deployer.t.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract VaultKeeperTest is Test, Deployer {

    bytes32 private reserve_cBTC = keccak256("CBTC");

    // moved from local variable to workaround "Stack too deep" compile issue
    uint256 usd2ndRunRiskPenalty;
    uint256 usd3rdRunRiskPenalty;
    uint256 myr1stRunRiskPenalty;
    uint256[] vaultIDs;
    bytes3[] _tabs;
    uint256[] _prices;
    uint256[] _timestamps;
    address vaultOwner;
    bytes3 vaultTab;
    uint256 listIndex;

    struct VaultDetails {
        address vaultOwner;
        uint256 vaultId;
        bytes3 tab;
        bytes32 reserveKey;
        uint256 osTab;
        uint256 reserveValue;
        uint256 minReserveValue;
    }

    struct RiskPenaltyCharge {
        address owner;
        uint256 vaultId;
        uint256 delta;
        uint256 chargedRP;
    }

    event RiskPenaltyCharged(
        uint256 indexed timestamp,
        address indexed vaultOwner,
        uint256 indexed vaultId,
        uint256 delta,
        uint256 riskPenaltyAmt
    );
    event StartVaultLiquidation(
        uint256 indexed timestamp, address indexed vaultOwner, uint256 indexed vaultId, uint256 latestRiskPenaltyAmt
    );

    event UpdatedTabParams(bytes3[] tab, uint256[] riskPenaltyPerFrame);
    event UpdatedVaultManagerAddress(address old, address _new);
    event UpdatedRiskPenaltyFrameInSecond(uint256 b4, uint256 _after);
    event UpdatedReserveParams(bytes32[] reserveKey, uint256[] minReserveRatio, uint256[] liquidationRatio);
    event TabWithdraw(address indexed vaultOwner, uint256 indexed id, uint256 withdrawAmt, uint256 newAmt);

    function setUp() public {
        test_deploy();

        vaultKeeper.setRiskPenaltyFrameInSecond(10);
        nextBlock(1703753421);
    }

    function nextBlock(uint256 increment) internal {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
    }

    function testUpdateVaultManagerAddress() public {
        vm.expectEmit(vaultKeeperAddr);
        emit UpdatedVaultManagerAddress(vaultManagerAddr, address(this));
        vaultKeeper.updateVaultManagerAddress(address(this));
    }

    function testSetReserveParams() public {
        bytes32[] memory _reserveKey = new bytes32[](1);
        uint256[] memory _processFeeRate = new uint256[](1);
        uint256[] memory _minReserveRatio = new uint256[](1);
        uint256[] memory _liquidationRatio = new uint256[](1);

        _reserveKey[0] = keccak256("CBTC");
        _processFeeRate[0] = 123;
        _minReserveRatio[0] = 123;
        _liquidationRatio[0] = 123;

        vm.expectEmit(vaultKeeperAddr);
        emit UpdatedReserveParams(_reserveKey, _minReserveRatio, _liquidationRatio);
        config.setReserveParams(_reserveKey, _processFeeRate, _minReserveRatio, _liquidationRatio);

        uint256[] memory wrongLength = new uint256[](2);
        wrongLength[0] = 123;
        wrongLength[1] = 456;
        vm.expectRevert();
        config.setReserveParams(_reserveKey, _processFeeRate, _minReserveRatio, wrongLength);

        vm.startPrank(address(timelockController));

        vm.expectRevert();
        vaultKeeper.setReserveParams(_reserveKey, _minReserveRatio, wrongLength);

        _minReserveRatio[0] = 99;
        vm.expectRevert();
        vaultKeeper.setReserveParams(_reserveKey, _minReserveRatio, _liquidationRatio);

        _minReserveRatio[0] = 101;
        _liquidationRatio[0] = 99;
        vm.expectRevert();
        vaultKeeper.setReserveParams(_reserveKey, _minReserveRatio, _liquidationRatio);

        vm.stopPrank();
    }

    function testSetTabParams() public {
        _tabs = new bytes3[](1);
        uint256[] memory riskPenaltyPerFrameList = new uint256[](1);
        uint256[] memory _processFeeRate = new uint256[](1);
        _tabs[0] = 0x555344;
        riskPenaltyPerFrameList[0] = 150;
        _processFeeRate[0] = 123;

        vm.expectEmit(vaultKeeperAddr);
        emit UpdatedTabParams(_tabs, riskPenaltyPerFrameList);
        vaultManager.initNewTab(0x555344); // USD

        vm.expectEmit(vaultKeeperAddr);
        emit UpdatedTabParams(_tabs, riskPenaltyPerFrameList);
        config.setTabParams(_tabs, riskPenaltyPerFrameList, _processFeeRate);

        vm.startPrank(address(timelockController));

        uint256[] memory wrongLength = new uint256[](2);
        wrongLength[0] = 123;
        wrongLength[1] = 456;
        vm.expectRevert();
        vaultKeeper.setTabParams(_tabs, wrongLength);

        riskPenaltyPerFrameList[0] = 0;
        vm.expectRevert();
        vaultKeeper.setTabParams(_tabs, riskPenaltyPerFrameList);

        vm.stopPrank();
    }

    function testSetRiskPenaltyFrameInSecond() public {
        vm.expectEmit(vaultKeeperAddr);
        emit UpdatedRiskPenaltyFrameInSecond(10, 9999999);
        vaultKeeper.setRiskPenaltyFrameInSecond(9999999);
    }

    function testCheckVault() public {
        vaultManager.initNewTab(0x555344); // USD
        nextBlock(1);

        // skip oracle module (intentionally, for testing), update price directly into PriceOracle
        _tabs = new bytes3[](1);
        _tabs[0] = 0x555344; // USD
        _prices = new uint256[](1);
        _timestamps = new uint256[](1);
        _prices[0] = 0x0000000000000000000000000000000000000000000005734280aa3b4be80000; // BTC/USD 25738
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);

        nextBlock(1);
        assertEq(priceOracle.getPrice(0x555344), 25738000000000000000000);

        // mint 10 BTC
        cBTC.mint(eoa_accounts[0], 10e18);
        assertEq(cBTC.balanceOf(eoa_accounts[0]), 10e18);

        nextBlock(1);
        vm.startPrank(eoa_accounts[0]);

        // approve 10 BTC to vault manager
        cBTC.approve(address(vaultManager), 10e18);
        assertEq(cBTC.allowance(eoa_accounts[0], address(vaultManager)), 10e18);

        // create vault
        // current reserve ratio = 25738 / 14298 = 180.01%, just slightly above minimum reserve ratio
        vaultManager.createVault(reserve_cBTC, 1e18, 0x555344, 14298e18); // max withdrawable = 25738 / 180% =
            // 14298.888888888888888888888888889
        vaultIDs = vaultManager.getAllVaultIDByOwner(eoa_accounts[0]);
        assertEq(vaultIDs[0], 1);

        (
            bytes3 tab,
            bytes32 reserveKey,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            uint256 reserveValue,
            uint256 minReserveValue
        ) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[0]);
        assertEq(reserveKey, keccak256("CBTC"));
        assertEq(price, 25738000000000000000000);
        assertEq(reserveAmt, 1e18);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 25738e18);
        assertEq(minReserveValue, 257364e17);

        vm.stopPrank();

        nextBlock(1 days);
        // price dropped, RR below 180%, start charging risk penalty
        _prices[0] = 20000e18; // BTC/USD 20000
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        nextBlock(1);
        assertEq(priceOracle.getPrice(0x555344), 20000e18);
        (,, price,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[0]);
        assertEq(price, 20000e18);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 20000e18);
        assertEq(minReserveValue, 257364e17);

        // checkVault
        nextBlock(1);
        console.log("checkVault, block timestamp: ", block.timestamp); // 1703839827
        bytes memory checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256))",
            block.timestamp,
            eoa_accounts[0],
            vaultIDs[0],
            tab,
            reserveKey,
            osTab,
            reserveValue,
            minReserveValue
        );
        bytes memory data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);

        uint256 delta = minReserveValue - reserveValue;
        console.log("delta: ", delta);
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], vaultIDs[0]));
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(vaultIDs[0]);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), vaultIDs[0]);
        assertEq(vaultTab, tab);

        // second checkVault: passed RP frame, expect to charge risk penalty
        nextBlock(10); // 1703839827 + 10
        checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256))",
            block.timestamp,
            eoa_accounts[0],
            vaultIDs[0],
            tab,
            reserveKey,
            osTab,
            reserveValue,
            minReserveValue
        );
        vm.expectEmit();
        emit RiskPenaltyCharged(
            1703839837, eoa_accounts[0], vaultIDs[0], delta, FixedPointMathLib.mulDiv(150, delta, 10000)
        );
        data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);
        (,,,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[0]);
        assertEq(osTab, 14384046000000000000000); // minted tab 14298e18 + risk penalty charged 86046e15
        assertEq(reserveValue, 20000e18);
        assertEq(minReserveValue, 258912828e14);
        console.log("current checkedTimestamp: ", vaultKeeper.checkedTimestamp()); // 1703839837
        // charged RP in prev frame, delta recorded in current frame
        delta = minReserveValue - reserveValue;
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], vaultIDs[0]));
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(vaultIDs[0]);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), vaultIDs[0]);
        vm.expectRevert();
        assertEq(vaultKeeper.vaultIdList(1), 0); // expect not existed

        // third checkVault: price dropped further, reserve ratio below 120%, charge RP for more frames and liquidate
        nextBlock(1);
        _prices[0] = 17000e18; // BTC/USD 17000
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps); // timestamp 1703839838
        assertEq(priceOracle.getPrice(0x555344), 17000e18);

        nextBlock(106); // 10 frames passed
        assertEq(data.length, 0);
        (,,,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[0]);
        checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256))",
            block.timestamp, // 1703839837 + 1 + 106 = 1703839944, 1703839944 - 1703839837 = 107 / 10 = 10, 10 * 10 = 100,
                // 1703839837 + 100 = 1703839937
            eoa_accounts[0],
            vaultIDs[0],
            tab,
            reserveKey,
            osTab,
            reserveValue,
            minReserveValue
        );
        vm.expectEmit(vaultKeeperAddr);
        emit RiskPenaltyCharged(
            1703839937, eoa_accounts[0], vaultIDs[0], delta, FixedPointMathLib.mulDiv(150, delta, 10000)
        );
        vm.expectEmit(vaultKeeperAddr);
        emit StartVaultLiquidation(block.timestamp, eoa_accounts[0], vaultIDs[0], 135755211534000000000);
        data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);
        (,,,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[0]);
        assertEq(osTab, 14608170453534000000000); // 14384046000000000000000 + 88369242000000000000 +
            // 135755211534000000000 = 14608170453534000000000
        // assertEq(reserveValue, 17000e18);
        assertEq(reserveValue, 0);
        assertEq(minReserveValue, 26294706816361200000000); // 14608170453534000000000 * 180 / 100 =
            // 26294706816361200000000
    }

    function testCheckVault_2ndLargestVaultDelta_thenLiquidate() public {
        vaultManager.initNewTab(0x555344); // USD
        vaultManager.initNewTab(0x4d5952); // MYR

        nextBlock(10);
        // skip oracle module (intentionally, for testing), update price directly into PriceOracle
        _tabs = new bytes3[](2);
        _tabs[0] = 0x555344; // USD
        _tabs[1] = 0x4d5952;
        _prices = new uint256[](2);
        _prices[0] = 25738e18; // BTC/USD 25738
        _prices[1] = 174603438331485931421445; // BTC/MYR 174603.438331485931421445
        _timestamps = new uint256[](2);
        _timestamps[0] = block.timestamp;
        _timestamps[1] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);

        assertEq(priceOracle.getPrice(_tabs[0]), _prices[0]);
        assertEq(priceOracle.getPrice(_tabs[1]), _prices[1]);

        // mint 2 BTC
        cBTC.mint(eoa_accounts[0], 2e18);
        assertEq(cBTC.balanceOf(eoa_accounts[0]), 2e18);

        vm.startPrank(eoa_accounts[0]);

        // approve 2 BTC to vault manager
        cBTC.approve(address(vaultManager), 2e18);
        assertEq(cBTC.allowance(eoa_accounts[0], address(vaultManager)), 2e18);

        // create vault
        // current reserve ratio = 25738 / 14298 = 180.01%, just slightly above minimum reserve ratio
        vaultManager.createVault(reserve_cBTC, 1e18, 0x555344, 14298e18); // max withdrawable = 25738 / 180% =
            // 14298.888888888888888888888888889
        vaultIDs = vaultManager.getAllVaultIDByOwner(eoa_accounts[0]);
        assertEq(vaultIDs[0], 1);

        vaultManager.createVault(reserve_cBTC, 1e18, 0x4d5952, 97001910184158850789691); // mint 97001.910184158850789691
            // sMYR
        vaultIDs = new uint256[](0);
        vaultIDs = vaultManager.getAllVaultIDByOwner(eoa_accounts[0]);
        assertEq(vaultIDs[0], 1);
        assertEq(vaultIDs[1], 2);

        (
            bytes3 tab,
            bytes32 reserveKey,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            uint256 reserveValue,
            uint256 minReserveValue
        ) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[0]);
        assertEq(keccak256(abi.encodePacked(tab)), keccak256(abi.encodePacked(_tabs[0]))); // USD
        assertEq(reserveKey, keccak256("CBTC"));
        assertEq(price, 25738000000000000000000);
        assertEq(reserveAmt, 1e18);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 25738e18);
        assertEq(minReserveValue, 257364e17);

        (tab, reserveKey, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[1]);
        assertEq(keccak256(abi.encodePacked(tab)), keccak256(abi.encodePacked(_tabs[1]))); // MYR
        assertEq(reserveKey, keccak256("CBTC"));
        assertEq(price, 174603438331485931421445);
        assertEq(reserveAmt, 1e18);
        assertEq(osTab, 97001910184158850789691);
        assertEq(reserveValue, 174603438331485931421445);
        assertEq(minReserveValue, 174603438331485931421443); // 97001910184158850789691 * 180 / 100 =
            // 174603438331485931421443.8

        vm.stopPrank();

        // drop price, expect USD and MYR vaults to be charged risk penalty
        nextBlock(100);
        _prices[0] = 20000e18; // BTC/USD 20000
        _prices[1] = 150000e18;
        _timestamps[0] = block.timestamp;
        _timestamps[1] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        assertEq(priceOracle.getPrice(0x555344), 20000e18);

        (,, price,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[0]);
        assertEq(price, 20000e18);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 20000e18);
        assertEq(minReserveValue, 257364e17);

        // checkVault
        console.log("checkVault, block timestamp: ", block.timestamp);
        bytes memory checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256))",
            block.timestamp,
            eoa_accounts[0],
            vaultIDs[0],
            _tabs[0],
            reserveKey,
            osTab,
            reserveValue,
            minReserveValue
        );
        bytes memory data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);

        uint256 delta = minReserveValue - reserveValue;
        console.log("usd delta: ", delta);
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], vaultIDs[0]));
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(vaultIDs[0]);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), vaultIDs[0]);
        console.log("current checkedTimestamp: ", vaultKeeper.checkedTimestamp());

        (,, price,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[1]);
        assertEq(price, 150000e18);
        assertEq(osTab, 97001910184158850789691);
        assertEq(reserveValue, 150000e18);
        assertEq(minReserveValue, 174603438331485931421443); // delta = 174603.438331485931421443 - 150000e18 =
            // 24603.438331485931421443
        // delta * 1.5% = to be charged risk penalty 369.051574972288971321645

        checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256))",
            block.timestamp,
            eoa_accounts[0],
            vaultIDs[1],
            _tabs[1],
            reserveKey,
            osTab,
            reserveValue,
            minReserveValue
        );
        data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);
        delta = minReserveValue - reserveValue;
        uint256 firstRunMyrDelta = delta;
        console.log("myr delta: ", firstRunMyrDelta);
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], vaultIDs[1]));
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(vaultIDs[1]);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), vaultIDs[1]);

        // 2nd, On same frame, price changes so delta is updated

        nextBlock(1);
        _prices[0] = 19000e18; // BTC/USD 19000
        _prices[1] = 155000e18;
        _timestamps[0] = block.timestamp;
        _timestamps[1] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        assertEq(priceOracle.getPrice(_tabs[0]), 19000e18);
        assertEq(priceOracle.getPrice(_tabs[1]), 155000e18);

        (,, price,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[0]);
        assertEq(price, 19000e18);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 19000e18);
        assertEq(minReserveValue, 257364e17); // same as previous, delta(risk penalty) not yet reflected into OS, since
            // it is still on same frame

        // checkVault
        console.log("checkVault, block timestamp: ", block.timestamp);
        checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256))",
            block.timestamp,
            eoa_accounts[0],
            vaultIDs[0],
            _tabs[0],
            reserveKey,
            osTab,
            reserveValue,
            minReserveValue
        );
        data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);

        delta = minReserveValue - reserveValue;
        console.log("usd delta (2nd run): ", delta);
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], vaultIDs[0])); // delta is updated when price
            // dropped from 20000e18 to 19000e18
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(vaultIDs[0]);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), vaultIDs[0]);
        console.log("current checkedTimestamp: ", vaultKeeper.checkedTimestamp());
        uint256 usd2ndRunDelta = delta;

        nextBlock(1);
        (,, price,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[1]);
        assertEq(price, 155000e18);
        assertEq(osTab, 97001910184158850789691);
        assertEq(reserveValue, 155000e18);
        assertEq(minReserveValue, 174603438331485931421443); // delta = 174603.438331485931421443 - 155000e18 =
            // 19603.438331485931421443
        // delta * 1.5% = to be charged risk penalty 294.051574972288971321645

        checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256))",
            block.timestamp,
            eoa_accounts[0],
            vaultIDs[1],
            _tabs[1],
            reserveKey,
            osTab,
            reserveValue,
            minReserveValue
        );
        data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);
        delta = minReserveValue - reserveValue;
        console.log("myr delta (2nd run): ", delta);
        assertEq(24603438331485931421443, vaultKeeper.largestVaultDelta(eoa_accounts[0], vaultIDs[1])); // largest delta
            // remained
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(vaultIDs[1]);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), vaultIDs[1]);

        // 3rd run, dropped price below 120%, liquidate both usd and myr vaults
        nextBlock(10);

        _prices[0] = 15000e18;
        _prices[1] = 100000e18;
        _timestamps[0] = block.timestamp;
        _timestamps[1] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        assertEq(priceOracle.getPrice(_tabs[0]), 15000e18);
        assertEq(priceOracle.getPrice(_tabs[1]), 100000e18);

        (,, price,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[0]);
        assertEq(price, 15000e18);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 15000e18);
        assertEq(minReserveValue, 257364e17);

        // checkVault
        console.log("checkVault, block timestamp: ", block.timestamp);
        checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256))",
            block.timestamp,
            eoa_accounts[0],
            vaultIDs[0],
            _tabs[0],
            reserveKey,
            osTab,
            reserveValue,
            minReserveValue
        );
        usd2ndRunRiskPenalty = FixedPointMathLib.mulDiv(150, usd2ndRunDelta, 10000);
        usd3rdRunRiskPenalty = FixedPointMathLib.mulDiv(
            150, FixedPointMathLib.mulDiv((usd2ndRunRiskPenalty + 14298e18), 180, 100) - 15000e18, 10000
        );
        myr1stRunRiskPenalty = FixedPointMathLib.mulDiv(150, firstRunMyrDelta, 10000);

        vm.expectEmit(vaultKeeperAddr);
        emit RiskPenaltyCharged(1703753542, eoa_accounts[0], vaultIDs[0], usd2ndRunDelta, usd2ndRunRiskPenalty); // usd
            // risk penalty
        vm.expectEmit(vaultKeeperAddr);
        emit RiskPenaltyCharged(1703753542, eoa_accounts[0], vaultIDs[1], firstRunMyrDelta, myr1stRunRiskPenalty); // myr
            // risk penalty
        vm.expectEmit(vaultKeeperAddr);
        emit StartVaultLiquidation(1703753544, eoa_accounts[0], vaultIDs[0], usd3rdRunRiskPenalty);
        data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);

        (,, price,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[0]);
        assertEq(price, 15000e18);
        assertEq(osTab, 14298e18 + usd2ndRunRiskPenalty + usd3rdRunRiskPenalty);
        // assertEq(reserveValue, 15000e18);
        assertEq(reserveValue, 0);
        assertEq(minReserveValue, FixedPointMathLib.mulDiv(osTab, 180, 100));

        nextBlock(1);
        (,, price,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], vaultIDs[1]);
        assertEq(price, 100000e18);
        assertEq(osTab, 97001910184158850789691 + myr1stRunRiskPenalty);
        assertEq(reserveValue, 100000e18);
        assertEq(minReserveValue, FixedPointMathLib.mulDiv(osTab, 180, 100));
        delta = minReserveValue - reserveValue;
        console.log("myr delta (3nd run): ", delta);

        checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256))",
            block.timestamp,
            eoa_accounts[0],
            vaultIDs[1],
            _tabs[1],
            reserveKey,
            osTab,
            reserveValue,
            minReserveValue
        );
        vm.expectEmit(vaultKeeperAddr);
        emit StartVaultLiquidation(
            block.timestamp, eoa_accounts[0], vaultIDs[1], FixedPointMathLib.mulDiv(150, delta, 10000)
        );
        data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);
    }

    /// @dev selectively clearing risk penalty of a vault
    function testPushVaultRiskPenalty() public {
        vaultManager.initNewTab(0x555344); // USD

        // skip oracle module (intentionally, for testing), update price directly into PriceOracle
        _tabs = new bytes3[](1);
        _tabs[0] = 0x555344; // USD
        _prices = new uint256[](1);
        _prices[0] = 10000e18;
        _timestamps = new uint256[](1);
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        assertEq(priceOracle.getPrice(0x555344), 10000e18);

        // mint 1 BTC
        cBTC.mint(eoa_accounts[0], 1e18);
        assertEq(cBTC.balanceOf(eoa_accounts[0]), 1e18);

        vm.startPrank(eoa_accounts[0]);

        // approve 1 BTC to vault manager
        cBTC.approve(address(vaultManager), 1e18);
        assertEq(cBTC.allowance(eoa_accounts[0], address(vaultManager)), 1e18);

        // create vault
        vaultManager.createVault(reserve_cBTC, 1e18, 0x555344, 5000e18); // RR 200%

        vm.stopPrank();

        nextBlock(1 days);

        // price dropped
        _prices[0] = 8000e18;
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        assertEq(priceOracle.getPrice(0x555344), 8000e18);

        (
            bytes3 tab,
            bytes32 reserveKey,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            uint256 reserveValue,
            uint256 minReserveValue
        ) = vaultManager.getVaultDetails(eoa_accounts[0], 1);
        assertEq(price, 8000e18);
        assertEq(reserveAmt, 1e18);
        assertEq(osTab, 5000e18);
        assertEq(reserveValue, 8000e18);
        assertEq(minReserveValue, 9000e18);

        // checkVault - uncleared risk penalty is created
        bytes memory checkVaultData = abi.encodeWithSignature(
            "checkVault(uint256,(address,uint256,bytes3,bytes32,uint256,uint256,uint256))",
            block.timestamp,
            eoa_accounts[0],
            1,
            tab,
            reserveKey,
            osTab,
            reserveValue,
            minReserveValue
        );
        bytes memory data = Address.functionCall(vaultKeeperAddr, checkVaultData);
        assertEq(data.length, 0);

        uint256 delta = minReserveValue - reserveValue;
        console.log("delta: ", delta);
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], 1)); // delta 1000, RP 1.5% = 15, new OS = 5015
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(1);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), 1);
        assertEq(vaultTab, tab);

        // price back to 10000e18, try to mint more, expect pending risk penalty is updated before mint more
        nextBlock(1);
        _prices[0] = 10000e18;
        _timestamps[0] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        assertEq(priceOracle.getPrice(0x555344), 10000e18);

        vm.startPrank(eoa_accounts[0]);

        vm.expectRevert();
        vaultManager.adjustTab(1, 555e18, true); // withdrawal more than max. withdraw due to 555e18 did not consider
            // pending risk penalty to charge

        vm.expectEmit(vaultManagerAddr);
        emit TabWithdraw(eoa_accounts[0], 1, 540e18, 5540e18);
        vaultManager.adjustTab(1, 540e18, true); // withdraw tab, max withdraw 5555, deduct os 5555 - 5015 = 540

        vm.stopPrank();

        (,, price,, osTab, reserveValue, minReserveValue) = vaultManager.getVaultDetails(eoa_accounts[0], 1);
        assertEq(price, 10000e18);
        assertEq(osTab, 5555e18);
        assertEq(reserveValue, 10000e18);
        assertEq(minReserveValue, 9999e18);
    }

}
