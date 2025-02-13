// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {ITransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {VaultKeeper_newImpl} from "./upgrade/VaultKeeper_newImpl.sol";
import {IVaultKeeper} from "../contracts/interfaces/IVaultKeeper.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";
import {IConfig} from "../contracts/interfaces/IConfig.sol";

contract VaultKeeperTest is Deployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    uint256 usd2ndRunRiskPenalty;
    uint256 usd3rdRunRiskPenalty;
    uint256 myr1stRunRiskPenalty;    
    address vaultOwner;
    bytes3 vaultTab;
    uint256 listIndex;

    function setUp() public {
        deploy();

        vm.startPrank(address(governanceTimelockController));
        vaultKeeper.setRiskPenaltyFrameInSecond(10); // changed from default 24 hours 
        vm.stopPrank();
        nextBlock(1703753421);
    }

    function test_permission() public {
        assertEq(vaultKeeper.defaultAdmin() , address(governanceTimelockController));
        assertEq(vaultKeeper.hasRole(EXECUTOR_ROLE, address(governanceTimelockController)), true);
        assertEq(vaultKeeper.hasRole(EXECUTOR_ROLE, address(emergencyTimelockController)), true);
        assertEq(vaultKeeper.hasRole(EXECUTOR_ROLE, keeperAddr), true);
        assertEq(vaultKeeper.hasRole(EXECUTOR_ROLE, address(vaultManager)), true);

        assertEq(vaultKeeper.hasRole(MAINTAINER_ROLE, address(governanceTimelockController)), true);
        assertEq(vaultKeeper.hasRole(MAINTAINER_ROLE, address(emergencyTimelockController)), true);
        assertEq(vaultKeeper.hasRole(MAINTAINER_ROLE, keeperAddr), true);
        assertEq(vaultKeeper.hasRole(MAINTAINER_ROLE, address(config)), true);

        assertEq(vaultKeeper.hasRole(DEPLOYER_ROLE, address(governanceTimelockController)), true);
        assertEq(vaultKeeper.hasRole(DEPLOYER_ROLE, address(emergencyTimelockController)), true);

        assertEq(vaultKeeper.hasRole(UPGRADER_ROLE, address(tabProxyAdmin)), true);

        assertEq(vaultKeeper.vaultManager(), address(vaultManager));
        assertEq(vaultKeeper.riskPenaltyFrameInSecond(), 10);

        vm.expectRevert();
        vaultKeeper.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        vaultKeeper.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        vaultKeeper.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(vaultKeeper.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        assertEq(tabProxyAdmin.owner(), address(governanceTimelockController));
        vm.startPrank(address(governanceTimelockController));
        tabProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(vaultKeeper)), 
            address(new VaultKeeper_newImpl()),
            abi.encodeWithSignature("upgraded(string)", "upgraded_v2")
        );

        VaultKeeper_newImpl upgraded_v2 = VaultKeeper_newImpl(address(vaultKeeper));
        assertEq(keccak256(bytes(upgraded_v2.version())), keccak256("upgraded_v2"));
        assertEq(upgraded_v2.newFunction(), 1e18);

        vm.expectRevert(); // unauthorized
        upgraded_v2.upgraded("test");
        vm.stopPrank();

        assertEq(upgraded_v2.vaultManager(), address(vaultManager));
        assertEq(vaultKeeper.riskPenaltyFrameInSecond(), 10);
    }

    function test_updateVaultManagerAddress() public {
        vm.expectRevert(); // unauthorized
        vaultKeeper.updateVaultManagerAddress(owner);

        vm.startPrank(address(governanceTimelockController));

        vm.expectRevert(IVaultKeeper.ZeroAddress.selector);
        vaultKeeper.updateVaultManagerAddress(address(0));
        vm.expectRevert(IVaultKeeper.InvalidVaultManager.selector);
        vaultKeeper.updateVaultManagerAddress(eoa_accounts[1]);

        vm.expectEmit();
        emit IVaultKeeper.UpdatedVaultManagerAddress(vaultKeeper.vaultManager(), address(reserveSafe));
        vaultKeeper.updateVaultManagerAddress(address(reserveSafe));
        assertEq(vaultKeeper.vaultManager(), address(reserveSafe));
        assertEq(vaultKeeper.hasRole(EXECUTOR_ROLE, address(reserveSafe)), true);

        vm.stopPrank();
    }

    function test_setTabParams() public {
        bytes3[] memory tabs = new bytes3[](2);
        bytes3[] memory tabs3 = new bytes3[](3);
        tabs[0] = bytes3(abi.encodePacked("USD"));
        tabs[1] = bytes3(abi.encodePacked("JPY"));
        IConfig.TabParams[] memory tabParams = new IConfig.TabParams[](2);
        IConfig.TabParams[] memory tabParams3 = new IConfig.TabParams[](3);
        tabParams[0].riskPenaltyPerFrame = 1;
        tabParams[0].processFeeRate = 2;
        tabParams[0].minReserveRatio = 3;
        tabParams[0].liquidationRatio = 4;
        tabParams[1].riskPenaltyPerFrame = 5;
        tabParams[1].processFeeRate = 6;
        tabParams[1].minReserveRatio = 7;
        tabParams[1].liquidationRatio = 8;

        vm.startPrank(eoa_accounts[1]);
        vm.expectRevert(); // unauthorized
        vaultKeeper.setTabParams(tabs, tabParams);

        vm.startPrank(address(governanceTimelockController));
        
        vm.expectRevert(IConfig.InvalidArrayLength.selector);
        vaultKeeper.setTabParams(tabs, tabParams3);
        vm.expectRevert(IConfig.InvalidArrayLength.selector);
        vaultKeeper.setTabParams(tabs3, tabParams);

        vm.expectEmit(address(vaultKeeper));
        emit IConfig.UpdatedTabParams(tabs[0], 1, 2, 3, 4);
        vm.expectEmit(address(vaultKeeper));
        emit IConfig.UpdatedTabParams(tabs[1], 5, 6, 7, 8);
        vaultKeeper.setTabParams(tabs, tabParams);

        (uint256 riskPenaltyPerFrame, uint256 processFeeRate, uint256 minReserveRatio, uint256 liquidationRatio) = 
            vaultKeeper.tabParams(keccak256(abi.encodePacked(tabs[0])));
        assertEq(riskPenaltyPerFrame, 1);
        assertEq(processFeeRate, 2);
        assertEq(minReserveRatio, 3);
        assertEq(liquidationRatio, 4);
        ( riskPenaltyPerFrame, processFeeRate, minReserveRatio, liquidationRatio) = 
            vaultKeeper.tabParams(keccak256(abi.encodePacked(tabs[1])));
        assertEq(riskPenaltyPerFrame, 5);
        assertEq(processFeeRate, 6);
        assertEq(minReserveRatio, 7);
        assertEq(liquidationRatio, 8);
        vm.stopPrank();
    }

    function test_setRiskPenaltyFrameInSecond(uint256 value) public {
        vm.assume(value > 0 && value < type(uint256).max);
        require(value > 0 && value < type(uint256).max);

        vm.startPrank(eoa_accounts[0]);
        vm.expectRevert(); // unauthorized
        vaultKeeper.setRiskPenaltyFrameInSecond(value);

        vm.startPrank(address(governanceTimelockController));
        vm.expectRevert(IVaultKeeper.ZeroValue.selector);
        vaultKeeper.setRiskPenaltyFrameInSecond(0);

        vm.expectEmit();
        emit IVaultKeeper.UpdatedRiskPenaltyFrameInSecond(10, value);
        vaultKeeper.setRiskPenaltyFrameInSecond(value);
        assertEq(vaultKeeper.riskPenaltyFrameInSecond(), value);
        vm.stopPrank();
    }

    function test_checkVault() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        uint256 assignedPrice = 25738e18;
        uint256 vaultId;

        vm.startPrank(deployer);
        cbBTC.mint(eoa_accounts[0], 10e8);

        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(usd); // USD
        nextBlock(1);
        priceOracle.setDirectPrice(usd, assignedPrice, block.timestamp);

        nextBlock(1);
        vm.startPrank(eoa_accounts[0]);

        // approve 10 BTC to vault manager
        cbBTC.approve(address(vaultManager), 10e8);
        assertEq(cbBTC.allowance(eoa_accounts[0], address(vaultManager)), 10e8);

        // create vault
        // current reserve ratio = 25738 / 14298 = 180.01%, just slightly above minimum reserve ratio
        vaultManager.createVault(
            address(cbBTC), 
            1e18, 
            14298e18, 
            signer.getUpdatePriceSignature(usd, assignedPrice, block.timestamp)
        ); // max withdrawable = 25738 / 180% = 14298.888888888888888888888888889
        vaultId = vaultManager.getAllVaultIDByOwner(eoa_accounts[0])[0];
        assertEq(vaultId, 1);

        (
            bytes3 tab,
            address reserveAddr,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            uint256 reserveValue,
            uint256 minReserveValue
        ) = vaultUtils.getVaultDetails(eoa_accounts[0], vaultId, assignedPrice);
        assertEq(reserveAddr, address(cbBTC));
        assertEq(price, assignedPrice);
        assertEq(reserveAmt, 1e18);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 25738e18);
        assertEq(minReserveValue, 257364e17);

        vm.stopPrank();
        nextBlock(1 days);

        // price dropped, RR below 180%, start charging risk penalty
        assignedPrice = 20000e18; 
        vm.startPrank(address(governanceTimelockController));
        priceOracle.setDirectPrice(usd, assignedPrice, block.timestamp);
        vm.stopPrank();
        (,, price,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], vaultId, priceOracle.getPrice(usd));
        assertEq(price, assignedPrice);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 20000e18);
        assertEq(minReserveValue, 257364e17);

        nextBlock(1);
        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(tab, assignedPrice, block.timestamp);
        
        IVaultKeeper.VaultDetails memory vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            vaultId,
            usd,
            address(cbBTC),
            osTab,
            reserveValue,
            minReserveValue
        );

        vm.startPrank(eoa_accounts[0]);
        vm.expectRevert(); // unauthorized
        vaultKeeper.checkVault(block.timestamp, vd, priceData);

        // first checkVault, risk penalty not charged, still within same frame
        vm.startPrank(address(governanceTimelockController));
        vaultKeeper.checkVault(block.timestamp, vd, priceData);

        uint256 delta = minReserveValue - reserveValue;
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], vaultId));
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(vaultId);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), vaultId);
        assertEq(vaultTab, tab);

        // second checkVault: passed RP frame, expect to charge risk penalty on 1 frame
        nextBlock(10);
        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(tab, assignedPrice, block.timestamp);

        vm.startPrank(address(governanceTimelockController));
        vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            vaultId,
            usd,
            address(cbBTC),
            osTab,
            reserveValue,
            minReserveValue
        );
        vm.expectEmit(address(vaultKeeper));
        emit IVaultKeeper.RiskPenaltyCharged(block.timestamp, eoa_accounts[0], vaultId, delta, Math.mulDiv(150, delta, 10000));
        vaultKeeper.checkVault(block.timestamp, vd, priceData);

        (,,,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], vaultId, assignedPrice);
        assertEq(osTab, 14384046000000000000000); // minted tab 14298e18 + risk penalty charged 86046e15
        assertEq(reserveValue, 20000e18);
        assertEq(minReserveValue, 258912828e14);

        // charged RP in prev frame, delta recorded in current frame
        delta = minReserveValue - reserveValue; // 5891.2828
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], vaultId));
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(vaultId);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), vaultId);
        vm.expectRevert();
        assertEq(vaultKeeper.vaultIdList(1), 0); // expect not existed

        // third checkVault: price dropped further, reserve ratio below 120%, charge RP for more frames and liquidate
        nextBlock(1);
        assignedPrice = 17000e18; // BTC/USD 17000
        nextBlock(106); // 10 frames passed

        vm.startPrank(address(governanceTimelockController));
        priceOracle.setDirectPrice(usd, assignedPrice, block.timestamp);
        vm.stopPrank();

        (,,,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], vaultId, assignedPrice);
        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(tab, assignedPrice, block.timestamp);
        vm.startPrank(address(governanceTimelockController));
        vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            vaultId,
            usd,
            address(cbBTC),
            osTab,
            reserveValue,
            minReserveValue
        );
        vm.expectEmit(false, false, false, false, address(vaultKeeper));
        emit IVaultKeeper.RiskPenaltyCharged(block.timestamp, eoa_accounts[0], vaultId, delta, Math.mulDiv(150, delta, 10000)); // prev. frame risk penalty
        vm.expectEmit(address(vaultKeeper));
        emit IVaultKeeper.StartVaultLiquidation(block.timestamp, eoa_accounts[0], vaultId, 135755211534000000000);
        vm.expectEmit(address(vaultKeeper));
        emit IVaultKeeper.RiskPenaltyCharged(block.timestamp, eoa_accounts[0], vaultId, 9050347435600000000000, 135755211534000000000); // current frame's risk penalty
        vaultKeeper.checkVault(block.timestamp, vd, priceData);

        (,,,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], vaultId, assignedPrice);
        // OS: 14384046000000000000000 + 88369242000000000000 + 135755211534000000000 = 14608170453534000000000
        assertEq(osTab, 14608170453534000000000);
        assertEq(reserveValue, 0);
        // 14608170453534000000000 * 180 / 100 = 26294706816361200000000
        assertEq(minReserveValue, 26294706816361200000000); 
    }

    function test_checkVault_2ndLargestVaultDelta_thenLiquidate() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        bytes3 myr = bytes3(abi.encodePacked("MYR"));
        uint256 usdPrice = 25738e18;
        uint256 myrPrice = 174603438331485931421445;

        vm.startPrank(deployer);
        cbBTC.mint(eoa_accounts[0], 2e8);

        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(usd); // USD
        governanceAction.createNewTab(myr); // MYR
        nextBlock(1);
        priceOracle.setDirectPrice(usd, usdPrice, block.timestamp);
        priceOracle.setDirectPrice(myr, myrPrice, block.timestamp);

        nextBlock(1);
        vm.startPrank(eoa_accounts[0]);

        // approve 10 BTC to vault manager
        cbBTC.approve(address(vaultManager), 2e8);
        assertEq(cbBTC.allowance(eoa_accounts[0], address(vaultManager)), 2e8);

        // create vault
        // current reserve ratio = 25738 / 14298 = 180.01%, just slightly above minimum reserve ratio
        vaultManager.createVault(
            address(cbBTC), 
            1e18, 
            14298e18, 
            signer.getUpdatePriceSignature(usd, usdPrice, block.timestamp)
        );
        vaultManager.createVault(
            address(cbBTC), 
            1e18, 
            97001910184158850789691, 
            signer.getUpdatePriceSignature(myr, myrPrice, block.timestamp)
        );
        assertEq(vaultManager.getAllVaultIDByOwner(eoa_accounts[0])[0], 1);
        assertEq(vaultManager.getAllVaultIDByOwner(eoa_accounts[0])[1], 2);

        (
            bytes3 tab,
            address reserveAddr,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            uint256 reserveValue,
            uint256 minReserveValue
        ) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, usdPrice);
        assertEq(keccak256(abi.encodePacked(tab)), keccak256(abi.encodePacked(usd))); // USD
        assertEq(reserveAddr, address(cbBTC));
        assertEq(price, usdPrice);
        assertEq(reserveAmt, 1e18);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 25738e18);
        assertEq(minReserveValue, 257364e17);

        (tab, reserveAddr, price, reserveAmt, osTab, reserveValue, minReserveValue) =
            vaultUtils.getVaultDetails(eoa_accounts[0], 2, myrPrice);
        assertEq(keccak256(abi.encodePacked(tab)), keccak256(abi.encodePacked(myr))); // MYR
        assertEq(reserveAddr, address(cbBTC));
        assertEq(price, myrPrice);
        assertEq(reserveAmt, 1e18);
        assertEq(osTab, 97001910184158850789691);
        assertEq(reserveValue, 174603438331485931421445);
        // 97001910184158850789691 * 180 / 100 = 174603438331485931421443.8
        assertEq(minReserveValue, 174603438331485931421443); 

        vm.stopPrank();

        // drop price, expect USD and MYR vaults to be charged risk penalty
        nextBlock(100);
        vm.startPrank(address(governanceTimelockController));
        usdPrice = 20000e18; // BTC/USD 20000
        myrPrice = 150000e18;
        priceOracle.setDirectPrice(usd, usdPrice, block.timestamp);
        priceOracle.setDirectPrice(myr, myrPrice, block.timestamp);

        (,, price,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, usdPrice);
        assertEq(price, 20000e18);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 20000e18);
        assertEq(minReserveValue, 257364e17);

        // checkVault
        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, usdPrice, block.timestamp);
        
        IVaultKeeper.VaultDetails memory vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            1,
            usd,
            address(cbBTC),
            osTab,
            reserveValue,
            minReserveValue
        );
        // first checkVault, risk penalty not charged, still within same frame
        vm.startPrank(address(governanceTimelockController));
        vaultKeeper.checkVault(block.timestamp, vd, priceData);

        uint256 delta = minReserveValue - reserveValue;
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], 1));
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(1);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), 1);

        (,, price,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], 2, myrPrice);
        assertEq(price, 150000e18);
        assertEq(osTab, 97001910184158850789691);
        assertEq(reserveValue, 150000e18);
        // delta = 174603.438331485931421443 - 150000e18 = 24603.438331485931421443
        // delta * 1.5% = to be charged risk penalty 369.051574972288971321645
        assertEq(minReserveValue, 174603438331485931421443); 

        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(myr, myrPrice, block.timestamp);

        vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            2,
            myr,
            address(cbBTC),
            osTab,
            reserveValue,
            minReserveValue
        );
        vm.startPrank(address(governanceTimelockController));
        vaultKeeper.checkVault(block.timestamp, vd, priceData);

        delta = minReserveValue - reserveValue;
        uint256 firstRunMyrDelta = delta;
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], 2));
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(2);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), 2);

        // 2nd, On same frame, price changes and largest delta is updated
        nextBlock(1);
        usdPrice = 19000e18; // BTC/USD 19000
        myrPrice = 155000e18;
        vm.startPrank(address(governanceTimelockController));
        priceOracle.setDirectPrice(usd, usdPrice, block.timestamp);
        priceOracle.setDirectPrice(myr, myrPrice, block.timestamp);
        
        (,, price,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, usdPrice);
        assertEq(price, 19000e18);
        assertEq(osTab, 14298e18); // same as previous, delta(risk penalty) not yet reflected into OS
        assertEq(reserveValue, 19000e18);
        assertEq(minReserveValue, 257364e17);

        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, myrPrice, block.timestamp); 

        vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            1,
            usd,
            address(cbBTC),
            osTab,
            reserveValue,
            minReserveValue
        );

        // checkVault
        vm.startPrank(address(governanceTimelockController));
        vaultKeeper.checkVault(block.timestamp, vd, priceData);

        delta = minReserveValue - reserveValue;
        // delta is updated when price dropped from 20000e18 to 19000e18
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], 1)); 
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(1);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), 1);
        uint256 usd2ndRunDelta = delta;

        nextBlock(1);
        (,, price,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], 2, myrPrice);
        assertEq(price, 155000e18);
        assertEq(osTab, 97001910184158850789691);
        assertEq(reserveValue, 155000e18);
        assertEq(minReserveValue, 174603438331485931421443);

        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(myr, myrPrice, block.timestamp); 

        vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            2,
            myr,
            address(cbBTC),
            osTab,
            reserveValue,
            minReserveValue
        );
        vm.startPrank(address(governanceTimelockController));
        vaultKeeper.checkVault(block.timestamp, vd, priceData);
        delta = minReserveValue - reserveValue;
        assertEq(24603438331485931421443, vaultKeeper.largestVaultDelta(eoa_accounts[0], 2)); // same as prev.
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(2);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), 2);

        // 3rd run, dropped price below 120%, liquidate both usd and myr vaults
        nextBlock(10);
        usdPrice = 15000e18;
        myrPrice = 100000e18;
        vm.startPrank(address(governanceTimelockController));
        priceOracle.setDirectPrice(usd, usdPrice, block.timestamp);
        priceOracle.setDirectPrice(myr, myrPrice, block.timestamp);

        (,, price,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, usdPrice);
        assertEq(price, 15000e18);
        assertEq(osTab, 14298e18);
        assertEq(reserveValue, 15000e18);
        assertEq(minReserveValue, 257364e17);

        vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            1,
            usd,
            address(cbBTC),
            osTab,
            reserveValue,
            minReserveValue
        );

        usd2ndRunRiskPenalty = Math.mulDiv(150, usd2ndRunDelta, 10000);
        usd3rdRunRiskPenalty = Math.mulDiv(150, Math.mulDiv((usd2ndRunRiskPenalty + 14298e18), 180, 100) - 15000e18, 10000);
        myr1stRunRiskPenalty = Math.mulDiv(150, firstRunMyrDelta, 10000);

        // checkVault
        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit(false, false, false, false, address(vaultKeeper));
        emit IVaultKeeper.RiskPenaltyCharged(block.timestamp, eoa_accounts[0], 1, usd2ndRunDelta, usd2ndRunRiskPenalty); 
        vm.expectEmit(false, false, false, false, address(vaultKeeper));
        emit IVaultKeeper.RiskPenaltyCharged(block.timestamp, eoa_accounts[0], 2, firstRunMyrDelta, myr1stRunRiskPenalty);
        vm.expectEmit(address(vaultKeeper));
        emit IVaultKeeper.StartVaultLiquidation(block.timestamp, eoa_accounts[0], 1, usd3rdRunRiskPenalty);
        vaultKeeper.checkVault(block.timestamp, vd, priceData);

        (,, price,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, usdPrice);
        assertEq(price, 15000e18);
        assertEq(osTab, 14298e18 + usd2ndRunRiskPenalty + usd3rdRunRiskPenalty);
        assertEq(reserveValue, 0);
        assertEq(minReserveValue, Math.mulDiv(osTab, 180, 100));

        nextBlock(1);
        (,, price,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], 2, myrPrice);
        assertEq(price, 100000e18);
        assertEq(osTab, 97001910184158850789691 + myr1stRunRiskPenalty);
        assertEq(reserveValue, 100000e18);
        assertEq(minReserveValue, Math.mulDiv(osTab, 180, 100));
        delta = minReserveValue - reserveValue;

        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(myr, myrPrice, block.timestamp); 

        vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            2,
            myr,
            address(cbBTC),
            osTab,
            reserveValue,
            minReserveValue
        );

        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit(address(vaultKeeper));
        emit IVaultKeeper.StartVaultLiquidation(block.timestamp, eoa_accounts[0], 2, Math.mulDiv(150, delta, 10000));
        vaultKeeper.checkVault(block.timestamp, vd, priceData);
    }

    /// @dev selectively clearing risk penalty of a vault
    function test_pushVaultRiskPenalty() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        uint256 assignedPrice = 10000e18;

        vm.startPrank(deployer);
        cbBTC.mint(eoa_accounts[0], 1e8);

        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(usd); // USD
        nextBlock(1);
        priceOracle.setDirectPrice(usd, assignedPrice, block.timestamp);

        nextBlock(1);
        vm.startPrank(eoa_accounts[0]);

        // approve 10 BTC to vault manager
        cbBTC.approve(address(vaultManager), 1e8);
        assertEq(cbBTC.allowance(eoa_accounts[0], address(vaultManager)), 1e8);

        // create vault
        // current reserve ratio = 25738 / 14298 = 180.01%, just slightly above minimum reserve ratio
        vaultManager.createVault(
            address(cbBTC), 
            1e18, 
            5000e18, 
            signer.getUpdatePriceSignature(usd, assignedPrice, block.timestamp)
        );

        // price dropped
        nextBlock(1 days);
        assignedPrice = 8000e18;

        vm.startPrank(address(governanceTimelockController));
        priceOracle.setDirectPrice(usd, assignedPrice, block.timestamp);

        (
            bytes3 tab,
            ,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            uint256 reserveValue,
            uint256 minReserveValue
        ) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, assignedPrice);
        assertEq(price, 8000e18);
        assertEq(reserveAmt, 1e18);
        assertEq(osTab, 5000e18);
        assertEq(reserveValue, 8000e18);
        assertEq(minReserveValue, 9000e18);

        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, assignedPrice, block.timestamp); 

        IVaultKeeper.VaultDetails memory vd = IVaultKeeper.VaultDetails(
            eoa_accounts[0],
            1,
            usd,
            address(cbBTC),
            osTab,
            reserveValue,
            minReserveValue
        );
        vm.startPrank(address(governanceTimelockController));
        vaultKeeper.checkVault(block.timestamp, vd, priceData);

        uint256 delta = minReserveValue - reserveValue;
        assertEq(delta, vaultKeeper.largestVaultDelta(eoa_accounts[0], 1)); // delta 1000, RP 1.5% = 15, new OS = 5015
        (vaultOwner, vaultTab, listIndex) = vaultKeeper.vaultMap(1);
        assertEq(vaultOwner, eoa_accounts[0]);
        assertEq(vaultKeeper.vaultIdList(listIndex), 1);
        assertEq(vaultTab, tab);

        // price back to 10000e18, try to mint more, expect pending risk penalty is updated before mint more
        nextBlock(1);
        assignedPrice = 10000e18;
        
        vm.startPrank(eoa_accounts[0]);
        priceData = signer.getUpdatePriceSignature(usd, assignedPrice, block.timestamp);
        // withdrawal more than max. withdraw due to 555e18 did not consider pending risk penalty to charge
        vm.expectRevert(abi.encodeWithSelector(IVaultManager.ExceededWithdrawable.selector, 540555555555555555555));
        vaultManager.withdrawTab(1, 555e18, priceData);

        priceData = signer.getUpdatePriceSignature(usd, assignedPrice, block.timestamp);
        vm.expectEmit(address(vaultManager));
        emit IVaultManager.TabWithdraw(eoa_accounts[0], 1, 540e18, 5540e18);
        // withdraw tab, max withdraw 5555, deduct os 5555 - 5015 = 540
        vaultManager.withdrawTab(1, 540e18, priceData); 

        vm.stopPrank();

        (,, price,, osTab, reserveValue, minReserveValue) = vaultUtils.getVaultDetails(eoa_accounts[0], 1, assignedPrice);
        assertEq(price, 10000e18);
        assertEq(osTab, 5555e18);
        assertEq(reserveValue, 10000e18);
        assertEq(minReserveValue, 9999e18);
    }

}
