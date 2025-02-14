// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {ITransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {VaultManager_newImpl} from "./upgrade/VaultManager_newImpl.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";
import {IConfig} from "../contracts/interfaces/IConfig.sol";
import {IReserveRegistry} from "../contracts/interfaces/IReserveRegistry.sol";
import {ITabRegistry} from "../contracts/interfaces/ITabRegistry.sol";
import {IPriceOracle} from "../contracts/interfaces/IPriceOracle.sol";
import {IVaultKeeper} from "../contracts/interfaces/IVaultKeeper.sol";

contract VaultManagerTest is Deployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant CTRL_ALT_DEL_ROLE = keccak256("CTRL_ALT_DEL_ROLE");

    bytes3 usd = bytes3(abi.encodePacked("USD"));
    address reserve_cbBTC; 
    address tab;

    function setUp() public {
        deploy();

        reserve_cbBTC = address(cbBTC);
        vm.startPrank(deployer);
        cbBTC.mint(eoa_accounts[0], 10e8);

        vm.startPrank(eoa_accounts[0]);
        cbBTC.approve(address(vaultManager), 10e8);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp);
        vaultManager.createVault(
            reserve_cbBTC, 
            1e18, 
            50000e18, 
            priceData
        );   
        tab = tabRegistry.getTabAddress(usd);
    }

    function test_permission() public {
        assertEq(vaultManager.defaultAdmin() , address(governanceTimelockController));
        assertEq(vaultManager.hasRole(DEPLOYER_ROLE, address(governanceTimelockController)), true);
        assertEq(vaultManager.hasRole(DEPLOYER_ROLE, address(emergencyTimelockController)), true);
        assertEq(vaultManager.hasRole(DEPLOYER_ROLE, owner), false);

        assertEq(vaultManager.hasRole(UPGRADER_ROLE, address(tabProxyAdmin)), true);
        
        assertEq(vaultManager.hasRole(CTRL_ALT_DEL_ROLE, address(governanceTimelockController)), true);
        assertEq(vaultManager.hasRole(CTRL_ALT_DEL_ROLE, address(emergencyTimelockController)), true);
        
        assertEq(vaultManager.hasRole(KEEPER_ROLE, address(vaultKeeper)), true);
        assertEq(vaultManager.hasRole(CTRL_ALT_DEL_ROLE, address(tabRegistry)), true);
        assertEq(vaultManager.getRoleAdmin(KEEPER_ROLE), DEPLOYER_ROLE);
        assertEq(vaultManager.getRoleAdmin(DEPLOYER_ROLE), CTRL_ALT_DEL_ROLE);
        
        assertEq(address(vaultManager.config()), address(config));
        assertEq(address(vaultManager.reserveRegistry()), address(reserveRegistry));
        assertEq(address(vaultManager.tabRegistry()), address(tabRegistry));
        assertEq(address(vaultManager.priceOracle()), address(priceOracle));
        assertEq(address(vaultManager.vaultKeeper()), address(vaultKeeper));

        // createVault from setup
        assertEq(vaultManager.getOwnerList()[0], eoa_accounts[0]);
        assertEq(vaultManager.getAllVaultIDByOwner(eoa_accounts[0])[0], 1);
        assertEq(vaultManager.getVaults(eoa_accounts[0], 1).reserveAmt, 1e18);
        
        vm.expectRevert();
        vaultManager.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        vaultManager.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        vaultManager.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(vaultManager.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        assertEq(tabProxyAdmin.owner(), address(governanceTimelockController));
        vm.startPrank(address(governanceTimelockController));
        tabProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(vaultManager)), 
            address(new VaultManager_newImpl()),
            abi.encodeWithSignature("upgraded(string)", "upgraded_v2")
        );

        VaultManager_newImpl upgraded_v2 = VaultManager_newImpl(address(vaultManager));
        assertEq(keccak256(bytes(upgraded_v2.version())), keccak256("upgraded_v2"));
        assertEq(upgraded_v2.newFunction(), 1e18);

        vm.expectRevert(); // unauthorized
        upgraded_v2.upgraded("test");
        vm.stopPrank();

        assertEq(vaultManager.getOwnerList()[0], eoa_accounts[0]);
        assertEq(vaultManager.getAllVaultIDByOwner(eoa_accounts[0])[0], 1);
        assertEq(vaultManager.getVaults(eoa_accounts[0], 1).reserveAmt, 1e18);

        assertEq(address(vaultManager.config()), address(config));
        assertEq(address(vaultManager.reserveRegistry()), address(reserveRegistry));
        assertEq(address(vaultManager.tabRegistry()), address(tabRegistry));
        assertEq(address(vaultManager.priceOracle()), address(priceOracle));
        assertEq(address(vaultManager.vaultKeeper()), address(vaultKeeper));
    }

    function test_configContractAddress() public {
        vm.expectRevert(); // unauthorized
        vaultManager.configContractAddress(owner, owner, owner, owner, owner);

        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit();
        emit IVaultManager.UpdatedContract(owner, owner, owner, owner, owner);
        vaultManager.configContractAddress(owner, owner, owner, owner, owner);
        assertEq(address(vaultManager.config()), owner);
        assertEq(address(vaultManager.reserveRegistry()), owner);
        assertEq(address(vaultManager.tabRegistry()), owner);
        assertEq(address(vaultManager.priceOracle()), owner);
        assertEq(address(vaultManager.vaultKeeper()), owner);
        assertEq(vaultManager.hasRole(KEEPER_ROLE, owner), true);
        assertEq(vaultManager.hasRole(CTRL_ALT_DEL_ROLE, owner), true);
        vm.stopPrank();
    }

    function test_createVault() public {
        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp);
        
        vm.expectRevert(IVaultManager.ZeroAddress.selector);
        vaultManager.createVault(address(0), 1e18, 50000e18, priceData);

        vm.expectRevert(IVaultManager.ZeroValue.selector);
        vaultManager.createVault(reserve_cbBTC, 0, 50000e18, priceData);
        vm.expectRevert(IVaultManager.ZeroValue.selector);
        vaultManager.createVault(reserve_cbBTC, 1e18, 0, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.ExceededWithdrawable.selector, 55555555555555555555555));
        vaultManager.createVault(reserve_cbBTC, 1e18, 55556e18, priceData);

        TabERC20 sUSD = TabERC20(tab);
        vm.expectEmit();
        emit IVaultManager.NewVault(eoa_accounts[0], 2, reserve_cbBTC, 1e18, address(sUSD), 55555e18);
        vaultManager.createVault(reserve_cbBTC, 1e18, 55555e18, priceData);

        assertEq(cbBTC.balanceOf(eoa_accounts[0]), 10e8 - 1e8 - 1e8);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 1e8 + 1e8);
        assertEq(sUSD.totalSupply(), 50000e18 + 55555e18);
        assertEq(vaultManager.getOwnerList()[0], eoa_accounts[0]);
        assertEq(vaultManager.getAllVaultIDByOwner(eoa_accounts[0])[0], 1);
        assertEq(vaultManager.getAllVaultIDByOwner(eoa_accounts[0])[1], 2);
        assertEq(vaultManager.getVaults(eoa_accounts[0], 2).tabAmt, 55555e18);
    }

    function test_createVault_fuzzyPrice(uint256 _price) public {
        vm.assume(_price > 1e8 && _price < 1e25);
        require(_price > 1e8 && _price < 1e25);
        uint256 _mintAmt = Math.mulDiv(Math.mulDiv(_price, 1e18, 1e18), 100, 250);
        
        nextBlock(100);
        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, _price, block.timestamp);

        vaultManager.createVault(reserve_cbBTC, 1e18, _mintAmt, priceData);

        assertEq(cbBTC.balanceOf(eoa_accounts[0]), 10e8 - 1e8 - 1e8);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 1e8 + 1e8);
        TabERC20 sUSD = TabERC20(tab);
        assertEq(sUSD.totalSupply(), 50000e18 + _mintAmt);
        IVaultManager.Vault memory v = vaultManager.getVaults(eoa_accounts[0], 2);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, 1e18);
        assertEq(v.tab, tab);
        assertEq(v.tabAmt, _mintAmt);
        assertEq(v.osTabAmt, 0);
        assertEq(v.pendingOsMint, 0);
    }

    function test_createVault_fuzzyDeposit(uint256 _depositAmt) public {
        vm.assume(_depositAmt > 1e8 && _depositAmt < 8.999e18);
        require(_depositAmt > 1e8 && _depositAmt < 8.999e18);
        uint256 _price = 9468634e16; // 94,686.34
        uint256 _mintAmt = Math.mulDiv(Math.mulDiv(_depositAmt, _price, 1e18), 100, 250);
        
        nextBlock(100);
        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, _price, block.timestamp);

        vaultManager.createVault(reserve_cbBTC, _depositAmt, _mintAmt, priceData);
        
        uint256 nativeDepositAmt = reserveSafe.getNativeTransferAmount(reserve_cbBTC, _depositAmt);
        assertEq(cbBTC.balanceOf(eoa_accounts[0]), 10e8 - 1e8 - nativeDepositAmt);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 1e8 + nativeDepositAmt);
        TabERC20 sUSD = TabERC20(tab);
        assertEq(sUSD.totalSupply(), 50000e18 + _mintAmt);
        IVaultManager.Vault memory v = vaultManager.getVaults(eoa_accounts[0], 2);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, _depositAmt);
        assertEq(v.tab, tab);
        assertEq(v.tabAmt, _mintAmt);
        assertEq(v.osTabAmt, 0);
        assertEq(v.pendingOsMint, 0);
    }

    function test_disabledReserve() public {
        vm.startPrank(address(governanceTimelockController));
        governanceAction.disableReserve(reserve_cbBTC);
        vm.startPrank(eoa_accounts[0]);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidReserve.selector, reserve_cbBTC));
        vaultManager.createVault(reserve_cbBTC, 1e18, 50000e18, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidReserve.selector, reserve_cbBTC));
        vaultManager.withdrawReserve(1, 1e8, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidReserve.selector, reserve_cbBTC));
        vaultManager.depositReserve(eoa_accounts[0], 1, 1e8);

        vaultManager.withdrawTab(1, 1e18, priceData);

        TabERC20 sUSD = TabERC20(tab);
        sUSD.approve(address(vaultManager), 1e18);
        vaultManager.paybackTab(eoa_accounts[0], 1, 1e18);

        vm.startPrank(address(vaultKeeper));
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, 1e18);
    }

    function test_ctrlAltDel() public {
        vm.startPrank(address(governanceTimelockController));

        // Fixed price fall below existing vault's reserve liquidation level
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.LiquidatingVault.selector, eoa_accounts[0], 1));
        governanceAction.ctrlAltDel(usd, 1e18); 

        governanceAction.ctrlAltDel(usd, 100000e18);

        vm.startPrank(eoa_accounts[0]);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.CtrlAltDelTab.selector, usd));
        vaultManager.createVault(reserve_cbBTC, 1e18, 50000e18, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.CtrlAltDelTab.selector, usd));
        vaultManager.withdrawTab(1, 1e18, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[0], 1));
        vaultManager.paybackTab(eoa_accounts[0], 1, 1e18);

        // able to withdraw reserve
        vaultManager.withdrawReserve(1, 1e8, priceData);

        // able to deposit reserve, although it shouldn't
        vaultManager.depositReserve(eoa_accounts[0], 1, 1e8);

        vm.startPrank(address(vaultKeeper));
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[0], 1));
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, 1e18);
    }

    function test_frozenTab() public {
        vm.startPrank(address(governanceTimelockController));
        governanceAction.disableTab(usd);
        vm.startPrank(eoa_accounts[0]);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.DisabledTab.selector, usd));
        vaultManager.createVault(reserve_cbBTC, 1e18, 50000e18, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.DisabledTab.selector, usd));
        vaultManager.withdrawTab(1, 1e18, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.DisabledTab.selector, usd));
        vaultManager.paybackTab(eoa_accounts[0], 1, 1e18);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.DisabledTab.selector, usd));
        vaultManager.withdrawReserve(1, 1e8, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.DisabledTab.selector, usd));
        vaultManager.depositReserve(eoa_accounts[0], 1, 1e8);
    }

    function test_liquidated() public {
        nextBlock(100);
        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, 50000e18, block.timestamp);

        vm.startPrank(address(governanceTimelockController));
        (
            , 
            , 
            , 
            , 
            uint256 osTab, 
            uint256 reserveValue, 
            uint256 minReserveValue
        ) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, 50000e18);
        IVaultKeeper.VaultDetails memory vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            1,
            usd,
            reserve_cbBTC,
            osTab,
            reserveValue,
            minReserveValue
        );
        vm.expectEmit(address(vaultManager));
        emit IVaultManager.LiquidatedVaultAuction(
            1, reserve_cbBTC, 1e18, tab, Math.mulDiv(50000e18, 90, 100)
        );
        vaultKeeper.checkVault(block.timestamp, vd, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidLiquidatedVault.selector, 1));
        vaultManager.withdrawTab(1, 1e18, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidLiquidatedVault.selector, 1));
        vaultManager.paybackTab(eoa_accounts[0], 1, 1e18);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[0], 1));
        vaultManager.withdrawReserve(1, 1e8, priceData);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[0], 1));
        vaultManager.depositReserve(eoa_accounts[0], 1, 1e8);
    }

    /// forge-config: default.fuzz.show-logs = false
    function test_withdrawTab(uint256 _price) public {
        vm.assume(_price > 30000e18 && _price < 8.88888888e25);
        require(_price > 30000e18 && _price < 8.88888888e25);
        (
            ,
            ,
            ,
            ,
            ,
            uint256 reserveValue,
            uint256 minReserveValue
        ) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, _price);
        if (minReserveValue > reserveValue)
            return;
        (, uint256 _mintAmt) = Math.trySub(Math.mulDiv(Math.mulDiv(_price, 1e18, 1e18), 100, 180), 50000e18);
        if (_mintAmt == 0)
            return;
        
        nextBlock(100);

        vm.startPrank(eoa_accounts[1]); // non-owner
        priceData = signer.getUpdatePriceSignature(usd, _price, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[1], 1));
        vaultManager.withdrawTab(1, _mintAmt, priceData);

        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, _price, block.timestamp);
        vm.expectEmit();
        emit IVaultManager.TabWithdraw(eoa_accounts[0], 1, _mintAmt, 50000e18 + _mintAmt);
        vaultManager.withdrawTab(1, _mintAmt, priceData);

        assertEq(cbBTC.balanceOf(eoa_accounts[0]), 10e8 - 1e8);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 1e8);
        TabERC20 sUSD = TabERC20(tab);
        assertEq(sUSD.totalSupply(), 50000e18 + _mintAmt);
        IVaultManager.Vault memory v = vaultManager.getVaults(eoa_accounts[0], 1);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, 1e18);
        assertEq(v.tab, tab);
        assertEq(v.tabAmt, 50000e18 + _mintAmt);
        assertEq(v.osTabAmt, 0);
        assertEq(v.pendingOsMint, 0);

        (, _mintAmt) = Math.trySub(Math.mulDiv(Math.mulDiv(_price, 1e18, 1e18), 100, 180), v.tabAmt);
        if (_mintAmt > 0) {
            vm.expectEmit();
            emit IVaultManager.TabWithdraw(eoa_accounts[0], 1, _mintAmt, 50000e18 + _mintAmt);
            vaultManager.withdrawTab(1, _mintAmt, priceData);
        } else {
            vm.expectRevert(abi.encodeWithSelector(IVaultManager.ExceededWithdrawable.selector, 0));
            vaultManager.withdrawTab(1, 1, priceData);
        }
    }

    function test_paybackTab(uint256 _paybackAmt, uint256 _riskPenaltyAmt) public {
        vm.assume(_riskPenaltyAmt > 0 && _riskPenaltyAmt < (type(uint256).max - 50000e18) && _paybackAmt > 0 && _paybackAmt <= 50000e18);
        require(_riskPenaltyAmt > 0 && _riskPenaltyAmt < (type(uint256).max - 50000e18) && _paybackAmt > 0 && _paybackAmt <= 50000e18);
        
        vm.startPrank(eoa_accounts[0]);

        TabERC20 sUSD = TabERC20(tab);
        vm.expectRevert();
        vaultManager.paybackTab(eoa_accounts[0], 1, _paybackAmt);

        vm.expectRevert(IVaultManager.ExcessAmount.selector);
        vaultManager.paybackTab(eoa_accounts[0], 1, 50000e18 + 1);

        sUSD.approve(address(vaultManager), _paybackAmt);
        vm.expectEmit();
        emit IVaultManager.TabReturned(eoa_accounts[0], 1, _paybackAmt, 50000e18 - _paybackAmt);
        vaultManager.paybackTab(eoa_accounts[0], 1, _paybackAmt);

        assertEq(cbBTC.balanceOf(address(reserveSafe)), 1e8);
        assertEq(sUSD.balanceOf(eoa_accounts[0]), 50000e18 - _paybackAmt);
        assertEq(sUSD.totalSupply(), 50000e18 - _paybackAmt);
        IVaultManager.Vault memory v = vaultManager.getVaults(eoa_accounts[0], 1);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, 1e18);
        assertEq(v.tab, tab);
        assertEq(v.tabAmt, 50000e18 - _paybackAmt);
        assertEq(v.osTabAmt, 0);
        assertEq(v.pendingOsMint, 0);

        // Assume user buy from tabs from market, workaround by minting more in test
        vm.startPrank(address(vaultManager));
        sUSD.mint(eoa_accounts[0], _riskPenaltyAmt);
        
        uint256 extraMintTab = 1e18;
        if (_paybackAmt == 50000e18) { // special case, fuzzer fully settled OS tab amt
            vm.startPrank(eoa_accounts[0]);
            priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp);
            vaultManager.withdrawTab(1, extraMintTab, priceData);
        } else
            extraMintTab = 0;
        vm.startPrank(address(vaultKeeper));
        vm.expectEmit();
        emit IVaultManager.RiskPenaltyCharged(eoa_accounts[0], 1, _riskPenaltyAmt, v.osTabAmt + extraMintTab + _riskPenaltyAmt);
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, _riskPenaltyAmt);

        vm.startPrank(eoa_accounts[0]);
        _paybackAmt = v.tabAmt + extraMintTab + _riskPenaltyAmt;
        sUSD.approve(address(vaultManager), _paybackAmt);
        vm.expectEmit();
        emit IVaultManager.TabReturned(eoa_accounts[0], 1, _paybackAmt, 0);
        vaultManager.paybackTab(eoa_accounts[0], 1, _paybackAmt);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 1e8);
        assertEq(sUSD.balanceOf(eoa_accounts[0]), 0);
        assertEq(sUSD.balanceOf(config.treasury()), _riskPenaltyAmt);
        assertEq(sUSD.totalSupply(), _riskPenaltyAmt);
        v = vaultManager.getVaults(eoa_accounts[0], 1);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, 1e18);
        assertEq(v.tab, tab);
        assertEq(v.tabAmt, 0);
        assertEq(v.osTabAmt, 0);
        assertEq(v.pendingOsMint, 0);

        // able to withdraw full deposit since all O/S tabs is paybacked
        vm.expectEmit();
        emit IVaultManager.ReserveWithdraw(eoa_accounts[0], 1, 1e18, 0);
        vaultManager.withdrawReserve(1, 1e18, priceData);
        assertEq(cbBTC.balanceOf(eoa_accounts[0]), 10e8);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 0);

    }

    function test_withdrawReserve(uint256 _price) public {
        vm.assume(_price > 30000e18 && _price < 8.88888888e25);
        require(_price > 30000e18 && _price < 8.88888888e25);
        (
            ,
            ,
            ,
            ,
            uint256 osTab,
            uint256 reserveValue,
            uint256 minReserveValue
        ) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, _price);
        if (minReserveValue > reserveValue)
            return;
        uint256 withdrawableReserveAmt = Math.mulDiv(Math.mulDiv(1e18, _price, 1e18) - Math.mulDiv(osTab, 180, 100), 1e18, _price); 
        if (withdrawableReserveAmt == 0)
            return;

        nextBlock(100);

        vm.startPrank(eoa_accounts[1]); // non-owner
        priceData = signer.getUpdatePriceSignature(usd, _price, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[1], 1));
        vaultManager.withdrawReserve(1, withdrawableReserveAmt, priceData);

        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, _price, block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(IVaultManager.ExceededWithdrawable.selector, withdrawableReserveAmt));
        vaultManager.withdrawReserve(1, withdrawableReserveAmt + 1, priceData);

        vm.expectEmit();
        emit IVaultManager.ReserveWithdraw(eoa_accounts[0], 1, withdrawableReserveAmt, 1e18 - withdrawableReserveAmt);
        vaultManager.withdrawReserve(1, withdrawableReserveAmt, priceData);

        TabERC20 sUSD = TabERC20(tab);
        uint256 nativeWithdrawAmt = reserveSafe.getNativeTransferAmount(reserve_cbBTC, withdrawableReserveAmt);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 1e8 - nativeWithdrawAmt);
        assertEq(cbBTC.balanceOf(eoa_accounts[0]), 10e8 - 1e8 + nativeWithdrawAmt);
        assertEq(sUSD.balanceOf(eoa_accounts[0]), 50000e18);
        assertEq(sUSD.totalSupply(), 50000e18);
        IVaultManager.Vault memory v = vaultManager.getVaults(eoa_accounts[0], 1);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, 1e18 - withdrawableReserveAmt);
        assertEq(v.tab, tab);
        assertEq(v.tabAmt, 50000e18);
        assertEq(v.osTabAmt, 0);
        assertEq(v.pendingOsMint, 0);
    }

    function test_depositReserve(uint256 _depositAmt) public {
        vm.assume(_depositAmt > 0 && _depositAmt < type(uint256).max / 2);
        require(_depositAmt > 0 && _depositAmt < type(uint256).max / 2);

        // charge risk penalty    
        vm.startPrank(address(vaultKeeper));
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, _depositAmt);
        vm.stopPrank();
    
        vm.startPrank(deployer);
        cbBTC.mint(eoa_accounts[0], _depositAmt);

        vm.startPrank(eoa_accounts[0]);
        cbBTC.approve(address(vaultManager), _depositAmt);

        vm.expectRevert(IVaultManager.ZeroValue.selector);
        vaultManager.depositReserve(eoa_accounts[0], 1, 0);

        vm.expectEmit();
        emit IVaultManager.ReserveAdded(eoa_accounts[0], 1, _depositAmt, 1e18 + _depositAmt);
        vaultManager.depositReserve(eoa_accounts[0], 1, _depositAmt);

        TabERC20 sUSD = TabERC20(tab);
        uint256 nativeDepositAmt = reserveSafe.getNativeTransferAmount(reserve_cbBTC, _depositAmt);
        assertEq(sUSD.balanceOf(config.treasury()), _depositAmt); // OS Tabs minted to treasury
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 1e8 + nativeDepositAmt);
        IVaultManager.Vault memory v = vaultManager.getVaults(eoa_accounts[0], 1);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, 1e18 + _depositAmt);
        assertEq(v.tab, tab);
        assertEq(v.tabAmt, 50000e18);
        assertEq(v.osTabAmt, _depositAmt); // risk penalty
        assertEq(v.pendingOsMint, 0);
        uint256 price = 1e18;
        (
            , 
            , 
            , 
            , 
            uint256 osTab, 
            uint256 reserveValue, 
            // minReserveValue
        ) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, price);
        assertEq(osTab, 50000e18 + _depositAmt);
        assertEq(reserveValue, Math.mulDiv(1e18, price, 1e18) + _depositAmt);

        // try pay back 50000e18 + portion of charged risk penalty
        uint256 paybackAmt = 50000e18 + (_depositAmt / 2);
        uint256 expectedOSTotal = osTab - paybackAmt;
        uint256 expectedTabBal;
        uint256 expectedOSBal;
        if (_depositAmt > paybackAmt) {
            expectedTabBal = 50000e18;
            expectedOSBal = _depositAmt - paybackAmt;
        } else {
            expectedTabBal = 50000e18 - (paybackAmt - _depositAmt);
            expectedOSBal = 0;
        }
        vm.startPrank(address(vaultManager));
        sUSD.mint(eoa_accounts[0], _depositAmt / 2);

        vm.startPrank(eoa_accounts[0]);
        sUSD.approve(address(vaultManager), paybackAmt);
        vm.expectEmit();
        emit IVaultManager.TabReturned(eoa_accounts[0], 1, paybackAmt, expectedTabBal);
        vaultManager.paybackTab(eoa_accounts[0], 1, paybackAmt);

        assertEq(sUSD.balanceOf(config.treasury()), _depositAmt);
        v = vaultManager.getVaults(eoa_accounts[0], 1);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, 1e18 + _depositAmt);
        assertEq(v.tab, tab);
        assertEq(v.tabAmt, expectedTabBal);
        assertEq(v.osTabAmt, expectedOSBal);
        assertEq(v.pendingOsMint, 0);
        (
            , 
            , 
            , 
            , 
            osTab, 
            reserveValue, 
            // minReserveValue
        ) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, price);
        assertEq(osTab, expectedOSTotal);
    }

    function test_chargeRiskPenalty_liquidateVault(uint256 _amt) public {
        vm.assume(_amt > 0 && _amt < type(uint256).max / 2);
        require(_amt > 0 && _amt < type(uint256).max / 2);

        nextBlock(10);
        vm.startPrank(eoa_accounts[0]);
        uint256 price = 30000e18;
        priceData = signer.getUpdatePriceSignature(usd, price, block.timestamp);

        vm.startPrank(address(vaultKeeper));
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, owner, 1));
        vaultManager.chargeRiskPenalty(owner, 1, _amt);
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[0], 9));
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 9, _amt);

        vm.expectRevert(IVaultManager.ZeroValue.selector);
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, 0);

        vm.expectEmit();
        emit IVaultManager.RiskPenaltyCharged(eoa_accounts[0], 1, _amt, _amt);
        vaultManager.chargeRiskPenalty(eoa_accounts[0], 1, _amt);
        IVaultManager.Vault memory v = vaultManager.getVaults(eoa_accounts[0], 1);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, 1e18);
        assertEq(v.tab, tab);
        assertEq(v.tabAmt, 50000e18);
        assertEq(v.osTabAmt, _amt);
        assertEq(v.pendingOsMint, _amt);

        uint256 extraRP = _amt / 2;
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.InvalidVault.selector, eoa_accounts[0], 9));
        vaultManager.liquidateVault(9, _amt, priceData);

        vm.expectEmit();
        emit IVaultManager.RiskPenaltyCharged(eoa_accounts[0], 1, extraRP, _amt + extraRP);
        vm.expectEmit();
        emit IVaultManager.LiquidatedVaultAuction(1, reserve_cbBTC, 1e18, tab, Math.mulDiv(price, 90, 100));
        vaultManager.liquidateVault(1, extraRP, priceData);
        assertEq(cbBTC.balanceOf(eoa_accounts[0]), 10e8 - 1e8);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), 0);
        assertEq(cbBTC.balanceOf(address(auctionManager)), 1e8);
        TabERC20 sUSD = TabERC20(tab);
        assertEq(sUSD.totalSupply(), 50000e18);
        v = vaultManager.getVaults(eoa_accounts[0], 1);
        assertEq(v.reserveAddr, reserve_cbBTC);
        assertEq(v.reserveAmt, 0);
        assertEq(v.tab, tab);
        assertEq(v.tabAmt, 50000e18);
        assertEq(v.osTabAmt, _amt + extraRP);
        assertEq(v.pendingOsMint, _amt + extraRP);

        IVaultManager.LiquidatedVault memory lv = vaultManager.getLiquidatedVault(1);
        assertEq(lv.vaultOwner, eoa_accounts[0]);
        assertEq(lv.auctionAddr, address(auctionManager));
    }

}