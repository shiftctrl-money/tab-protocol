// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {UniDeployer} from "./UniDeployer.t.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IZUniTabOperation} from "../contracts/interfaces/IZUniTabOperation.sol";
import {IZUniCreateVault} from "../contracts/interfaces/IZUniCreateVault.sol";
import {ZUniCreateVault} from "../contracts/core/ZUniCreateVault.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";

contract ZUniCreateVaultTest is UniDeployer {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");

    bytes3 usd = bytes3(abi.encodePacked("USD"));
    bytes3 aud = bytes3(abi.encodePacked("AUD"));

    function setUp() public {
        deploy();
        deployUniWrapper();
    }

    function test_permission() public {
        assertEq(zUniCreateVault.defaultAdmin() , address(zUniGovernance));
        assertEq(zUniCreateVault.hasRole(DEPLOYER_ROLE, address(zUniGovernance)), true);
        assertEq(zUniCreateVault.hasRole(DEPLOYER_ROLE, deployer), true);
        assertEq(zUniCreateVault.hasRole(UPGRADER_ROLE, deployer), true);
        assertEq(zUniCreateVault.hasRole(GATEWAY_ROLE, zetaGateway), true);
        assertEq(zUniCreateVault.hasRole(EXECUTOR_ROLE, deployer), true);
        
        vm.expectRevert();
        zUniCreateVault.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(zUniGovernance));
        zUniCreateVault.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        zUniCreateVault.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(zUniCreateVault.defaultAdmin() , owner);
    }

    function test_upgrade() public {
        vm.startPrank(address(444));
        ZUniCreateVault newContract = new ZUniCreateVault();
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            UPGRADER_ROLE));
        zUniCreateVault.upgradeToAndCall(address(newContract), "");

        vm.startPrank(deployer);
        zUniCreateVault.upgradeToAndCall(address(newContract), "");
    }

    function test_setBitcoinChainID() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniCreateVault.setBitcoinChainID(123456);

        vm.startPrank(deployer);
        vm.expectRevert(IZUniCreateVault.InvalidChainID.selector);
        zUniCreateVault.setBitcoinChainID(0);

        vm.expectEmit();
        emit IZUniCreateVault.UpdatedBitcoinChainID(10333, 123456);
        zUniCreateVault.setBitcoinChainID(123456);
        assertEq(zUniCreateVault.BITCOIN_CHAIN_ID(), 123456);
    }

    function test_setChainIdToZrc20() public {
        uint32[] memory chainId = new uint32[](2);
        address[] memory zrc20 = new address[](2);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniCreateVault.setChainIdToZrc20(chainId, zrc20);

        vm.startPrank(deployer);
        uint32[] memory invChainId = new uint32[](3);
        vm.expectRevert(IZUniTabOperation.InvalidLength.selector);
        zUniCreateVault.setChainIdToZrc20(invChainId, zrc20);

        chainId[0] = 100;
        chainId[1] = 101;
        zrc20[0] = address(100);
        zrc20[1] = address(0);
        vm.expectRevert(IZUniTabOperation.InvalidAddress.selector);
        zUniCreateVault.setChainIdToZrc20(chainId, zrc20);

        zrc20[1] = address(101);
        vm.expectEmit();
        emit IZUniCreateVault.UpdatedChainIdToZrc20(100, address(0), address(100));
        emit IZUniCreateVault.UpdatedChainIdToZrc20(101, address(0), address(101));
        zUniCreateVault.setChainIdToZrc20(chainId, zrc20);
        assertEq(zUniCreateVault.chainIdToZrc20(11155112), ethereumZrc20);
        assertEq(zUniCreateVault.chainIdToZrc20(98), bnbZrc20);
        assertEq(zUniCreateVault.chainIdToZrc20(31337), zetaZrc20);
        assertEq(zUniCreateVault.chainIdToZrc20(100), address(100));
        assertEq(zUniCreateVault.chainIdToZrc20(101), address(101));
    }

    function test_setGateway() public {
        address newGateway = address(555);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniCreateVault.setGateway(newGateway);

        vm.startPrank(deployer);
        vm.expectRevert(IZUniTabOperation.InvalidAddress.selector);
        zUniCreateVault.setGateway(address(0));

        vm.startPrank(deployer);
        vm.expectEmit();
        emit IZUniTabOperation.UpdatedGateway(zetaGateway, newGateway);
        zUniCreateVault.setGateway(newGateway);
        assertEq(zUniCreateVault.gateway(), newGateway);
        assertEq(zUniCreateVault.hasRole(GATEWAY_ROLE, zetaGateway), false);
        assertEq(zUniCreateVault.hasRole(GATEWAY_ROLE, newGateway), true);
    }

    function test_setVaultManager() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniCreateVault.setVaultManager(address(666));

        vm.startPrank(deployer);
        vm.expectRevert(IZUniTabOperation.InvalidAddress.selector);
        zUniCreateVault.setVaultManager(address(0));

        vm.expectEmit();
        emit IZUniTabOperation.UpdatedVaultManager(zUniCreateVault.vaultManager(), address(666));
        zUniCreateVault.setVaultManager(address(666));
        assertEq(zUniCreateVault.vaultManager(), address(666));
    }

    function test_setZUniTab() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniCreateVault.setZUniTab(address(777));

        vm.startPrank(deployer);
        vm.expectRevert(IZUniTabOperation.InvalidAddress.selector);
        zUniCreateVault.setZUniTab(address(0));

        vm.expectEmit();
        emit IZUniTabOperation.UpdatedZUniTab(zUniCreateVault.zUniTab(), address(777));
        zUniCreateVault.setZUniTab(address(777));
        assertEq(zUniCreateVault.zUniTab(), address(777));
    }

    function test_setDexRouter() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniCreateVault.setDexRouter(address(777));

        vm.startPrank(deployer);
        vm.expectRevert(IZUniTabOperation.InvalidAddress.selector);
        zUniCreateVault.setDexRouter(address(0));

        vm.expectEmit();
        emit IZUniTabOperation.UpdatedDexRouter(zUniCreateVault.dexRouter(), address(777));
        zUniCreateVault.setDexRouter(address(777));
        assertEq(zUniCreateVault.dexRouter(), address(777));
    }

    function test_setBTCBTC() public {
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniCreateVault.setBTCBTC(address(777));

        vm.startPrank(deployer);
        vm.expectRevert(IZUniTabOperation.InvalidAddress.selector);
        zUniCreateVault.setBTCBTC(address(0));

        vm.expectEmit();
        emit IZUniTabOperation.UpdatedBTCBTC(zUniCreateVault.BTC_BTC(), address(777));
        zUniCreateVault.setBTCBTC(address(777));
        assertEq(zUniCreateVault.BTC_BTC(), address(777));
    }

    function test_setAuthorizedUniCaller() public {
        address[] memory caller = new address[](1);
        bool[] memory authorized = new bool[](1);

        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            DEPLOYER_ROLE));
        zUniCreateVault.setAuthorizedUniCaller(caller, authorized);

        vm.startPrank(deployer);
        address[] memory invCaller = new address[](2);
        vm.expectRevert(IZUniTabOperation.InvalidLength.selector);
        zUniCreateVault.setAuthorizedUniCaller(invCaller, authorized);

        caller[0] = address(0);
        authorized[0] = true;
        vm.expectRevert(IZUniTabOperation.InvalidAddress.selector);
        zUniCreateVault.setAuthorizedUniCaller(caller, authorized);

        caller[0] = address(111);
        vm.expectEmit();
        emit IZUniTabOperation.UpdatedAuthorizedUniCaller(address(111), true);
        zUniCreateVault.setAuthorizedUniCaller(caller, authorized);
        assertEq(zUniCreateVault.authorizedUniCallers(address(111)), true);
        assertEq(zUniCreateVault.authorizedUniCallers(address(uniCreateVault)), true);
    }

    function test_onCall_reverts() public {
        bytes32 usdKey = zUniCreateVault.tabKey(bytes3("USD"));
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(444)),
            senderEVM: address(444),
            chainID: 10333
        });
        bytes memory messageBTC = abi.encodePacked(
            address(0),         // vault owner
            uint32(11155112),   // destination chain id
            usdKey,             // Tab key
            uint16(200)         // desired reserve ratio
        );
        vm.startPrank(owner);
        btcBtc.transfer(address(zUniCreateVault), 10e8);
        vm.startPrank(address(444));
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            address(444), 
                            GATEWAY_ROLE));
        zUniCreateVault.onCall(context, address(0), 0, "");

        vm.startPrank(zetaGateway);
        vm.expectRevert(IZUniCreateVault.InvalidReceiver.selector);
        zUniCreateVault.onCall(context, address(btcBtc), 1e8, messageBTC);

        uint256 bal = btcBtc.balanceOf(address(444));
        messageBTC = abi.encodePacked(
            address(444),       // vault owner
            uint32(11155112),   // destination chain id
            bytes32(0),         // Tab key
            uint16(200)         // desired reserve ratio
        );
        vm.expectEmit();
        emit IZUniCreateVault.InvalidCreateVaultRequest(address(444), 11155112, bytes32(0), 200, 1e8);
        zUniCreateVault.onCall(context, address(btcBtc), 1e8, messageBTC);
        assertEq(btcBtc.balanceOf(address(444)), bal + 1e8);

        messageBTC = abi.encodePacked(
            address(444),       // vault owner
            uint32(11155112),   // destination chain id
            usdKey,             // Tab key
            uint16(179)         // desired reserve ratio
        );
        vm.expectEmit();
        emit IZUniCreateVault.InvalidCreateVaultRequest(address(444), 11155112, usdKey, 179, 1e8);
        zUniCreateVault.onCall(context, address(btcBtc), 1e8, messageBTC);
        assertEq(btcBtc.balanceOf(address(444)), bal + 2e8);

        messageBTC = abi.encodePacked(
            address(444),   // vault owner
            uint32(414),    // destination chain id
            usdKey,         // Tab key
            uint16(180)     // desired reserve ratio
        );
        vm.expectEmit();
        emit IZUniCreateVault.InvalidCreateVaultRequest(address(444), 414, usdKey, 180, 1e8);
        zUniCreateVault.onCall(context, address(btcBtc), 1e8, messageBTC);
        assertEq(btcBtc.balanceOf(address(444)), bal + 3e8);

        context = MessageContext({
            sender: abi.encode(address(444)),
            senderEVM: address(444),
            chainID: 11155112
        });
        vm.expectRevert(IZUniTabOperation.Unauthorized.selector);
        zUniCreateVault.onCall(context, address(0), 0, "");
    }

    function test_onCall_evmDeposit_ETHReserve(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 10 ether && _amt < 100 ether);
        require(_amt > 10 ether && _amt < 100 ether);

        uint256 receiveTabAmt = 1e17;
        bytes32 usdKey = zUniCreateVault.tabKey(usd);
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniCreateVault)),
            senderEVM: address(uniCreateVault),
            chainID: 11155112
        });
        vm.startPrank(deployer);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, 11155112);
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        IERC20(ethereumZrc20).transfer(address(zUniCreateVault), _amt); // use native ETH as reserve

        // Use VaultUtils to estimate converted BTC.BTC amount locked into vault
        uint256 amountIn = vaultUtils.getAmountsIn(
            zUniCreateVault.dexRouter(),
            ethereumZrc20,
            bnbZrc20,
            0.001 ether,
            address(zUniTab)
        );
        uint256 minOutAmount = vaultUtils.getAmountsOut(
            zUniCreateVault.dexRouter(),
            ethereumZrc20,
            address(btcBtc),
            _amt - amountIn
        );

        vm.startPrank(zetaGateway);
        // Create vault with ETH
        bytes memory message = abi.encode(
            bnbZrc20,           // destination
            address(888),       // receiver
            address(0),         // send token
            0,                  // send token amount
            receiveTabAmt,      // receive tab amount
            0.001 ether,        // receive gas amount
            0,                  // btcOutMin
            priceData           // price signature
        );
        vm.expectEmit(true, true, false, false);
        emit IZUniCreateVault.ZCreateVault(
            deployer,
            address(888),
            context.chainID,
            ethereumZrc20,
            _amt,   // invalid value - placeholder only
            _amt,   // invalid value - placeholder only
            0.001 ether,
            usdKey,
            receiveTabAmt
        );
        zUniCreateVault.onCall(context, ethereumZrc20, _amt, message);

        (
            bytes3 tab,
            address reserveAddr,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            ,,
        ) = vaultUtils.getVaultDetails(deployer, 1, 100000e18);
        assertEq(tab == usd, true);
        assertEq(reserveAddr, address(btcBtc));
        assertEq(price, 100000e18);
        assertEq(osTab, receiveTabAmt);
        assertEq(IERC20(btcBtc).balanceOf(address(reserveSafe)), reserveSafe.getNativeTransferAmount(address(btcBtc), reserveAmt));
        assertEq(reserveSafe.getNativeTransferAmount(address(btcBtc), reserveAmt), minOutAmount);
        address tabAddr = tabRegistry.tabs(usdKey);
        assertEq(IERC20(tabAddr).balanceOf(address(zUniTab)), 0);
        assertEq(IERC20(tabAddr).balanceOf(address(888)), 0);
        assertEq(IERC20(tabAddr).totalSupply(), 0); // burnt tab in ZetaChain hence supply is zero
        (uint256 chainID,,,,,,) = vaultManager.vaults(deployer, 1);
        assertEq(chainID, 11155112);
    }

    function test_onCall_evmDeposit_TokenReserve(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 10 ether && _amt < 100 ether);
        require(_amt > 10 ether && _amt < 100 ether);

        uint256 receiveTabAmt = 3e17;
        bytes32 audKey = zUniCreateVault.tabKey(aud);
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniCreateVault)),
            senderEVM: address(uniCreateVault),
            chainID: 11155112
        });
        vm.startPrank(deployer);
        priceData = signer.getUpdatePriceSignature(aud, 180000e18, block.timestamp, 11155112);
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        IERC20(zetaEthereumUsdc).transfer(address(zUniCreateVault), _amt); // use ERC20 token as reserve

        vm.startPrank(zetaGateway);
        // Create vault with USDC
        bytes memory message = abi.encode(
            zetaZrc20,          // destination
            address(888),       // receiver
            zetaEthereumUsdc,   // send token
            _amt,               // send token amount
            receiveTabAmt,      // receive tab amount
            0.001 ether,        // receive gas amount
            0,
            priceData           // price signature
        );
        vm.expectEmit(true, true, false, false);
        emit IZUniCreateVault.ZCreateVault(
            deployer,
            address(888),
            context.chainID,
            zetaEthereumUsdc,
            _amt,   // invalid value - placeholder only
            _amt,   // invalid value - placeholder only
            0.001 ether,
            audKey,
            receiveTabAmt
        );
        zUniCreateVault.onCall(context, zetaEthereumUsdc, _amt, message);

        (
            bytes3 tab,
            address reserveAddr,
            uint256 price,
            uint256 reserveAmt,
            uint256 osTab,
            ,,
        ) = vaultUtils.getVaultDetails(deployer, 1, 180000e18);
        assertEq(tab == aud, true);
        assertEq(reserveAddr, address(btcBtc));
        assertEq(price, 180000e18);
        assertEq(osTab, receiveTabAmt);
        assertEq(IERC20(btcBtc).balanceOf(address(reserveSafe)), reserveSafe.getNativeTransferAmount(address(btcBtc), reserveAmt));
        address tabAddr = tabRegistry.tabs(audKey);
        assertEq(IERC20(tabAddr).balanceOf(address(zUniTab)), 0);
        assertEq(IERC20(tabAddr).balanceOf(address(888)), receiveTabAmt);
        assertEq(address(888).balance, 0.001 ether);
        (uint256 chainID,,,,,,) = vaultManager.vaults(deployer, 1);
        assertEq(chainID, 11155112);
    }

    // User (sender and receiver) is on same chain
    function test_onCall_evmDeposit_sameChain(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 10 ether && _amt < 100 ether);
        require(_amt > 10 ether && _amt < 100 ether);

        uint256 receiveTabAmt = 3e17;
        bytes32 usdKey = zUniCreateVault.tabKey(usd);
        MessageContext memory context = MessageContext({
            sender: abi.encode(address(uniCreateVault)),
            senderEVM: address(uniCreateVault),
            chainID: 11155112
        });
        vm.startPrank(deployer);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp);
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        IERC20(ethereumZrc20).transfer(address(zUniCreateVault), _amt); // use native ETH as reserve
        IERC20(zetaEthereumUsdc).transfer(address(zUniCreateVault), _amt); // use ERC20 token as reserve

        vm.startPrank(zetaGateway);
        // Create vault with ETH
        bytes memory message = abi.encode(
            ethereumZrc20,      // destination
            deployer,           // receiver
            address(0),         // send token
            0,                  // send token amount
            receiveTabAmt,      // receive tab amount
            0,                  // receive gas amount
            0,
            priceData           // price signature
        );
        vm.expectEmit(true, true, false, false);
        emit IZUniCreateVault.ZCreateVault(
            deployer,
            deployer,
            context.chainID,
            ethereumZrc20,
            _amt,   // invalid value - placeholder only
            _amt,   // invalid value - placeholder only
            0,
            usdKey,
            receiveTabAmt
        );
        zUniCreateVault.onCall(context, ethereumZrc20, _amt, message);
        (
            ,
            ,
            ,
            uint256 reserveAmt,
            uint256 osTab,
            ,,
        ) = vaultUtils.getVaultDetails(deployer, 1, 100000e18);

        vm.startPrank(deployer);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp);

        vm.startPrank(zetaGateway);
        message = abi.encode(
            ethereumZrc20,      // destination
            deployer,           // receiver
            zetaEthereumUsdc,   // send token
            _amt,               // send token amount
            receiveTabAmt,      // receive tab amount
            0,                  // receive gas amount
            0,
            priceData           // price signature
        );
        zUniCreateVault.onCall(context, zetaEthereumUsdc, _amt, message);
        (
            ,
            ,
            ,
            uint256 reserveAmt2,
            uint256 osTab2,
            ,,
        ) = vaultUtils.getVaultDetails(deployer, 2, 100000e18);
        assertEq(IERC20(btcBtc).balanceOf(address(reserveSafe)), reserveSafe.getNativeTransferAmount(address(btcBtc), reserveAmt + reserveAmt2));
        assertEq(receiveTabAmt * 2, osTab + osTab2);
        address tabAddr = tabRegistry.tabs(usdKey);
        assertEq(IERC20(tabAddr).balanceOf(address(zUniTab)), 0);
        assertEq(IERC20(tabAddr).balanceOf(deployer), 0);
        assertEq(IERC20(tabAddr).totalSupply(), 0); // burnt tab in ZetaChain hence supply is zero
    }

    // Executor invokes with sponsored gas to fuel destination transfer
    function test_onCall_bitcoinDeposit(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 1e6 && _amt < 15e7);
        require(_amt > 1e6 && _amt < 15e7);

        bytes32 usdKey = zUniCreateVault.tabKey(usd);
        MessageContext memory context = MessageContext({
            sender: abi.encode(deployer),
            senderEVM: address(0),
            chainID: 10333 // BITCOIN_CHAIN_ID
        });
        bytes memory message = abi.encodePacked(
            deployer,               // vault owner
            uint32(11155112),       // destination chain id
            usdKey,                 // Tab key
            uint16(200)             // desired reserve ratio
        );
        vm.startPrank(owner);
        btcBtc.transfer(address(zUniCreateVault), _amt);

        vm.startPrank(zetaGateway);
        uint256 ts = block.timestamp;
        bytes32 senderKey = keccak256(context.sender);
        bytes32 requestKey = keccak256(abi.encode(deployer, ethereumZrc20, usdKey, 200, ts));
        vm.expectEmit();
        emit IZUniCreateVault.NativeCreateVaultReq(
            senderKey,          // senderKey
            requestKey,         // requestKey
            deployer,           // vaultOwner
            ethereumZrc20,      // destination
            usdKey,             // tabKey
            200,                // reserveRatio
            _amt                // amount
        );
        zUniCreateVault.onCall(context, address(btcBtc), _amt, message);

        IZUniCreateVault.NativeCreateVaultRequest memory r;
        (
            r.sender,
            r.chainID,
            r.receiver,
            r.destination,
            r.reserveRatio,
            r.tabKey,
            r.depositAmt,
            r.depositTimestamp,
            r.createdTimestamp
        ) = zUniCreateVault.createVaultRequests(senderKey, requestKey);
        assertEq(keccak256(r.sender), keccak256(context.sender));
        assertEq(r.chainID, 11155112);
        assertEq(r.receiver, deployer);
        assertEq(r.destination, ethereumZrc20);
        assertEq(r.reserveRatio, 200);
        assertEq(r.tabKey, usdKey);
        assertEq(r.depositAmt, _amt);
        assertEq(r.depositTimestamp, ts);
        assertEq(r.createdTimestamp, 0);

        // Test: Protocol executor module invokes processCreateVaultRequest()
        vm.expectRevert(abi.encodeWithSelector(
                            IAccessControl.AccessControlUnauthorizedAccount.selector, 
                            zetaGateway, 
                            EXECUTOR_ROLE));
        zUniCreateVault.processCreateVaultRequest(senderKey, requestKey, priceData);

        vm.startPrank(deployer); // executor
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, 11155112);
        
        vm.expectRevert(IZUniCreateVault.InvalidRequest.selector);
        zUniCreateVault.processCreateVaultRequest(keccak256(""), requestKey, priceData);

        vm.expectEmit();
        emit IZUniCreateVault.NativeCreatedVault(
            senderKey,
            requestKey,
            deployer,
            ethereumZrc20,
            usdKey,
            Math.mulDiv(Math.mulDiv(priceData.price, zUniCreateVault.scaleUp(_amt), 1e18), 100, 200),
            _amt
        );
        zUniCreateVault.processCreateVaultRequest{value: 0.00001 ether}(senderKey, requestKey, priceData);
    }

    // Executor invokes without paying extra gas - deduct gas from deposited BTC 
    function test_onCall_bitcoinDeposit_NoGas(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 1e5 && _amt < 1e8);
        require(_amt > 1e5 && _amt < 1e8);

        bytes32 usdKey = zUniCreateVault.tabKey(usd);
        MessageContext memory context = MessageContext({
            sender: abi.encode(deployer),
            senderEVM: address(0),
            chainID: 10333 // BITCOIN_CHAIN_ID
        });
        bytes memory message = abi.encodePacked(
            deployer,               // vault owner
            uint32(11155112),       // destination chain id
            usdKey,                 // Tab key
            uint16(200)             // desired reserve ratio
        );
        vm.startPrank(owner);
        btcBtc.transfer(address(zUniCreateVault), _amt);

        vm.startPrank(zetaGateway);
        uint256 ts = block.timestamp;
        bytes32 senderKey = keccak256(context.sender);
        bytes32 requestKey = keccak256(abi.encode(deployer, ethereumZrc20, usdKey, 200, ts));
        zUniCreateVault.onCall(context, address(btcBtc), _amt, message);

        vm.startPrank(deployer);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, 11155112);
        vm.expectEmit(false, false, false, false);
        emit IZUniCreateVault.NativeCreatedVault(
            senderKey,
            requestKey,
            deployer,
            ethereumZrc20,
            usdKey,
            Math.mulDiv(Math.mulDiv(priceData.price, zUniCreateVault.scaleUp(_amt), 1e18), 100, 200),
            _amt
        );
        uint256 sid = vm.snapshot();
        // not sending gas
        zUniCreateVault.processCreateVaultRequest(senderKey, requestKey, priceData);

        IZUniCreateVault.NativeCreateVaultRequest memory r;
        (
            r.sender,
            r.chainID,
            r.receiver,
            r.destination,
            r.reserveRatio,
            r.tabKey,
            r.depositAmt,
            r.depositTimestamp,
            r.createdTimestamp
        ) = zUniCreateVault.createVaultRequests(senderKey, requestKey);
        assertEq(keccak256(r.sender), keccak256(context.sender));
        assertEq(r.chainID, 11155112);
        assertEq(r.receiver, deployer);
        assertEq(r.destination, ethereumZrc20);
        assertEq(r.reserveRatio, 200);
        assertEq(r.tabKey, usdKey);
        assertEq(r.depositTimestamp, ts);
        assertEq(r.createdTimestamp, block.timestamp);

        (uint256 chainID,,uint256 reserveAmt,,,,) = vaultManager.vaults(deployer, 1);
        assertEq(chainID, 11155112);
        assertEq(_amt - reserveSafe.getNativeTransferAmount(address(btcBtc), reserveAmt) >= 0, true);

        vm.revertTo(sid);
        // use available balance stored in contract for gas payment
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        IERC20(ethereumZrc20).transfer(address(zUniCreateVault), 1e18); 

        vm.startPrank(deployer);
        zUniCreateVault.processCreateVaultRequest(senderKey, requestKey, priceData);
        (chainID,, reserveAmt,,,,) = vaultManager.vaults(deployer, 1);
        assertEq(_amt, reserveSafe.getNativeTransferAmount(address(btcBtc), reserveAmt)); // exact amount of BTC is used as reserve 

        // Can't cancel request since it has been processed
        vm.expectRevert(abi.encodeWithSelector(
                            IZUniCreateVault.InvalidRequest.selector));
        zUniCreateVault.refundCreateVaultRequest(senderKey, requestKey);

        vm.revertTo(sid);
        address BTC_BTC = zUniCreateVault.BTC_BTC();
        uint256 balB4 = IERC20(BTC_BTC).balanceOf(deployer);
        // cancel create vault require and refund
        vm.expectEmit();
        emit IZUniCreateVault.NativeCreateVaultRefund(
            senderKey,
            requestKey,
            deployer,
            BTC_BTC,
            _amt
        );
        zUniCreateVault.refundCreateVaultRequest(senderKey, requestKey);
        assertEq(IERC20(BTC_BTC).balanceOf(deployer), balB4 + _amt);
    }

    function test_onCall_bitcoinDeposit_invalidCases() public {
        if (zetaGateway.code.length == 0)
            return;
        bytes32 usdKey = zUniCreateVault.tabKey(usd);
        MessageContext memory context = MessageContext({
            sender: abi.encode(deployer),
            senderEVM: address(0),
            chainID: 10333 // BITCOIN_CHAIN_ID
        });
        bytes memory message = abi.encodePacked(
            deployer,               // vault owner
            uint32(11155112),       // destination chain id
            usdKey,                 // Tab key
            uint16(200)             // desired reserve ratio
        );
        vm.startPrank(owner);
        btcBtc.transfer(address(zUniCreateVault), 1e6);

        vm.startPrank(zetaGateway);
        uint256 ts = block.timestamp;
        bytes32 senderKey = keccak256(context.sender);
        bytes32 requestKey = keccak256(abi.encode(deployer, ethereumZrc20, usdKey, 200, ts));
        zUniCreateVault.onCall(context, address(btcBtc), 1e6, message); // BTC create vault request stored

        // updater is zetaGateway
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp); 
        
        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IZUniCreateVault.InvalidSigUpdater.selector,
            address(zetaGateway), 
            deployer
        ));
        zUniCreateVault.processCreateVaultRequest(senderKey, requestKey, priceData);

        // correct updater, but invalid chainID
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp); 
        vm.expectRevert(abi.encodeWithSelector(IZUniCreateVault.InvalidSigChainID.selector,
            block.chainid, 
            11155112
        ));
        zUniCreateVault.processCreateVaultRequest(senderKey, requestKey, priceData);

        // BTC/USD low price
        priceData = signer.getUpdatePriceSignature(usd, 100, block.timestamp, 11155112); 
        vm.expectRevert(abi.encodeWithSelector(IZUniCreateVault.ZeroTabAmount.selector, 
            100,
            zUniCreateVault.scaleUp(1e6),
            200
        ));
        zUniCreateVault.processCreateVaultRequest{value: 0.00001 ether}(senderKey, requestKey, priceData);
    }

    function test_zCreateVault_revertCases() public {
        vm.startPrank(deployer);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, 11155112);
        vm.expectRevert(abi.encodeWithSelector(IZUniCreateVault.AmbiguousAsset.selector, ethereumZrc20, 0, 1 ether));
        zUniCreateVault.zCreateVault{value: 1 ether}(ethereumZrc20, 0, ethereumZrc20, address(888), 1e18, 1e18, 0, priceData);

        vm.expectRevert(abi.encodeWithSelector(IZUniCreateVault.AmbiguousAsset.selector, address(0), 1 ether, 1 ether));
        zUniCreateVault.zCreateVault{value: 1 ether}(address(0), 1 ether, ethereumZrc20, address(888), 1e18, 1e18, 0, priceData);

        vm.expectRevert(IZUniCreateVault.RequiredAssetAddress.selector);
        zUniCreateVault.zCreateVault(address(0), 1 ether, ethereumZrc20, address(888), 1e18, 1e18, 0, priceData);

        vm.expectRevert(IZUniCreateVault.RequiredAssetAmount.selector);
        zUniCreateVault.zCreateVault(ethereumZrc20, 0, ethereumZrc20, address(888), 1e18, 1e18, 0, priceData);

        vm.expectRevert(IZUniCreateVault.RequiredDestination.selector);
        zUniCreateVault.zCreateVault(ethereumZrc20, 1 ether, address(0), address(888), 1e18, 1e18, 0, priceData);

        vm.expectRevert(IZUniCreateVault.RequiredReceiver.selector);
        zUniCreateVault.zCreateVault(ethereumZrc20, 1 ether, ethereumZrc20, address(0), 1e18, 1e18, 0, priceData);

        vm.expectRevert(IZUniCreateVault.ZeroMintTabAmount.selector);
        zUniCreateVault.zCreateVault(ethereumZrc20, 1 ether, ethereumZrc20, address(888), 0, 1e18, 0, priceData);

        vm.expectRevert();
        zUniCreateVault.zCreateVault{value: 444}(address(0), 0, ethereumZrc20, address(888), 1e18, 1e18, 0, priceData);
    }

    function test_zCreateVault(uint256 _amt) public {
        if (zetaGateway.code.length == 0)
            return;
        vm.assume(_amt > 10 ether && _amt < 100 ether);
        require(_amt > 10 ether && _amt < 100 ether);

        uint256 receiveTabAmt = 1e17;
        uint256 receiveGasAmt = 12345;
        bytes32 tabKey = zUniCreateVault.tabKey(usd);
        
        vm.deal(deployer, _amt);
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        IERC20(zetaEthereumUsdc).transfer(deployer, _amt);

        vm.startPrank(deployer);
        IERC20(zetaEthereumUsdc).approve(address(zUniCreateVault), _amt);
        priceData = signer.getUpdatePriceSignature(usd, 100000e18, block.timestamp, 31337);
        
        uint256 sid = vm.snapshot();

        // (1) native token - non zeta destination : deduct destination gas + receiveGasAmt
        console.log("Native, Non-Zeta");
        uint256 amountIn = vaultUtils.getAmountsIn(
            zUniCreateVault.dexRouter(),
            zetaZrc20,
            bnbZrc20,
            receiveGasAmt,
            address(zUniTab)
        );
        uint256 minOutAmount = vaultUtils.getAmountsOut(
            zUniCreateVault.dexRouter(),
            zetaZrc20,
            address(btcBtc),
            _amt - amountIn
        );

        vm.expectEmit();
        emit IZUniCreateVault.ZCreateVault(deployer, address(888), 31337, zetaZrc20, (_amt - amountIn), minOutAmount, receiveGasAmt, tabKey, receiveTabAmt);
        zUniCreateVault.zCreateVault{value: _amt}(address(0), 0, bnbZrc20, address(888), receiveTabAmt, receiveGasAmt, 0, priceData);

        vm.revertTo(sid);
        // (1.1) zero receiveGasAmt
        console.log("Native, Non-Zeta, zero gas");
        amountIn = vaultUtils.getAmountsIn(
            zUniCreateVault.dexRouter(),
            zetaZrc20,
            bnbZrc20,
            0,
            address(zUniTab)
        );
        minOutAmount = vaultUtils.getAmountsOut(
            zUniCreateVault.dexRouter(),
            zetaZrc20,
            address(btcBtc),
            _amt - amountIn
        );
        emit IZUniCreateVault.ZCreateVault(deployer, address(888), 31337, zetaZrc20, (_amt - amountIn), minOutAmount, 0, tabKey, receiveTabAmt);
        zUniCreateVault.zCreateVault{value: _amt}(address(0), 0, bnbZrc20, address(888), receiveTabAmt, 0, 0, priceData);

        vm.revertTo(sid);
        // (2) native token - zeta destination : only deduct receiveGasAmt
        console.log("Native, Zeta");
        amountIn = _amt - receiveGasAmt;
        minOutAmount = vaultUtils.getAmountsOut(
            zUniCreateVault.dexRouter(),
            zetaZrc20,
            address(btcBtc),
            amountIn
        );
        vm.expectEmit();
        emit IZUniCreateVault.ZCreateVault(deployer, address(888), 31337, zetaZrc20, amountIn, minOutAmount, receiveGasAmt, tabKey, receiveTabAmt);
        zUniCreateVault.zCreateVault{value: _amt}(address(0), 0, zetaZrc20, address(888), receiveTabAmt, receiveGasAmt, 0, priceData);
        assertEq(address(888).balance, receiveGasAmt);

        vm.revertTo(sid);
        // (3) supported asset token - non zeta destination
        console.log("Asset Token, Non-Zeta");
        amountIn = vaultUtils.getAmountsIn(
            zUniCreateVault.dexRouter(),
            zetaEthereumUsdc,
            bnbZrc20,
            receiveGasAmt,
            address(zUniTab)
        );
        minOutAmount = vaultUtils.getAmountsOut(
            zUniCreateVault.dexRouter(),
            zetaEthereumUsdc,
            address(btcBtc),
            _amt - amountIn
        );

        vm.expectEmit();
        emit IZUniCreateVault.ZCreateVault(deployer, address(888), 31337, zetaEthereumUsdc, (_amt - amountIn), minOutAmount, receiveGasAmt, tabKey, receiveTabAmt);
        zUniCreateVault.zCreateVault(zetaEthereumUsdc, _amt, bnbZrc20, address(888), receiveTabAmt, receiveGasAmt, 0, priceData);

        vm.revertTo(sid);
        // (3.1) zero receiveTabAmt
        console.log("Asset Token, Non-Zeta, zero gas");
        amountIn = vaultUtils.getAmountsIn(
            zUniCreateVault.dexRouter(),
            zetaEthereumUsdc,
            bnbZrc20,
            0,
            address(zUniTab)
        );
        minOutAmount = vaultUtils.getAmountsOut(
            zUniCreateVault.dexRouter(),
            zetaEthereumUsdc,
            address(btcBtc),
            _amt - amountIn
        );

        vm.expectEmit();
        emit IZUniCreateVault.ZCreateVault(deployer, address(888), 31337, zetaEthereumUsdc, (_amt - amountIn), minOutAmount, 0, tabKey, receiveTabAmt);
        zUniCreateVault.zCreateVault(zetaEthereumUsdc, _amt, bnbZrc20, address(888), receiveTabAmt, 0, 0, priceData);

        vm.revertTo(sid);
        // (4) supported asset token - zeta destination
        console.log("Asset Token, Zeta");
        amountIn = vaultUtils.getAmountsIn(
            zUniCreateVault.dexRouter(),
            zetaEthereumUsdc,
            zetaZrc20,
            receiveGasAmt,
            address(zUniTab)
        );
        minOutAmount = vaultUtils.getAmountsOut(
            zUniCreateVault.dexRouter(),
            zetaEthereumUsdc,
            address(btcBtc),
            _amt - amountIn
        );
        vm.expectEmit();
        emit IZUniCreateVault.ZCreateVault(deployer, address(888), 31337, zetaEthereumUsdc, (_amt - amountIn), minOutAmount, receiveGasAmt, tabKey, receiveTabAmt);
        zUniCreateVault.zCreateVault(zetaEthereumUsdc, _amt, zetaZrc20, address(888), receiveTabAmt, receiveGasAmt, 0, priceData);
        assertEq(address(888).balance, receiveGasAmt);
    }

}
