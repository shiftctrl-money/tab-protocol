// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IUniTabOperation} from "../contracts/interfaces/IUniTabOperation.sol";
import {IUniPaybackTab} from "../contracts/interfaces/IUniPaybackTab.sol";
import {UniPaybackTab} from "../contracts/core/UniPaybackTab.sol";

contract UniPaybackTabTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(uniPaybackTab.defaultAdmin() , address(uniGovernance1));
        assertEq(uniPaybackTab.hasRole(DEPLOYER_ROLE, address(uniGovernance1)), true);
        assertEq(uniPaybackTab.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(uniPaybackTab.hasRole(PAUSER_ROLE, address(uniGovernance1)), true);
        assertEq(uniPaybackTab.hasRole(PAUSER_ROLE, deployer), true);
        assertEq(uniPaybackTab.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(uniPaybackTab.hasRole(GATEWAY_ROLE, ethereumGateway), true);
        
        vm.expectRevert();
        uniPaybackTab.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(uniGovernance1));
        uniPaybackTab.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        uniPaybackTab.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(uniPaybackTab.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        UniPaybackTab newContract = new UniPaybackTab();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        uniPaybackTab.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        uniPaybackTab.upgradeToAndCall(address(newContract), "");
    }

    function test_pause_unpause() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniPaybackTab.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniPaybackTab.unpause();

        vm.startPrank(address(uniGovernance1));
        uniPaybackTab.pause();
        assertEq(uniPaybackTab.paused(), true);
        uniPaybackTab.unpause();
        assertEq(uniPaybackTab.paused(), false);
    }

    function test_updateZetaToken() public {
        assertEq(uniPaybackTab.zetaToken(), zetaZrc20);
        address newZetaToken = address(555);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniPaybackTab.updateZetaToken(newZetaToken);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniPaybackTab.updateZetaToken(address(0));

        vm.startPrank(deployer);
        vm.expectEmit();
        emit IUniPaybackTab.UpdatedZetaToken(zetaZrc20, newZetaToken);
        uniPaybackTab.updateZetaToken(newZetaToken);

        assertEq(uniPaybackTab.zetaToken(), newZetaToken);
    }

    function test_updateVaultManager() public {
        assertEq(uniPaybackTab.vaultManager(), address(vaultManager));
        address newAddr = address(555);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniPaybackTab.updateVaultManager(newAddr);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniPaybackTab.updateVaultManager(address(0));

        vm.startPrank(deployer);
        vm.expectEmit();
        emit IUniPaybackTab.UpdatedVaultManager(address(vaultManager), newAddr);
        uniPaybackTab.updateVaultManager(newAddr);

        assertEq(uniPaybackTab.vaultManager(), newAddr);
    }

    function test_setUniTab() public {
        assertEq(uniPaybackTab.uniTab(), address(uniTab1));
        address newAddr = address(555);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniPaybackTab.setUniTab(newAddr);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniPaybackTab.setUniTab(address(0));

        vm.startPrank(deployer);
        vm.expectEmit();
        emit IUniTabOperation.UpdatedUniTab(address(uniTab1), newAddr);
        uniPaybackTab.setUniTab(newAddr);

        assertEq(uniPaybackTab.uniTab(), newAddr);
    }

    function test_paybackTab_revert() public {
        vm.startPrank(address(uniGovernance1));
        uniPaybackTab.pause();
        vm.expectRevert(abi.encodeWithSelector(
                            PausableUpgradeable.EnforcedPause.selector));
        uniPaybackTab.paybackTab(
            owner,
            123,
            address(333),
            1e18
        );
        uniPaybackTab.unpause();

        vm.expectRevert(IUniPaybackTab.ZeroPayback.selector);
        uniPaybackTab.paybackTab(
            owner,
            123,
            address(0),
            1e18
        );
        vm.expectRevert(IUniPaybackTab.ZeroPayback.selector);
        uniPaybackTab.paybackTab(
            owner,
            123,
            address(333),
            0
        );

        address sUSD = tabRegistry.tabs(uniPaybackTab.tabKey(bytes3(abi.encodePacked("USD"))));
        vm.expectRevert(); // insufficient tab amount
        uniPaybackTab.paybackTab(
            owner,
            123,
            sUSD,
            100e18
        );
    }

    function test_paybackTab(uint256 _amt) public {
        if (ethereumGateway.code.length == 0)
            return;
        vm.assume(_amt > 0.1 ether && _amt < 100 ether);
        require(_amt > 0.1 ether && _amt < 100 ether);

        bytes3 usd = bytes3(abi.encodePacked("USD"));
        address sUSD = tabRegistry.tabs(uniPaybackTab.tabKey(usd));
        
        vm.startPrank(address(vaultManager));
        (bool success, ) = sUSD.call(abi.encodeWithSignature("mint(address,uint256)", address(888), _amt));
        assertEq(success, true);
        uint256 bal = IERC20(sUSD).balanceOf(address(888));
        assertEq(bal, _amt);

        vm.startPrank(address(888));
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, 11155112);
        IERC20(sUSD).approve(address(uniPaybackTab), _amt);
        vm.expectEmit();
        emit IUniPaybackTab.PaybackTab(
            address(888),
            123,
            sUSD,
            _amt
        );
        uniPaybackTab.paybackTab(
            address(888),
            123,
            sUSD,
            _amt
        );
        assertEq(IERC20(sUSD).balanceOf(address(888)), bal - _amt);
    }
}
