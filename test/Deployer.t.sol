// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {TransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {CTRL} from "../contracts/token/CTRL.sol";
import {CBBTC} from "../contracts/token/CBBTC.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
import {ShiftCTRLGovernor} from "../contracts/governance/ShiftCTRLGovernor.sol";
import {ShiftCTRLEmergencyGovernor} from "../contracts/governance/ShiftCTRLEmergencyGovernor.sol";
import {GovernanceAction} from "../contracts/governance/GovernanceAction.sol";
import {PriceOracle} from "../contracts/oracle/PriceOracle.sol";
import {IPriceOracle} from "../contracts/interfaces/IPriceOracle.sol";
import {IPriceOracleManager} from "../contracts/interfaces/IPriceOracleManager.sol";
import {PriceOracleManager} from "../contracts/oracle/PriceOracleManager.sol";
import {ReserveSafe} from "../contracts/reserve/ReserveSafe.sol";
import {ReserveRegistry} from "../contracts/reserve/ReserveRegistry.sol";
import {AuctionManager} from "../contracts/core/AuctionManager.sol";
import {Config} from "../contracts/core/Config.sol";
import {ProtocolVault} from "../contracts/core/ProtocolVault.sol";
import {TabRegistry} from "../contracts/core/TabRegistry.sol";
import {VaultKeeper} from "../contracts/core/VaultKeeper.sol";
import {VaultManager} from "../contracts/core/VaultManager.sol";
import {VaultUtils} from "../contracts/utils/VaultUtils.sol";
import {Signer} from "./Signer.sol";

interface CheatCodes {

    // Gets address for a given private key, (privateKey) => (address)
    function addr(uint256) external returns (address);

}

interface ICBBTC {
    function masterMinter() external returns (address);
    function configureMinter(address,uint256) external returns (bool);
}

abstract contract Deployer is Test {

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public owner;
    address public deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    // Signer signer;
    // address signerAuthorizedAddr = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // anvil first test acct
    address secureSignerAddr; // replace private key in Signer util.
    address oracleRelayerSignerAddr = 0x6cC15689B28227d97481Fac73614cD8D35ede6D2; 
    address oracleProviderPerformanceSignerAddr = 0x92b6153228B61324cAdCAab510FB38c6661b992e;
    address tabRegistryFreezerAddr = 0x6DA75E7831c14810C285e49D3219bEA63bDf5C14;
    address treasuryAddr = 0x7045CC042c0571F671236db73ba93BD1B82b2326;
    address keeperAddr = 0x930718756DeE144963697D6EB532c9a6Cf10d0F6;
    address[] public eoa_accounts;

    ProxyAdmin tabProxyAdmin;
    CBBTC cbBTC;
    CTRL ctrl;
    TimelockController governanceTimelockController;
    TimelockController emergencyTimelockController;
    ShiftCTRLGovernor shiftCtrlGovernor;
    ShiftCTRLEmergencyGovernor shiftCtrlEmergencyGovernor;
    GovernanceAction governanceAction;
    
    TabERC20 tabERC20;
    VaultManager vaultManager;
    Config config;
    ReserveRegistry reserveRegistry;
    ReserveSafe reserveSafe;
    TabRegistry tabRegistry;
    TabFactory tabFactory;
    PriceOracle priceOracle;
    PriceOracleManager priceOracleManager;
    VaultKeeper vaultKeeper;
    AuctionManager auctionManager;
    VaultUtils vaultUtils;
    ProtocolVault protocolVault;
    Signer signer;

    IPriceOracle.UpdatePriceData priceData;

    constructor() {
        owner = address(this);
        console.log("owner: ", owner);
        
        CheatCodes cheats = CheatCodes(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        eoa_accounts = new address[](10);
        eoa_accounts[0] = cheats.addr(1);
        eoa_accounts[1] = cheats.addr(2);
        eoa_accounts[2] = cheats.addr(3);
        eoa_accounts[3] = cheats.addr(4);
        eoa_accounts[4] = cheats.addr(5);
        eoa_accounts[5] = cheats.addr(6);
        eoa_accounts[6] = cheats.addr(7);
        eoa_accounts[7] = cheats.addr(8);
        eoa_accounts[8] = cheats.addr(9);
        eoa_accounts[9] = cheats.addr(10);
    }

    function nextBlock(uint256 increment) public {
        vm.roll(block.number + increment);
        vm.warp(block.timestamp + increment);
    }

    function deploy() public {
        console.log("Deploying protocol contracts on chain id: ", block.chainid);

        if (block.chainid == 84532) { // running for testnet
            tabProxyAdmin = ProxyAdmin(0xF44013D4BE0F452938B0b805Bc5Bf0D3Fbd4102c);
            cbBTC = CBBTC(0x7eC62ECbE14B6E3A8B70942dFDf302B4dd9d6a51);
            ctrl = CTRL(0x193410b8cdeD8F4D63E43D0f2AeD99bd862ed1Bc);
            governanceTimelockController = TimelockController(payable(0x783bDAF73E8F40672421204d6FF3f448767d72c6));
            emergencyTimelockController = TimelockController(payable(0x997275213b66AEAAb4042dF9457F2913969368f2));
            shiftCtrlGovernor = ShiftCTRLGovernor(payable(0x89E7068cf18F22765D1F2902d1BaB8C839B8d013));
            shiftCtrlEmergencyGovernor = ShiftCTRLEmergencyGovernor(payable(0xcb41b90E53C227241cdB018e87797afcE158d061));
            governanceAction = GovernanceAction(0xE1a5CC4599DA4bd2D25F57442222647Fe1B69Dda);
            vaultManager = VaultManager(0xeAf6aB024D4a7192322090Fea1C402a5555cD107);
            tabRegistry = TabRegistry(0x9b2F93f5be029Fbb4Cb51491951943f7368b2f1C);
            tabERC20 = TabERC20(0xE914B685a2912C2F5016EF5b29C7cD7Ec7904815);
            tabFactory = TabFactory(0x83F19d560935F5299E7DE4296e7cb7adA0417525);
            reserveRegistry = ReserveRegistry(0xDA8A64cDFaeb08b3f28b072b0d4aC371953F5B6E);
            reserveSafe = ReserveSafe(0xE8a28176Bed3a53CBF2Bc65B597811909F1A1389);
            auctionManager = AuctionManager(0xB93cb66DFaa0cDA61D83BF9f39A076EA2fa2827B);
            config = Config(0x25B9982A32106EeB2Aa052319011De58A7d33457);
            vaultUtils = VaultUtils(0x99843f8306AecdDC8EE6d47F1A144836D332a5B4);
            priceOracleManager = PriceOracleManager(0xBdFd9503f62A23092504eD072158092B6B3342ac);
            priceOracle = PriceOracle(0x7a65f5f7b2ba2F15468688c8e98835A3f9be2520);
            vaultKeeper = VaultKeeper(0x303818F385f1675BBB07dDE155987f6b7041753c);
            protocolVault = ProtocolVault(0xBC6bef5A3a1211B033322F3730e8DFf2f81AcA84);

            signer = new Signer(address(priceOracle), owner);
            if (secureSignerAddr != address(0)) { // applicable when deployment is replaced by other secure address
                signer.updateSigner(
                    secureSignerAddr, 
                    0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
                );
                vm.startPrank(address(governanceTimelockController));
                priceOracle.revokeRole(keccak256("SIGNER_ROLE"), 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
                priceOracle.grantRole(keccak256("SIGNER_ROLE"), secureSignerAddr);
                vm.stopPrank();
            }
            if (keeperAddr != address(0)) {
                vm.startPrank(address(governanceTimelockController));
                vaultKeeper.grantRole(keccak256("EXECUTOR_ROLE"), keeperAddr);
                vaultKeeper.grantRole(keccak256("MAINTAINER_ROLE"), keeperAddr);
                vm.stopPrank();
            }
            console.log("Skipped deployment, using existing contracts on testnet.");
        } else if (block.chainid == 8453) {
            deployer = owner;
            treasuryAddr = 0xC325719B907e2F739d956fB082Fa6De9Fc9d85fD;
            oracleRelayerSignerAddr = 0x7A50C47A1594318dfBFFA26F56c2B47E0d4e113b;
            oracleProviderPerformanceSignerAddr = 0xEC5082fbd4B4FE790F5837cb38B2e30566526485;
            tabRegistryFreezerAddr = 0xc812DEBDe11a4995C657002D67A8D4761BD3EDdA;
            keeperAddr = 0xd16E103f592Db4e6887a835Ac4a7Dc680Bd78500;

            tabProxyAdmin = ProxyAdmin(0x65FB1EF0f9C15b2653421D9008fd7E55889890E2);
            cbBTC = CBBTC(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf); // mainnet existing cbBTC
            vm.startPrank(ICBBTC(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf).masterMinter());
            ICBBTC(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf).configureMinter(address(this), type(uint256).max); // allow tester to mint
            vm.stopPrank();
            cbBTC.mint(deployer, 100e8); // follow default mint amount in simulated local CBBTC
            ctrl = CTRL(0x505568c65fF95E5e97Ca97B476BEb0db64F91499);
            governanceTimelockController = TimelockController(payable(0x75977C03b7AFc9B0E645A6402B2b46E438F146D5));
            emergencyTimelockController = TimelockController(payable(0x4bedAa52B64A4b8aff01a5354516c2897ecEf58B));
            shiftCtrlGovernor = ShiftCTRLGovernor(payable(0x747E429c1ceb8b0FB576650BEd6623785eAb0348));
            shiftCtrlEmergencyGovernor = ShiftCTRLEmergencyGovernor(payable(0x95205Ed4F55a012DCfd1497aEecc3C3A66496b22));
            governanceAction = GovernanceAction(0xEBf09013763412Eb1108257fde050545F780D09c);
            vaultManager = VaultManager(0x11138452B689fd55d5Ad3991A6166dbBb6C2A774);
            tabRegistry = TabRegistry(0x01D988944c3Bb067f56e600619345C3dB161f444);
            tabERC20 = TabERC20(0xf0ab89867c3053f91ebeD2b0dBe44B47BE2A0C13);
            tabFactory = TabFactory(0x83F19d560935F5299E7DE4296e7cb7adA0417525);
            reserveRegistry = ReserveRegistry(0xb59B6ba5426255B669C3966261aC4b2D59A76943);
            reserveSafe = ReserveSafe(0x6cdEB78a62bD94f2c08D6AbB0f1412B0F959a9A0);
            auctionManager = AuctionManager(0x731D9aD52663c2767A48303D09a668F9cE3aecc4);
            config = Config(0xC81455d98AD16db5043c775bD1eCd2677E39e670);
            vaultUtils = VaultUtils(0x4034a758F7CFB316f5923B7a2568D8ff21ea998a);
            priceOracleManager = PriceOracleManager(0x5f6c5A786a1Aa89d3B18606f93Dc6bfA011a2fBC);
            priceOracle = PriceOracle(0x8c3Fd83a9dFEC3D5e389aea60cA980A2e72A9A5A);
            vaultKeeper = VaultKeeper(0xBbFD14d040b7E3b3cC3eef52DCB1E84Cb3E397C5);
            bytes memory protocolVaultInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                address(governanceTimelockController),  // Governance controller
                address(tabProxyAdmin),        // upgrader
                address(vaultManager),         // Vault manager
                address(reserveSafe)
            );
            ProtocolVault protocolVaultImpl = new ProtocolVault(); // implementation
            address protocolVaultAddr = address(
                new TransparentUpgradeableProxy(
                    address(protocolVaultImpl), address(tabProxyAdmin), protocolVaultInitData
                )
            );
            protocolVault = ProtocolVault(protocolVaultAddr);
            vm.startPrank(address(governanceTimelockController));
            tabRegistry.setProtocolVaultAddress(protocolVaultAddr);
            vm.stopPrank();
            console.log("protocolVault: ", address(protocolVault));
            
            signer = new Signer(address(priceOracle), address(this));
            vm.startPrank(address(governanceTimelockController));
            priceOracle.grantRole(keccak256("SIGNER_ROLE"), 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
            vm.stopPrank();
        
            vm.startPrank(address(governanceTimelockController));
            vaultKeeper.grantRole(keccak256("EXECUTOR_ROLE"), 0xd16E103f592Db4e6887a835Ac4a7Dc680Bd78500);
            vaultKeeper.grantRole(keccak256("MAINTAINER_ROLE"), 0xd16E103f592Db4e6887a835Ac4a7Dc680Bd78500);
            vm.stopPrank();

            // remove permissions
            address mainnetDeployer = 0x553A9FB9B5590EE27d8ddc589005afca99D51aa3;
            vm.startPrank(mainnetDeployer);
            tabFactory.transferOwnership(address(governanceTimelockController));
            vaultManager.renounceRole(keccak256("DEPLOYER_ROLE"), mainnetDeployer);
            governanceAction.renounceRole(MAINTAINER_ROLE, mainnetDeployer);
            tabRegistry.renounceRole(MAINTAINER_ROLE, mainnetDeployer);
            reserveRegistry.renounceRole(MAINTAINER_ROLE, mainnetDeployer);
            config.renounceRole(MAINTAINER_ROLE, mainnetDeployer);
            priceOracleManager.renounceRole(MAINTAINER_ROLE, mainnetDeployer);

            ctrl.grantRole(keccak256("MINTER_ROLE"), address(this));
            ctrl.grantRole(UPGRADER_ROLE, address(governanceTimelockController));
            ctrl.grantRole(UPGRADER_ROLE, address(emergencyTimelockController));
            ctrl.beginDefaultAdminTransfer(address(governanceTimelockController));
            vm.stopPrank();
        
            console.log("Skipped deployment, using existing contracts on mainnet.");
        } else { // e.g. anvil, 31337
            deployer = owner;
            oracleRelayerSignerAddr = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

            // Single ProxyAdmin used in all upgradeable contracts in the protocol
            tabProxyAdmin = new ProxyAdmin(owner);
            console.log("tabProxyAdmin: ", address(tabProxyAdmin));
            
            // Deploy reserve token: cbBTC
            // Simulate mainnet 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
            cbBTC = new CBBTC(owner);
            console.log("cbBTC: ", address(cbBTC));

            // Deploy governance token: CTRL
            address ctrlImplementation = address(new CTRL());
            bytes memory ctrlInitData = abi.encodeWithSignature("initialize(address,address)", owner, owner);
            address ctrlAddr = address(new TransparentUpgradeableProxy(
                ctrlImplementation, 
                address(tabProxyAdmin), 
                ctrlInitData
            ));
            ctrl = CTRL(ctrlAddr);
            console.log("CTRL: ", address(ctrl));

            // Governance
            address[] memory tempAddrs = new address[](1);
            tempAddrs[0] = owner;
            governanceTimelockController = new TimelockController(2 days, tempAddrs, tempAddrs, owner);
            emergencyTimelockController = new TimelockController(0, tempAddrs, tempAddrs, owner);

            tabProxyAdmin.transferOwnership(address(governanceTimelockController));

            shiftCtrlGovernor = new ShiftCTRLGovernor(IVotes(address(ctrl)), governanceTimelockController);
            shiftCtrlEmergencyGovernor = new ShiftCTRLEmergencyGovernor(IVotes(address(ctrl)), emergencyTimelockController);
            console.log("governanceTimelockController: ", address(governanceTimelockController));
            console.log("emergencyTimelockController: ", address(emergencyTimelockController));
            console.log("shiftCtrlGovernor: ", address(shiftCtrlGovernor));
            console.log("shiftCtrlEmergencyGovernor: ", address(shiftCtrlEmergencyGovernor));

            address shiftCtrlGovernorAddr = address(shiftCtrlGovernor);
            governanceTimelockController.grantRole(EXECUTOR_ROLE, shiftCtrlGovernorAddr);
            governanceTimelockController.grantRole(PROPOSER_ROLE, shiftCtrlGovernorAddr);
            governanceTimelockController.grantRole(CANCELLER_ROLE, shiftCtrlGovernorAddr);
            governanceTimelockController.grantRole(TIMELOCK_ADMIN_ROLE, shiftCtrlGovernorAddr);

            address shiftCtrlEmergencyGovernorAddr = address(shiftCtrlEmergencyGovernor);
            emergencyTimelockController.grantRole(EXECUTOR_ROLE, shiftCtrlEmergencyGovernorAddr);
            emergencyTimelockController.grantRole(PROPOSER_ROLE, shiftCtrlEmergencyGovernorAddr);
            emergencyTimelockController.grantRole(CANCELLER_ROLE, shiftCtrlEmergencyGovernorAddr);
            emergencyTimelockController.grantRole(TIMELOCK_ADMIN_ROLE, shiftCtrlEmergencyGovernorAddr);

            governanceTimelockController.revokeRole(EXECUTOR_ROLE, owner);
            governanceTimelockController.revokeRole(PROPOSER_ROLE, owner);
            governanceTimelockController.revokeRole(CANCELLER_ROLE, owner);
            governanceTimelockController.revokeRole(TIMELOCK_ADMIN_ROLE, owner);

            emergencyTimelockController.revokeRole(EXECUTOR_ROLE, owner);
            emergencyTimelockController.revokeRole(PROPOSER_ROLE, owner);
            emergencyTimelockController.revokeRole(CANCELLER_ROLE, owner);
            emergencyTimelockController.revokeRole(TIMELOCK_ADMIN_ROLE, owner);

            address governance = address(governanceTimelockController);
            address emergencyGov = address(emergencyTimelockController);

            bytes memory governanceActionInitData =
                abi.encodeWithSignature("initialize(address,address,address,address)", governance, emergencyGov, owner, address(tabProxyAdmin));
            GovernanceAction governanceActionImpl = new GovernanceAction(); // implementation
            address governanceActionAddr = address(new TransparentUpgradeableProxy(
                address(governanceActionImpl), 
                address(tabProxyAdmin), 
                governanceActionInitData
            ));
            governanceAction = GovernanceAction(governanceActionAddr);
            console.log("governanceAction: ", address(governanceAction));

            // VaultManager
            bytes memory vaultManagerInitData =
                abi.encodeWithSignature("initialize(address,address,address,address)", governance, emergencyGov, address(tabProxyAdmin), owner);
            VaultManager vaultManagerImpl = new VaultManager(); // implementation
            address vaultManagerAddr = address(new TransparentUpgradeableProxy(
                address(vaultManagerImpl), 
                address(tabProxyAdmin), 
                vaultManagerInitData)
            );
            vaultManager = VaultManager(vaultManagerAddr);
            console.log("vaultManager: ", address(vaultManager));

            // TabRegistry
            tabRegistry = new TabRegistry(
                governance,                // Governance controller
                emergencyGov,              // Emergency governance controller
                governanceActionAddr,      // Governance action
                owner,                     // Deployer
                tabRegistryFreezerAddr,    // Permission to freeze tab
                address(vaultManager)      // Vault Manager
            );
            console.log("tabRegistry: ", address(tabRegistry));

            // TAB token implementation code: TabERC20
            tabERC20 = new TabERC20();
            console.log("tabERC20: ", address(tabERC20));

            // TabFactory: expect to use same address so created Tab addresses are consistent
            // For EVM deployment:
            // 1. Re-use or deploy Skybit create3 factory contract on target chain.
            // 2. Refer script/`DeployTabFactory.s.sol`, run script to deploy.
            // 3. Deploy TabERC20 
            // 4. Call TabFactory.upgradeTo(address tabERC20) to set implementation.
            
            // Reference:
            // tabFactory = ISkybitCreate3Factory(skybitCreate3Factory).deploy(
            //     keccak256(abi.encodePacked("ShiftCTRL_v1_TabFactory")), 
            //     abi.encodePacked(type(TabFactory).creationCode, abi.encode(address(tabERC20), governanceTimelockController))
            // );
            tabFactory = new TabFactory(address(tabERC20), owner); 
            tabFactory.updateTabRegistry(address(tabRegistry));
            console.log("tabFactory: ", address(tabFactory));
            
            tabRegistry.setTabFactory(address(tabFactory));

            // ReserveRegistry
            reserveRegistry = new ReserveRegistry(
                governance,             // Governance controller
                emergencyGov,           // Emergency governance controller
                governanceActionAddr,   // Governance action
                owner                   // Deployer
            );
            console.log("reserveRegistry: ", address(reserveRegistry));

            // ReserveSafe
            reserveSafe = new ReserveSafe(governance, emergencyGov, address(vaultManager), address(reserveRegistry));
            reserveRegistry.updateReserveSafe(address(reserveSafe));
            reserveRegistry.addReserve(address(cbBTC), address(reserveSafe));
            console.log("reserveSafe: ", address(reserveSafe));

            // AuctionManager
            auctionManager = new AuctionManager(governance, emergencyGov, address(vaultManager), address(reserveSafe));
            console.log("auctionManager: ", address(auctionManager));

            // Config
            config = new Config(
                governance,                 // Governance controller
                emergencyGov,               // Emergency governance controller
                governanceActionAddr,       // Governance action
                owner,                      // Deployer
                treasuryAddr,               // Treasury
                address(tabRegistry),       // Tab registry
                address(auctionManager)     // Auction manager
            );
            tabRegistry.setConfigAddress(address(config));
            console.log("config: ", address(config));

            // VaultUtils
            vaultUtils = new VaultUtils(governance, vaultManagerAddr, address(config));
            console.log("vaultUtils: ", address(vaultUtils));

            // PriceOracleManager
            bytes memory priceOracleManagerInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address,address)",
                governance,                 // Governance controller
                emergencyGov,               // Emergency governance controller
                governanceActionAddr,       // Governance action
                owner,                      // Deployer
                address(tabProxyAdmin),     // Upgrader
                oracleProviderPerformanceSignerAddr,       // Authorized tab-oracle module caller
                address(tabRegistry)        // Tab registry
            );
            PriceOracleManager priceOracleManagerImpl = new PriceOracleManager(); // implementation
            address priceOracleManagerAddr = address(
                new TransparentUpgradeableProxy(
                    address(priceOracleManagerImpl), address(tabProxyAdmin), priceOracleManagerInitData
                )
            );
            priceOracleManager = PriceOracleManager(priceOracleManagerAddr);
            tabRegistry.setPriceOracleManagerAddress(priceOracleManagerAddr);
            console.log("priceOracleManager: ", address(priceOracleManager));

            // PriceOracle
            priceOracle = new PriceOracle(
                governance,                 // Governance action
                emergencyGov,               // Emergency governance action
                address(vaultManager),      // Vault manager
                priceOracleManagerAddr,     // Price oracle manager
                address(tabRegistry),       // Tab registry
                oracleRelayerSignerAddr     // Oracle price signer
            );
            priceOracleManager.setPriceOracle(address(priceOracle));
            console.log("priceOracle: ", address(priceOracle));

            governanceAction.setContractAddress(
                address(config), 
                address(tabRegistry), 
                address(reserveRegistry), 
                address(priceOracleManager)
            );

            // Vault keeper
            bytes memory vaultKeeperInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                governance,                 // Governance controller
                emergencyGov,               // Emergency governance controller
                address(tabProxyAdmin),     // Upgrader
                keeperAddr,                 // Tab-keeper module caller
                address(vaultManager),      // Vault manager
                address(config)             // Config
            );
            VaultKeeper vaultKeeperImpl = new VaultKeeper(); // implementation
            address vaultKeeperAddr = address(
                new TransparentUpgradeableProxy(address(vaultKeeperImpl), address(tabProxyAdmin), vaultKeeperInitData)
            );
            vaultKeeper = VaultKeeper(vaultKeeperAddr);
            console.log("vaultKeeper: ", address(vaultKeeper));

            vaultManager.configContractAddress(
                address(config), 
                address(reserveRegistry), 
                address(tabRegistry),
                address(priceOracle), 
                address(vaultKeeper)
            );

            config.setVaultKeeperAddress(vaultKeeperAddr);

            // ProtocolVault
            bytes memory protocolVaultInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                governance,                 // Governance controller
                address(tabProxyAdmin),     // upgrader
                vaultManagerAddr,           // Vault manager
                address(reserveSafe)
            );
            ProtocolVault protocolVaultImpl = new ProtocolVault(); // implementation
            address protocolVaultAddr = address(
                new TransparentUpgradeableProxy(
                    address(protocolVaultImpl), address(tabProxyAdmin), protocolVaultInitData
                )
            );
            protocolVault = ProtocolVault(protocolVaultAddr);
            // Todo (before executing ctrlAltDel operation): 
            // Revoke MINTER_ROLE from VaultManager on targeted tab.
            // Grant MINTER_ROLE to ProtocolVault on targeted tab.

            tabRegistry.setProtocolVaultAddress(protocolVaultAddr);

            console.log("protocolVault: ", address(protocolVault));

            governanceAction.addPriceOracleProvider(
                0x346Ed1282B89D8c948b404C3c3599f8D8ba2AA0e, // provider
                address(ctrl), // paymentTokenAddress: CTRL address
                1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
                150,        // blockCountPerFeed
                10,         // feedSize: minimum number of currency pairs sent by provider
                bytes32(0)  // whitelistedIPAddr: allow sending from any IP
            );
            governanceAction.addPriceOracleProvider(
                0xE728C3436836d980AeCd7DcB2935dc808c2E5a5f, // provider
                address(ctrl), // paymentTokenAddress: CTRL address
                1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
                150,        // blockCountPerFeed
                10,         // feedSize: minimum number of currency pairs sent by provider
                bytes32(0)  // whitelistedIPAddr: allow sending from any IP
            );
            governanceAction.addPriceOracleProvider(
                0x6EeA49a87c6e46c8EC6C74C9870717eFF8616C3B, // provider
                address(ctrl), // paymentTokenAddress: CTRL address
                1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
                150,        // blockCountPerFeed
                10,         // feedSize: minimum number of currency pairs sent by provider
                bytes32(0)  // whitelistedIPAddr: allow sending from any IP
            );

            signer = new Signer(address(priceOracle), owner);

            // remove permissions
            tabFactory.transferOwnership(governance);
            vaultManager.renounceRole(keccak256("DEPLOYER_ROLE"), owner);
            governanceAction.renounceRole(MAINTAINER_ROLE, owner);
            tabRegistry.renounceRole(MAINTAINER_ROLE, owner);
            reserveRegistry.renounceRole(MAINTAINER_ROLE, owner);
            config.renounceRole(MAINTAINER_ROLE, owner);
            priceOracleManager.renounceRole(MAINTAINER_ROLE, owner);

            ctrl.grantRole(UPGRADER_ROLE, governance);
            ctrl.grantRole(UPGRADER_ROLE, emergencyGov);
            ctrl.beginDefaultAdminTransfer(governance);
            // After 1 day grace period, call: governanceController.acceptDefaultAdminTransfer()
        }
    }

}
