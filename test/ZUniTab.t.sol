// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ICREATE3Factory} from "../contracts/interfaces/ICREATE3Factory.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {ZUniTab} from "../contracts/token/ZUniTab.sol";
import {ZUniTab_newImpl} from "./upgrade/ZUniTab_newImpl.sol";
import {IZUniTab} from "../contracts/interfaces/IZUniTab.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RevertContext,AbortContext} from "@zetachain/protocol-contracts/contracts/Revert.sol";
import {IWETH9} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IWZETA.sol";
import {ZRC20, ZRC20Errors} from "@zetachain/protocol-contracts/contracts/zevm/ZRC20.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";

// Need Localnet to run test, command:
// npx zetachain@latest localnet start
// forge test -vvv --match-path test/ZUniTab.t.sol --rpc-url http://127.0.0.1:8545
contract ZUniTabTest is Test {
    address public deployer;
    address public create3Factory;

    address governanceController;
    address emergencyGov;
    address upgrader;
    address gatewayAddress; // local side gateway
    address zetaToken; // ZetaChain zetaToken
    address uniswapV2Router;
    address universalTabAddress;
    uint256 sourceChainId;

    address PROTOCOL_ADDRESS;
    GatewayZEVM gateway;
    address baseZrc20;
    address arbitrumZrc20;
    address ethereumZrc20;
    address avalancheZrc20;

    address sUsd;
    address sAud;
    address sMyr;
    address newUsd;

    TabFactory tabFactory;
    TabERC20 tabERC20;
    ZUniTab zetaUniversalTab;

    error EmptyCharacter();

    constructor() {
        create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
        universalTabAddress = 0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933;
        sourceChainId = 84532; // default base testnet

        if (block.chainid == 7001) { // zeta testnet
            deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
            
            gatewayAddress = 0x6c533f7fE93fAE114d0954697069Df33C9B74fD7;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
            uniswapV2Router = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;

            baseZrc20 = 0x236b0DE675cC8F46AE186897fCCeFe3370C9eDeD;
            arbitrumZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            ethereumZrc20 = 0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0;
            avalancheZrc20 = 0xEe9CC614D03e7Dbe994b514079f4914a605B4719;

            // assumed using same addresses across all EVM chains
            sUsd = 0x25698AcdfC0A3C3dBbBD352afF212CEB256bcfCd;
            sAud = 0xEbb42c2eD11aBA266da245e6e1B815Ab86A3A967;
            sMyr = 0x22D0579c3944609012Ed8d0EC6ECb40836CfAe24;
        } else if (block.chainid == 7000) { // zeta mainnet
            deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;

            gatewayAddress = 0xfEDD7A6e3Ef1cC470fbfbF955a22D793dDC0F44E;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
            uniswapV2Router = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;

            baseZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            arbitrumZrc20 = 0xA614Aebf7924A3Eb4D066aDCA5595E4980407f1d;
            ethereumZrc20 = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891;
            avalancheZrc20 = 0xE8d7796535F1cd63F0fe8D631E68eACe6839869B;

            // assumed using same addresses across all EVM chains
            sUsd = 0x25698AcdfC0A3C3dBbBD352afF212CEB256bcfCd;
            sAud = 0xEbb42c2eD11aBA266da245e6e1B815Ab86A3A967;
            sMyr = 0x22D0579c3944609012Ed8d0EC6ECb40836CfAe24;
        } else if (block.chainid == 31337) { // localnet
            deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

            gatewayAddress = 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e;
            zetaToken = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
            uniswapV2Router = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;

            baseZrc20 = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;     // ZRC-20 ETH.ETH on 11155112
            arbitrumZrc20 = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b; // ZRC-20 BNB.BNB on 98
            ethereumZrc20 = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
            avalancheZrc20 = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b;

            sUsd = 0x25698AcdfC0A3C3dBbBD352afF212CEB256bcfCd;
            sAud = 0xEbb42c2eD11aBA266da245e6e1B815Ab86A3A967;
            sMyr = 0x22D0579c3944609012Ed8d0EC6ECb40836CfAe24;
            console.log("Chain ID 31337");
        }
        governanceController = deployer;
        emergencyGov = deployer;
        if (gatewayAddress.code.length > 0) {
            gateway = GatewayZEVM(payable(gatewayAddress));
            PROTOCOL_ADDRESS = gateway.PROTOCOL_ADDRESS();
            console.log("PROTOCOL_ADDRESS: ", PROTOCOL_ADDRESS);
        }
        _deploy();
    }

    function setUp() public {
        
    }

    function nextBlock(uint256 increment) public {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
    }

    function deployTab(bytes3 _tab) internal returns(address){
        string memory _symbol = _addTabCodePrefix(_tab);
        string memory _name = string(abi.encodePacked("Sound ", _tab));
        return tabFactory.createTab(governanceController, address(zetaUniversalTab), _name, _symbol, _tab);
    }

    function _addTabCodePrefix(bytes3 _tab) internal pure returns (string memory) {
        bytes memory b = new bytes(4);
        b[0] = hex"73"; // prefix s
        if (_tab[0] == 0x0)
            revert EmptyCharacter();
        b[1] = _tab[0];
        if (_tab[1] == 0x0)
            revert EmptyCharacter();
        b[2] = _tab[1];
        if (_tab[2] == 0x0)
            revert EmptyCharacter();
        b[3] = _tab[2];
        return string(b);
    }

    function _deploy() internal {
        vm.startPrank(deployer);

        tabERC20 = new TabERC20();
        console.log("TabERC20 deployed at:", address(tabERC20));

        if (create3Factory.code.length == 0) {
            tabFactory = new TabFactory(address(tabERC20), governanceController);
        } else {
            tabFactory = TabFactory(ICREATE3Factory(create3Factory).deploy(
                keccak256(abi.encodePacked("ShiftCTRL_v1.01.000: TabFactory")), 
                abi.encodePacked(type(TabFactory).creationCode, abi.encode(address(tabERC20), governanceController))
            ));
        }
        console.log("TabFactory deployed at:", address(tabFactory));
        console.log("TabFactory TabERC20 implementation:", tabFactory.implementation());
        upgrader = deployer;

        address zetaUniversalTabImplementation = address(new ZUniTab());
        console.log("zUniTabImplementation: ", zetaUniversalTabImplementation);
        bytes memory initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            governanceController, emergencyGov, upgrader, deployer, gatewayAddress, uniswapV2Router);
        if (create3Factory.code.length == 0) {
            zetaUniversalTab = ZUniTab(payable(new ERC1967Proxy(
                zetaUniversalTabImplementation, 
                initData
            )));
            zetaUniversalTab.updateDebugSuccess(true, true, true);
        } else {
            address payable zetaUniversalTabAddr = payable(address(TabFactory(ICREATE3Factory(create3Factory).deploy(
                keccak256(abi.encodePacked("ShiftCTRL_v1.01.000: UniversalTab")), 
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(zetaUniversalTabImplementation, initData))
            ))));
            zetaUniversalTab = ZUniTab(zetaUniversalTabAddr);
        }
        console.log("ZUniTab: ", address(zetaUniversalTab));

        vm.startPrank(governanceController);
        // TODO to replace with real TabRegistry address
        tabFactory.updateCreator(deployer);

        sUsd = deployTab(bytes3(abi.encodePacked("USD")));
        console.log("sUsd: ", sUsd);
        sAud = deployTab(bytes3(abi.encodePacked("AUD")));
        console.log("sAud: ", sAud);
        sMyr = deployTab(bytes3(abi.encodePacked("MYR")));
        console.log("sMyr: ", sMyr);
        newUsd = deployTab(bytes3(abi.encodePacked("NEW")));

        // Set connected UniversalTab contracts in supported chains
        address[] memory zrc20s = new address[](4); // https://www.zetachain.com/docs/developers/evm/zrc20/
        zrc20s[0] = baseZrc20;
        zrc20s[1] = arbitrumZrc20;
        zrc20s[2] = ethereumZrc20;
        zrc20s[3] = zetaToken;
        address[] memory universals = new address[](4);
        universals[0] = universalTabAddress;
        universals[1] = universalTabAddress;
        universals[2] = universalTabAddress;
        universals[3] = address(zetaUniversalTab);
        zetaUniversalTab.setConnected(zrc20s, universals);

        bool[] memory isAuthorized = new bool[](4);
        isAuthorized[0] = true;
        isAuthorized[1] = true;
        isAuthorized[2] = true;
        isAuthorized[3] = true;
        zetaUniversalTab.setAuthorizedSender(universals, isAuthorized);
        
        // Set connected chains gas limit
        address[] memory destinations = new address[](4);
        destinations[0] = baseZrc20;
        destinations[1] = arbitrumZrc20;
        destinations[2] = zetaToken;
        destinations[3] = ethereumZrc20;
        uint256[] memory gasLimit = new uint256[](4);
        gasLimit[0] = 120000;
        gasLimit[1] = 120000;
        gasLimit[2] = 120000;
        gasLimit[3] = 120000;
        zetaUniversalTab.setGasLimit(destinations, gasLimit); // TODO adjust accordingly
        
        // Set Tab addresses mapping on each chain
        bytes32[] memory tabKeys = new bytes32[](3); 
        tabKeys[0] = TabERC20(sUsd).tabKey();
        tabKeys[1] = TabERC20(sAud).tabKey();
        tabKeys[2] = TabERC20(sMyr).tabKey();
        address[] memory destToken = new address[](3);
        destToken[0] = sUsd;
        destToken[1] = sAud;
        destToken[2] = sMyr;
        zetaUniversalTab.setTabAddress(baseZrc20, tabKeys, destToken);
        destToken[0] = sUsd;
        destToken[1] = sAud;
        destToken[2] = sMyr;
        zetaUniversalTab.setTabAddress(arbitrumZrc20, tabKeys, destToken);
        destToken[0] = sUsd;
        destToken[1] = sAud;
        destToken[2] = sMyr;
        zetaUniversalTab.setTabAddress(ethereumZrc20, tabKeys, destToken);
        destToken[0] = sUsd;
        destToken[1] = sAud;
        destToken[2] = sMyr;
        zetaUniversalTab.setTabAddress(zetaToken, tabKeys, destToken);

        // TODO mainnet only
        // tabFactory.transferOwnership(governanceController);

        vm.stopPrank();
    }

    function test_permission() public {
        ZUniTab ut = new ZUniTab();
        bytes memory initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(0), address(1), address(1), address(1), address(1), address(1));
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(1), address(0), address(1), address(1), address(1), address(1));
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        new ERC1967Proxy(
            address(ut), 
            initData
        );
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(1), address(1), address(0), address(1), address(1), address(1));
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        new ERC1967Proxy(
            address(ut), 
            initData
        );
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(1), address(1), address(1), address(0), address(1), address(1));
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        new ERC1967Proxy(
            address(ut), 
            initData
        );
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(1), address(1), address(1), address(1), address(0), address(1));
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        new ERC1967Proxy(
            address(ut), 
            initData
        );
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(1), address(1), address(1), address(1), address(1), address(0));
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        new ERC1967Proxy(
            address(ut), 
            initData
        );

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        zetaUniversalTab.initialize(address(1), address(1), address(1), address(1), address(1), address(1));

        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.DEFAULT_ADMIN_ROLE(), governanceController), true);
        
        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.DEPLOYER_ROLE(), governanceController), true);
        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.DEPLOYER_ROLE(), emergencyGov), true);
        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.DEPLOYER_ROLE(), deployer), true);

        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.PAUSER_ROLE(), governanceController), true);
        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.PAUSER_ROLE(), emergencyGov), true);
        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.PAUSER_ROLE(), deployer), true);

        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.UPGRADER_ROLE(), upgrader), true);

        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.GATEWAY_ROLE(), gatewayAddress), true);

        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.DEPLOYER_ROLE(), address(1)), false);
        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.PAUSER_ROLE(), address(2)), false);
        assertEq(zetaUniversalTab.hasRole(zetaUniversalTab.GATEWAY_ROLE(), address(3)), false);

        assertEq(TabERC20(sUsd).hasRole(TabERC20(sUsd).MINTER_ROLE(), address(zetaUniversalTab)), true);
        assertEq(TabERC20(sUsd).hasRole(TabERC20(sUsd).MINTER_ROLE(), address(tabFactory)), false);
        assertEq(TabERC20(sUsd).hasRole(TabERC20(sUsd).MINTER_ROLE(), address(4)), false);
        assertEq(TabERC20(sUsd).hasRole(TabERC20(sUsd).MINTER_ROLE(), address(5)), false);

        vm.expectRevert();
        zetaUniversalTab.beginDefaultAdminTransfer(address(999));

        vm.startPrank(governanceController);
        zetaUniversalTab.beginDefaultAdminTransfer(address(999));
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(address(999));
        zetaUniversalTab.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(zetaUniversalTab.defaultAdmin() , address(999));
    }

    function test_upgrade() public {
        vm.startPrank(upgrader);
        zetaUniversalTab.upgradeToAndCall(
            address(new ZUniTab_newImpl()),
            abi.encodeWithSignature("upgraded(string)", "upgraded_v2")
        );

        ZUniTab_newImpl upgraded_v2 = ZUniTab_newImpl(payable(address(zetaUniversalTab)));
        assertEq(keccak256(bytes(upgraded_v2.version())), keccak256("upgraded_v2"));
        assertEq(upgraded_v2.newFunction(), 1e18);

        vm.expectRevert(); // unauthorized
        upgraded_v2.upgraded("test");
        vm.stopPrank();

        assertEq(upgraded_v2.gasLimitAmounts(baseZrc20), 120000);
        assertEq(upgraded_v2.gasLimitAmounts(arbitrumZrc20), 120000);
        assertEq(upgraded_v2.uniswapRouter(), uniswapV2Router);
        assertEq(address(GatewayZEVM(upgraded_v2.gateway())), gatewayAddress);
        assertEq(upgraded_v2.connected(baseZrc20), universalTabAddress);
        assertEq(upgraded_v2.connected(arbitrumZrc20), universalTabAddress);
        assertEq(upgraded_v2.connected(ethereumZrc20), universalTabAddress);
        assertEq(upgraded_v2.tabAddresses(zetaToken, TabERC20(sUsd).tabKey()), sUsd);
    }

    function test_pause_unpause() public {
        vm.deal(deployer, 1 ether);
        vm.expectRevert();
        zetaUniversalTab.pause();
        
        vm.startPrank(deployer);
        zetaUniversalTab.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        zetaUniversalTab.transferCrossChain(sUsd, baseZrc20, address(0), 0, address(123), 100000);

        zetaUniversalTab.unpause();
        
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        IZUniTab(zetaUniversalTab).transferCrossChain{value: 0.001 ether}(sUsd, zetaToken, address(0), 0, address(0), 100000);

        vm.stopPrank();
    }

    function test_setConnected() public {
        address[] memory zrc20 = new address[](1);
        address[] memory universalTab = new address[](1);
        vm.expectRevert(); // unauthorized
        zetaUniversalTab.setConnected(zrc20, universalTab);
        vm.startPrank(deployer);

        universalTab = new address[](2);
        vm.expectRevert(IZUniTab.InvalidLength.selector);
        zetaUniversalTab.setConnected(zrc20, universalTab);

        universalTab = new address[](1);
        zrc20[0] = address(0);
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        zetaUniversalTab.setConnected(zrc20, universalTab);

        zrc20[0] = address(1);
        universalTab[0] = address(0);
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        zetaUniversalTab.setConnected(zrc20, universalTab);

        universalTab[0] = address(2);
        vm.expectEmit();
        emit IZUniTab.SetConnected(address(1), address(2));
        zetaUniversalTab.setConnected(zrc20, universalTab);
        assertEq(zetaUniversalTab.connected(address(1)), address(2));
        assertEq(zetaUniversalTab.connected(address(2)), address(0));

        vm.stopPrank();
    }

    function test_setGasLimit(uint256 _gasLimit) public {
        vm.assume(_gasLimit > 0);
        require(_gasLimit > 0);
        address[] memory destination = new address[](1);
        uint256[] memory gasLimit = new uint256[](1);
        vm.expectRevert(); // unauthorized
        zetaUniversalTab.setGasLimit(destination, gasLimit);
        vm.startPrank(deployer);

        destination = new address[](2);
        vm.expectRevert(IZUniTab.InvalidLength.selector);
        zetaUniversalTab.setGasLimit(destination, gasLimit);

        destination = new address[](1);
        destination[0] = address(0);
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        zetaUniversalTab.setGasLimit(destination, gasLimit);

        destination[0] = address(1);
        gasLimit[0] = 0;
        vm.expectRevert(IZUniTab.InvalidGasLimit.selector);
        zetaUniversalTab.setGasLimit(destination, gasLimit);

        gasLimit[0] = _gasLimit;
        assertEq(zetaUniversalTab.gasLimitAmounts(address(1)), 0);
        vm.expectEmit();
        emit IZUniTab.UpdatedGasLimit(address(1), gasLimit[0]);
        zetaUniversalTab.setGasLimit(destination, gasLimit);
        assertEq(zetaUniversalTab.gasLimitAmounts(address(1)), gasLimit[0]);

        assertEq(zetaUniversalTab.gasLimitAmounts(baseZrc20), 120000);
        destination[0] = baseZrc20;
        zetaUniversalTab.setGasLimit(destination, gasLimit);
        assertEq(zetaUniversalTab.gasLimitAmounts(baseZrc20), gasLimit[0]);

        vm.stopPrank();
    }

    function test_setTabAddress() public {
        address zrc20GasToken = address(1);
        bytes32[] memory tabKeys = new bytes32[](1);
        address[] memory destToken = new address[](1);
        vm.expectRevert(); // unauthorized
        zetaUniversalTab.setTabAddress(zrc20GasToken, tabKeys, destToken);
        vm.startPrank(deployer);

        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        zetaUniversalTab.setTabAddress(address(0), tabKeys, destToken);

        zrc20GasToken = baseZrc20;
        tabKeys = new bytes32[](2);
        vm.expectRevert(IZUniTab.InvalidLength.selector);
        zetaUniversalTab.setTabAddress(zrc20GasToken, tabKeys, destToken);

        tabKeys = new bytes32[](1);
        tabKeys[0] = bytes32("");
        destToken[0] = address(123);
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        zetaUniversalTab.setTabAddress(zrc20GasToken, tabKeys, destToken);
        
        tabKeys[0] = TabERC20(sUsd).tabKey();
        destToken[0] = address(0);
        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        zetaUniversalTab.setTabAddress(zrc20GasToken, tabKeys, destToken);

        destToken[0] = address(123);
        assertEq(zetaUniversalTab.tabAddresses(baseZrc20, tabKeys[0]), sUsd);
        vm.expectEmit();
        emit IZUniTab.UpdatedTabAddress(baseZrc20, 1);
        zetaUniversalTab.setTabAddress(zrc20GasToken, tabKeys, destToken);

        assertEq(TabERC20(sUsd).tabKey(), keccak256(abi.encodePacked(bytes3(abi.encodePacked("USD")))));
        assertEq(TabERC20(sAud).tabKey(), keccak256(abi.encodePacked(bytes3(abi.encodePacked("AUD")))));
        assertEq(TabERC20(sMyr).tabKey(), keccak256(abi.encodePacked(bytes3(abi.encodePacked("MYR")))));

        tabKeys = new bytes32[](5); 
        destToken = new address[](5);
        tabKeys[0] = keccak256(abi.encodePacked(bytes3(abi.encodePacked("XPF"))));
        destToken[0] = address(101);
        tabKeys[1] = keccak256(abi.encodePacked(bytes3(abi.encodePacked("YER"))));
        destToken[1] = address(102);
        tabKeys[2] = keccak256(abi.encodePacked(bytes3(abi.encodePacked("ZAR"))));
        destToken[2] = address(103);
        tabKeys[3] = keccak256(abi.encodePacked(bytes3(abi.encodePacked("ZMW"))));
        destToken[3] = address(104);
        tabKeys[4] = keccak256(abi.encodePacked(bytes3(abi.encodePacked("ZWL"))));
        destToken[4] = address(105);
        zetaUniversalTab.setTabAddress(address(200), tabKeys, destToken);
        zetaUniversalTab.setTabAddress(address(201), tabKeys, destToken);
        assertEq(zetaUniversalTab.tabAddresses(address(200), keccak256(abi.encodePacked(bytes3(abi.encodePacked("XPF"))))), address(101));
        assertEq(zetaUniversalTab.tabAddresses(address(200), keccak256(abi.encodePacked(bytes3(abi.encodePacked("ZWL"))))), address(105));
        assertEq(zetaUniversalTab.tabAddresses(address(201), keccak256(abi.encodePacked(bytes3(abi.encodePacked("ZAR"))))), address(103));
        assertEq(zetaUniversalTab.tabAddresses(address(201), keccak256(abi.encodePacked(bytes3(abi.encodePacked("ZMW"))))), address(104));

        tabKeys = new bytes32[](2); 
        destToken = new address[](2);
        tabKeys[0] = keccak256(abi.encodePacked(bytes3(abi.encodePacked("AAA"))));
        destToken[0] = address(106);
        tabKeys[1] = keccak256(abi.encodePacked(bytes3(abi.encodePacked("BBB"))));
        destToken[1] = address(107);
        zetaUniversalTab.setTabAddress(address(200), tabKeys, destToken);
        zetaUniversalTab.setTabAddress(address(201), tabKeys, destToken);
        assertEq(zetaUniversalTab.tabAddresses(address(200), keccak256(abi.encodePacked(bytes3(abi.encodePacked("XPF"))))), address(101));
        assertEq(zetaUniversalTab.tabAddresses(address(200), keccak256(abi.encodePacked(bytes3(abi.encodePacked("ZWL"))))), address(105));
        assertEq(zetaUniversalTab.tabAddresses(address(201), keccak256(abi.encodePacked(bytes3(abi.encodePacked("ZAR"))))), address(103));
        assertEq(zetaUniversalTab.tabAddresses(address(201), keccak256(abi.encodePacked(bytes3(abi.encodePacked("ZMW"))))), address(104));
        assertEq(zetaUniversalTab.tabAddresses(address(200), keccak256(abi.encodePacked(bytes3(abi.encodePacked("AAA"))))), address(106));
        assertEq(zetaUniversalTab.tabAddresses(address(200), keccak256(abi.encodePacked(bytes3(abi.encodePacked("BBB"))))), address(107));
        assertEq(zetaUniversalTab.tabAddresses(address(201), keccak256(abi.encodePacked(bytes3(abi.encodePacked("AAA"))))), address(106));
        assertEq(zetaUniversalTab.tabAddresses(address(201), keccak256(abi.encodePacked(bytes3(abi.encodePacked("BBB"))))), address(107));

        vm.stopPrank();
    }

    function test_setGateway() public {
        vm.expectRevert(); // unauthorized
        zetaUniversalTab.setGateway(address(0));
        vm.startPrank(deployer);

        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        zetaUniversalTab.setGateway(address(0));

        vm.expectEmit();
        emit IZUniTab.SetGateway(gatewayAddress, address(123));
        zetaUniversalTab.setGateway(address(123));
        assertEq(address(GatewayZEVM(zetaUniversalTab.gateway())), address(123));

        vm.stopPrank();
    }

    function test_setUniswapRouter() public {
        vm.expectRevert(); // unauthorized
        zetaUniversalTab.setUniswapRouter(address(0));
        vm.startPrank(deployer);

        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        zetaUniversalTab.setUniswapRouter(address(0));

        vm.expectEmit();
        emit IZUniTab.SetUniswapRouter(uniswapV2Router, address(123));
        zetaUniversalTab.setUniswapRouter(address(123));
        assertEq(zetaUniversalTab.uniswapRouter(), address(123));

        vm.stopPrank();
    }

    function test_transferCrossChain(uint256 _amt) public {
        vm.assume(_amt > 0);
        require(_amt > 0);
        vm.deal(deployer, 3 ether); // ZETA gas
        uint256 initEthBalance = deployer.balance;

        vm.expectRevert(IZUniTab.ZeroMsgValue.selector);
        zetaUniversalTab.transferCrossChain(sUsd, zetaToken, address(0), 0, address(123), 100000);

        vm.expectRevert(IZUniTab.InvalidAddress.selector);
        IZUniTab(address(zetaUniversalTab)).transferCrossChain{value: 1 ether}(sUsd, zetaToken, address(0), 0, address(0), 100000);

        vm.expectRevert(IZUniTab.InvalidGasLimit.selector);
        IZUniTab(address(zetaUniversalTab)).transferCrossChain{value: 1 ether}(sUsd, address(999), address(0), 0, deployer, 100000);

        vm.startPrank(address(zetaUniversalTab));
        TabERC20(sUsd).mint(deployer, _amt);
        TabERC20(sAud).mint(deployer, _amt);
        assertEq(TabERC20(sUsd).balanceOf(deployer), _amt);
        assertEq(TabERC20(sAud).balanceOf(deployer), _amt);

        vm.startPrank(deployer);
        TabERC20(sUsd).approve(address(zetaUniversalTab), _amt);
        TabERC20(sAud).approve(address(zetaUniversalTab), _amt);

        // Invalid zrc20 gas address
        address[] memory destinations = new address[](1);
        destinations[0] = address(100);
        uint256[] memory gasLimit = new uint256[](1);
        gasLimit[0] = 100000;
        zetaUniversalTab.setGasLimit(destinations, gasLimit);
        // vm.expectRevert(IZUniTab.InvalidAddress.selector);
        vm.expectRevert(); // withdrawGasFeeWithGasLimit will fail due to invalid zrc20 gas address set (address(100))
        IZUniTab(address(zetaUniversalTab)).transferCrossChain{value: 1 ether}(sUsd, address(100), address(0), 0, address(999), 100000);

        if (gatewayAddress.code.length == 0)
            return; // skip if gateway not deployed

        vm.expectEmit();
        emit IZUniTab.TokenTransfer(
            sUsd, 
            baseZrc20, 
            deployer, 
            _amt
        );
        IZUniTab(zetaUniversalTab).transferCrossChain{value: 1 ether}(
            sUsd, 
            baseZrc20, 
            address(0), 
            0, 
            deployer,
            _amt
        );
        assertEq(TabERC20(sUsd).balanceOf(deployer), 0);

        vm.expectEmit();
        emit IZUniTab.TokenTransfer(
            sAud, 
            baseZrc20,
            deployer,
            _amt
        );
        IZUniTab(zetaUniversalTab).transferCrossChain{value: 1 ether}(
            sAud, 
            baseZrc20,
            address(0), 
            0, 
            deployer, 
            _amt
        );
        assertEq(TabERC20(sAud).balanceOf(deployer), 0);
        assertEq(deployer.balance, initEthBalance - 2 ether);

        vm.stopPrank();
    }

    function test_onCall(uint256 _amt) public {
        vm.assume(_amt > 0);
        require(_amt > 0);
        uint256 transferGasAmt = 1 ether;
        bytes32 tabKey = TabERC20(sUsd).tabKey();
        // assume 'deployer' sent from Base to Zeta chain
        MessageContext memory context = MessageContext({
            sender: abi.encode(universalTabAddress),
            senderEVM: universalTabAddress,
            chainID: sourceChainId
        });
        bytes memory message = abi.encode(
            sUsd,                       // tabAddress
            tabKey,                     // tabKey
            zetaToken,                  // destination
            address(123),               // receiver
            _amt,                       // tokenAmount  
            deployer                    // sender
        );

        vm.expectRevert(); // unauthorized: only Gateway can call
        zetaUniversalTab.onCall(context, zetaToken, transferGasAmt, message);

        if (gatewayAddress.code.length == 0)
            return; // skip if gateway not deployed
        vm.startPrank(PROTOCOL_ADDRESS);
        // expected sender in authorizedSender mapping
        context = MessageContext({
            sender: abi.encode(address(999)),
            senderEVM: address(999),
            chainID: sourceChainId
        });
        vm.expectRevert(IZUniTab.Unauthorized.selector);
        gateway.depositAndCall(context, baseZrc20, transferGasAmt, address(zetaUniversalTab), message);

        context = MessageContext({
            sender: abi.encode(universalTabAddress),
            senderEVM: universalTabAddress,
            chainID: sourceChainId
        });
        // destination must be connected
        message = abi.encode(
            sUsd,                       // tabAddress
            tabKey,                     // tabKey
            address(999),               // destination
            address(123),               // receiver
            _amt,                       // tokenAmount  
            deployer,                   // sender
            address(0),                 // callToAddress
            "",                         // callData
            false                       // performERC20Approve
        );
        vm.expectRevert(IZUniTab.UnsupportedDestination.selector);
        gateway.depositAndCall(context, baseZrc20, transferGasAmt, address(zetaUniversalTab), message);

        // Base to Zeta transfer
        message = abi.encode(
            sUsd,                       // tabAddress
            tabKey,                     // tabKey
            zetaToken,                  // destination
            address(123),               // receiver
            _amt,                       // tokenAmount  
            deployer,                   // sender
            address(0),                 // callToAddress
            "",                         // callData
            false                       // performERC20Approve
        );
        uint256 initBal = address(123).balance;
        vm.expectEmit();
        emit IZUniTab.TokenMinted(address(123), sUsd, _amt);
        gateway.depositAndCall(context, baseZrc20, transferGasAmt, address(zetaUniversalTab), message);
        assertEq(TabERC20(sUsd).balanceOf(address(123)), _amt);
        assertEq(address(123).balance > initBal, true);

        // Base-Zeta-Arbitrum transfer
        message = abi.encode(
            sUsd,                       // tabAddress
            tabKey,                     // tabKey
            arbitrumZrc20,              // destination
            address(456),               // receiver
            _amt,                       // tokenAmount  
            deployer,                   // sender
            address(0),                 // callToAddress
            "",                         // callData
            false                       // performERC20Approve
        );
        initBal = address(456).balance;
        vm.expectEmit();
        emit IZUniTab.TokenTransferToDestination(arbitrumZrc20, deployer, address(456), sUsd, _amt);
        gateway.depositAndCall(context, baseZrc20, transferGasAmt, address(zetaUniversalTab), message);
        // zeta side receiver should not receive anything
        assertEq(TabERC20(sUsd).balanceOf(address(456)), 0);
        assertEq(address(456).balance, initBal);
        vm.stopPrank();
    }

    function test_onRevert(uint256 _amt) public {
        vm.assume(_amt > 0);
        require(_amt > 0);
        uint256 transferAmount = 1.4764 ether;
        RevertContext memory revertContext = RevertContext({
            sender: address(zetaUniversalTab),  // ZetaUniversalTab address
            asset: arbitrumZrc20,               // asset
            amount: transferAmount,             // gasAmount
            revertMessage: abi.encode(sUsd, address(123), _amt, deployer) // tab, receiver, amount, sender
        });
        vm.expectRevert(); // unauthorized
        zetaUniversalTab.onRevert(revertContext);

        if (arbitrumZrc20.code.length == 0 || gatewayAddress.code.length == 0)
            return;

        uint256 initDeployerBalance = deployer.balance; // sender to receive refund
        uint256 initZrcBalance = ZRC20(arbitrumZrc20).balanceOf(deployer);

        vm.startPrank(PROTOCOL_ADDRESS);
        // revert base to arbitrum transfer failure, arbitrum gas is refunded to sender in zeta chain
        vm.expectEmit();
        emit IZUniTab.TokenTransferReverted(
            sUsd,
            deployer,
            arbitrumZrc20,
            _amt,
            transferAmount
        );
        gateway.depositAndRevert(arbitrumZrc20, transferAmount, address(zetaUniversalTab), revertContext);
        assertEq(TabERC20(sUsd).balanceOf(deployer), _amt); // refunded to sender
        assertEq(ZRC20(arbitrumZrc20).balanceOf(deployer), initZrcBalance + transferAmount); // refunded arbitrum gas
        assertEq(deployer.balance, initDeployerBalance); // zeta balance remained

        vm.stopPrank();
    }

    function test_onAbort(uint256 _amt) public {
        vm.assume(_amt > 0);
        require(_amt > 0);
        uint256 transferAmount = _amt;
        AbortContext memory abortContext = AbortContext({
            sender: abi.encodePacked(address(444)),
            asset: address(0),
            amount: _amt,
            outgoing: true,
            chainID: block.chainid,
            revertMessage: abi.encode(sUsd, address(890), _amt, address(567)) // Tab address, receiver, amount, sender
        });

        if (gatewayAddress.code.length == 0)
            return; // skip if gateway not deployed

        vm.expectRevert();
        gateway.executeAbort(address(zetaUniversalTab), abortContext);

        vm.startPrank(PROTOCOL_ADDRESS);
        vm.expectRevert(IZUniTab.Unauthorized.selector);
        gateway.executeAbort(address(zetaUniversalTab), abortContext);

        // ZetaChain outbound, revert failed, hence sender is ZetaUniversalTab
        abortContext.sender = abi.encodePacked(address(zetaUniversalTab)); 
        emit IZUniTab.TokenTransferReverted(
            sUsd,
            address(567),       // sender
            address(0),
            _amt,
            transferAmount
        );
        gateway.executeAbort(address(zetaUniversalTab), abortContext);
        assertEq(TabERC20(sUsd).balanceOf(address(567)), _amt);

        abortContext.asset = baseZrc20;
        abortContext.amount = 123.45678 ether;
        abortContext.revertMessage = abi.encode(sAud, address(890), 1 ether, address(567));
        gateway.deposit(baseZrc20, abortContext.amount, address(zetaUniversalTab));
        assertEq(ZRC20(baseZrc20).balanceOf(address(zetaUniversalTab)), abortContext.amount);
        gateway.executeAbort(address(zetaUniversalTab), abortContext);

        assertEq(ZRC20(baseZrc20).balanceOf(address(567)), abortContext.amount);
        assertEq(TabERC20(sAud).balanceOf(address(567)), 1 ether);
        assertEq(ZRC20(baseZrc20).balanceOf(address(zetaUniversalTab)), 0);
    }

}