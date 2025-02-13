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
    address signerAuthorizedAddr = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // anvil first test acct
    address secureSignerAddr; // replace private key in Signer util.
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
            tabProxyAdmin = ProxyAdmin(0x406DB224F4E273483D87D99668e0c991CAeb710f);
            cbBTC = CBBTC(0x9da86651c82124B732eF0AB25a1226a4F3e44333);
            ctrl = CTRL(0x0ACBDd01671D2BDd33F08b269f41FA4d0c3e437C);
            governanceTimelockController = TimelockController(payable(0xBB6F0a372cb8104e2898d5e7c052e5637fAF9b4f));
            emergencyTimelockController = TimelockController(payable(0x0402A1ad934aB61035260FC0fa5A0c851057386b));
            shiftCtrlGovernor = ShiftCTRLGovernor(payable(0x9C93FAa3F264f8B099aaEC940a82F1972e8de3ef));
            shiftCtrlEmergencyGovernor = ShiftCTRLEmergencyGovernor(payable(0x6a359b2D17EBed1E4eDDB765d3832E07a29a26E3));
            governanceAction = GovernanceAction(0x8188C7fc2f746998f4b00709C08661caE22b5fa0);
            vaultManager = VaultManager(0x1a13d6a511A9551eC1A493C26362836e80aC4d65);
            tabRegistry = TabRegistry(0x82dd76890513D1DdE4208c75945046392cfa79B6);
            tabERC20 = TabERC20(0xf6dD022b6404454fe75Bc0276A8E98DEF9D0Fb03);
            tabFactory = TabFactory(0x042903578B67B36AC5CCe2c3d75292D62C16C459);
            reserveRegistry = ReserveRegistry(0xe18688d77743F1B2334e4A2602c1a054dE72a7cB);
            reserveSafe = ReserveSafe(0xEB18eeEA567617e321481aB0456B65c96595b15b);
            auctionManager = AuctionManager(0x6D280966Bcb6E3727564a4F3e2680651EACF62fd);
            config = Config(0x258D5a48D45f675C3129335651B9c3aacaC62Ed1);
            vaultUtils = VaultUtils(0xCEdfa0601F074D281B89E6f8Ba604eEEe36dD34c);
            priceOracleManager = PriceOracleManager(0x9228d75707D5796FA3501eAAa332Fb35C76f9C4f);
            priceOracle = PriceOracle(0x5c181D405c962710a854e2A31ac8dcbe9770B682);
            vaultKeeper = VaultKeeper(0x80D8773Ff8B40C6B432f7f026498bCaDEf9E33B7);
            protocolVault = ProtocolVault(0x9445B22e959e3CC9690Cf6653BE63ac541B61128);

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
        } else { // e.g. anvil, 31337
            deployer = owner;

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
                signerAuthorizedAddr,      // Oracle relayer
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
                governance,        // Governance controller
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
                signerAuthorizedAddr,       // Authorized tab-oracle module caller
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
                signerAuthorizedAddr        // Oracle price signer
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
