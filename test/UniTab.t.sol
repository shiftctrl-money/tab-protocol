// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ICREATE3Factory} from "../contracts/interfaces/ICREATE3Factory.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {IUniTab} from "../contracts/interfaces/IUniTab.sol";
import {UniTab} from "../contracts/token/UniTab.sol";
import {Config} from "../contracts/core/Config.sol";
import {TabRegistry} from "../contracts/core/TabRegistry.sol";
import {VaultKeeper} from "../contracts/core/VaultKeeper.sol";
import {UniTab_newImpl} from "./upgrade/UniTab_newImpl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {RevertContext} from "@zetachain/protocol-contracts/contracts/Revert.sol";
import {MessageContext} from "@zetachain/protocol-contracts/contracts/evm/interfaces/IGatewayEVM.sol";
import {GatewayEVM} from "@zetachain/protocol-contracts/contracts/evm/GatewayEVM.sol";

// Need Localnet to run test, command:
// npx zetachain@latest localnet start
// forge test -vvv --match-path test/UniTab.t.sol --rpc-url http://127.0.0.1:8545
contract UniTabTest is Test {
    address public deployer;
    address public create3Factory;

    address governanceController;
    address emergencyGov;
    address upgrader;
    address gatewayAddress; // local gateway
    address gatewayAdmin;
    address zetaToken; // ZetaChain zetaToken
    address baseZrc20;
    address arbitrumZrc20;
    address ethereumZrc20;
    address avalancheZrc20;
    GatewayEVM gateway;

    TabFactory tabFactory;
    TabERC20 tabERC20;
    UniTab universalTab;

    address sUsd;
    address sAud;
    address sMyr;
    address newUsd;

    error EmptyCharacter();

    constructor() {
        deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;

        if (block.chainid == 84532) { // base testnet
            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
            governanceController = address(100);
            emergencyGov = address(101);
            gatewayAddress = 0x0c487a766110c85d301D96E33579C5B317Fa4995;
            gatewayAdmin = 0x55122f7590164Ac222504436943FAB17B62F5d7d;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
            gateway = GatewayEVM(payable(gatewayAddress));
        } else if (block.chainid == 8453) { // base mainnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
            governanceController = address(100);
            emergencyGov = address(101);
            gatewayAddress = 0x48B9AACC350b20147001f88821d31731Ba4C30ed;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 11155111) { // ethereum testnet
            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
            governanceController = address(100);
            emergencyGov = address(101);
            gatewayAddress = 0x0c487a766110c85d301D96E33579C5B317Fa4995;
            gatewayAdmin = 0x55122f7590164Ac222504436943FAB17B62F5d7d;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
            gateway = GatewayEVM(payable(gatewayAddress));
        } else if (block.chainid == 1) { // ethereum mainnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
            governanceController = address(100);
            emergencyGov = address(101);
            gatewayAddress = 0x48B9AACC350b20147001f88821d31731Ba4C30ed;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 421614) { // arbitrum testnet
            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
            governanceController = address(100);
            emergencyGov = address(101);
            gatewayAddress = 0x0dA86Dc3F9B71F84a0E97B0e2291e50B7a5df10f;
            gatewayAdmin = 0x55122f7590164Ac222504436943FAB17B62F5d7d;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
            gateway = GatewayEVM(payable(gatewayAddress));
        } else if (block.chainid == 42161) { // arbitrum mainnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
            governanceController = address(100);
            emergencyGov = address(101);
            gatewayAddress = 0x1C53e188Bc2E471f9D4A4762CFf843d32C2C8549;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 43113) { // avalanche Fuji testnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
            governanceController = address(100);
            emergencyGov = address(101);
            gatewayAddress = 0x0dA86Dc3F9B71F84a0E97B0e2291e50B7a5df10f;
            gatewayAdmin = 0xb741531a1A8984d5188d1058f47EB7cBd57F4655;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
            gateway = GatewayEVM(payable(gatewayAddress));
        } else if (block.chainid == 43114) { // avalanche C-chain mainnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
            governanceController = address(100);
            emergencyGov = address(101);
            gatewayAddress = 0x1C53e188Bc2E471f9D4A4762CFf843d32C2C8549;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 31337) { // localnet
            deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
            create3Factory = address(0);
            governanceController = address(100);
            emergencyGov = address(101);
            gatewayAddress = 0x59b670e9fA9D0A427751Af201D676719a970857b;
            zetaToken = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        }

        if (block.chainid == 84532 || 
            block.chainid == 11155111 || 
            block.chainid == 421614 ||
            block.chainid == 43113
        ) { // testnet
            baseZrc20 = 0x236b0DE675cC8F46AE186897fCCeFe3370C9eDeD;
            arbitrumZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            ethereumZrc20 = 0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0;
            avalancheZrc20 = 0xEe9CC614D03e7Dbe994b514079f4914a605B4719;
            vm.startPrank(gatewayAdmin);
            gateway.updateTSSAddress(address(666));
            vm.stopPrank();
        } else if (block.chainid == 31337) { // localnet, anvil
            baseZrc20 = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;     // ZRC-20 ETH.ETH on 11155112
            arbitrumZrc20 = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b; // ZRC-20 BNB.BNB on 98
            ethereumZrc20 = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
            avalancheZrc20 = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b;
        } else { // mainnet
            baseZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            arbitrumZrc20 = 0xA614Aebf7924A3Eb4D066aDCA5595E4980407f1d;
            ethereumZrc20 = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891;
            avalancheZrc20 = 0xE8d7796535F1cd63F0fe8D631E68eACe6839869B;
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
        return tabFactory.createTab(governanceController, address(universalTab), _name, _symbol, _tab);
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

        tabERC20 = new TabERC20(); // implementation contract
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

        address universalTabImplementation = address(new UniTab());
        console.log("universalTabImplementation: ", universalTabImplementation);
        bytes memory initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            governanceController, emergencyGov, upgrader, deployer, gatewayAddress, zetaToken);
        if (create3Factory.code.length == 0) {
            universalTab = UniTab(payable(new ERC1967Proxy(universalTabImplementation, initData)));
            universalTab.updateDebugSuccess(true, true, true);
        } else {
            address payable universalTabAddr = payable(address(TabFactory(ICREATE3Factory(create3Factory).deploy(
                keccak256(abi.encodePacked("ShiftCTRL_v1.01.000: UniTab")), 
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(universalTabImplementation, initData))
            ))));
            universalTab = UniTab(universalTabAddr);
        }
        console.log("uniTab: ", address(universalTab));

        vm.startPrank(governanceController);
        tabFactory.updateCreator(governanceController); // For mainnet, update to correct TabRegistry address

        sUsd = deployTab(bytes3(abi.encodePacked("USD"))); // sUSD
        console.log("sUsd: ", sUsd);
        sAud = deployTab(bytes3(abi.encodePacked("AUD"))); // sAUD
        console.log("sAud: ", sAud);
        sMyr = deployTab(bytes3(abi.encodePacked("MYR"))); // sMYR
        console.log("sMyr: ", sMyr);
        newUsd = deployTab(bytes3(abi.encodePacked("NEW")));

        // Set onRevert gas limit
        universalTab.setRevertGasLimit(120000);

        address[] memory tabs = new address[](3);
        tabs[0] = sUsd;
        tabs[1] = sAud; 
        tabs[2] = sMyr;
        bool[] memory isAuthorized = new bool[](3);
        isAuthorized[0] = true;
        isAuthorized[1] = true;
        isAuthorized[2] = true;
        universalTab.setAuthorizedTab(tabs, isAuthorized);

        universalTab.setUniversal(deployer);
        // universalTab.setGateway(gatewayAddress);
        // universalTab.setZetaToken(zetaToken);

        vm.stopPrank();
    }

    function test_permission() public {
        UniTab ut = new UniTab();
        bytes memory initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(0), address(1), address(1), address(1), address(1), address(1));
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(1), address(0), address(1), address(1), address(1), address(1));
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        new ERC1967Proxy(
            address(ut), 
            initData
        );
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(1), address(1), address(0), address(1), address(1), address(1));
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        new ERC1967Proxy(
            address(ut), 
            initData
        );
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(1), address(1), address(1), address(0), address(1), address(1));
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        new ERC1967Proxy(
            address(ut), 
            initData
        );
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(1), address(1), address(1), address(1), address(0), address(1));
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        new ERC1967Proxy(
            address(ut), 
            initData
        );
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(1), address(1), address(1), address(1), address(1), address(0));
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        new ERC1967Proxy(
            address(ut), 
            initData
        );

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        universalTab.initialize(address(1), address(1), address(1), address(1), address(1), address(1));

        assertEq(universalTab.hasRole(universalTab.DEFAULT_ADMIN_ROLE(), governanceController), true);
        
        assertEq(universalTab.hasRole(universalTab.DEPLOYER_ROLE(), governanceController), true);
        assertEq(universalTab.hasRole(universalTab.DEPLOYER_ROLE(), emergencyGov), true);
        assertEq(universalTab.hasRole(universalTab.DEPLOYER_ROLE(), deployer), true);

        assertEq(universalTab.hasRole(universalTab.PAUSER_ROLE(), governanceController), true);
        assertEq(universalTab.hasRole(universalTab.PAUSER_ROLE(), emergencyGov), true);
        assertEq(universalTab.hasRole(universalTab.PAUSER_ROLE(), deployer), true);

        assertEq(universalTab.hasRole(universalTab.UPGRADER_ROLE(), upgrader), true);

        assertEq(universalTab.hasRole(universalTab.GATEWAY_ROLE(), gatewayAddress), true);

        assertEq(universalTab.hasRole(universalTab.DEPLOYER_ROLE(), address(1)), false);
        assertEq(universalTab.hasRole(universalTab.PAUSER_ROLE(), address(2)), false);
        assertEq(universalTab.hasRole(universalTab.GATEWAY_ROLE(), address(3)), false);

        assertEq(TabERC20(sUsd).hasRole(TabERC20(sUsd).MINTER_ROLE(), address(universalTab)), true);
        assertEq(TabERC20(sUsd).hasRole(TabERC20(sUsd).MINTER_ROLE(), address(tabFactory)), false);
        assertEq(TabERC20(sUsd).hasRole(TabERC20(sUsd).MINTER_ROLE(), address(4)), false);
        assertEq(TabERC20(sUsd).hasRole(TabERC20(sUsd).MINTER_ROLE(), address(5)), false);

        vm.expectRevert();
        universalTab.beginDefaultAdminTransfer(address(999));

        vm.startPrank(governanceController);
        universalTab.beginDefaultAdminTransfer(address(999));
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(address(999));
        universalTab.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(universalTab.defaultAdmin() , address(999));
    }

    function test_upgrade() public {
        vm.startPrank(upgrader);
        universalTab.upgradeToAndCall(
            address(new UniTab_newImpl()),
            abi.encodeWithSignature("upgraded(string)", "upgraded_v2")
        );

        UniTab_newImpl upgraded_v2 = UniTab_newImpl(payable(address(universalTab)));
        assertEq(keccak256(bytes(upgraded_v2.version())), keccak256("upgraded_v2"));
        assertEq(upgraded_v2.newFunction(), 1e18);

        vm.expectRevert(); // unauthorized
        upgraded_v2.upgraded("test");
        vm.stopPrank();

        assertEq(upgraded_v2.universal(), deployer);
        assertEq(upgraded_v2.zetaToken(), zetaToken);

        assertEq(upgraded_v2.authorizedTabs(sUsd), true);
        assertEq(upgraded_v2.authorizedTabs(sAud), true);
        assertEq(upgraded_v2.authorizedTabs(sMyr), true);
        assertEq(upgraded_v2.authorizedTabs(address(123)), false);
    }

    function test_pause_unpause() public {
        vm.expectRevert();
        universalTab.pause();
        
        vm.startPrank(deployer);
        universalTab.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        universalTab.burnAndMintNewTab(sUsd, 1e18);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        universalTab.transferCrossChain(sUsd, zetaToken, address(123), 100000);

        universalTab.unpause();
        vm.expectRevert(IUniTab.UnauthorizedTab.selector);
        universalTab.burnAndMintNewTab(sUsd, 1e18);

        vm.expectRevert(IUniTab.InvalidAddress.selector);
        universalTab.transferCrossChain(sUsd, zetaToken, address(0), 100000);

        vm.stopPrank();
    }

    function test_setRevertGasLimit(uint256 _gasLimit) public {
        vm.assume(_gasLimit > 0);
        require(_gasLimit > 0);
        
        vm.expectRevert(); // unauthorized
        universalTab.setRevertGasLimit(_gasLimit);
        
        vm.startPrank(deployer);
        vm.expectRevert(IUniTab.InvalidGasLimit.selector);
        universalTab.setRevertGasLimit(0);

        assertEq(universalTab.revertGasLimit(), 120000);
        vm.expectEmit();
        emit IUniTab.UpdatedGasLimit(120000, _gasLimit);
        universalTab.setRevertGasLimit(_gasLimit);
        assertEq(universalTab.revertGasLimit(), _gasLimit);

        vm.stopPrank();
    }

    function test_setAuthorizedTab() public {
        address[] memory tabAddress = new address[](1);
        tabAddress[0] = sUsd;
        bool[] memory isAuthorized = new bool[](1);
        isAuthorized[0] = true;
        bool[] memory invalidIsAuthorized = new bool[](2);
        invalidIsAuthorized[0] = true;
        invalidIsAuthorized[1] = true;

        vm.expectRevert();
        universalTab.setAuthorizedTab(tabAddress, isAuthorized);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTab.InvalidLength.selector);
        universalTab.setAuthorizedTab(tabAddress, invalidIsAuthorized);

        tabAddress[0] = address(0);
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        universalTab.setAuthorizedTab(tabAddress, isAuthorized);

        tabAddress[0] = address(123);
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        universalTab.setAuthorizedTab(tabAddress, isAuthorized);

        tabAddress[0] = sUsd;
        vm.expectEmit();
        emit IUniTab.AuthorizedTab(sUsd, true);
        universalTab.setAuthorizedTab(tabAddress, isAuthorized);
        assertEq(universalTab.authorizedTabs(sUsd), true);

        isAuthorized[0] = false;
        universalTab.setAuthorizedTab(tabAddress, isAuthorized);
        assertEq(universalTab.authorizedTabs(sUsd), false);
        assertEq(universalTab.authorizedTabs(address(321)), false);

        vm.stopPrank();
    }

    function test_setUniversal() public {
        vm.expectRevert();
        universalTab.setUniversal(address(1));
        assertEq(universalTab.universal(), deployer);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        universalTab.setUniversal(address(0));

        vm.expectEmit();
        emit IUniTab.UpdatedZetaUniversal(deployer, address(1));
        universalTab.setUniversal(address(1));
        assertEq(universalTab.universal(), address(1));
        vm.stopPrank();
    }

    function test_setGateway() public {
        vm.expectRevert();
        universalTab.setGateway(address(1));
        assertEq(address(universalTab.gateway()), gatewayAddress);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        universalTab.setGateway(address(0));

        vm.expectEmit();
        emit IUniTab.UpdatedGateway(gatewayAddress, address(1));
        universalTab.setGateway(address(1));
        assertEq(address(universalTab.gateway()), address(1));
        vm.stopPrank();
    }

    function test_setZetaToken() public {
        vm.expectRevert();
        universalTab.setZetaToken(address(1));
        assertEq(universalTab.zetaToken(), zetaToken);

        vm.startPrank(deployer);
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        universalTab.setZetaToken(address(0));

        vm.expectEmit();
        emit IUniTab.UpdatedZetaToken(zetaToken, address(1));
        universalTab.setZetaToken(address(1));
        assertEq(universalTab.zetaToken(), address(1));
        vm.stopPrank();
    }

    function test_setOldToNewTabAddress() public {
        vm.expectRevert();
        universalTab.setOldToNewTabAddress(sUsd, newUsd);
        vm.startPrank(deployer);
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        universalTab.setOldToNewTabAddress(address(0), newUsd);
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        universalTab.setOldToNewTabAddress(sUsd, address(0));
        vm.expectRevert(IUniTab.UnauthorizedTab.selector);
        universalTab.setOldToNewTabAddress(address(444), newUsd);

        address[] memory tabAddress = new address[](1);
        tabAddress[0] = newUsd;
        bool[] memory isAuthorized = new bool[](1);
        isAuthorized[0] = true;
        universalTab.setAuthorizedTab(tabAddress, isAuthorized);   

        vm.expectEmit();
        emit IUniTab.MappedOldToNewTab(sUsd, newUsd);
        universalTab.setOldToNewTabAddress(sUsd, newUsd);
        assertEq(universalTab.oldToNewTabAddresses(sUsd), newUsd);

        vm.stopPrank();
    }

    function test_burnAndMintNewTab(uint256 _amt) public {
        vm.assume(_amt > 0);
        require(_amt > 0);
        vm.startPrank(deployer);

        address[] memory tabAddress = new address[](1);
        tabAddress[0] = newUsd;
        bool[] memory isAuthorized = new bool[](1);
        isAuthorized[0] = true;
        universalTab.setAuthorizedTab(tabAddress, isAuthorized);   

        universalTab.setOldToNewTabAddress(sUsd, newUsd);
        
        vm.startPrank(address(universalTab));
        TabERC20(sUsd).mint(deployer, _amt);
        assertEq(TabERC20(sUsd).balanceOf(deployer), _amt);

        vm.startPrank(deployer);
        TabERC20(sUsd).approve(address(universalTab), _amt);
        
        vm.expectRevert(IUniTab.UnauthorizedTab.selector);
        universalTab.burnAndMintNewTab(address(123), _amt);

        vm.expectRevert(IUniTab.ZeroAmount.selector);
        universalTab.burnAndMintNewTab(sUsd, 0);

        vm.expectEmit();
        emit IUniTab.ConvertedOldToNewTab(sUsd, newUsd, deployer, _amt);
        universalTab.burnAndMintNewTab(sUsd, _amt);
        assertEq(TabERC20(sUsd).balanceOf(deployer), 0);
        assertEq(TabERC20(newUsd).balanceOf(deployer), _amt);
    }

    function test_transferCrossChain(uint256 _amt) public {
        vm.assume(_amt > 0);
        require(_amt > 0);
        vm.deal(deployer, 2 ether);
        uint256 initEthBalance = deployer.balance;

        vm.expectRevert(IUniTab.InvalidAddress.selector);
        universalTab.transferCrossChain(sUsd, zetaToken, address(0), 100000);

        vm.expectRevert(IUniTab.RequiredCrossChainGas.selector);
        IUniTab(universalTab).transferCrossChain{value: 0}(
            sUsd, 
            address(456), // non-zeta destination required gas 
            address(123), 
            _amt
        );

        if (gatewayAddress.code.length == 0)
            return; // skip if gateway not deployed

        vm.startPrank(address(universalTab));
        TabERC20(sUsd).mint(deployer, _amt);
        TabERC20(sAud).mint(deployer, _amt);
        assertEq(TabERC20(sUsd).balanceOf(deployer), _amt);
        assertEq(TabERC20(sAud).balanceOf(deployer), _amt);

        vm.startPrank(deployer);
        TabERC20(sUsd).approve(address(universalTab), _amt);
        TabERC20(sAud).approve(address(universalTab), _amt);

        // Source to Zeta, direct call only
        vm.expectEmit();
        emit IUniTab.TokenTransfer(
            sUsd, 
            zetaToken, 
            address(123), 
            _amt
        );
        IUniTab(universalTab).transferCrossChain{value: 0}(
            sUsd, 
            zetaToken, 
            address(123), 
            _amt
        );
        assertEq(TabERC20(sUsd).balanceOf(deployer), 0);

        // Source to Zeta, deposit extra ETH to ZETA gas
        vm.expectEmit();
        emit IUniTab.TokenTransfer(
            sAud, 
            zetaToken, 
            address(123), 
            _amt
        );
        IUniTab(universalTab).transferCrossChain{value: 1 ether}(
            sAud, 
            zetaToken, 
            address(123), 
            _amt
        );

        vm.startPrank(address(universalTab));
        TabERC20(sAud).mint(deployer, _amt);
        vm.startPrank(deployer);
        TabERC20(sAud).approve(address(universalTab), _amt);
        vm.deal(deployer, 2 ether);
        initEthBalance = deployer.balance;

        vm.expectEmit();
        emit IUniTab.TokenTransfer(
            sAud, 
            baseZrc20,
            address(123),
            _amt
        );
        IUniTab(universalTab).transferCrossChain{value: 2 ether}(
            sAud, 
            baseZrc20,
            address(123), 
            _amt
        );
        assertEq(TabERC20(sAud).balanceOf(deployer), 0);
        assertEq(deployer.balance, initEthBalance - 2 ether);

        vm.stopPrank();
    }

    function test_onCall(uint256 _amt) public {
        vm.assume(_amt > 0);
        require(_amt > 0);
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        MessageContext memory context = MessageContext({
            sender: deployer
        });
        // assume 'deployer' sent from Base to Arb chain
        bytes memory message = abi.encode(
            sUsd,           // tabAddress
            usd,
            deployer,       // receiver
            _amt,           // amount
            0,              // gasAmount
            deployer        // sender
        );

        vm.expectRevert(); // unauthorized: only Gateway can call
        universalTab.onCall(context, message);

        vm.startPrank(gatewayAddress);
        
        // expected sender to be connected ZUniTab
        context = MessageContext({
            sender: address(123)
        });
        vm.expectRevert(IUniTab.Unauthorized.selector);
        universalTab.onCall(context, message);

        context = MessageContext({
            sender: deployer // workaround for test. Expected to be ZUniTab deployed on ZetaChain
        });
        assertEq(TabERC20(sUsd).balanceOf(deployer), 0); // not yet received

        message = abi.encode(
            sUsd,           // tabAddress
            usd,
            deployer,       // receiver
            _amt,           // amount
            1.9 ether,      // gasAmount
            address(0)      // sender, INVALID
        );
        vm.expectRevert(IUniTab.InvalidAddress.selector);
        universalTab.onCall(context, message);

        message = abi.encode(
            sUsd,           // tabAddress
            usd,
            deployer,       // receiver
            _amt,           // amount
            1.9 ether,      // gasAmount
            deployer        // sender
        );
        vm.deal(gatewayAddress, 1.8 ether);
        vm.expectRevert(IUniTab.GasTokenTransferFailed.selector);
        IUniTab(universalTab).onCall{value: 1.8 ether}(context, message);
        assertEq(gatewayAddress.balance >= 1.8 ether, true);

        vm.deal(gatewayAddress, 1.9 ether);
        uint256 initEthBalance = gatewayAddress.balance;
        console.log("initEthBalance: ", initEthBalance);
        vm.expectEmit();
        emit IUniTab.TokenTransferReceived(
            sUsd, 
            deployer, 
            _amt,
            1.9 ether
        );
        IUniTab(universalTab).onCall{value: 1.9 ether}(context, message);
        assertEq(TabERC20(sUsd).balanceOf(deployer), _amt);
        assertEq(gatewayAddress.balance, initEthBalance - 1.9 ether);
        vm.startPrank(deployer);
        TabERC20(sUsd).burn(_amt); // burn to avoid potential overflow 

        if (block.chainid == 84532 || block.chainid == 421614) { // base/arbitrum testnet
            initEthBalance = 1.6661 ether;
            vm.deal(address(666), initEthBalance);
            vm.deal(address(universalTab), 1.333 ether);
            context = MessageContext({
                sender: deployer // workaround. Should be ZUniTab
            });
            message = abi.encode(
                sUsd,           // tabAddress
                address(456),   // receiver
                _amt,           // amount
                1.666 ether,    // gasAmount
                address(123)    // sender
            );
            vm.startPrank(address(666));
            vm.expectEmit();
            emit IUniTab.TokenTransferReceived(
                sUsd, 
                address(456), 
                _amt,
                1.666 ether
            );
            gateway.execute{value: 1.666 ether}(context, address(universalTab), message);
            assertEq(address(666).balance, initEthBalance - 1.666 ether);
            assertEq(address(universalTab).balance, 1.333 ether);
            assertEq(address(456).balance, 1.666 ether);
            assertEq(TabERC20(sUsd).balanceOf(address(456)), _amt);
        }
    }

    function test_onRevert(uint256 _amt) public {
        vm.assume(_amt > 0);
        require(_amt > 0);
        uint256 transferAmount = 1.4764 ether;
        RevertContext memory revertContext = RevertContext({
            sender: address(123), // ZUniTab address
            asset: address(0),    // asset
            amount: transferAmount, // gasAmount
            revertMessage: abi.encode(sUsd, address(123), _amt, deployer) // Tab address, receiver, amount, sender
        });
        vm.expectRevert(); // unauthorized
        universalTab.onRevert(revertContext);

        vm.startPrank(gatewayAddress);

        vm.expectRevert(IUniTab.Unauthorized.selector);
        universalTab.onRevert(revertContext);

        revertContext = RevertContext({
            sender: deployer, // ZUniTab address
            asset: address(0),    // asset
            amount: transferAmount, // gasAmount
            revertMessage: abi.encode(sUsd, address(123), _amt, address(777)) // Tab address, receiver, amount, sender
        });

        // vm.expectRevert(IUniTab.GasTokenRefundFailed.selector);
        // universalTab.onRevert(revertContext); // insufficient _amt 

        vm.deal(address(universalTab), transferAmount); // simulate gas token transfer to Revert address
        uint256 initBalance = address(universalTab).balance;
        uint256 initDeployerBalance = address(777).balance;
        vm.expectEmit();
        emit IUniTab.TokenTransferReverted(
            sUsd,
            address(777),
            address(0),
            _amt,
            transferAmount
        );
        universalTab.onRevert(revertContext);
        assertEq(TabERC20(sUsd).balanceOf(address(777)), _amt);
        assertEq(address(universalTab).balance, initBalance - transferAmount); // reverted gas amount
        assertEq(address(777).balance, initDeployerBalance + transferAmount); // received gas amount
        vm.startPrank(address(777));
        TabERC20(sUsd).burn(_amt);

        if (block.chainid == 84532 || block.chainid == 421614) { // base/arbitrum testnet
            transferAmount = 0.2319897 ether;
            vm.deal(address(666), transferAmount + 0.001 ether);
            vm.deal(address(universalTab), 1.333 ether);
            revertContext = RevertContext({
                sender: deployer,       // ZUniTab address
                asset: address(0),      // asset
                amount: transferAmount, // gasAmount
                revertMessage: abi.encode(sUsd, address(123), _amt, address(456)) // Tab address, receiver, amount, sender
            });

            initBalance = address(666).balance;
            initDeployerBalance = address(456).balance;
            vm.startPrank(address(666));
            vm.expectEmit();
            emit IUniTab.TokenTransferReverted(
                sUsd, 
                address(456), 
                address(0),
                _amt,
                transferAmount
            );
            gateway.executeRevert{value: transferAmount}(address(universalTab), bytes(""), revertContext);
            assertEq(address(666).balance, initBalance - transferAmount);
            assertEq(address(456).balance, initDeployerBalance + transferAmount);
            assertEq(TabERC20(sUsd).balanceOf(address(456)), _amt);
        }

        vm.stopPrank();
    }

    // Refer TabRegistry.loadTabs() function 
    function test_loadTabs() public {
        TabRegistry tabRegistry = new TabRegistry(
            governanceController,
            emergencyGov,
            address(111),
            deployer,
            address(222),
            address(333)
        );
        Config config = new Config(
            governanceController,
            emergencyGov,
            address(111),
            deployer,
            address(222),
            address(tabRegistry),
            address(333)
        );
        VaultKeeper vkImpl = new VaultKeeper();
        VaultKeeper vaultKeeper = VaultKeeper(address(new ERC1967Proxy(
            address(vkImpl), 
            abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
                governanceController, emergencyGov, deployer, address(444), address(555), address(config)
        ))));
        vm.startPrank(deployer);
        tabRegistry.setTabFactory(address(tabFactory));
        tabRegistry.setConfigAddress(address(config));
        config.setVaultKeeperAddress(address(vaultKeeper));
        assertEq(tabRegistry.activatedTabCount(), 0);

        // expect all TabFactory's tabs to be copied over into TabFactory
        tabRegistry.loadTabs();
        assertEq(tabRegistry.activatedTabCount(), tabFactory.getTabListLength());
        assertEq(tabRegistry.getTabAddress(bytes3(abi.encodePacked("USD"))), sUsd);
        assertEq(tabRegistry.getTabAddress(bytes3(abi.encodePacked("AUD"))), sAud);
        assertEq(tabRegistry.getTabAddress(bytes3(abi.encodePacked("MYR"))), sMyr);

        assertEq(keccak256(abi.encodePacked(tabRegistry.tabList(0))), keccak256(abi.encodePacked("USD")));
        assertEq(keccak256(abi.encodePacked(tabRegistry.tabList(1))), keccak256(abi.encodePacked("AUD")));
        assertEq(keccak256(abi.encodePacked(tabRegistry.tabList(2))), keccak256(abi.encodePacked("MYR")));
        vm.stopPrank();
    }

    // gas 154832 154702 base / arbitrum
    //     129832 ethereum
    function test_onCall_gas() public {
        uint256 initEthBalance = 1.6661 ether;
        vm.deal(address(666), initEthBalance);
        vm.deal(address(universalTab), 1.333 ether);
        MessageContext memory context = MessageContext({
            sender: deployer // workaround. Should be ZUniTab
        });
        bytes memory message = abi.encode(
            sUsd,           // tabAddress
            address(456),   // receiver
            1 ether,        // amount
            1.666 ether,    // gasAmount
            address(123)    // sender
        );
        if (block.chainid != 31337) {
            vm.startPrank(address(666));
            gateway.execute{value: 1.666 ether}(context, address(universalTab), message);
        }
    }

    // gas 159901 base / arbitrum
    //     134901 ethereum
    function test_onRevert_gas() public {
        uint256 _amt = 123.456 ether;
        uint256 transferAmount = 0.2319897 ether;
        RevertContext memory revertContext = RevertContext({
            sender: deployer,       // ZUniTab address
            asset: address(0),      // asset
            amount: transferAmount, // gasAmount
            revertMessage: abi.encode(sUsd, address(123), _amt, address(456)) // Tab address, receiver, amount, sender
        });
        vm.deal(address(666), 1.333 ether);
        if (block.chainid != 31337) {
            vm.startPrank(address(666));
            gateway.executeRevert{value: transferAmount}(address(universalTab), bytes(""), revertContext);
        }
    }

}