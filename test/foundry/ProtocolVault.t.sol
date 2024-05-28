// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FixedPointMathLib } from "lib/solady/src/utils/FixedPointMathLib.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IGovernanceAction } from "../../contracts/governance/interfaces/IGovernanceAction.sol";
import { IPriceOracleManager } from "../../contracts/oracle/interfaces/IPriceOracleManager.sol";
import { ProtocolVault } from "../../contracts/ProtocolVault.sol";
import { CBTC } from "../../contracts/token/CBTC.sol";
import { TabERC20 } from "../../contracts/token/TabERC20.sol";
import { ReserveSafe } from "../../contracts/ReserveSafe.sol";

import { Deployer } from "./Deployer.t.sol";
import { RateSimulator } from "./helper/RateSimulator.sol";

interface AccessControlInterface {

    function grantRole(bytes32 role, address account) external;

}

contract ProtocolVaultTest is Test, Deployer {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    IGovernanceAction governanceAction;
    IPriceOracleManager priceOracleManager;
    ProtocolVault protocolVault;
    address protocolVaultAddr;
    RateSimulator rs;

    bytes3[10] tab10;
    uint256[10] price10;
    bytes updatePriceData;

    bytes data;

    struct TabPool {
        bytes3 tab;
        uint256 timestamp;
        uint256 listSize;
        uint256[9] medianList;
    }

    TabPool[10] tabPools;

    bytes32 cid1;
    bytes32 cid2;
    string cid;

    struct CID {
        bytes32 ipfsCID_1;
        bytes32 ipfsCID_2;
    }

    CID cidParts;

    address wbtc1Addr;
    address wbtc2Addr;
    CBTC wBTC1;
    CBTC wBTC2;
    ReserveSafe btc1Safe;
    ReserveSafe btc2Safe;

    // ProtocolVault
    struct PVault {
        address reserveAddr; // locked reserve address, e.g. WBTC, cBTC
        uint256 reserveAmt; // reserve value (18 decimals)
        address tab; // Tab currency
        uint256 tabAmt; // Tab currency reserve (18 decimals)
        uint256 price; // RESERVE/TAB price rate
    }

    // VaultManager
    struct Vault {
        address reserveAddr; // locked reserve address, e.g. WBTC, cBTC
        uint256 reserveAmt; // reserve value (18 decimals)
        address tab; // minted tab currency
        uint256 tabAmt; // tab currency value (18 decimals)
        uint256 osTabAmt; // other O/S tab, e.g. risk penalty or fee amt
        uint256 pendingOsMint; //  osTabAmt to be minted out
    }

    event InitCtrlAltDel(address reserveAddr, uint256 reserveAmt, address tabAddr, uint256 tabAmt, uint256 price);
    event BuyTab(address indexed buyer, address reserveAddr, uint256 reserveAmt, address tabAddr, uint256 tabAmt);
    event SellTab(address indexed seller, address reserveAddr, uint256 reserveAmt, address tabAddr, uint256 tabAmt);

    event CtrlAltDelTab(bytes3 indexed _tab, uint256 _btcTabRate);

    event CtrlAltDel(
        bytes3 indexed tab, uint256 btcTabRate, uint256 totalTabs, uint256 totalReserve, uint256 consoReserve
    );

    event UpdatedPrice(bytes3 indexed _tab, uint256 _oldPrice, uint256 _newPrice, uint256 _timestamp);

    error PostCtrlAltDelFixedPrice();

    function setUp() public {
        test_deploy();

        governanceAction = IGovernanceAction(governanceActionAddr);
        priceOracleManager = IPriceOracleManager(priceOracleManagerAddr);

        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)", owner, vaultManagerAddr, address(reserveRegistry)
        );
        protocolVaultAddr =
            address(new TransparentUpgradeableProxy(address(new ProtocolVault()), address(tabProxyAdmin), initData));
        protocolVault = ProtocolVault(protocolVaultAddr);

        tabRegistry.setProtocolVaultAddress(protocolVaultAddr);

        vaultManager.grantRole(keccak256("KEEPER_ROLE"), address(this));

        rs = new RateSimulator();
        (tab10, price10) = rs.retrieve10(100);

        for (uint256 i = 0; i < 10; i++) {
            vaultManager.initNewTab(tab10[i]); // tab creation order: TabRegistry, PriceOracleManager

            AccessControlInterface(tabRegistry.tabs(tab10[i])).grantRole(MINTER_ROLE, protocolVaultAddr);

            uint256[9] memory prices;
            for (uint256 n = 0; n < 9; n++) {
                prices[n] = price10[i] + n;
            }
            tabPools[i] = TabPool(tab10[i], block.timestamp, 9, prices);
        }

        (cid1, cid2, cid) = generateCID("bafkreiflhctgqx6pcu6kkzqo5nxkhttdxsduopoajd7irdcehs4fdrzwj4");
        cidParts = CID(cid1, cid2);

        nextBlock(1);
        governanceAction.addPriceOracleProvider(
            eoa_accounts[7], // provider
            address(ctrl), // paymentTokenAddress
            1000000000000000000, // paymentAmt
            20, // blockCountPerFeed: expect 1 feed for each 20 blocks
            10, // feedSize: provider sends at least 10 currency prices per feed
            bytes32(abi.encodePacked("127.0.0.1,192.168.1.1")) // whitelistedIPAddr
        );

        // updatePrice
        nextBlock(1);
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);

        // simulate different reserve types
        bytes32 reserve_ctrlBTC = keccak256("CBTC");
        bytes32 reserve_WBTC1 = keccak256("WBTC1");
        address ctrlBTCImplementation = address(new CBTC());
        bytes memory ctrlBtcInitData =
            abi.encodeWithSignature("initialize(address,address,address)", owner, owner, owner);
        wbtc1Addr =
            address(new TransparentUpgradeableProxy(ctrlBTCImplementation, address(cBTCProxyAdmin), ctrlBtcInitData));
        wBTC1 = CBTC(wbtc1Addr);
        btc1Safe = new ReserveSafe(owner, owner, address(vaultManager), wbtc1Addr);
        reserveRegistry.addReserve(reserve_WBTC1, wbtc1Addr, address(btc1Safe));

        bytes32 reserve_WBTC2 = keccak256("WBTC2");
        ctrlBTCImplementation = address(new CBTC());
        wbtc2Addr =
            address(new TransparentUpgradeableProxy(ctrlBTCImplementation, address(cBTCProxyAdmin), ctrlBtcInitData));
        wBTC2 = CBTC(wbtc2Addr);
        btc2Safe = new ReserveSafe(owner, owner, address(vaultManager), wbtc2Addr);
        reserveRegistry.addReserve(reserve_WBTC2, wbtc2Addr, address(btc2Safe));

        bytes32[] memory reserveKey = new bytes32[](2);
        reserveKey[0] = reserve_WBTC1;
        reserveKey[1] = reserve_WBTC2;
        uint256[] memory processFeeRate = new uint256[](2);
        processFeeRate[0] = 0;
        processFeeRate[1] = 0;
        uint256[] memory minReserveRatio = new uint256[](2);
        minReserveRatio[0] = 180;
        minReserveRatio[1] = 180;
        uint256[] memory liquidationRatio = new uint256[](2);
        liquidationRatio[0] = 120;
        liquidationRatio[1] = 120;
        config.setReserveParams(reserveKey, processFeeRate, minReserveRatio, liquidationRatio);

        cBTC.mint(eoa_accounts[0], 10e18);
        wBTC1.mint(eoa_accounts[0], 10e18);
        wBTC2.mint(eoa_accounts[0], 10e18);
        wBTC1.mint(eoa_accounts[1], 10e18);
        wBTC2.mint(eoa_accounts[1], 10e18);

        vm.startPrank(eoa_accounts[0]);

        cBTC.approve(address(vaultManager), type(uint256).max);
        wBTC1.approve(address(vaultManager), type(uint256).max);
        wBTC2.approve(address(vaultManager), type(uint256).max);

        vaultManager.createVault(reserve_ctrlBTC, 5e18, tab10[0], 10000e18);
        vaultManager.createVault(reserve_WBTC2, 2e18, tab10[0], 1234e18);
        vaultManager.createVault(reserve_WBTC1, 1e17, tab10[1], 1e18); // tab-1, ignored
        vaultManager.createVault(reserve_WBTC1, 5e18, tab10[0], 1648e18);
        vaultManager.createVault(reserve_WBTC2, 5e18, tab10[0], 20400e18);
        vaultManager.createVault(reserve_WBTC1, 1e17, tab10[2], 1e18); // tab-2, to be ignored
        vaultManager.createVault(reserve_ctrlBTC, 5e18, tab10[0], 10000e18);

        vm.stopPrank();

        // Create more vaults from different owners
        vm.startPrank(eoa_accounts[1]);

        wBTC1.approve(address(vaultManager), type(uint256).max);
        wBTC2.approve(address(vaultManager), type(uint256).max);

        vaultManager.createVault(reserve_WBTC2, 5e18, tab10[1], 20400e18); // tab-1, ignored
        vaultManager.createVault(reserve_WBTC1, 1e18, tab10[0], 1e18);

        vm.stopPrank();
    }

    function nextBlock(uint256 increment) internal {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
        for (uint256 i = 0; i < 10; i++) {
            uint256[9] memory prices;
            for (uint256 n = 0; n < 9; n++) {
                prices[n] = price10[i] + n;
            }
            tabPools[i] = TabPool(tab10[i], block.timestamp, 9, prices);
        }
    }

    function generateCID(string memory s) internal pure returns (bytes32, bytes32, string memory) {
        bytes memory bcid = abi.encodePacked(s);
        bytes memory part1 = new bytes(32);
        for (uint256 i = 0; i < 31; i++) {
            part1[i] = bcid[i];
        }
        bytes memory part2 = new bytes(28);
        for (uint256 i = 0; i < 28; i++) {
            part2[i] = bcid[i + 31];
        }
        return (bytes32(part1), bytes32(part2), s);
    }

    function getTotalReserveConsolidated(uint256 price) internal pure returns (uint256 total) {
        total += FixedPointMathLib.mulDiv(10000e18, 1e18, price); // vault 1  reserve_ctrlBTC
        total += FixedPointMathLib.mulDiv(1234e18, 1e18, price); // vault 2  reserve_WBTC2
        total += FixedPointMathLib.mulDiv(1648e18, 1e18, price); // vault 4  reserve_WBTC1
        total += FixedPointMathLib.mulDiv(20400e18, 1e18, price); // vault 5  reserve_WBTC2
        total += FixedPointMathLib.mulDiv(10000e18, 1e18, price); // vault 7  reserve_ctrlBTC
        total += FixedPointMathLib.mulDiv(1e18, 1e18, price); // vault 9  reserve_WBTC1
    }

    function testCtrlAltDel() public {
        uint256 fixedPrice = 139777768634848658534534;
        address tab0Addr = tabRegistry.tabs(tab10[0]);

        vm.expectEmit(protocolVaultAddr);
        emit InitCtrlAltDel(
            address(cBTC), FixedPointMathLib.mulDiv(10000e18, 1e18, fixedPrice) * 2, tab0Addr, 10000e18 * 2, fixedPrice
        );
        vm.expectEmit(protocolVaultAddr);
        emit InitCtrlAltDel(
            wbtc2Addr,
            FixedPointMathLib.mulDiv(1234e18, 1e18, fixedPrice) + FixedPointMathLib.mulDiv(20400e18, 1e18, fixedPrice),
            tab0Addr,
            (1234e18 + 20400e18),
            fixedPrice
        );
        vm.expectEmit(protocolVaultAddr);
        emit InitCtrlAltDel(
            wbtc1Addr,
            FixedPointMathLib.mulDiv(1648e18, 1e18, fixedPrice) + FixedPointMathLib.mulDiv(1e18, 1e18, fixedPrice),
            tab0Addr,
            (1648e18 + 1e18),
            fixedPrice
        );

        vm.expectEmit(vaultManagerAddr);
        emit CtrlAltDel(
            tab10[0],
            fixedPrice,
            (20000e18 + 1648e18 + 1e18 + 1234e18 + 20400e18),
            23e18,
            getTotalReserveConsolidated(fixedPrice)
        );

        vm.expectEmit(address(priceOracle));
        emit UpdatedPrice(tab10[0], tabPools[0].medianList[4], fixedPrice, block.timestamp);

        vm.expectEmit(address(tabRegistry));
        emit CtrlAltDelTab(tab10[0], fixedPrice);

        vm.expectEmit(governanceActionAddr);
        emit CtrlAltDelTab(tab10[0], fixedPrice);

        governanceAction.ctrlAltDel(tab10[0], fixedPrice); // oracle price value = 136218495510421100881726, set to
            // fixed price 139777768634848658534534

        bytes3[] memory postDepegTabs = tabRegistry.getCtrlAltDelTabList();
        assertEq(postDepegTabs[0], tab10[0]);
        assertEq(tabRegistry.ctrlAltDelTab(tab10[0]), fixedPrice);
        assertEq(priceOracle.ctrlAltDelTab(tab10[0]), fixedPrice);

        PVault memory v;
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(address(cBTC), tab0Addr);
        assertEq(v.reserveAddr, address(cBTC));
        assertEq(v.reserveAmt, FixedPointMathLib.mulDiv(10000e18, 1e18, fixedPrice) * 2);
        assertEq(v.tab, tab0Addr);
        assertEq(v.tabAmt, 20000e18);
        assertEq(v.price, fixedPrice);

        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(wbtc1Addr, tab0Addr);
        assertEq(v.reserveAddr, wbtc1Addr);
        assertEq(
            v.reserveAmt,
            FixedPointMathLib.mulDiv(1648e18, 1e18, fixedPrice) + FixedPointMathLib.mulDiv(1e18, 1e18, fixedPrice)
        );
        assertEq(v.tab, tab0Addr);
        assertEq(v.tabAmt, 1648e18 + 1e18);
        assertEq(v.price, fixedPrice);

        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(wbtc2Addr, tab0Addr);
        assertEq(v.reserveAddr, wbtc2Addr);
        assertEq(
            v.reserveAmt,
            FixedPointMathLib.mulDiv(1234e18, 1e18, fixedPrice) + FixedPointMathLib.mulDiv(20400e18, 1e18, fixedPrice)
        );
        assertEq(v.tab, tab0Addr);
        assertEq(v.tabAmt, 1234e18 + 20400e18);
        assertEq(v.price, fixedPrice);

        nextBlock(10 days);
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        vm.expectRevert(PostCtrlAltDelFixedPrice.selector);
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData);
    }

    function testCtrlAltDelInvalidCall() public {
        address tabAddr = tabRegistry.tabs(tab10[0]);
        governanceAction.ctrlAltDel(tab10[0], 139777768634848658534534);

        vm.expectRevert("INVALID_TAB");
        governanceAction.ctrlAltDel(bytes3(abi.encodePacked("XXX")), 123e18);

        vm.expectRevert("INVALID_RATE");
        governanceAction.ctrlAltDel(tab10[0], 0);

        vm.expectRevert("CTRL_ALT_DEL_DONE");
        governanceAction.ctrlAltDel(tab10[0], 123e18);

        vm.startPrank(vaultManagerAddr);
        vm.expectRevert("initCtrlAltDel/EXISTED_VAULT");
        protocolVault.initCtrlAltDel(address(cBTC), 1, tabAddr, 1, 1);
        vm.stopPrank();

        vm.startPrank(eoa_accounts[0]);
        vm.expectRevert("CTRL_ALT_DEL_DONE");
        vaultManager.createVault(keccak256("WBTC2"), 1e18, tab10[0], 1e18);
        vm.stopPrank();
    }

    function testStatusAfterCtrlAltDel() public {
        uint256 fixedPrice = 139777768634848658534534;

        governanceAction.ctrlAltDel(tab10[0], fixedPrice);

        Vault memory m;

        uint256 id = vaultManager.vaultOwners(eoa_accounts[0], 6);
        assertEq(id, 7); // index 6 = vault id 7

        vm.expectRevert();
        vaultManager.vaultOwners(eoa_accounts[0], 7); // index 7 is not existed for owner eoa_accounts[0]

        console.log("Checking post ctl-alt-del vault status of owner: ", eoa_accounts[0]);
        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);
        assertEq(m.reserveAmt, 5e18 - FixedPointMathLib.mulDiv(10000e18, 1e18, fixedPrice));
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 2);
        assertEq(m.reserveAmt, 2e18 - FixedPointMathLib.mulDiv(1234e18, 1e18, fixedPrice));
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 3);
        assertEq(m.reserveAmt, 1e17); // tab is not ctrl-alt-del, full reserve remained
        assertEq(m.tabAmt, 1e18);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 4);
        assertEq(m.reserveAmt, 5e18 - FixedPointMathLib.mulDiv(1648e18, 1e18, fixedPrice));
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 5);
        assertEq(m.reserveAmt, 5e18 - FixedPointMathLib.mulDiv(20400e18, 1e18, fixedPrice));
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 6);
        assertEq(m.reserveAmt, 1e17); // tab is not ctrl-alt-del, full reserve remained
        assertEq(m.tabAmt, 1e18);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 7);
        assertEq(m.reserveAmt, 5e18 - FixedPointMathLib.mulDiv(10000e18, 1e18, fixedPrice));
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        // withdraw excess reserve
        vm.startPrank(eoa_accounts[0]);

        vm.expectRevert("EXCEED_WITHDRAWABLE_AMT");
        vaultManager.adjustReserve(3, 1e17, true); // vault's tab is not ctrl-alt-del

        address reserveSafeAddr = reserveRegistry.reserveAddrSafe(address(cBTC));
        uint256 balB4 = IERC20(address(cBTC)).balanceOf(reserveSafeAddr);

        vaultManager.adjustReserve(1, 5e18 - FixedPointMathLib.mulDiv(10000e18, 1e18, fixedPrice), true);
        uint256 balAfter = IERC20(address(cBTC)).balanceOf(reserveSafeAddr);
        assertEq(balB4 - (5e18 - FixedPointMathLib.mulDiv(10000e18, 1e18, fixedPrice)), balAfter); // withdraw reserve
            // from safe

        vaultManager.adjustReserve(2, 2e18 - FixedPointMathLib.mulDiv(1234e18, 1e18, fixedPrice), true);

        balB4 = wBTC1.balanceOf(eoa_accounts[0]); // 4800000000000000000
        vaultManager.adjustReserve(4, 5e18 - FixedPointMathLib.mulDiv(1648e18, 1e18, fixedPrice), true);

        balAfter = wBTC1.balanceOf(eoa_accounts[0]);
        assertEq(balB4 + 5e18 - FixedPointMathLib.mulDiv(1648e18, 1e18, fixedPrice), balAfter); // owner received excess
            // reserve

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 4);
        assertEq(m.reserveAmt, 0); // no more reserve in the vault
        assertEq(m.tabAmt, 0);

        vm.stopPrank();
    }

    function testReserveSafe() public {
        uint256 fixedPrice = 139777768634848658534534;

        address safe1 = reserveRegistry.reserveAddrSafe(address(cBTC));
        address safe2 = reserveRegistry.reserveAddrSafe(wbtc1Addr);
        address safe3 = reserveRegistry.reserveAddrSafe(wbtc2Addr);

        // Safe balances before ctrl-alt-del
        uint256 bal1 = IERC20(address(cBTC)).balanceOf(safe1);
        uint256 bal2 = IERC20(wbtc1Addr).balanceOf(safe2);
        uint256 bal3 = IERC20(wbtc2Addr).balanceOf(safe3);

        assertEq(bal1, 5e18 + 5e18);
        assertEq(bal2, 5e18 + 1e17 + 1e17 + 1e18);
        assertEq(bal3, 5e18 + 2e18 + 5e18);

        governanceAction.ctrlAltDel(tab10[0], fixedPrice);

        // transferred from Safe into ProtocolVault
        uint256 bal1Af = IERC20(address(cBTC)).balanceOf(safe1);
        uint256 bal2Af = IERC20(wbtc1Addr).balanceOf(safe2);
        uint256 bal3Af = IERC20(wbtc2Addr).balanceOf(safe3);

        assertEq(bal1Af, bal1 - ((FixedPointMathLib.mulDiv(10000e18, 1e18, fixedPrice)) * 2));
        assertEq(
            bal2Af,
            bal2
                - (
                    (FixedPointMathLib.mulDiv(1648e18, 1e18, fixedPrice))
                        + (FixedPointMathLib.mulDiv(1e18, 1e18, fixedPrice))
                )
        );
        assertEq(
            bal3Af,
            bal3
                - (
                    (FixedPointMathLib.mulDiv(1234e18, 1e18, fixedPrice))
                        + (FixedPointMathLib.mulDiv(20400e18, 1e18, fixedPrice))
                )
        );

        bal1 = IERC20(address(cBTC)).balanceOf(protocolVaultAddr);
        bal2 = IERC20(wbtc1Addr).balanceOf(protocolVaultAddr);
        bal3 = IERC20(wbtc2Addr).balanceOf(protocolVaultAddr);

        assertEq(bal1, ((FixedPointMathLib.mulDiv(10000e18, 1e18, fixedPrice)) * 2));
        assertEq(
            bal2,
            ((FixedPointMathLib.mulDiv(1648e18, 1e18, fixedPrice)) + (FixedPointMathLib.mulDiv(1e18, 1e18, fixedPrice)))
        );
        assertEq(
            bal3,
            (
                (FixedPointMathLib.mulDiv(1234e18, 1e18, fixedPrice))
                    + (FixedPointMathLib.mulDiv(20400e18, 1e18, fixedPrice))
            )
        );
    }

    function testDisabledReserve() public {
        uint256 fixedPrice = 139777768634848658534534;
        address tab0Addr = tabRegistry.tabs(tab10[0]);

        governanceAction.ctrlAltDel(tab10[0], fixedPrice);

        reserveRegistry.removeReserve(keccak256("CBTC"));

        vm.expectRevert("buyTab/DISABLED_RESERVE");
        protocolVault.buyTab(address(cBTC), tab0Addr, 1e18);
    }

    function testBuySellTab() public {
        uint256 fixedPrice = 139777768634848658534534;
        address tab0Addr = tabRegistry.tabs(tab10[0]);

        governanceAction.ctrlAltDel(tab10[0], fixedPrice);

        // Mint some tokens for tester
        cBTC.mint(eoa_accounts[5], 100e18);
        wBTC1.mint(eoa_accounts[5], 100e18);
        wBTC2.mint(eoa_accounts[5], 100e18);
        vm.startPrank(vaultManagerAddr);
        TabERC20(tab0Addr).mint(eoa_accounts[5], 100e18);
        vm.stopPrank();

        vm.startPrank(eoa_accounts[5]);

        // give approval, sell TAB later
        cBTC.approve(protocolVaultAddr, type(uint256).max);
        wBTC1.approve(protocolVaultAddr, type(uint256).max);
        wBTC2.approve(protocolVaultAddr, type(uint256).max);
        TabERC20(tab0Addr).approve(protocolVaultAddr, type(uint256).max);

        PVault memory v;
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(address(cBTC), tab0Addr);
        // console.log("Vault tabAmt: ", v.tabAmt);
        // console.log("Vault reserveAmt: ", v.reserveAmt);
        // console.log("Vault price: ", v.price);

        // validation checks
        vm.expectRevert("buyTab/INVALID_VAULT");
        protocolVault.buyTab(eoa_accounts[8], tab0Addr, 1e18); // invalid eoa_accounts[8], expect reserve contract
            // address
        vm.expectRevert("sellTab/INVALID_VAULT");
        protocolVault.sellTab(eoa_accounts[8], tab0Addr, 1e18); // invalid eoa_accounts[8]
        vm.expectRevert("sellTab/INVALID_AMT");
        protocolVault.sellTab(address(cBTC), tab0Addr, 1e30); // Sell tab amount exceeded tabAmt maintained in vault

        uint256 userBtcBalB4 = IERC20(address(cBTC)).balanceOf(eoa_accounts[5]);
        uint256 btcBalB4 = IERC20(address(cBTC)).balanceOf(protocolVaultAddr);
        uint256 tabBalB4 = IERC20(tab0Addr).balanceOf(eoa_accounts[5]);

        // Sell TAB, buy BTC
        vm.expectEmit();
        emit SellTab(
            eoa_accounts[5], address(cBTC), FixedPointMathLib.mulDiv(43523e15, 1e18, fixedPrice), tab0Addr, 43523e15
        );
        uint256 value = protocolVault.sellTab(address(cBTC), tab0Addr, 43523e15);
        assertEq(userBtcBalB4 + value, IERC20(address(cBTC)).balanceOf(eoa_accounts[5])); // received btc
        assertEq(tabBalB4 - 43523e15, IERC20(tab0Addr).balanceOf(eoa_accounts[5])); // sold tab, reduced balance
        assertEq(btcBalB4 - value, IERC20(address(cBTC)).balanceOf(protocolVaultAddr));

        userBtcBalB4 = IERC20(address(cBTC)).balanceOf(eoa_accounts[5]);
        btcBalB4 = IERC20(address(cBTC)).balanceOf(protocolVaultAddr);
        tabBalB4 = IERC20(tab0Addr).balanceOf(eoa_accounts[5]);

        // Sell BTC, buy TAB
        vm.expectEmit();
        emit BuyTab(eoa_accounts[5], address(cBTC), 1e17, tab0Addr, FixedPointMathLib.mulDiv(1e17, fixedPrice, 1e18));
        value = protocolVault.buyTab(address(cBTC), tab0Addr, 1e17); // spend 1e17 btc to buy tab
        assertEq(userBtcBalB4 - 1e17, IERC20(address(cBTC)).balanceOf(eoa_accounts[5])); // user wallet spent btc
        assertEq(btcBalB4 + 1e17, IERC20(address(cBTC)).balanceOf(protocolVaultAddr)); // vault increased btc reserve
        assertEq(tabBalB4 + value, IERC20(tab0Addr).balanceOf(eoa_accounts[5])); // user received tab

        console.log("POST-TEST");
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(address(cBTC), tab0Addr);
        // console.log("Vault tabAmt: ", v.tabAmt);
        // console.log("Vault reserveAmt: ", v.reserveAmt);
        // console.log("Vault price: ", v.price);

        vm.stopPrank();
    }

    function testSellTab_sellFullTabAmtInVault() public {
        uint256 fixedPrice = 272389271443287478942585; // changed price from 2723892714432874789425858
        address tab1Addr = tabRegistry.tabs(tab10[1]);
        uint256 value;

        wBTC1.mint(eoa_accounts[5], 100e18);
        wBTC2.mint(eoa_accounts[5], 100e18);

        governanceAction.ctrlAltDel(tab10[1], fixedPrice);

        PVault memory v;
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(wbtc1Addr, tab1Addr);
        // console.log("Vault tabAmt: ", v.tabAmt);
        // console.log("Vault reserveAmt: ", v.reserveAmt);
        // console.log("Vault price: ", v.price);

        // reserve type 1
        vm.startPrank(vaultManagerAddr);
        TabERC20(tab1Addr).mint(eoa_accounts[5], v.tabAmt); // assume user is holding same tab amount as the protocol
            // vault
        vm.stopPrank();

        vm.startPrank(eoa_accounts[5]);

        wBTC1.approve(protocolVaultAddr, type(uint256).max);
        wBTC2.approve(protocolVaultAddr, type(uint256).max);
        TabERC20(tab1Addr).approve(protocolVaultAddr, type(uint256).max);

        vm.expectRevert("sellTab/ZERO_RESERVE_AMT");
        protocolVault.sellTab(wbtc1Addr, tab1Addr, 123);

        value = protocolVault.sellTab(wbtc1Addr, tab1Addr, v.tabAmt);
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(wbtc1Addr, tab1Addr);
        assertEq(v.reserveAmt, 0);
        assertEq(v.tabAmt, 0);
        vm.stopPrank();

        // reserve type 2
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(wbtc2Addr, tab1Addr);
        vm.startPrank(vaultManagerAddr);
        TabERC20(tab1Addr).mint(eoa_accounts[6], v.tabAmt);
        vm.stopPrank();

        vm.startPrank(eoa_accounts[6]);
        TabERC20(tab1Addr).approve(protocolVaultAddr, type(uint256).max);
        value = protocolVault.sellTab(wbtc2Addr, tab1Addr, v.tabAmt);
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(wbtc2Addr, tab1Addr);
        assertEq(v.reserveAmt, 0);
        assertEq(v.tabAmt, 0);
        vm.stopPrank();
    }

    function testVaultWithPendingOS(uint256 riskPenaltyToCharge) public {
        uint256 fixedPrice = 272389271443287478942585; // changed price from 2723892714432874789425858
        uint256 maxRPCharged = FixedPointMathLib.mulDiv(5e18, fixedPrice, 1e18) / 20400e18;

        // Vault OS + riskPenaltyToCharge has to be within liquidation ratio
        if (maxRPCharged >= riskPenaltyToCharge) {
            vm.assume(maxRPCharged - riskPenaltyToCharge >= 0);
            require(maxRPCharged - riskPenaltyToCharge >= 0);
        } else {
            riskPenaltyToCharge = bound(riskPenaltyToCharge, 1, maxRPCharged);
            require(riskPenaltyToCharge >= 1 && riskPenaltyToCharge <= maxRPCharged);
        }

        address tab1Addr = tabRegistry.tabs(tab10[1]);

        wBTC2.mint(eoa_accounts[5], 100e18);

        uint256 treasuryBalB4 = TabERC20(tab1Addr).balanceOf(config.treasury());

        vaultManager.chargeRiskPenalty(eoa_accounts[1], 8, riskPenaltyToCharge); // total os = 20400e18 +
            // riskPenaltyToCharge

        governanceAction.ctrlAltDel(tab10[1], fixedPrice);

        assertEq(treasuryBalB4 + riskPenaltyToCharge, TabERC20(tab1Addr).balanceOf(config.treasury()));

        PVault memory v;
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(wbtc2Addr, tab1Addr);
        assertEq(v.tabAmt, 20400e18 + riskPenaltyToCharge);

        Vault memory m;
        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[1], 8);
        assertEq(m.reserveAmt, 5e18 - v.reserveAmt); // remaining reserve in user vault
        assertEq(m.tabAmt, 0); // all OS amounts are zero after ctrl-alt-del
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);
    }

    /// @dev sample calculation in excel: ctrl_alt_del.xlsx
    function testSimulatedExcelData() public {
        uint256 fixedPrice = 20000e18; // 1 BTC = 20000 TAB
        address tab4Addr = tabRegistry.tabs(tab10[4]);
        bytes32 reserve_WBTC1 = keccak256("WBTC1");

        uint256[9] memory prices;
        for (uint256 n = 0; n < 9; n++) {
            prices[n] = 30000e18;
        }
        tabPools[4] = TabPool(tab10[4], block.timestamp, 9, prices);
        updatePriceData = abi.encodeWithSignature(
            "updatePrice((bytes3,uint256,uint256,uint256[9])[10],(bytes32,bytes32))", tabPools, cidParts
        );
        data = Address.functionCall(priceOracleManagerAddr, updatePriceData); // tab10[4] updated to fixedPrice

        wBTC1.mint(eoa_accounts[5], 100e18);
        wBTC1.mint(eoa_accounts[6], 100e18);
        wBTC1.mint(eoa_accounts[7], 100e18);
        wBTC1.mint(eoa_accounts[8], 100e18);

        vm.startPrank(eoa_accounts[5]);
        wBTC1.approve(address(vaultManager), type(uint256).max);
        vaultManager.createVault(reserve_WBTC1, 8e18, tab10[4], 100000e18);
        vm.stopPrank();

        vm.startPrank(eoa_accounts[6]);
        wBTC1.approve(address(vaultManager), type(uint256).max);
        vaultManager.createVault(reserve_WBTC1, 10e18, tab10[4], 120000e18);
        vm.stopPrank();

        vm.startPrank(eoa_accounts[7]);
        wBTC1.approve(address(vaultManager), type(uint256).max);
        vaultManager.createVault(reserve_WBTC1, 45e18, tab10[4], 500000e18);
        vm.stopPrank();

        vm.startPrank(eoa_accounts[8]);
        wBTC1.approve(address(vaultManager), type(uint256).max);
        vaultManager.createVault(reserve_WBTC1, 10e18, tab10[4], 166666e18);
        vm.stopPrank();

        vaultManager.chargeRiskPenalty(eoa_accounts[5], 10, 3000e18);
        vaultManager.chargeRiskPenalty(eoa_accounts[6], 11, 1500e18);

        vm.expectEmit(protocolVaultAddr);
        emit InitCtrlAltDel(wbtc1Addr, 445583e14, tab4Addr, 891166e18, fixedPrice);

        vm.expectEmit(vaultManagerAddr);
        emit CtrlAltDel(tab10[4], fixedPrice, 891166e18, 73e18, 445583e14);

        vm.expectEmit(address(priceOracle));
        emit UpdatedPrice(tab10[4], tabPools[4].medianList[4], fixedPrice, block.timestamp);

        vm.expectEmit(address(tabRegistry));
        emit CtrlAltDelTab(tab10[4], fixedPrice);

        vm.expectEmit(governanceActionAddr);
        emit CtrlAltDelTab(tab10[4], fixedPrice);

        governanceAction.ctrlAltDel(tab10[4], fixedPrice);

        bytes3[] memory postDepegTabs = tabRegistry.getCtrlAltDelTabList();
        assertEq(postDepegTabs[0], tab10[4]);
        assertEq(tabRegistry.ctrlAltDelTab(tab10[4]), fixedPrice);
        assertEq(priceOracle.ctrlAltDelTab(tab10[4]), fixedPrice);

        PVault memory v;
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(wbtc1Addr, tab4Addr);
        assertEq(v.reserveAddr, wbtc1Addr);
        assertEq(v.reserveAmt, 445583e14);
        assertEq(v.tab, tab4Addr);
        assertEq(v.tabAmt, 891166e18);
        assertEq(v.price, fixedPrice);

        Vault memory m;
        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[5], 10);
        assertEq(m.reserveAmt, 285e16);
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[6], 11);
        assertEq(m.reserveAmt, 3925e15);
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[7], 12);
        assertEq(m.reserveAmt, 20e18);
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[8], 13);
        assertEq(m.reserveAmt, 16667e14);
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);
    }

}
