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
    tabProxyAdmin:  0xF44013D4BE0F452938B0b805Bc5Bf0D3Fbd4102c
    CBBTC deployed at: 0x7eC62ECbE14B6E3A8B70942dFDf302B4dd9d6a51
    CTRL implementation:  0x32CDaE2Eb710D7722Bcf7aFE1c33Cb3091C6fee8
    CTRL:  0x193410b8cdeD8F4D63E43D0f2AeD99bd862ed1Bc
    governanceTimelockController:  0x783bDAF73E8F40672421204d6FF3f448767d72c6
    emergencyTimelockController:  0x997275213b66AEAAb4042dF9457F2913969368f2
    shiftCtrlGovernor:  0x89E7068cf18F22765D1F2902d1BaB8C839B8d013
    shiftCtrlEmergencyGovernor:  0xcb41b90E53C227241cdB018e87797afcE158d061
    governanceActionImpl:  0xe4Cd0192D1e2976e80BF5F943B3f12E802c8dB6a
    governanceAction:  0xE1a5CC4599DA4bd2D25F57442222647Fe1B69Dda
    vaultManagerImpl:  0x65EdEf576C0c7A928E7CD2331de60111b5c0011B
    vaultManager:  0xeAf6aB024D4a7192322090Fea1C402a5555cD107
    tabRegistry:  0x9b2F93f5be029Fbb4Cb51491951943f7368b2f1C
    tabFactory:  0x83F19d560935F5299E7DE4296e7cb7adA0417525
    reserveRegistry:  0xDA8A64cDFaeb08b3f28b072b0d4aC371953F5B6E
    reserveSafe:  0xE8a28176Bed3a53CBF2Bc65B597811909F1A1389
    auctionManager:  0xB93cb66DFaa0cDA61D83BF9f39A076EA2fa2827B
    config:  0x25B9982A32106EeB2Aa052319011De58A7d33457
    vaultUtils:  0x99843f8306AecdDC8EE6d47F1A144836D332a5B4
    priceOracleManagerImpl:  0xA850B25e6489e8259CAFFD9571d6dE6fE842C8cf
    priceOracleManager:  0xBdFd9503f62A23092504eD072158092B6B3342ac
    priceOracle:  0x7a65f5f7b2ba2F15468688c8e98835A3f9be2520
    vaultKeeperImpl:  0x7a50Da5330b6fc3838Ef6EA757458a7601231aA8
    vaultKeeper:  0x303818F385f1675BBB07dDE155987f6b7041753c
    protocolVaultImpl:  0xE332Fc0D65a0aDAd9eD7cf5964D5223cF0a25bC3
    protocolVault:  0xBC6bef5A3a1211B033322F3730e8DFf2f81AcA84
   Tab Protocol deployment is completed.
 */
contract DeployMain is Script {
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    address owner = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56; // deployer

    address cbBTCAddr; // TODO For mainnet, use 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
    address faucetAddr = 0xe23492593e019AbC07255755B2ae813E3DD76F31;
    address tabFactoryAddr = 0x83F19d560935F5299E7DE4296e7cb7adA0417525;
    address treasuryAddr = 0x7045CC042c0571F671236db73ba93BD1B82b2326;
    // TODO to run forked testnet, adjust `Signer.sol` to match configured oracle signer.
    address oracleRelayerSignerAddr = 0x6cC15689B28227d97481Fac73614cD8D35ede6D2; 
    address oracleProviderPerformanceSignerAddr = 0x92b6153228B61324cAdCAab510FB38c6661b992e;
    address tabRegistryFreezerAddr = 0x6DA75E7831c14810C285e49D3219bEA63bDf5C14;
    address keeperAddr = 0x930718756DeE144963697D6EB532c9a6Cf10d0F6;

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

        // Add 3 oracle providers for testnet
        // Assume 5-min feed interval and 2s block gen. time,
        // each feed is expected to arrive within 60/2 * 5 = 150 blocks.
        // (TODO: Uncomment for local testnet fork test)
        governanceAction.addPriceOracleProvider(
            0x346Ed1282B89D8c948b404C3c3599f8D8ba2AA0e, // provider
            0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F, // paymentTokenAddress: CTRL address
            1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
            150,        // blockCountPerFeed
            10,         // feedSize: minimum number of currency pairs sent by provider
            bytes32(0)  // whitelistedIPAddr: allow sending from any IP
        );
        governanceAction.addPriceOracleProvider(
            0xE728C3436836d980AeCd7DcB2935dc808c2E5a5f, // provider
            0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F, // paymentTokenAddress: CTRL address
            1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
            150,        // blockCountPerFeed
            10,         // feedSize: minimum number of currency pairs sent by provider
            bytes32(0)  // whitelistedIPAddr: allow sending from any IP
        );
        governanceAction.addPriceOracleProvider(
            0x6EeA49a87c6e46c8EC6C74C9870717eFF8616C3B, // provider
            0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F, // paymentTokenAddress: CTRL address
            1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
            150,        // blockCountPerFeed
            10,         // feedSize: minimum number of currency pairs sent by provider
            bytes32(0)  // whitelistedIPAddr: allow sending from any IP
        );

        // Testnet only: mint to faucet address
        cbBTC.mint(faucetAddr, 1e18);           // 10,000,000,000 cbBTC
        cbBTC.mint(owner, 1e18);                // 10,000,000,000 cbBTC
        cbBTC.mint(0x16601e7dBf2642bF7832053417eE0E17C9c49f93, 1e8);
        ctrl.mint(faucetAddr, 100000000e18);    // 100,000,000 CTRL
        ctrl.mint(owner, 100000000e18);         // 100,000,000 CTRL

        // remove permissions
        // (TODO: Uncomment for mainnet or local testnet fork test)
        /*
        tabFactory.transferOwnership(governance);
        vaultManager.renounceRole(DEPLOYER_ROLE, owner);
        governanceAction.renounceRole(MAINTAINER_ROLE, owner);
        tabRegistry.renounceRole(MAINTAINER_ROLE, owner);
        reserveRegistry.renounceRole(MAINTAINER_ROLE, owner);
        config.renounceRole(MAINTAINER_ROLE, owner);
        priceOracleManager.renounceRole(MAINTAINER_ROLE, owner);
        */

        ctrl.grantRole(UPGRADER_ROLE, governance);
        ctrl.grantRole(UPGRADER_ROLE, emergencyGov);
        // (TODO: Uncomment for mainnet or local testnet fork test)
        // ctrl.beginDefaultAdminTransfer(governance);
        // After 1 day grace period, call: governanceController.acceptDefaultAdminTransfer()

        console.log("Tab Protocol deployment is completed.");

        vm.stopBroadcast();
    }

}