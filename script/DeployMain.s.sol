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

/// @dev Refer https://github.com/mds1/multicall/blob/main/src/interfaces/IMulticall3.sol
// interface IMulticall3 {
//     struct Call3 {
//         address target;
//         bool allowFailure;
//         bytes callData;
//     }

//     struct Result {
//         bool success;
//         bytes returnData;
//     }
    
//     function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData);
// }

/**
 * @dev Execute to deploy full Tab Protocol on testnet or mainnet.
 * Sample logs:
 * Deploying protocol contracts...
    tabProxyAdmin:  0x2c112a83E7859c7e513C94ee95B55707c87f6004
    CBBTC deployed at: 0xfDd7b819ca8422e2031abA3A46cE2Ee2386E3c13
    CTRL implementation:  0x8D756b55986Ea70B78E31afbD9139F3e8F9Cef7f
    CTRL:  0x7F53Fb785Feee996117205e2b81e4D77755701Fe
    governanceTimelockController:  0x4e41d11Cb9540891a55B9744a59025E5382DDeCF
    emergencyTimelockController:  0xE5A01AD9d0065e66553B3bF9C3E12F0b6aC20201
    shiftCtrlGovernor:  0x6EdeC03274302038C3A3E8C3853E100f6A67D10f
    shiftCtrlEmergencyGovernor:  0x82d558fD3a71fB4E1256424E8be724Cb5Ca744A5
    governanceActionImpl:  0xeFC0d67F4897035Dcbf68eE24cb6CD35e79Bc331
    governanceAction:  0xfE8F568092ebBaE143af77952e2AE222d6E56896
    vaultManagerImpl:  0x2A73B84Af2DB25F628CB5959d8e40E27a905eBeB
    vaultManager:  0x11276132F98756673d66DBfb424d0ae0510d9219
    tabRegistry:  0x33B54050d72c8Ffeb6c0d7E0857c7C012643DeA0
    tabFactory:  0x9F440e98dD11a44AeDC8CA88bb7cA3756fdfFED1
    reserveRegistry:  0x5824F087B9AE3327e0Ee9cc9DB04E2Cc08ec1BA3
    reserveSafe:  0xF308055b4b8Ea0ccec1699cab524185967c28ea0
    auctionManager:  0xA4C2b64Bd05BF29c297C06D5bd1DaC3E99F57558
    config:  0x61f2f994d35fDc75990Fe273e34913a3AcC928E6
    vaultUtils:  0x8786dA72C762e4A83286cD91b0CBC9a7C8E5531B
    priceOracleManagerImpl:  0x8d5aC91A6464769C5817254bE2478Ff5490E072F
    priceOracleManager:  0x192Ee2bAD42B9e4C903975fE5615888e39be7A6a
    priceOracle:  0xa6188Fcd9f90F76c692D139099D9909B78fb632c
    vaultKeeperImpl:  0xbb606E52525785ab444ddbd459301C5C62F09316
    vaultKeeper:  0xd9AF87C4D2Ff3f250f6B3a66C9313e37d912117b
    protocolVaultImpl:  0x29F7D66da1051d5feE3bf395539EDdA9E3D4b731
    protocolVault:  0xD5D2DA37819FCa1514570499B6eA59F98A57f2aF
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

    address multicall3Addr = 0xcA11bde05977b3631167028862bE2a173976CA11;
    address cbBTCAddr; // TODO For mainnet, use 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
    address faucetAddr = 0xe23492593e019AbC07255755B2ae813E3DD76F31;
    address tabFactoryAddr = 0x9F440e98dD11a44AeDC8CA88bb7cA3756fdfFED1;
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