// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IUniTabOperation} from "../contracts/interfaces/IUniTabOperation.sol";
import {IUniAuctionBid} from "../contracts/interfaces/IUniAuctionBid.sol";
import {UniAuctionBid} from "../contracts/core/UniAuctionBid.sol";

contract UniAuctionBidTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(uniAuctionBid.defaultAdmin() , address(uniGovernance1));
        assertEq(uniAuctionBid.hasRole(DEPLOYER_ROLE, address(uniGovernance1)), true);
        assertEq(uniAuctionBid.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(uniAuctionBid.hasRole(PAUSER_ROLE, address(uniGovernance1)), true);
        assertEq(uniAuctionBid.hasRole(PAUSER_ROLE, deployer), true);
        assertEq(uniAuctionBid.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(uniAuctionBid.hasRole(GATEWAY_ROLE, ethereumGateway), true);
        
        vm.expectRevert();
        uniAuctionBid.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(uniGovernance1));
        uniAuctionBid.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        uniAuctionBid.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(uniAuctionBid.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        UniAuctionBid newContract = new UniAuctionBid();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        uniAuctionBid.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        uniAuctionBid.upgradeToAndCall(address(newContract), "");
    }

    function test_pause_unpause() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniAuctionBid.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniAuctionBid.unpause();

        vm.startPrank(address(uniGovernance1));
        uniAuctionBid.pause();
        assertEq(uniAuctionBid.paused(), true);
        uniAuctionBid.unpause();
        assertEq(uniAuctionBid.paused(), false);
    }

    function test_updateZetaToken() public {
        assertEq(uniAuctionBid.zetaToken(), zetaZrc20);
        address newZetaToken = address(555);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniAuctionBid.updateZetaToken(newZetaToken);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniAuctionBid.updateZetaToken(address(0));

        vm.startPrank(deployer);
        vm.expectEmit();
        emit IUniAuctionBid.UpdatedZetaToken(zetaZrc20, newZetaToken);
        uniAuctionBid.updateZetaToken(newZetaToken);

        assertEq(uniAuctionBid.zetaToken(), newZetaToken);
    }

    function test_updateAuctionManager() public {
        assertEq(uniAuctionBid.auctionManager(), address(auctionManager));
        address newAddr = address(555);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniAuctionBid.updateAuctionManager(newAddr);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniAuctionBid.updateAuctionManager(address(0));

        vm.startPrank(deployer);
        vm.expectEmit();
        emit IUniAuctionBid.UpdatedAuctionManager(address(auctionManager), newAddr);
        uniAuctionBid.updateAuctionManager(newAddr);

        assertEq(uniAuctionBid.auctionManager(), newAddr);
    }

    function test_bidWithTab_revert() public {
        vm.startPrank(address(uniGovernance1));
        uniAuctionBid.pause();
        vm.expectRevert(abi.encodeWithSelector(
                            PausableUpgradeable.EnforcedPause.selector));
        uniAuctionBid.bidWithTab(
            123,
            address(333),
            1e18,
            address(888)
        );
        uniAuctionBid.unpause();

        vm.expectRevert(IUniAuctionBid.ZeroTab.selector);
        uniAuctionBid.bidWithTab(
            123,
            address(0),
            1e18,
            address(888)
        );
        vm.expectRevert(IUniAuctionBid.ZeroTab.selector);
        uniAuctionBid.bidWithTab(
            123,
            address(333),
            0,
            address(888)
        );

        address sUSD = tabRegistry.tabs(uniAuctionBid.tabKey(bytes3(abi.encodePacked("USD"))));
        vm.expectRevert(); // insufficient tab amount
        uniAuctionBid.bidWithTab(
            123,
            sUSD,
            1e18,
            address(888)
        );
    }

    function test_bidWithTab(uint256 _amt) public {
        if (ethereumGateway.code.length == 0)
            return;
        vm.assume(_amt > 0.1 ether && _amt < 100 ether);
        require(_amt > 0.1 ether && _amt < 100 ether);

        bytes3 usd = bytes3(abi.encodePacked("USD"));
        address sUSD = tabRegistry.tabs(uniAuctionBid.tabKey(usd));
        
        vm.startPrank(address(vaultManager));
        (bool success, ) = sUSD.call(abi.encodeWithSignature("mint(address,uint256)", address(888), _amt));
        assertEq(success, true);
        uint256 bal = IERC20(sUSD).balanceOf(address(888));
        assertEq(bal, _amt);

        vm.startPrank(address(888));
        IERC20(sUSD).approve(address(uniAuctionBid), _amt);
        vm.expectEmit();
        emit IUniAuctionBid.BidWithTab(
            address(888),
            address(888),
            123,
            sUSD,
            _amt
        );
        uniAuctionBid.bidWithTab(
            123,
            sUSD,
            _amt,
            address(888)
        );
        assertEq(IERC20(sUSD).balanceOf(address(888)), bal - _amt);
    }
}
