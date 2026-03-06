// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IUniTabOperation} from "../contracts/interfaces/IUniTabOperation.sol";
import {IUniCreateVault} from "../contracts/interfaces/IUniCreateVault.sol";
import {UniCreateVault} from "../contracts/core/UniCreateVault.sol";
import "@zetachain/protocol-contracts/contracts/evm/GatewayEVM.sol";

contract UniCreateVaultTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    bytes3 usd = bytes3(abi.encodePacked("USD"));
    address tab;

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(uniCreateVault.defaultAdmin() , address(uniGovernance1));
        assertEq(uniCreateVault.hasRole(DEPLOYER_ROLE, address(uniGovernance1)), true);
        assertEq(uniCreateVault.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(uniCreateVault.hasRole(PAUSER_ROLE, address(uniGovernance1)), true);
        assertEq(uniCreateVault.hasRole(PAUSER_ROLE, deployer), true);
        assertEq(uniCreateVault.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(uniCreateVault.hasRole(GATEWAY_ROLE, ethereumGateway), true);
        
        vm.expectRevert();
        uniCreateVault.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(uniGovernance1));
        uniCreateVault.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        uniCreateVault.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(uniCreateVault.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        UniCreateVault newContract = new UniCreateVault();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        uniCreateVault.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        uniCreateVault.upgradeToAndCall(address(newContract), "");
    }

    function test_setAuthorizedDestinations() public {
        assertEq(uniCreateVault.authorizedDestinations(ethereumZrc20), true);
        assertEq(uniCreateVault.authorizedDestinations(bnbZrc20), true);
        assertEq(uniCreateVault.authorizedDestinations(zetaZrc20), true);
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
        uniCreateVault.setAuthorizedDestinations(addrs, isAuthorized);

        vm.startPrank(deployer);

        bool[] memory invalidIsAuthorized = new bool[](1);
        invalidIsAuthorized[0] = true;
        vm.expectRevert(IUniCreateVault.InvalidLength.selector);
        uniCreateVault.setAuthorizedDestinations(addrs, invalidIsAuthorized);

        addrs[1] = address(0);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniCreateVault.setAuthorizedDestinations(addrs, isAuthorized);
        
        addrs[1] = address(123);
        uniCreateVault.setAuthorizedDestinations(addrs, isAuthorized);
        assertEq(uniCreateVault.authorizedDestinations(ethereumZrc20), false);
        assertEq(uniCreateVault.authorizedDestinations(address(123)), true);
    }

    function test_pause_unpause() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniCreateVault.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            PAUSER_ROLE));
        uniCreateVault.unpause();

        vm.startPrank(address(uniGovernance1));
        uniCreateVault.pause();
        assertEq(uniCreateVault.paused(), true);
        uniCreateVault.unpause();
        assertEq(uniCreateVault.paused(), false);
    }

    function test_setGateway() public {
        address newGateway = address(555);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniCreateVault.setGateway(newGateway);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniCreateVault.setGateway(address(0));

        vm.startPrank(deployer);
        vm.expectEmit();
        emit IUniTabOperation.UpdatedGateway(ethereumGateway, newGateway);
        uniCreateVault.setGateway(newGateway);
        assertEq(uniCreateVault.gateway(), newGateway);
        assertEq(uniCreateVault.hasRole(GATEWAY_ROLE, ethereumGateway), false);
        assertEq(uniCreateVault.hasRole(GATEWAY_ROLE, newGateway), true);
    }

    function test_setZrc20GasToken() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniCreateVault.setZrc20GasToken(address(666));

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniCreateVault.setZrc20GasToken(address(0));

        vm.expectEmit();
        emit IUniTabOperation.UpdatedZrc20GasToken(uniCreateVault.zrc20GasToken(), address(666));
        uniCreateVault.setZrc20GasToken(address(666));
        assertEq(uniCreateVault.zrc20GasToken(), address(666));
    }

    function test_setUniversal() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniCreateVault.setUniversal(address(777));

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidAddress.selector);
        uniCreateVault.setUniversal(address(0));

        vm.expectEmit();
        emit IUniTabOperation.UpdatedZetaUniversal(uniCreateVault.universal(), address(777));
        uniCreateVault.setUniversal(address(777));
        assertEq(uniCreateVault.universal(), address(777));
    }

    function test_setRevertGasLimit() public {
        uint256 newGasLimit = 500000;
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        uniCreateVault.setRevertGasLimit(newGasLimit);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTabOperation.InvalidGasLimit.selector);
        uniCreateVault.setRevertGasLimit(0);

        vm.expectEmit();
        emit IUniTabOperation.UpdatedGasLimit(uniCreateVault.revertGasLimit(), newGasLimit);
        uniCreateVault.setRevertGasLimit(newGasLimit);
        assertEq(uniCreateVault.revertGasLimit(), newGasLimit);
    }

    function test_createVault_validation() public {
        _testValidation();
    }

    function test_createVault_withNativeGas(uint256 _sendGasAmount) public {
        vm.assume(_sendGasAmount > 0.1 ether && _sendGasAmount < 10 ether);
        require(_sendGasAmount > 0.1 ether && _sendGasAmount < 10 ether);

        vm.deal(deployer, _sendGasAmount);
        vm.startPrank(deployer);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp);

        if (ethereumGateway.code.length > 0) {
            vm.expectEmit();
            emit IUniCreateVault.CreateVault(
                deployer,
                address(888),
                ethereumZrc20,
                address(0),
                0,
                _sendGasAmount,
                0,
                uniCreateVault.tabKey(usd),
                100e18
            );
            uniCreateVault.createVault{value: _sendGasAmount}(
                address(0),
                address(888),
                address(0),
                0,
                0,
                100e18,     // 100 sUSD
                0, 
                priceData
            );
        }
    }

    function test_createVault_withERCToken(uint256 _sendTokenAmount) public {
        if (ethereumUsdc.code.length == 0)
            return;
        address user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        uint256 bal = IERC20(ethereumUsdc).balanceOf(user);
        if (_sendTokenAmount > bal)
            _sendTokenAmount = bal;
        vm.assume(_sendTokenAmount > 1000 ether);
        require(_sendTokenAmount > 1000 ether);

        vm.startPrank(user);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp);

        if (ethereumGateway.code.length > 0) {
            IERC20(ethereumUsdc).approve(address(uniCreateVault), _sendTokenAmount);
            vm.expectEmit();
            emit IUniCreateVault.CreateVault(
                user,
                address(888),
                bnbZrc20,
                ethereumUsdc,
                _sendTokenAmount,
                0,
                0.0001 ether,
                uniCreateVault.tabKey(usd),
                100e18
            );
            uniCreateVault.createVault(
                bnbZrc20,
                address(888),
                ethereumUsdc,
                _sendTokenAmount,
                0.0001 ether,
                100e18,     // 100 sUSD
                0,
                priceData
            );
            assertEq(IERC20(ethereumUsdc).balanceOf(user), bal - _sendTokenAmount);
        }
    }

    function test_onRevert_nativeGas(uint256 _sendGasAmount) public {
        vm.assume(_sendGasAmount > 0.1 ether && _sendGasAmount < 10 ether);
        require(_sendGasAmount > 0.1 ether && _sendGasAmount < 10 ether);
        
        vm.deal(address(uniCreateVault), _sendGasAmount);
        RevertContext memory context = RevertContext({
            sender: address(zUniCreateVault),
            asset: address(0),      // asset
            amount: _sendGasAmount, // token / gasAmount
            revertMessage: abi.encode(address(888), 0, _sendGasAmount)
        });

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            GATEWAY_ROLE));
        uniCreateVault.onRevert(context);
        
        uint256 bal = address(888).balance;
        vm.startPrank(ethereumGateway);
        vm.expectEmit();
        emit IUniCreateVault.TokenOrGasTransferReverted(
            context.asset,
            address(888),
            0,
            _sendGasAmount,
            context.amount
        );
        uniCreateVault.onRevert(context);
        assertEq(address(888).balance, bal + _sendGasAmount);
    }

    function test_onRevert_erc20Token(uint256 _sendTokenAmount) public {
        if (ethereumUsdc.code.length == 0)
            return;
        address user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        uint256 bal = IERC20(ethereumUsdc).balanceOf(user);
        if (_sendTokenAmount > bal)
            _sendTokenAmount = bal;
        vm.assume(_sendTokenAmount > 1000 ether);
        require(_sendTokenAmount > 1000 ether);
        vm.startPrank(user);
        IERC20(ethereumUsdc).transfer(address(uniCreateVault), _sendTokenAmount);

        RevertContext memory context = RevertContext({
            sender: address(444),
            asset: ethereumUsdc,      // asset
            amount: _sendTokenAmount, // token / gasAmount
            revertMessage: abi.encode(address(888), _sendTokenAmount, 0)
        });
        
        vm.startPrank(ethereumGateway);
        vm.expectRevert(IUniTabOperation.Unauthorized.selector);
        uniCreateVault.onRevert(context);

        context.sender = address(zUniCreateVault);
        bal = IERC20(ethereumUsdc).balanceOf(address(888));
        vm.expectEmit();
        emit IUniCreateVault.TokenOrGasTransferReverted(
            context.asset,
            address(888),
            _sendTokenAmount,
            0,
            context.amount
        );
        uniCreateVault.onRevert(context);
        assertEq(IERC20(ethereumUsdc).balanceOf(address(888)), bal + _sendTokenAmount);
    }

    function _testValidation() internal {
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp);
        vm.startPrank(address(uniGovernance1));
        uniCreateVault.pause();

        vm.expectRevert(abi.encodeWithSelector(
                            PausableUpgradeable.EnforcedPause.selector));
        uniCreateVault.createVault(
            address(0),
            deployer,
            address(0),
            0,
            0,
            100e18,     // 100 sUSD
            0,
            priceData
        );
        uniCreateVault.unpause();

        vm.expectRevert(abi.encodeWithSelector(IUniCreateVault.InvalidDestination.selector));
        uniCreateVault.createVault(
            address(444),
            deployer,
            address(0),
            0,
            0,
            100e18,
            0,
            priceData
        );

        vm.expectRevert(abi.encodeWithSelector(IUniTabOperation.InvalidAddress.selector));
        uniCreateVault.createVault(
            address(0),
            address(0), // receiver
            address(0),
            0,
            0,
            100e18,
            0,
            priceData
        );

        vm.expectRevert(abi.encodeWithSelector(IUniCreateVault.InvalidSendTokenOrAmount.selector));
        uniCreateVault.createVault(
            address(0),
            deployer,
            address(0),     // _sendToken
            444,            // _sendAmount
            0,
            100e18,
            0,
            priceData
        );
        vm.expectRevert(abi.encodeWithSelector(IUniCreateVault.InvalidSendTokenOrAmount.selector));
        uniCreateVault.createVault(
            address(0),
            deployer,
            ethereumUsdc,   // _sendToken
            0,              // _sendAmount
            0,
            100e18,
            0,
            priceData
        );
        
        vm.expectRevert(abi.encodeWithSelector(IUniCreateVault.ZeroTabAmount.selector));
        uniCreateVault.createVault(
            address(0),
            deployer,
            address(0),
            0,
            0,
            0,              // _receiveTabAmt
            0,
            priceData
        );

        vm.expectRevert(abi.encodeWithSelector(IUniCreateVault.ZeroReserve.selector));
        uniCreateVault.createVault(
            address(0),
            deployer,
            address(0),
            0,
            0,
            100e18,     // 100 sUSD
            0,
            priceData
        );
        vm.stopPrank();
    }


}
