// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {ITransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Dec18BTC} from "./token/Dec18BTC.sol";
import {CBBTC} from "../contracts/token/CBBTC.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {ProtocolVault_newImpl} from "./upgrade/ProtocolVault_newImpl.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";
import {IProtocolVault} from "../contracts/interfaces/IProtocolVault.sol";
import {IPriceOracle} from "../contracts/interfaces/IPriceOracle.sol";
import {ITabRegistry} from "../contracts/interfaces/ITabRegistry.sol";
import {IGovernanceAction} from "../contracts/interfaces/IGovernanceAction.sol";

contract ProtocolVaultTest is Deployer {
    bytes32 public constant CTRL_ALT_DEL_ROLE = keccak256("CTRL_ALT_DEL_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 fixedPrice = 139777768634848658534534;

    bytes3 usd = bytes3(abi.encodePacked("USD"));
    bytes3 afn = bytes3(abi.encodePacked("AFN"));
    bytes3 all = bytes3(abi.encodePacked("ALL"));
    
    Dec18BTC cBTC;
    Dec18BTC wBTC1;
    CBBTC wBTC2;
    address reserve_ctrlBTC;
    address reserve_WBTC1;
    address reserve_WBTC2;
    address usdAddr;
    address afnAddr;
    address allAddr;

    function setUp() public {
        deploy();

        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(usd);
        governanceAction.createNewTab(afn);
        governanceAction.createNewTab(all);
        usdAddr = tabRegistry.getTabAddress(usd);
        afnAddr = tabRegistry.getTabAddress(afn);
        allAddr = tabRegistry.getTabAddress(all);
        
        governanceAction.addPriceOracleProvider(
            eoa_accounts[7], // provider
            address(ctrl), // paymentTokenAddress
            1e18, // paymentAmtPerFeed
            150, // blockCountPerFeed: every 150 blocks, expect min. 1 feed
            10, // feedSize: provider sends at least 10 currency pairs per feed
            bytes32(abi.encodePacked("127.0.0.1,192.168.1.1")) // whitelistedIPAddr
        );

        // 3 reserves: 
        // cBTC - 18 decimals
        // wBTC1 - 18 decimals
        // wBTC2 - 8 decimals
        cBTC = new Dec18BTC(deployer);
        reserve_ctrlBTC = address(cBTC);
        wBTC1 = new Dec18BTC(deployer); // 18 decimals BTC reserve token
        reserve_WBTC1 = address(wBTC1);
        wBTC2 = cbBTC;
        reserve_WBTC2 = address(wBTC2);

        governanceAction.addReserve(reserve_ctrlBTC, address(reserveSafe));        
        governanceAction.addReserve(reserve_WBTC1, address(reserveSafe));
        
        vm.stopPrank();

        vm.startPrank(deployer);
        cBTC.mint(eoa_accounts[0], 10e18);
        wBTC1.mint(eoa_accounts[0], 10e18);
        wBTC1.mint(eoa_accounts[1], 10e18);
        wBTC2.mint(eoa_accounts[0], 10e18);
        wBTC2.mint(eoa_accounts[1], 10e18);

        vm.startPrank(eoa_accounts[0]);

        cBTC.approve(address(vaultManager), type(uint256).max);
        wBTC1.approve(address(vaultManager), type(uint256).max);
        wBTC2.approve(address(vaultManager), type(uint256).max);

        vaultManager.createVault(reserve_ctrlBTC, 5e18, 10000e18, signer.getUpdatePriceSignature(usd, 136218495510421100881726, block.timestamp));
        vaultManager.createVault(reserve_WBTC2, 2e18, 1234e18, signer.getUpdatePriceSignature(usd, 136218495510421100881726, block.timestamp));
        vaultManager.createVault(reserve_WBTC1, 1e17, 1e18, signer.getUpdatePriceSignature(afn, 2723892714432874789425858, block.timestamp)); // tab-1, ignored
        vaultManager.createVault(reserve_WBTC1, 5e18, 1648e18, signer.getUpdatePriceSignature(usd, 136218495510421100881726, block.timestamp));
        vaultManager.createVault(reserve_WBTC2, 5e18, 20400e18, signer.getUpdatePriceSignature(usd, 136218495510421100881726, block.timestamp));
        vaultManager.createVault(reserve_WBTC1, 1e17, 1e18, signer.getUpdatePriceSignature(all, 3624800547223059694688378, block.timestamp)); // tab-2, to be ignored
        vaultManager.createVault(reserve_ctrlBTC, 5e18, 10000e18, signer.getUpdatePriceSignature(usd, 136218495510421100881726, block.timestamp));

        vm.stopPrank();

        // Create more vaults from different owners
        vm.startPrank(eoa_accounts[1]);

        wBTC1.approve(address(vaultManager), type(uint256).max);
        wBTC2.approve(address(vaultManager), type(uint256).max);

        vaultManager.createVault(reserve_WBTC2, 5e18, 20400e18, signer.getUpdatePriceSignature(afn, 2723892714432874789425858, block.timestamp)); // tab-1, ignored
        vaultManager.createVault(reserve_WBTC1, 1e18, 1e18, signer.getUpdatePriceSignature(usd, 136218495510421100881726, block.timestamp));

        vm.stopPrank();
    }

    function test_permission() public {
        assertEq(protocolVault.defaultAdmin() , address(governanceTimelockController));
        assertEq(protocolVault.hasRole(MANAGER_ROLE, address(governanceTimelockController)), true);
        assertEq(protocolVault.hasRole(CTRL_ALT_DEL_ROLE, address(governanceTimelockController)), true);
        assertEq(protocolVault.hasRole(CTRL_ALT_DEL_ROLE, address(vaultManager)), true);
        assertEq(protocolVault.hasRole(UPGRADER_ROLE, address(tabProxyAdmin)), true);

        assertEq(protocolVault.reserveSafe(), address(reserveSafe));
        
        vm.expectRevert();
        protocolVault.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        protocolVault.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        protocolVault.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(protocolVault.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        assertEq(tabProxyAdmin.owner(), address(governanceTimelockController));
        vm.startPrank(address(governanceTimelockController));
        tabProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(protocolVault)), 
            address(new ProtocolVault_newImpl()),
            abi.encodeWithSignature("upgraded(string)", "upgraded_v2")
        );

        ProtocolVault_newImpl upgraded_v2 = ProtocolVault_newImpl(address(protocolVault));
        assertEq(keccak256(bytes(upgraded_v2.version())), keccak256("upgraded_v2"));
        assertEq(upgraded_v2.newFunction(), 1e18);

        vm.expectRevert(); // unauthorized
        upgraded_v2.upgraded("test");
        vm.stopPrank();

        assertEq(upgraded_v2.reserveSafe(), address(reserveSafe));
    }

    function test_updateReserveSafe() public {
        vm.expectRevert(); // unauthorized
        protocolVault.updateReserveSafe(owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(IProtocolVault.ZeroAddress.selector);
        protocolVault.updateReserveSafe(address(0));

        vm.expectRevert(IProtocolVault.InvalidReserveSafe.selector);
        protocolVault.updateReserveSafe(eoa_accounts[0]);

        vm.expectEmit();
        emit IProtocolVault.UpdatedReserveSafe(address(reserveSafe), owner);
        protocolVault.updateReserveSafe(owner);
        assertEq(protocolVault.reserveSafe(), owner);
        vm.stopPrank();
    }
    
    function test_initCtrlAltDel() public {
        address protocolVaultAddr = address(protocolVault);

        vm.startPrank(address(governanceTimelockController));
        
        vm.expectEmit(protocolVaultAddr);
        emit IProtocolVault.InitCtrlAltDel(
            reserve_ctrlBTC, 
            Math.mulDiv(10000e18, 1e18, fixedPrice) * 2, 
            usdAddr, 
            10000e18 * 2, 
            fixedPrice
        );
        vm.expectEmit(protocolVaultAddr);
        emit IProtocolVault.InitCtrlAltDel(
            reserve_WBTC2,
            Math.mulDiv(1234e18, 1e18, fixedPrice) + Math.mulDiv(20400e18, 1e18, fixedPrice),
            usdAddr,
            (1234e18 + 20400e18),
            fixedPrice
        );
        vm.expectEmit(protocolVaultAddr);
        emit IProtocolVault.InitCtrlAltDel(
            reserve_WBTC1,
            Math.mulDiv(1648e18, 1e18, fixedPrice) + Math.mulDiv(1e18, 1e18, fixedPrice),
            usdAddr,
            (1648e18 + 1e18),
            fixedPrice
        );

        vm.expectEmit(address(vaultManager));
        emit IVaultManager.CtrlAltDel(
            usd,
            fixedPrice,
            (20000e18 + 1648e18 + 1e18 + 1234e18 + 20400e18),
            23e18,
            getTotalReserveConsolidated(fixedPrice)
        );

        vm.expectEmit(address(priceOracle));
        emit IPriceOracle.UpdatedPrice(usd, 136218495510421100881726, fixedPrice, block.timestamp);

        vm.expectEmit(address(tabRegistry));
        emit ITabRegistry.TriggeredCtrlAltDelTab(usd, fixedPrice);

        vm.expectEmit(address(governanceAction));
        emit IGovernanceAction.CtrlAltDelTab(usd, fixedPrice);

        // oracle price value = 136218495510421100881726, set to
        // fixed price 139777768634848658534534
        governanceAction.ctrlAltDel(usd, fixedPrice); 

        vm.stopPrank();

        bytes3[] memory postDepegTabs = tabRegistry.getCtrlAltDelTabList();
        assertEq(postDepegTabs[0], usd);
        assertEq(tabRegistry.ctrlAltDelTab(tabRegistry.tabCodeToTabKey(usd)), fixedPrice);
        assertEq(priceOracle.ctrlAltDelTab(usd), fixedPrice);

        IProtocolVault.PVault memory v;
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(reserve_ctrlBTC, usdAddr);
        assertEq(v.reserveAddr, reserve_ctrlBTC);
        assertEq(v.reserveAmt, Math.mulDiv(10000e18, 1e18, fixedPrice) * 2);
        assertEq(v.tab, usdAddr);
        assertEq(v.tabAmt, 20000e18);
        assertEq(v.price, fixedPrice);

        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(reserve_WBTC1, usdAddr);
        assertEq(v.reserveAddr, reserve_WBTC1);
        assertEq(
            v.reserveAmt,
            Math.mulDiv(1648e18, 1e18, fixedPrice) + Math.mulDiv(1e18, 1e18, fixedPrice)
        );
        assertEq(v.tab, usdAddr);
        assertEq(v.tabAmt, 1648e18 + 1e18);
        assertEq(v.price, fixedPrice);

        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(reserve_WBTC2, usdAddr);
        assertEq(v.reserveAddr, reserve_WBTC2);
        assertEq(
            v.reserveAmt,
            Math.mulDiv(1234e18, 1e18, fixedPrice) + Math.mulDiv(20400e18, 1e18, fixedPrice)
        );
        assertEq(v.tab, usdAddr);
        assertEq(v.tabAmt, 1234e18 + 20400e18);
        assertEq(v.price, fixedPrice);
    }

    function test_initCtrlAltDel_revert() public {
        vm.startPrank(address(governanceTimelockController));
        
        vm.expectRevert();
        governanceAction.ctrlAltDel(usd, 0);

        vm.expectRevert(IProtocolVault.ZeroValue.selector);
        protocolVault.initCtrlAltDel(reserve_ctrlBTC, 1e18, usdAddr, 100e18, 0);

        governanceAction.ctrlAltDel(usd, fixedPrice);

        vm.expectRevert(ITabRegistry.ExecutedDepeg.selector);
        governanceAction.ctrlAltDel(usd, fixedPrice);

        vm.expectRevert(IProtocolVault.ExistedProtovolVault.selector);
        protocolVault.initCtrlAltDel(reserve_ctrlBTC, 1e18, usdAddr, 100e18, fixedPrice);
        vm.expectRevert(IProtocolVault.ExistedProtovolVault.selector);
        protocolVault.initCtrlAltDel(reserve_WBTC1, 1e18, usdAddr, 100e18, fixedPrice);
        vm.expectRevert(IProtocolVault.ExistedProtovolVault.selector);
        protocolVault.initCtrlAltDel(reserve_WBTC2, 1e18, usdAddr, 100e18, fixedPrice);

        vm.stopPrank();
    }

    function test_initCtrlAltDel_postStatus() public {
        vm.startPrank(address(governanceTimelockController));
        governanceAction.ctrlAltDel(usd, fixedPrice);
        vm.stopPrank();

        IVaultManager.Vault memory m;

        uint256 id = vaultManager.vaultOwners(eoa_accounts[0], 6);
        assertEq(id, 7); // index 6 = vault id 7

        vm.expectRevert();
        vaultManager.vaultOwners(eoa_accounts[0], 7); // index 7 is not existed for owner eoa_accounts[0]

        console.log("Checking post ctl-alt-del vault status of owner: ", eoa_accounts[0]);
        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 1);
        assertEq(m.reserveAmt, 5e18 - Math.mulDiv(10000e18, 1e18, fixedPrice));
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 2);
        assertEq(m.reserveAmt, 2e18 - Math.mulDiv(1234e18, 1e18, fixedPrice));
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 3);
        assertEq(m.reserveAmt, 1e17); // tab is not ctrl-alt-del, full reserve remained
        assertEq(m.tabAmt, 1e18);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 4);
        assertEq(m.reserveAmt, 5e18 - Math.mulDiv(1648e18, 1e18, fixedPrice));
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 5);
        assertEq(m.reserveAmt, 5e18 - Math.mulDiv(20400e18, 1e18, fixedPrice) );
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 6);
        assertEq(m.reserveAmt, 1e17); // tab is not ctrl-alt-del, full reserve remained
        assertEq(m.tabAmt, 1e18);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 7);
        assertEq(m.reserveAmt, 5e18 - Math.mulDiv(10000e18, 1e18, fixedPrice));
        assertEq(m.tabAmt, 0);
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);

        // withdraw excess reserve
        vm.startPrank(eoa_accounts[0]);

        priceData = signer.getUpdatePriceSignature(afn, priceOracle.getPrice(afn), block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.ExceededWithdrawable.selector, 99999339181021902));
        vaultManager.withdrawReserve(3, 1e17, priceData); // vault's tab is not ctrl-alt-del

        address reserveSafeAddr = reserveRegistry.reserveAddrSafe(reserve_ctrlBTC);
        uint256 balB4 = cBTC.balanceOf(reserveSafeAddr);

        vaultManager.withdrawReserve(
            1, 
            5e18 - Math.mulDiv(10000e18, 1e18, fixedPrice), 
            signer.getUpdatePriceSignature(usd, priceOracle.getPrice(usd), block.timestamp)
        );
        uint256 balAfter = cBTC.balanceOf(reserveSafeAddr);
        assertEq(balB4 - (5e18 - Math.mulDiv(10000e18, 1e18, fixedPrice)), balAfter); 

        vaultManager.withdrawReserve(
            2, 
            2e18 - Math.mulDiv(1234e18, 1e18, fixedPrice), 
            signer.getUpdatePriceSignature(usd, priceOracle.getPrice(usd), block.timestamp)
        );

        balB4 = wBTC1.balanceOf(eoa_accounts[0]); // 4800000000000000000
        vaultManager.withdrawReserve(
            4, 
            5e18 - Math.mulDiv(1648e18, 1e18, fixedPrice), 
            signer.getUpdatePriceSignature(usd, priceOracle.getPrice(usd), block.timestamp)
        );

        balAfter = wBTC1.balanceOf(eoa_accounts[0]);
        // owner received excess reserve
        assertEq(balB4 + 5e18 - Math.mulDiv(1648e18, 1e18, fixedPrice), balAfter); 

        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[0], 4);
        assertEq(m.reserveAmt, 0); // no more reserve in the vault
        assertEq(m.tabAmt, 0);

        vm.stopPrank();
    }

    function test_reserveSafe_balance() public {
        address safe1 = reserveRegistry.reserveAddrSafe(reserve_ctrlBTC);
        address safe2 = reserveRegistry.reserveAddrSafe(reserve_WBTC1);
        address safe3 = reserveRegistry.reserveAddrSafe(reserve_WBTC2);

        // Safe balances before ctrl-alt-del
        uint256 bal1 = cBTC.balanceOf(safe1);
        uint256 bal2 = wBTC1.balanceOf(safe2);
        uint256 bal3 = wBTC2.balanceOf(safe3);

        assertEq(bal1, 5e18 + 5e18);
        assertEq(bal2, 5e18 + 1e17 + 1e17 + 1e18);
        assertEq(bal3, 5e8 + 2e8 + 5e8);

        vm.startPrank(address(governanceTimelockController));
        governanceAction.ctrlAltDel(usd, fixedPrice);
        vm.stopPrank();

        // transferred from Safe into ProtocolVault
        uint256 bal1Af = cBTC.balanceOf(safe1);
        uint256 bal2Af = wBTC1.balanceOf(safe2);
        uint256 bal3Af = wBTC2.balanceOf(safe3);

        assertEq(bal1Af, bal1 - ((Math.mulDiv(10000e18, 1e18, fixedPrice)) * 2));
        assertEq(
            bal2Af,
            bal2
                - (
                    (Math.mulDiv(1648e18, 1e18, fixedPrice))
                        + (Math.mulDiv(1e18, 1e18, fixedPrice))
                )
        );
        assertEq(
            bal3Af,
            bal3
                - reserveSafe.getNativeTransferAmount(reserve_WBTC2, Math.mulDiv(1234e18, 1e18, fixedPrice)
                    + Math.mulDiv(20400e18, 1e18, fixedPrice))
        );

        address protocolVaultAddr = address(protocolVault);
        bal1 = cBTC.balanceOf(protocolVaultAddr);
        bal2 = wBTC1.balanceOf(protocolVaultAddr);
        bal3 = wBTC2.balanceOf(protocolVaultAddr);
        
        assertEq(bal1, ((Math.mulDiv(10000e18, 1e18, fixedPrice)) * 2));
        assertEq(
            bal2,
            ((Math.mulDiv(1648e18, 1e18, fixedPrice)) + (Math.mulDiv(1e18, 1e18, fixedPrice)))
        );
        assertEq(bal3, reserveSafe.getNativeTransferAmount(
            reserve_WBTC2, 
            Math.mulDiv(1234e18, 1e18, fixedPrice) + Math.mulDiv(20400e18, 1e18, fixedPrice)
        ));
    }

    function test_buyTab_sellTab() public {
        address protocolVaultAddr = address(protocolVault);
        TabERC20 sUSD = TabERC20(usdAddr);

        vm.startPrank(address(governanceTimelockController));
        governanceAction.ctrlAltDel(usd, fixedPrice);
        sUSD.grantRole(MINTER_ROLE, protocolVaultAddr);
        vm.stopPrank();

        vm.startPrank(deployer);
        cBTC.mint(eoa_accounts[5], 100e18);
        wBTC1.mint(eoa_accounts[5], 100e18);
        wBTC2.mint(eoa_accounts[5], 100e8);
        vm.startPrank(address(vaultManager));
        sUSD.mint(eoa_accounts[5], 100e18);

        vm.startPrank(eoa_accounts[5]);
        cBTC.approve(protocolVaultAddr, type(uint256).max);
        wBTC1.approve(protocolVaultAddr, type(uint256).max);
        wBTC2.approve(protocolVaultAddr, type(uint256).max);
        sUSD.approve(protocolVaultAddr, type(uint256).max);

        IProtocolVault.PVault memory v;
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(reserve_ctrlBTC, usdAddr);
        uint256 userBtcBalB4 = cBTC.balanceOf(eoa_accounts[5]);
        uint256 btcBalB4 = cBTC.balanceOf(protocolVaultAddr);
        uint256 tabBalB4 = sUSD.balanceOf(eoa_accounts[5]);
        
        vm.expectRevert(IProtocolVault.NotExistedProtocolVault.selector);
        protocolVault.buyTab(owner, usdAddr, 1e18);
        vm.expectRevert(IProtocolVault.ZeroValue.selector);
        protocolVault.buyTab(reserve_ctrlBTC, usdAddr, 0);
        vm.expectRevert(IProtocolVault.NotExistedProtocolVault.selector);
        protocolVault.sellTab(owner, usdAddr, 1e18);
        vm.expectRevert(IProtocolVault.ZeroValue.selector);
        protocolVault.sellTab(reserve_ctrlBTC, usdAddr, 0);

        // Sell TAB, buy BTC
        vm.expectEmit();
        emit IProtocolVault.SellTab(
            eoa_accounts[5], reserve_ctrlBTC, Math.mulDiv(43523e15, 1e18, fixedPrice), usdAddr, 43523e15
        );
        uint256 value = protocolVault.sellTab(reserve_ctrlBTC, usdAddr, 43523e15);
        uint256 newReserveAmt = v.reserveAmt - value;
        value = reserveSafe.getNativeTransferAmount(reserve_ctrlBTC, value);

        assertEq(userBtcBalB4 + value, cBTC.balanceOf(eoa_accounts[5])); // received btc
        assertEq(tabBalB4 - 43523e15, sUSD.balanceOf(eoa_accounts[5])); // sold tab, reduced balance
        assertEq(btcBalB4 - value, cBTC.balanceOf(protocolVaultAddr));
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(reserve_ctrlBTC, usdAddr);
        assertEq(v.reserveAmt, newReserveAmt);

        userBtcBalB4 = cBTC.balanceOf(eoa_accounts[5]);
        btcBalB4 = cBTC.balanceOf(protocolVaultAddr);
        tabBalB4 = sUSD.balanceOf(eoa_accounts[5]);

        // Sell BTC, buy TAB
        vm.expectEmit();
        emit IProtocolVault.BuyTab(eoa_accounts[5], reserve_ctrlBTC, 1e17, usdAddr, Math.mulDiv(1e17, fixedPrice, 1e18));
        value = protocolVault.buyTab(reserve_ctrlBTC, usdAddr, 1e17); // spend 1e17 btc to buy tab

        assertEq(userBtcBalB4 - 1e17, cBTC.balanceOf(eoa_accounts[5])); // user wallet spent btc
        assertEq(btcBalB4 + 1e17, cBTC.balanceOf(protocolVaultAddr)); // vault increased btc reserve
        assertEq(tabBalB4 + value, sUSD.balanceOf(eoa_accounts[5])); // user received tab

        // sell tab, get BTC (8 decimals)
        userBtcBalB4 = wBTC2.balanceOf(eoa_accounts[5]);
        btcBalB4 = wBTC2.balanceOf(protocolVaultAddr);
        tabBalB4 = sUSD.balanceOf(eoa_accounts[5]);
        value = protocolVault.sellTab(reserve_WBTC2, usdAddr, 432e18);
        
        assertEq(Math.mulDiv(432e18, 1e18, fixedPrice), value);
        assertEq(wBTC2.balanceOf(eoa_accounts[5]), userBtcBalB4 + reserveSafe.getNativeTransferAmount(reserve_WBTC2, value));
        assertEq(wBTC2.balanceOf(protocolVaultAddr), btcBalB4 - reserveSafe.getNativeTransferAmount(reserve_WBTC2, value));
        assertEq(sUSD.balanceOf(eoa_accounts[5]), tabBalB4 - 432e18);

        // buy tab, sell BTC (8 decimals)
        userBtcBalB4 = wBTC2.balanceOf(eoa_accounts[5]);
        btcBalB4 = wBTC2.balanceOf(protocolVaultAddr);
        tabBalB4 = sUSD.balanceOf(eoa_accounts[5]);
        value = protocolVault.buyTab(reserve_WBTC2, usdAddr, 100e18);
        assertEq(Math.mulDiv(100e18, fixedPrice, 1e18), value);
        assertEq(wBTC2.balanceOf(eoa_accounts[5]), userBtcBalB4 - 100e8);
        assertEq(wBTC2.balanceOf(protocolVaultAddr), btcBalB4 + 100e8);
        assertEq(sUSD.balanceOf(eoa_accounts[5]), tabBalB4 + Math.mulDiv(100e18, fixedPrice, 1e18));

        vm.stopPrank();
    }

    function test_sellTab_clearBTCInVault() public {
        address protocolVaultAddr = address(protocolVault);
        TabERC20 sUSD = TabERC20(usdAddr);
        IProtocolVault.PVault memory v;

        // park sUSD to account-5
        vm.startPrank(eoa_accounts[0]);
        sUSD.transfer(eoa_accounts[5], 1648e18); // wBTC1
        sUSD.transfer(eoa_accounts[5], 20400e18); // wBTC2
        sUSD.transfer(eoa_accounts[5], 1234e18); // wBTC2
        
        vm.startPrank(eoa_accounts[1]);
        sUSD.transfer(eoa_accounts[5], 1e18); // wBTC1

        vm.startPrank(address(governanceTimelockController));
        governanceAction.ctrlAltDel(usd, fixedPrice);
        sUSD.grantRole(MINTER_ROLE, protocolVaultAddr);
        vm.stopPrank();

        vm.startPrank(eoa_accounts[5]);
        sUSD.approve(protocolVaultAddr, type(uint256).max);

        protocolVault.sellTab(reserve_WBTC1, usdAddr, 1648e18 + 1e18);
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(reserve_WBTC1, usdAddr);
        assertEq(v.reserveAmt, 0);
        assertEq(v.tabAmt, 0);

        protocolVault.sellTab(reserve_WBTC2, usdAddr, 20400e18 + 1234e18);
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(reserve_WBTC2, usdAddr);
        assertEq(v.reserveAmt, 0);
        assertEq(v.tabAmt, 0);

        vm.startPrank(address(vaultManager));
        sUSD.mint(eoa_accounts[5], 100e18);

        vm.startPrank(eoa_accounts[5]);
        vm.expectRevert(IProtocolVault.InsufficientReserveBalance.selector);
        protocolVault.sellTab(reserve_WBTC1, usdAddr, 100e18);
    }

    function test_PendingOSVault(uint256 riskPenaltyToCharge) public {
        fixedPrice = 272389271443287478942585;
        uint256 maxRPCharged = Math.mulDiv(5e18, fixedPrice, 1e18) / 20400e18;

        // Vault OS + riskPenaltyToCharge has to be within liquidation ratio
        if (maxRPCharged >= riskPenaltyToCharge) {
            vm.assume((maxRPCharged - riskPenaltyToCharge >= 0) && riskPenaltyToCharge > 0);
            require((maxRPCharged - riskPenaltyToCharge >= 0) && riskPenaltyToCharge > 0);
        } else {
            riskPenaltyToCharge = bound(riskPenaltyToCharge, 1, maxRPCharged);
            require(riskPenaltyToCharge >= 1 && riskPenaltyToCharge <= maxRPCharged);
        }

        TabERC20 sAFN = TabERC20(afnAddr);

        vm.startPrank(deployer);
        wBTC2.mint(eoa_accounts[5], 100e8);

        // risk penalty charged amount is stored in protocol treasury
        uint256 treasuryBalB4 = sAFN.balanceOf(config.treasury());

        // total os = 20400e18 + riskPenaltyToCharge
        vm.startPrank(address(vaultKeeper));
        vaultManager.chargeRiskPenalty(eoa_accounts[1], 8, riskPenaltyToCharge); 

        vm.startPrank(address(governanceTimelockController));
        governanceAction.ctrlAltDel(afn, fixedPrice);

        assertEq(treasuryBalB4 + riskPenaltyToCharge, sAFN.balanceOf(config.treasury()));

        IProtocolVault.PVault memory v;
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(reserve_WBTC2, afnAddr);
        assertEq(v.tabAmt, 20400e18 + riskPenaltyToCharge);

        IVaultManager.Vault memory m;
        (, m.reserveAmt,, m.tabAmt, m.osTabAmt, m.pendingOsMint) = vaultManager.vaults(eoa_accounts[1], 8);
        assertEq(m.reserveAmt, 5e18 - v.reserveAmt); // remaining reserve in user vault
        assertEq(m.tabAmt, 0); // all OS amounts are zero after ctrl-alt-del
        assertEq(m.osTabAmt, 0);
        assertEq(m.pendingOsMint, 0);
    }

    /// @dev sample calculation in excel: ctrl_alt_del.xlsx
    function test_SimulatedExcelData() public {
        fixedPrice = 20000e18; // 1 BTC = 20,000 TAB
        bytes3 xls = bytes3(abi.encodePacked("XLS"));

        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(xls);
        vm.stopPrank();
        
        address tab4Addr = tabRegistry.getTabAddress(xls);
        address reserve_cbBTC = address(cbBTC);

        vm.startPrank(deployer);
        cbBTC.mint(eoa_accounts[5], 100e8);
        cbBTC.mint(eoa_accounts[6], 100e8);
        cbBTC.mint(eoa_accounts[7], 100e8);
        cbBTC.mint(eoa_accounts[8], 100e8);

        vm.startPrank(eoa_accounts[5]);
        cbBTC.approve(address(vaultManager), type(uint256).max);
        vaultManager.createVault(reserve_cbBTC, 8e18, 100000e18, signer.getUpdatePriceSignature(xls, 30000e18, block.timestamp));

        vm.startPrank(eoa_accounts[6]);
        cbBTC.approve(address(vaultManager), type(uint256).max);
        vaultManager.createVault(reserve_cbBTC, 10e18, 120000e18, signer.getUpdatePriceSignature(xls, 30000e18, block.timestamp));

        vm.startPrank(eoa_accounts[7]);
        cbBTC.approve(address(vaultManager), type(uint256).max);
        vaultManager.createVault(reserve_cbBTC, 45e18, 500000e18, signer.getUpdatePriceSignature(xls, 30000e18, block.timestamp));

        vm.startPrank(eoa_accounts[8]);
        cbBTC.approve(address(vaultManager), type(uint256).max);
        vaultManager.createVault(reserve_cbBTC, 10e18, 166666e18, signer.getUpdatePriceSignature(xls, 30000e18, block.timestamp));

        vm.startPrank(address(vaultKeeper));
        vaultManager.chargeRiskPenalty(eoa_accounts[5], 10, 3000e18);
        vaultManager.chargeRiskPenalty(eoa_accounts[6], 11, 1500e18);

        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit(address(protocolVault));
        emit IProtocolVault.InitCtrlAltDel(reserve_cbBTC, 445583e14, tab4Addr, 891166e18, fixedPrice);

        vm.expectEmit(address(vaultManager));
        emit IVaultManager.CtrlAltDel(xls, fixedPrice, 891166e18, 73e18, 445583e14);

        vm.expectEmit(address(priceOracle));
        emit IPriceOracle.UpdatedPrice(xls, 30000e18, fixedPrice, block.timestamp);

        vm.expectEmit(address(tabRegistry));
        emit ITabRegistry.TriggeredCtrlAltDelTab(xls, fixedPrice);

        vm.expectEmit(address(governanceAction));
        emit IGovernanceAction.CtrlAltDelTab(xls, fixedPrice);

        governanceAction.ctrlAltDel(xls, fixedPrice);

        bytes3[] memory postDepegTabs = tabRegistry.getCtrlAltDelTabList();
        assertEq(postDepegTabs[0], xls);
        assertEq(tabRegistry.ctrlAltDelTab(tabRegistry.tabCodeToTabKey(xls)), fixedPrice);
        assertEq(priceOracle.ctrlAltDelTab(xls), fixedPrice);

        IProtocolVault.PVault memory v;
        (v.reserveAddr, v.reserveAmt, v.tab, v.tabAmt, v.price) = protocolVault.vaults(reserve_cbBTC, tab4Addr);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, 445583e14);
        assertEq(v.tab, tab4Addr);
        assertEq(v.tabAmt, 891166e18);
        assertEq(v.price, fixedPrice);

        IVaultManager.Vault memory m;
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

    function getTotalReserveConsolidated(uint256 price) internal pure returns (uint256 total) {
        total += Math.mulDiv(10000e18, 1e18, price); // vault 1  reserve_ctrlBTC
        total += Math.mulDiv(1234e18, 1e18, price); // vault 2  reserve_WBTC2
        total += Math.mulDiv(1648e18, 1e18, price); // vault 4  reserve_WBTC1
        total += Math.mulDiv(20400e18, 1e18, price); // vault 5  reserve_WBTC2
        total += Math.mulDiv(10000e18, 1e18, price); // vault 7  reserve_ctrlBTC
        total += Math.mulDiv(1e18, 1e18, price); // vault 9  reserve_WBTC1
    }
}
