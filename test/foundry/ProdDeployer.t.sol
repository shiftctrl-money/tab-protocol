// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { Signer } from "./helper/Signer.sol";
import "../../contracts/token/CTRL.sol";
import "../../contracts/token/CBTC.sol";
import "../../contracts/token/WBTC.sol";
import "../../contracts/token/TabERC20.sol";
import "../../contracts/governance/TimelockController.sol";
import "../../contracts/governance/ShiftCtrlGovernor.sol";
import "../../contracts/governance/ShiftCtrlEmergencyGovernor.sol";
import "../../contracts/governance/GovernanceAction.sol";
import "../../contracts/governance/interfaces/IGovernanceAction.sol";
import "../../contracts/TabProxyAdmin.sol";
import "../../contracts/VaultManager.sol";
import "../../contracts/VaultUtils.sol";
import "../../contracts/Config.sol";
import "../../contracts/ReserveRegistry.sol";
import "../../contracts/ReserveSafe.sol";
import "../../contracts/TabRegistry.sol";
import "../../contracts/TabFactory.sol";
import "../../contracts/oracle/PriceOracle.sol";
import "../../contracts/oracle/interfaces/IPriceOracleManager.sol";
import "../../contracts/oracle/PriceOracleManager.sol";
import "../../contracts/VaultKeeper.sol";
import "../../contracts/AuctionManager.sol";
import "../../contracts/ProtocolVault.sol";

interface CheatCodes {

    // Gets address for a given private key, (privateKey) => (address)
    function addr(uint256) external returns (address);

}

abstract contract ProdDeployer {

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    bytes32 reserve_cBTC = keccak256("CBTC");
    bytes32 reserve_wBTC = keccak256("WBTC");

    // deploy from deployKeylessly-Create3Factory.js, factoryToDeploy = `SKYBITSolady`
    address skybitCreate3Factory = 0xA8D5D2166B1FB90F70DF5Cc70EA7a1087bCF1750;
    // TODO: change addresses for mainnet deployment
    address UI_USER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;  // 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
    address TREASURY = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
    address PRICE_RELAYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    address KEEPER_RELAYER = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a

    address public deployer;
    Signer signer;
    address[] public eoa_accounts;

    TabProxyAdmin ctrlProxyAdmin;
    TabProxyAdmin tabProxyAdmin;
    TabProxyAdmin cBTCProxyAdmin;
    TabProxyAdmin wBTCProxyAdmin;
    
    CBTC cBTC; // Reserve Token. Protocol's replacement of WBTC
    WBTC wBTC; // Reserve Token. Simulate onchain WBTC
    CTRL ctrl; // governance token 
    // governance
    TimelockController governanceTimelockController;
    TimelockController emergencyTimelockController;
    ShiftCtrlGovernor shiftCtrlGovernor;
    ShiftCtrlEmergencyGovernor shiftCtrlEmergencyGovernor;
    GovernanceAction governanceAction;
    // Protocol contracts
    VaultManager vaultManager;
    VaultUtils vaultUtils;
    ReserveSafe cBTCReserveSafe;
    ReserveSafe wBTCReserveSafe;
    Config config;
    ReserveRegistry reserveRegistry;
    ProtocolVault protocolVault;
    TabRegistry tabRegistry;
    TabFactory tabFactory;
    PriceOracle priceOracle;
    PriceOracleManager priceOracleManager;
    VaultKeeper vaultKeeper;
    AuctionManager auctionManager;
    TabERC20 tabERC20;

    constructor() {
        CheatCodes cheats = CheatCodes(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        deployer = address(this);
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

    /// @dev Same deployment with production deployment script/Deploy.s.sol for local test
    function deploy() public {
        // console.log("Deploying contracts...");

        ctrlProxyAdmin = new TabProxyAdmin(deployer);
        ctrl = CTRL(deployCtrl(deployer, address(ctrlProxyAdmin)));
        // console.log("CTRL Proxy Admin: ", address(ctrlProxyAdmin));
        // console.log("CTRL: ", address(ctrl));

        tabProxyAdmin = new TabProxyAdmin(deployer);
        // console.log("TabProxyAdmin: ", address(tabProxyAdmin));

        address[] memory tempAddrs = new address[](0);
        governanceTimelockController = new TimelockController(2 days, tempAddrs, tempAddrs, deployer);
        emergencyTimelockController = new TimelockController(0, tempAddrs, tempAddrs, deployer);
        tabProxyAdmin.transferOwnership(address(governanceTimelockController));
        
        shiftCtrlGovernor = new ShiftCtrlGovernor(IVotes(address(ctrl)), governanceTimelockController);
        shiftCtrlEmergencyGovernor = new ShiftCtrlEmergencyGovernor(IVotes(address(ctrl)), emergencyTimelockController);
        
        governanceTimelockController.grantRole(EXECUTOR_ROLE, address(shiftCtrlGovernor));
        governanceTimelockController.grantRole(PROPOSER_ROLE, address(shiftCtrlGovernor));
        governanceTimelockController.grantRole(CANCELLER_ROLE, address(shiftCtrlGovernor));
        governanceTimelockController.grantRole(TIMELOCK_ADMIN_ROLE, address(shiftCtrlGovernor));

        emergencyTimelockController.grantRole(EXECUTOR_ROLE, address(shiftCtrlEmergencyGovernor));
        emergencyTimelockController.grantRole(PROPOSER_ROLE, address(shiftCtrlEmergencyGovernor));
        emergencyTimelockController.grantRole(CANCELLER_ROLE, address(shiftCtrlEmergencyGovernor));
        emergencyTimelockController.grantRole(TIMELOCK_ADMIN_ROLE, address(shiftCtrlEmergencyGovernor));

        governanceTimelockController.revokeRole(EXECUTOR_ROLE, deployer);
        governanceTimelockController.revokeRole(PROPOSER_ROLE, deployer);
        governanceTimelockController.revokeRole(CANCELLER_ROLE, deployer);
        governanceTimelockController.revokeRole(TIMELOCK_ADMIN_ROLE, deployer);
        
        emergencyTimelockController.revokeRole(EXECUTOR_ROLE, deployer);
        emergencyTimelockController.revokeRole(PROPOSER_ROLE, deployer);
        emergencyTimelockController.revokeRole(CANCELLER_ROLE, deployer);
        emergencyTimelockController.revokeRole(TIMELOCK_ADMIN_ROLE, deployer);

        // console.log("GovernanceTimelockController: ", address(governanceTimelockController));
        // console.log("GovernanceEmergencyTimelockController: ", address(emergencyTimelockController));
        // console.log("ShiftCtrlGovernor: ", address(shiftCtrlGovernor));
        // console.log("ShiftCtrlEmergencyGovernor: ", address(shiftCtrlEmergencyGovernor));

        ctrlProxyAdmin.transferOwnership(address(governanceTimelockController));

        cBTCProxyAdmin = new TabProxyAdmin(deployer);
        cBTC =  CBTC(deployCBTC(address(governanceTimelockController), address(emergencyTimelockController), deployer, address(cBTCProxyAdmin)));
        // console.log("cBTC Proxy Admin: ", address(cBTCProxyAdmin));
        // console.log("cBTC: ", address(cBTC));
        cBTCProxyAdmin.transferOwnership(address(governanceTimelockController));

        wBTCProxyAdmin = new TabProxyAdmin(deployer);
        wBTC = WBTC(deployWBTC(address(governanceTimelockController), address(emergencyTimelockController), deployer, address(wBTCProxyAdmin)));
        // console.log("wBTC Proxy Admin: ", address(wBTCProxyAdmin));
        // console.log("wBTC: ", address(wBTC));
        wBTCProxyAdmin.transferOwnership(address(governanceTimelockController));

        governanceAction = GovernanceAction(deployGovernanceAction(address(governanceTimelockController), address(emergencyTimelockController), deployer, address(tabProxyAdmin)));
        // console.log("GovernanceAction: ", address(governanceAction));
        
        vaultManager = VaultManager(deployVaultManager(address(governanceTimelockController), address(emergencyTimelockController), deployer, address(tabProxyAdmin)));
        // console.log("VaultManager: ", address(vaultManager));

        tabRegistry = new TabRegistry(address(governanceTimelockController), address(emergencyTimelockController), address(governanceAction), deployer, KEEPER_RELAYER, address(vaultManager), address(tabProxyAdmin));
        // console.log("TabRegistry: ", address(tabRegistry));

        // skip ISkybitCreate3Factory on test(anvil)
        tabFactory = new TabFactory(address(governanceTimelockController), address(tabRegistry));

        tabRegistry.setTabFactory(address(tabFactory));
        // console.log("TabFactory: ", address(tabFactory));

        reserveRegistry = new ReserveRegistry(address(governanceTimelockController), address(emergencyTimelockController), address(governanceAction), deployer);
        // console.log("ReserveRegistry: ", address(reserveRegistry));

        cBTCReserveSafe = new ReserveSafe(address(governanceTimelockController), address(emergencyTimelockController), address(vaultManager), address(cBTC));
        reserveRegistry.addReserve(reserve_cBTC, address(cBTC), address(cBTCReserveSafe));
        // console.log("ReserveSafe(CBTC): ", address(cBTCReserveSafe));

        wBTCReserveSafe = new ReserveSafe(address(governanceTimelockController), address(emergencyTimelockController), address(vaultManager), address(wBTC));
        reserveRegistry.addReserve(reserve_wBTC, address(wBTC), address(wBTCReserveSafe));
        // console.log("ReserveSafe(WBTC): ", address(wBTCReserveSafe));

        auctionManager = new AuctionManager(address(governanceTimelockController), address(emergencyTimelockController), address(vaultManager), address(reserveRegistry));
        // console.log("AuctionManager: ", address(auctionManager));

        config = new Config(address(governanceTimelockController), address(emergencyTimelockController), 
            address(governanceAction), deployer, TREASURY, address(tabRegistry), address(auctionManager));
        tabRegistry.setConfigAddress(address(config));
        // console.log("Config: ", address(config));

        vaultUtils = new VaultUtils(address(vaultManager), address(reserveRegistry), address(config));
        // console.log("VaultUtils: ", address(vaultUtils));

        priceOracleManager = PriceOracleManager(deployPriceOracleManager(address(governanceTimelockController), address(emergencyTimelockController), 
            address(governanceAction), deployer, address(tabRegistry), address(tabProxyAdmin)));
        // console.log("PriceOracleManager: ", address(priceOracleManager));

        priceOracle = new PriceOracle(address(governanceTimelockController), address(emergencyTimelockController), address(vaultManager), 
            address(priceOracleManager), address(tabRegistry), PRICE_RELAYER);
        // console.log("PriceOracle: ", address(priceOracle));
        priceOracleManager.setPriceOracle(address(priceOracle));

        vaultKeeper = VaultKeeper(deployVaultKeeper(address(governanceTimelockController), address(emergencyTimelockController), 
            deployer, address(vaultManager), address(config), address(tabProxyAdmin)));
        // console.log("VaultKeeper: ", address(vaultKeeper));

        vaultManager.configContractAddress(
            address(config), address(reserveRegistry), address(tabRegistry), address(priceOracle), address(vaultKeeper)
        ); 
        governanceAction.setContractAddress(
            address(config), address(tabRegistry), address(reserveRegistry), address(priceOracleManager)
        );
        config.setVaultKeeperAddress(address(vaultKeeper));
        tabRegistry.setPriceOracleManagerAddress(address(priceOracleManager));

        bytes32[] memory reserve = new bytes32[](2);
        reserve[0] = reserve_cBTC;
        reserve[1] = reserve_wBTC;
        uint256[] memory processFeeRate = new uint256[](2);
        processFeeRate[0] = 0;
        processFeeRate[1] = 0;
        uint256[] memory minReserveRatio = new uint256[](2);
        minReserveRatio[0] = 180;
        minReserveRatio[1] = 180;
        uint256[] memory liquidationRatio = new uint256[](2);
        liquidationRatio[0] = 120;
        liquidationRatio[1] = 120;
        config.setReserveParams(reserve, processFeeRate, minReserveRatio, liquidationRatio);

        protocolVault = ProtocolVault(deployProtocolVault(deployer, address(vaultManager), address(reserveRegistry), address(tabProxyAdmin)));
        tabRegistry.setProtocolVaultAddress(address(protocolVault));
        // Need to grant MINTER_ROLE to protocolVault for corresponding tab
        // AccessControlInterface(TAB_ADDRESS).grantRole(MINTER_ROLE, protocolVaultAddr);
        // console.log("ProtocolVault: ", address(protocolVault));

        // Revokes permission
        vaultManager.renounceRole(keccak256("DEPLOYER_ROLE"), deployer);
        governanceAction.renounceRole(MAINTAINER_ROLE, deployer);
        tabRegistry.renounceRole(MAINTAINER_ROLE, deployer);
        reserveRegistry.renounceRole(MAINTAINER_ROLE, deployer);
        config.renounceRole(MAINTAINER_ROLE, deployer);
        priceOracleManager.renounceRole(MAINTAINER_ROLE, deployer);
        vaultKeeper.renounceRole(keccak256("DEPLOYER_ROLE"), deployer);

        ctrl.grantRole(keccak256("UPGRADER_ROLE"), address(governanceTimelockController));
        ctrl.grantRole(keccak256("UPGRADER_ROLE"), address(emergencyTimelockController));
        // Ownership transfer is skipped in test script
        // CTRL(ctrl).beginDefaultAdminTransfer(governanceTimelockController);
            // governance to call acceptDefaultAdminTransfer

        signer = new Signer(address(priceOracle));
    }

    function deployCtrl(address _deployer, address _ctrlProxyAdmin) internal returns(address) {
        address ctrlImplementation = address(new CTRL());
        bytes memory ctrlInitData = abi.encodeCall(CTRL.initialize, (_deployer));
        return (
            address(new TransparentUpgradeableProxy(ctrlImplementation, _ctrlProxyAdmin, ctrlInitData))
        );
    }

    function deployCBTC(address _governanceTimelockController, address _governanceAction, address _deployer, address _cBTCProxyAdmin) internal returns(address) {
        address cBTCImplementation = address(new CBTC());
        bytes memory cBtcInitData = abi.encodeCall(CBTC.initialize, (_governanceTimelockController, _governanceAction, _deployer));
        return (
            address(new TransparentUpgradeableProxy(cBTCImplementation, _cBTCProxyAdmin, cBtcInitData))
        );
    }

    function deployWBTC(address _governanceTimelockController, address _governanceAction, address _deployer, address _wBTCProxyAdmin) internal returns(address) {
        address wBTCImplementation = address(new WBTC());
        bytes memory wBtcInitData = abi.encodeCall(WBTC.initialize, (_governanceTimelockController, _governanceAction, _deployer));
        return (
            address(new TransparentUpgradeableProxy(wBTCImplementation, _wBTCProxyAdmin, wBtcInitData))
        );
    }

    function deployGovernanceAction(address _governanceTimelockController, address _emergencyTimelockController, address _deployer, address _tabProxyAdmin) internal returns(address) {
        bytes memory governanceActionInitData = abi.encodeCall(GovernanceAction.initialize, (_governanceTimelockController, _emergencyTimelockController, _deployer));
        GovernanceAction governanceActionImpl = new GovernanceAction(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(governanceActionImpl), _tabProxyAdmin, governanceActionInitData)
        );
    }

    function deployVaultManager(address _governanceTimelockController, address _emergencyTimelockController, address _deployer, address _tabProxyAdmin) internal returns(address) {
        bytes memory vaultManagerInitData =
            abi.encodeCall(VaultManager.initialize, (_governanceTimelockController, _emergencyTimelockController, _deployer));
        VaultManager vaultManagerImpl = new VaultManager(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(vaultManagerImpl), _tabProxyAdmin, vaultManagerInitData)
        );
    }

    function deployPriceOracleManager(
        address _governanceTimelockController,
        address _emergencyTimelockController,
        address _governanceAction, 
        address _deployer, 
        address _tabRegistry, 
        address _tabProxyAdmin
    ) internal returns(address) {
        bytes memory priceOracleManagerInitData = abi.encodeCall(PriceOracleManager.initialize, 
            (_governanceTimelockController, _emergencyTimelockController, _governanceAction, _deployer, PRICE_RELAYER, _tabRegistry)
        );
        PriceOracleManager priceOracleManagerImpl = new PriceOracleManager(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(priceOracleManagerImpl), _tabProxyAdmin, priceOracleManagerInitData)
        );
    }

    function deployVaultKeeper(address _governanceTimelockController, address _emergencyTimelockController, address _deployer, address _vaultManager, address _config, address _tabProxyAdmin) internal returns(address) {
        bytes memory vaultKeeperInitData = abi.encodeCall(VaultKeeper.initialize,
            (_governanceTimelockController, _emergencyTimelockController, _deployer, KEEPER_RELAYER, _vaultManager, _config)
        );
        VaultKeeper vaultKeeperImpl = new VaultKeeper(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(vaultKeeperImpl), _tabProxyAdmin, vaultKeeperInitData)
        );
    }

    function deployProtocolVault(address _governanceTimelockController, address _vaultManager, address _reserveRegisty, address _tabProxyAdmin) internal returns(address) {
        bytes memory initData = abi.encodeCall(ProtocolVault.initialize, (_governanceTimelockController, _vaultManager, _reserveRegisty));
        return address(new TransparentUpgradeableProxy(address(new ProtocolVault()), _tabProxyAdmin, initData));
    }

}
