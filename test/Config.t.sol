// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {IConfig} from "../contracts/interfaces/IConfig.sol";

contract ConfigTest is Deployer {

    function setUp() public {
        deploy();
    }

    function test_permission() public {
        assertEq(config.defaultAdmin() , address(governanceTimelockController));
        assertEq(config.hasRole(MAINTAINER_ROLE, address(governanceTimelockController)), true);
        assertEq(config.hasRole(MAINTAINER_ROLE, address(emergencyTimelockController)), true);
        assertEq(config.hasRole(MAINTAINER_ROLE, address(governanceAction)), true);
        assertEq(config.hasRole(MAINTAINER_ROLE, owner), false);
        assertEq(config.hasRole(MAINTAINER_ROLE, address(tabRegistry)), true);

        vm.expectRevert();
        config.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        config.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        config.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(config.defaultAdmin() , owner);
    }

    function test_default() public view {
        IConfig.TabParams memory defTabParams = config.getTabParams(0x0);
        assertEq(defTabParams.riskPenaltyPerFrame, 150);
        assertEq(defTabParams.processFeeRate, 0);
        assertEq(defTabParams.minReserveRatio, 180);
        assertEq(defTabParams.liquidationRatio, 120);

        IConfig.AuctionParams memory auctionParams = config.getAuctionParams();
        assertEq(auctionParams.auctionStartPriceDiscount, 90);
        assertEq(auctionParams.auctionStepPriceDiscount, 97);
        assertEq(auctionParams.auctionStepDurationInSec, 60);
        assertEq(auctionParams.auctionManager, address(auctionManager));

        assertEq(config.treasury(), treasuryAddr);
        assertEq(config.vaultKeeper(), address(vaultKeeper));
    }

    function test_setVaultKeeperAddress() public {
        vm.expectRevert(); // unauthorized
        config.setVaultKeeperAddress(owner);

        vm.startPrank(address(governanceTimelockController));
        
        vm.expectRevert(IConfig.ZeroAddress.selector);
        config.setVaultKeeperAddress(address(0));
        
        vm.expectRevert(IConfig.InvalidContractAddress.selector);
        config.setVaultKeeperAddress(eoa_accounts[3]);

        vm.expectEmit();
        emit IConfig.UpdatedVaultKeeperAddress(address(vaultKeeper), owner);
        config.setVaultKeeperAddress(owner);

        vm.stopPrank();
    }

    function test_setTreasuryAddress() public {
        vm.expectRevert(); // unauthorized
        config.setTreasuryAddress(owner);

        vm.startPrank(address(governanceTimelockController));
        
        vm.expectRevert(IConfig.ZeroAddress.selector);
        config.setTreasuryAddress(address(0));

        vm.expectEmit();
        emit IConfig.UpdatedTreasuryAddress(treasuryAddr, owner);
        config.setTreasuryAddress(owner);

        vm.stopPrank();
    }

    function test_setDefTabParams() public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        vm.expectRevert(); // unauthorized
        config.setDefTabParams(usd);

        vm.startPrank(address(governanceTimelockController));
        vm.expectEmit();
        emit IConfig.DefaultTabParams(usd, 150, 0, 180, 120);
        config.setDefTabParams(usd);

        IConfig.TabParams memory defTabParams = config.getTabParams(0x0);
        IConfig.TabParams memory tabParams = config.getTabParams(usd);
        assertEq(defTabParams.riskPenaltyPerFrame, tabParams.riskPenaltyPerFrame);
        assertEq(defTabParams.processFeeRate, tabParams.processFeeRate);
        assertEq(defTabParams.minReserveRatio, tabParams.minReserveRatio);
        assertEq(defTabParams.liquidationRatio, tabParams.liquidationRatio);

        (
            uint256 riskPenaltyPerFrame,
            uint256 processFeeRate,
            uint256 minReserveRatio,
            uint256 liquidationRatio
        ) = vaultKeeper.tabParams(keccak256(abi.encodePacked(usd)));
        assertEq(riskPenaltyPerFrame, tabParams.riskPenaltyPerFrame);
        assertEq(processFeeRate, tabParams.processFeeRate);
        assertEq(minReserveRatio, tabParams.minReserveRatio);
        assertEq(liquidationRatio, tabParams.liquidationRatio);

        vm.stopPrank();
    }

    function test_setTabParams(uint256 value) public {
        vm.assume(value > 0 && value < (type(uint256).max - 100));
        require(value > 0 && value < (type(uint256).max - 100));
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        bytes3 aud = bytes3(abi.encodePacked("AUD"));
        bytes3[] memory tabs = new bytes3[](2);
        tabs[0] = usd;
        tabs[1] = aud;
        IConfig.TabParams[] memory tabParams = new IConfig.TabParams[](2);
        tabParams[0].riskPenaltyPerFrame = value;
        tabParams[0].processFeeRate = value;
        tabParams[0].minReserveRatio = value;
        tabParams[0].liquidationRatio = value;
        tabParams[1].riskPenaltyPerFrame = value;
        tabParams[1].processFeeRate = value;
        tabParams[1].minReserveRatio = value;
        tabParams[1].liquidationRatio = value;

        vm.expectRevert(); // unauthorized
        config.setTabParams(tabs, tabParams);

        vm.startPrank(address(governanceTimelockController));

        IConfig.TabParams[] memory singleTabParams = new IConfig.TabParams[](1);
        vm.expectRevert(IConfig.InvalidArrayLength.selector);
        config.setTabParams(tabs, singleTabParams);

        vm.expectEmit();
        emit IConfig.UpdatedTabParams(tabs[0], value, value, value, value);
        emit IConfig.UpdatedTabParams(tabs[1], value, value, value, value);
        config.setTabParams(tabs, tabParams);

        (
            uint256 riskPenaltyPerFrame,
            uint256 processFeeRate,
            uint256 minReserveRatio,
            uint256 liquidationRatio
        ) = vaultKeeper.tabParams(keccak256(abi.encodePacked(aud)));
        assertEq(riskPenaltyPerFrame, value);
        assertEq(processFeeRate, value);
        assertEq(minReserveRatio, value);
        assertEq(liquidationRatio, value);

        vm.stopPrank();
    }

    function test_setAuctionParams(uint256 value) public {
        vm.assume(value > 0 && value < (type(uint256).max - 100));
        require(value > 0 && value < (type(uint256).max - 100));
        
        vm.expectRevert(); // unauthorized
        config.setAuctionParams(value, value, value, owner);

        vm.startPrank(address(governanceTimelockController));

        vm.expectRevert(IConfig.ZeroValue.selector);
        config.setAuctionParams(0, value, value, owner);
        vm.expectRevert(IConfig.ZeroValue.selector);
        config.setAuctionParams(value, 0, value, owner);
        vm.expectRevert(IConfig.ZeroValue.selector);
        config.setAuctionParams(value, value, 0, owner);

        vm.expectRevert(IConfig.ZeroAddress.selector);
        config.setAuctionParams(value, value, value, address(0));

        vm.expectRevert(IConfig.InvalidContractAddress.selector);
        config.setAuctionParams(value, value, value, eoa_accounts[2]);

        IConfig.AuctionParams memory auctionParams = config.getAuctionParams();
        assertEq(auctionParams.auctionStartPriceDiscount, 90);
        assertEq(auctionParams.auctionStepPriceDiscount, 97);
        assertEq(auctionParams.auctionStepDurationInSec, 60);
        assertEq(auctionParams.auctionManager, address(auctionManager));

        vm.expectEmit();
        emit IConfig.UpdatedAuctionParams(value, value, value, owner);
        config.setAuctionParams(value, value, value, owner);

        auctionParams = config.getAuctionParams();
        assertEq(auctionParams.auctionStartPriceDiscount, value);
        assertEq(auctionParams.auctionStepPriceDiscount, value);
        assertEq(auctionParams.auctionStepDurationInSec, value);
        assertEq(auctionParams.auctionManager, owner);

       vm.stopPrank();
    }
}