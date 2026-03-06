// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IUniTabOperation} from "../contracts/interfaces/IUniTabOperation.sol";
import {IUniProtocolVaultBuyTab} from "../contracts/interfaces/IUniProtocolVaultBuyTab.sol";
import {UniProtocolVaultBuyTab} from "../contracts/core/UniProtocolVaultBuyTab.sol";
import "@zetachain/protocol-contracts/contracts/evm/GatewayEVM.sol";

contract UniProtocolVaultBuyTabTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(uniProtocolVaultBuyTab.defaultAdmin() , address(uniGovernance1));
        assertEq(uniProtocolVaultBuyTab.hasRole(DEPLOYER_ROLE, address(uniGovernance1)), true);
        assertEq(uniProtocolVaultBuyTab.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(uniProtocolVaultBuyTab.hasRole(PAUSER_ROLE, address(uniGovernance1)), true);
        assertEq(uniProtocolVaultBuyTab.hasRole(PAUSER_ROLE, deployer), true);
        assertEq(uniProtocolVaultBuyTab.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(uniProtocolVaultBuyTab.hasRole(GATEWAY_ROLE, ethereumGateway), true);
        
        vm.expectRevert();
        uniProtocolVaultBuyTab.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(uniGovernance1));
        uniProtocolVaultBuyTab.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        uniProtocolVaultBuyTab.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(uniProtocolVaultBuyTab.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        UniProtocolVaultBuyTab newContract = new UniProtocolVaultBuyTab();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        uniProtocolVaultBuyTab.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        uniProtocolVaultBuyTab.upgradeToAndCall(address(newContract), "");
    }

    function test_pause_unpause() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniProtocolVaultBuyTab.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniProtocolVaultBuyTab.unpause();

        vm.startPrank(address(uniGovernance1));
        uniProtocolVaultBuyTab.pause();
        assertEq(uniProtocolVaultBuyTab.paused(), true);
        uniProtocolVaultBuyTab.unpause();
        assertEq(uniProtocolVaultBuyTab.paused(), false);
    }

    function test_setAuthorizedDestinations() public {
        assertEq(uniProtocolVaultBuyTab.authorizedDestinations(ethereumZrc20), true);
        assertEq(uniProtocolVaultBuyTab.authorizedDestinations(bnbZrc20), true);
        assertEq(uniProtocolVaultBuyTab.authorizedDestinations(zetaZrc20), true);
        address[] memory addrs = new address[](2);
        addrs[0] = ethereumZrc20;
        addrs[1] = address(123);
        bool[] memory isAuthorized = new bool[](2);
        isAuthorized[0] = false;
        isAuthorized[1] = true;

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniProtocolVaultBuyTab.setAuthorizedDestinations(addrs, isAuthorized);

        vm.startPrank(deployer);

        bool[] memory invalidIsAuthorized = new bool[](1);
        invalidIsAuthorized[0] = true;
        vm.expectRevert(IUniProtocolVaultBuyTab.InvalidLength.selector);
        uniProtocolVaultBuyTab.setAuthorizedDestinations(addrs, invalidIsAuthorized);

        addrs[1] = address(0);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniProtocolVaultBuyTab.setAuthorizedDestinations(addrs, isAuthorized);
        
        addrs[1] = address(123);
        uniProtocolVaultBuyTab.setAuthorizedDestinations(addrs, isAuthorized);
        assertEq(uniProtocolVaultBuyTab.authorizedDestinations(ethereumZrc20), false);
        assertEq(uniProtocolVaultBuyTab.authorizedDestinations(address(123)), true);
    }

    function test_depositReserve_revert() public {
        bytes32 usdTabKey = uniProtocolVaultBuyTab.tabKey(bytes3(abi.encodePacked("USD")));
        vm.expectRevert(IUniProtocolVaultBuyTab.InvalidDestination.selector);
        uniProtocolVaultBuyTab.buyTab{value: 1 ether}(address(444), address(888), address(0), 0, 0, usdTabKey, 0);

        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniProtocolVaultBuyTab.buyTab{value: 1 ether}(ethereumZrc20, address(0), address(0), 0, 0, usdTabKey, 0);
        
        vm.expectRevert(IUniProtocolVaultBuyTab.InvalidSendTokenOrAmount.selector);
        uniProtocolVaultBuyTab.buyTab{value: 1 ether}(ethereumZrc20, address(888), address(0), 1e18, 0, usdTabKey, 0);
        vm.expectRevert(IUniProtocolVaultBuyTab.InvalidSendTokenOrAmount.selector);
        uniProtocolVaultBuyTab.buyTab{value: 1 ether}(ethereumZrc20, address(888), ethereumUsdc, 0, 0, usdTabKey, 0);

        vm.expectRevert(IUniProtocolVaultBuyTab.ZeroReserve.selector);
        uniProtocolVaultBuyTab.buyTab(ethereumZrc20, address(888), address(0), 0, 0, usdTabKey, 0);

        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        vm.expectRevert(IUniProtocolVaultBuyTab.ZeroTabKey.selector);
        uniProtocolVaultBuyTab.buyTab{value: 1 ether}(ethereumZrc20, address(888), address(0), 0, 0, bytes32(0), 0);

        vm.expectRevert(); // insufficient fund
        uniProtocolVaultBuyTab.buyTab(ethereumZrc20, address(888), ethereumUsdc, 100e18, 0, usdTabKey, 0);

        vm.startPrank(address(uniGovernance1));
        uniProtocolVaultBuyTab.pause();
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(
                            PausableUpgradeable.EnforcedPause.selector));
        uniProtocolVaultBuyTab.buyTab{value: 1 ether}(ethereumZrc20, address(888), address(0), 0, 0, usdTabKey, 0);
    }

    function test_buyTab_token(uint256 _amt) public {
        bytes32 usdTabKey = uniProtocolVaultBuyTab.tabKey(bytes3(abi.encodePacked("USD")));
        if (ethereumGateway.code.length == 0)
            return;
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        uint256 bal = IERC20(ethereumUsdc).balanceOf(owner);
        vm.assume(_amt > 10 ether && _amt <= bal);
        require(_amt > 10 ether && _amt <= bal);

        vm.startPrank(owner);
        IERC20(ethereumUsdc).approve(address(uniProtocolVaultBuyTab), _amt);
        vm.expectEmit();
        emit IUniProtocolVaultBuyTab.BuyTab(
            owner,
            address(888),
            ethereumZrc20,
            ethereumUsdc,
            _amt,
            0,
            0.0001 ether,
            usdTabKey
        );
        uniProtocolVaultBuyTab.buyTab(ethereumZrc20, address(888), ethereumUsdc, _amt, 0.0001 ether, usdTabKey, 0);
        assertEq(IERC20(ethereumUsdc).balanceOf(owner), bal - _amt);
    }

    function test_buyTab_gas(uint256 _amt) public {
        bytes32 usdTabKey = uniProtocolVaultBuyTab.tabKey(bytes3(abi.encodePacked("USD")));
        if (ethereumGateway.code.length == 0)
            return;
        vm.assume(_amt > 1 ether && _amt < 10 ether);
        require(_amt > 1 ether && _amt < 10 ether);
        vm.deal(address(888), _amt);

        uint256 bal = address(888).balance;
        vm.startPrank(address(888));
        vm.expectEmit();
        emit IUniProtocolVaultBuyTab.BuyTab(
            address(888),
            address(888),
            ethereumZrc20,
            address(0),
            0,
            _amt,
            0.0001 ether,
            usdTabKey
        );
        uniProtocolVaultBuyTab.buyTab{value: _amt}(ethereumZrc20, address(888), address(0), 0, 0.0001 ether, usdTabKey, 0);
        assertEq(address(888).balance, bal - _amt);
    }

    function test_onRevert() public {
        bytes memory message = abi.encode(
            address(888),        // sender
            100e18,              // token amount
            0                    // native gas amount
        );
        RevertContext memory context = RevertContext({
            sender: address(zUniProtocolVaultBuyTab),
            asset: ethereumUsdc,      // asset
            amount: 100e18,           // token / gasAmount
            revertMessage: message
        });
        if (ethereumGateway.code.length == 0)
            return;

        // Revert ERC-20 USDC
        if (IERC20(ethereumUsdc).balanceOf(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) > 100e18) {
            vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
            IERC20(ethereumUsdc).transfer(address(uniProtocolVaultBuyTab), 100e18);

            assertEq(IERC20(ethereumUsdc).balanceOf(address(888)), 0);
            vm.startPrank(ethereumGateway);
            vm.expectEmit();
            emit IUniProtocolVaultBuyTab.TokenOrGasTransferReverted(
                ethereumUsdc,
                address(888),
                100e18,
                0,
                100e18
            );
            uniProtocolVaultBuyTab.onRevert(context);
            assertEq(IERC20(ethereumUsdc).balanceOf(address(888)), 100e18);
        }

        // Revert native gas
        vm.startPrank(ethereumGateway);
        vm.deal(address(uniProtocolVaultBuyTab), 100e18);
        message = abi.encode(
            address(888),        // sender
            0,                   // token amount
            100e18               // native gas amount
        );
        context.asset = address(0);
        context.revertMessage = message;
        assertEq(address(888).balance, 0);
        vm.expectEmit();
        emit IUniProtocolVaultBuyTab.TokenOrGasTransferReverted(
            address(0),
            address(888),
            0,
            100e18,
            100e18
        );
        uniProtocolVaultBuyTab.onRevert(context);
        assertEq(address(888).balance, 100e18);

        // Failed cases
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                        IAccessControl.AccessControlUnauthorizedAccount.selector, 
                        address(444), 
                        GATEWAY_ROLE));
        uniProtocolVaultBuyTab.onRevert(context);

        vm.startPrank(ethereumGateway);
        context.sender = address(444);
        vm.expectRevert(IUniTabOperation.Unauthorized.selector);
        uniProtocolVaultBuyTab.onRevert(context);
    }
}
