// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IUniTabOperation} from "../contracts/interfaces/IUniTabOperation.sol";
import {IUniProtocolVaultSellTab} from "../contracts/interfaces/IUniProtocolVaultSellTab.sol";
import {UniProtocolVaultSellTab} from "../contracts/core/UniProtocolVaultSellTab.sol";

contract UniProtocolVaultSellTabTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    bytes3 usd = bytes3(abi.encodePacked("USD"));
    bytes32 usdTabKey;
    address sUSD;

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(uniProtocolVaultSellTab.defaultAdmin() , address(uniGovernance1));
        assertEq(uniProtocolVaultSellTab.hasRole(DEPLOYER_ROLE, address(uniGovernance1)), true);
        assertEq(uniProtocolVaultSellTab.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(uniProtocolVaultSellTab.hasRole(PAUSER_ROLE, address(uniGovernance1)), true);
        assertEq(uniProtocolVaultSellTab.hasRole(PAUSER_ROLE, deployer), true);
        assertEq(uniProtocolVaultSellTab.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(uniProtocolVaultSellTab.hasRole(GATEWAY_ROLE, ethereumGateway), true);
        
        vm.expectRevert();
        uniProtocolVaultSellTab.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(uniGovernance1));
        uniProtocolVaultSellTab.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        uniProtocolVaultSellTab.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(uniProtocolVaultSellTab.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        UniProtocolVaultSellTab newContract = new UniProtocolVaultSellTab();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        uniProtocolVaultSellTab.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        uniProtocolVaultSellTab.upgradeToAndCall(address(newContract), "");
    }

    function test_pause_unpause() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniProtocolVaultSellTab.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniProtocolVaultSellTab.unpause();

        vm.startPrank(address(uniGovernance1));
        uniProtocolVaultSellTab.pause();
        assertEq(uniProtocolVaultSellTab.paused(), true);
        uniProtocolVaultSellTab.unpause();
        assertEq(uniProtocolVaultSellTab.paused(), false);
    }

    function test_updateZetaToken() public {
        assertEq(uniProtocolVaultSellTab.zetaToken(), zetaZrc20);
        address newZetaToken = address(555);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniProtocolVaultSellTab.updateZetaToken(newZetaToken);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniProtocolVaultSellTab.updateZetaToken(address(0));

        vm.startPrank(deployer);
        vm.expectEmit();
        emit IUniProtocolVaultSellTab.UpdatedZetaToken(zetaZrc20, newZetaToken);
        uniProtocolVaultSellTab.updateZetaToken(newZetaToken);

        assertEq(uniProtocolVaultSellTab.zetaToken(), newZetaToken);
    }

    function test_updateProtocolVault() public {
        assertEq(uniProtocolVaultSellTab.protocolVault(), address(protocolVault));
        address newAddr = address(555);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniProtocolVaultSellTab.updateProtocolVault(newAddr);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniProtocolVaultSellTab.updateProtocolVault(address(0));

        vm.startPrank(deployer);
        vm.expectEmit();
        emit IUniProtocolVaultSellTab.UpdatedProtocolVault(address(protocolVault), newAddr);
        uniProtocolVaultSellTab.updateProtocolVault(newAddr);

        assertEq(uniProtocolVaultSellTab.protocolVault(), newAddr);
    }

    function test_sellTab_revert() public {
        usdTabKey = uniProtocolVaultBuyTab.tabKey(usd);
        sUSD = tabRegistry.tabs(usdTabKey);
        vm.startPrank(address(uniGovernance1));
        uniProtocolVaultSellTab.pause();
        vm.expectRevert(abi.encodeWithSelector(
                            PausableUpgradeable.EnforcedPause.selector));
        uniProtocolVaultSellTab.sellTab(
            address(btcBtc),
            sUSD,
            100e18,
            address(888)
        );
        uniProtocolVaultSellTab.unpause();

        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniProtocolVaultSellTab.sellTab(
            address(0),
            sUSD,
            100e18,
            address(888)
        );
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniProtocolVaultSellTab.sellTab(
            address(btcBtc),
            sUSD,
            100e18,
            address(0)
        );

        vm.expectRevert(IUniProtocolVaultSellTab.ZeroTab.selector);
        uniProtocolVaultSellTab.sellTab(
            address(btcBtc),
            address(0),
            100e18,
            address(888)
        );
        vm.expectRevert(IUniProtocolVaultSellTab.ZeroTab.selector);
        uniProtocolVaultSellTab.sellTab(
            address(btcBtc),
            sUSD,
            0,
            address(888)
        );

        vm.expectRevert(); // insufficient tab amount
        uniProtocolVaultSellTab.sellTab(
            address(btcBtc),
            sUSD,
            100e18,
            address(888)
        );
    }

    function test_sellTab(uint256 _amt) public {
        usdTabKey = uniProtocolVaultBuyTab.tabKey(usd);
        sUSD = tabRegistry.tabs(usdTabKey);
        if (ethereumGateway.code.length == 0)
            return;
        vm.assume(_amt > 0.1 ether && _amt < 100 ether);
        require(_amt > 0.1 ether && _amt < 100 ether);

        vm.startPrank(address(vaultManager));
        (bool success, ) = sUSD.call(abi.encodeWithSignature("mint(address,uint256)", address(888), _amt));
        assertEq(success, true);
        uint256 bal = IERC20(sUSD).balanceOf(address(888));
        assertEq(bal, _amt);

        vm.startPrank(address(888));
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, 11155112);
        IERC20(sUSD).approve(address(uniProtocolVaultSellTab), _amt);
        vm.expectEmit();
        emit IUniProtocolVaultSellTab.SellTab(
            address(888),
            address(888),
            address(btcBtc),
            sUSD,
            _amt
        );
        uniProtocolVaultSellTab.sellTab(
            address(btcBtc),
            sUSD,
            _amt,
            address(888)
        );
        assertEq(IERC20(sUSD).balanceOf(address(888)), bal - _amt);
    }
}
