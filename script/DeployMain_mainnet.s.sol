// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";

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

/**
 * @dev Execute to deploy full Tab Protocol on testnet or mainnet.
 * Sample logs:
 * Deploying protocol contracts...
    tabProxyAdmin:  0x65FB1EF0f9C15b2653421D9008fd7E55889890E2
    CBBTC already deployed at: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
    CTRL implementation:  0x14Eba0BF66eA9Ff235EA463403ad607A85c58d1e
    CTRL:  0x505568c65fF95E5e97Ca97B476BEb0db64F91499
    governanceTimelockController:  0x75977C03b7AFc9B0E645A6402B2b46E438F146D5
    emergencyTimelockController:  0x4bedAa52B64A4b8aff01a5354516c2897ecEf58B
    shiftCtrlGovernor:  0x747E429c1ceb8b0FB576650BEd6623785eAb0348
    shiftCtrlEmergencyGovernor:  0x95205Ed4F55a012DCfd1497aEecc3C3A66496b22
    governanceActionImpl:  0x5836eA95D4b6EA81cC763e319b1298b156CcB92A
    governanceAction:  0xEBf09013763412Eb1108257fde050545F780D09c
    vaultManagerImpl:  0x70676FbA5a7200A971687A2b961706cA6B69CB2B
    vaultManager:  0x11138452B689fd55d5Ad3991A6166dbBb6C2A774
    tabRegistry:  0x01D988944c3Bb067f56e600619345C3dB161f444
    tabFactory:  0x83F19d560935F5299E7DE4296e7cb7adA0417525
    reserveRegistry:  0xb59B6ba5426255B669C3966261aC4b2D59A76943
    reserveSafe:  0x6cdEB78a62bD94f2c08D6AbB0f1412B0F959a9A0
    auctionManager:  0x731D9aD52663c2767A48303D09a668F9cE3aecc4
    config:  0xC81455d98AD16db5043c775bD1eCd2677E39e670
    vaultUtils:  0x4034a758F7CFB316f5923B7a2568D8ff21ea998a
    priceOracleManagerImpl:  0x1543fC99934Df914CDb153d842A516304F60C2aa
    priceOracleManager:  0x5f6c5A786a1Aa89d3B18606f93Dc6bfA011a2fBC
    priceOracle:  0x8c3Fd83a9dFEC3D5e389aea60cA980A2e72A9A5A
    vaultKeeperImpl:  0x99cdB3AE102b7E1a2dD2018ff1D525f7BfD768E0
    vaultKeeper:  0xBbFD14d040b7E3b3cC3eef52DCB1E84Cb3E397C5
   Tab Protocol deployment is completed.
 */
contract DeployMainnet is Script {
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    address owner = 0x553A9FB9B5590EE27d8ddc589005afca99D51aa3; // deployer

    address cbBTCAddr = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address tabFactoryAddr = 0x83F19d560935F5299E7DE4296e7cb7adA0417525;
    address treasuryAddr = 0xC325719B907e2F739d956fB082Fa6De9Fc9d85fD; // Safe wallet
    address oracleRelayerSignerAddr = 0x7A50C47A1594318dfBFFA26F56c2B47E0d4e113b; 
    address oracleProviderPerformanceSignerAddr = 0xEC5082fbd4B4FE790F5837cb38B2e30566526485;
    address tabRegistryFreezerAddr = 0xc812DEBDe11a4995C657002D67A8D4761BD3EDdA;
    address keeperAddr = 0xd16E103f592Db4e6887a835Ac4a7Dc680Bd78500;

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

    function run() external {
        vm.startBroadcast(owner);

        console.log("Deploying protocol contracts...");

        // Single ProxyAdmin used in all upgradeable contracts in the protocol
        tabProxyAdmin = new ProxyAdmin(owner);
        console.log("tabProxyAdmin: ", address(tabProxyAdmin));

        // CBBTC: reserve token
        if (cbBTCAddr == address(0)) { // testnet: deploy simulated CBBTC so protocol can mint reserve tokens
            cbBTC = new CBBTC(owner);
            cbBTCAddr = address(cbBTC);
            console.log("CBBTC deployed at:", cbBTCAddr);
        } else { // mainnet
            // cbBTC = CBBTC(cbBTCAddr);
            console.log("CBBTC already deployed at:", cbBTCAddr);
        }

        // CTRL: Governance token
        address ctrlImplementation = address(new CTRL());
        console.log("CTRL implementation: ", ctrlImplementation);
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
        console.log("governanceActionImpl: ", address(governanceActionImpl));
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
        console.log("vaultManagerImpl: ", address(vaultManagerImpl));
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
            tabRegistryFreezerAddr,    // Tab freezer
            address(vaultManager)      // Vault Manager
        );
        console.log("tabRegistry: ", address(tabRegistry));

        tabFactory = TabFactory(tabFactoryAddr); 
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
        reserveRegistry.addReserve(cbBTCAddr, address(reserveSafe));
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
            oracleProviderPerformanceSignerAddr, // Provider feed count submission
            address(tabRegistry)        // Tab registry
        );
        PriceOracleManager priceOracleManagerImpl = new PriceOracleManager(); // implementation
        console.log("priceOracleManagerImpl: ", address(priceOracleManagerImpl));
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
        console.log("vaultKeeperImpl: ", address(vaultKeeperImpl));
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
        if (block.chainid == 84532) { // Deploy if it is running for testnet
            bytes memory protocolVaultInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                governance,                 // Governance controller
                address(tabProxyAdmin),     // upgrader
                vaultManagerAddr,           // Vault manager
                address(reserveSafe)
            );
            ProtocolVault protocolVaultImpl = new ProtocolVault(); // implementation
            console.log("protocolVaultImpl: ", address(protocolVaultImpl));
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
        }

        // Default 3 oracle providers
        // Assume 5-min feed interval and 2s block gen. time,
        // each feed is expected to arrive within 60/2 * 5 = 150 blocks.
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
/*
        // Default CTRL allocation to support governance and AirDrop campaigns
        ctrl.mint(treasuryAddr, 1000000e18);    // 1,000,000 CTRL
        ctrl.mint(owner, 1000000e18);           // 1,000,000 CTRL

        // remove permissions
        // (TODO: Uncomment for mainnet or local testnet fork test)
        
        tabFactory.transferOwnership(governance);
        vaultManager.renounceRole(DEPLOYER_ROLE, owner);
        governanceAction.renounceRole(MAINTAINER_ROLE, owner);
        tabRegistry.renounceRole(MAINTAINER_ROLE, owner);
        reserveRegistry.renounceRole(MAINTAINER_ROLE, owner);
        config.renounceRole(MAINTAINER_ROLE, owner);
        priceOracleManager.renounceRole(MAINTAINER_ROLE, owner);
        

        ctrl.grantRole(UPGRADER_ROLE, governance);
        ctrl.grantRole(UPGRADER_ROLE, emergencyGov);
        // (TODO: Uncomment for mainnet or local testnet fork test)
        ctrl.beginDefaultAdminTransfer(governance);
        // After 1 day grace period, call: governanceController.acceptDefaultAdminTransfer()
*/
        console.log("Tab Protocol deployment is completed.");

        vm.stopBroadcast();
    }

}