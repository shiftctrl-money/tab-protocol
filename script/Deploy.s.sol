// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/token/TabERC20.sol";
import "../contracts/TabProxyAdmin.sol";
import "../contracts/token/CTRL.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ISkybitCreate3Factory} from "../contracts/shared/interfaces/ISkybitCreate3Factory.sol";
import "../contracts/token/CBTC.sol";
import "../contracts/governance/TimelockController.sol";
import "../contracts/governance/ShiftCtrlGovernor.sol";
import "../contracts/governance/ShiftCtrlEmergencyGovernor.sol";
import "../contracts/governance/interfaces/IGovernanceAction.sol";
import "../contracts/governance/GovernanceAction.sol";
import "../contracts/VaultManager.sol";
import "../contracts/VaultUtils.sol";
import "../contracts/TabRegistry.sol";
import "../contracts/TabFactory.sol";
import "../contracts/AuctionManager.sol";
import "../contracts/Config.sol";
import "../contracts/ReserveRegistry.sol";
import "../contracts/ReserveSafe.sol";
import "../contracts/oracle/PriceOracle.sol";
import "../contracts/oracle/interfaces/IPriceOracleManager.sol";
import "../contracts/oracle/PriceOracleManager.sol";
import "../contracts/VaultKeeper.sol";
// import "../contracts/ProtocolVault.sol";

// https://www.0xdev.co/how-to-write-scripts-in-solidity-using-foundry/
contract Deploy is Script {
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    bytes32 reserve_cBTC = keccak256("CBTC");

    address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    // deploy from deployKeylessly-Create3Factory.js, factoryToDeploy = `SKYBITSolady`
    address skybitCreate3Factory = 0xA8D5D2166B1FB90F70DF5Cc70EA7a1087bCF1750;
    address UI_USER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;  // 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
    address TREASURY = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
    address PRICE_RELAYER = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
    address KEEPER_RELAYER = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a

    address cBTCProxyAdmin;
    address cBTC;
    address ctrlProxyAdmin;
    address ctrl;
    address tabProxyAdmin;
    address shiftCtrlGovernor;
    address shiftCtrlEmergencyGovernor;
    address governanceTimelockController;
    address emergencyTimelockController;
    address governanceAction;
    address vaultManager;
    address vaultUtils;
    address tabRegistry;
    address tabFactory;
    address auctionManager;
    address config;
    address reserveRegistry;
    address reserveSafe;
    address priceOracleManager;
    address priceOracle;
    address vaultKeeper;
    address protocolVault;


    function run() external {
        // deployer = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployer);

        ctrlProxyAdmin = address(new TabProxyAdmin(deployer));
        ctrl = deployCtrl(deployer, ctrlProxyAdmin);
        console.log("CTRL Proxy Admin: ", ctrlProxyAdmin);
        console.log("CTRL: ", ctrl);

        tabProxyAdmin = address(new TabProxyAdmin(deployer));
        console.log("TabProxyAdmin: ", tabProxyAdmin);

        address[] memory tempAddrs = new address[](0);
        TimelockController delayedTimelock = new TimelockController(2 days, tempAddrs, tempAddrs, deployer);
        TimelockController emergencyTimelock = new TimelockController(0, tempAddrs, tempAddrs, deployer);
        governanceTimelockController = address(delayedTimelock);
        emergencyTimelockController = address(emergencyTimelock);
        TabProxyAdmin(tabProxyAdmin).transferOwnership(governanceTimelockController);
        
        ShiftCtrlGovernor governor = new ShiftCtrlGovernor(IVotes(ctrl), delayedTimelock);
        shiftCtrlGovernor = address(governor);
        ShiftCtrlEmergencyGovernor emergencyGovernor = new ShiftCtrlEmergencyGovernor(IVotes(ctrl), emergencyTimelock);
        shiftCtrlEmergencyGovernor = address(emergencyGovernor);
        
        delayedTimelock.grantRole(EXECUTOR_ROLE, shiftCtrlGovernor);
        delayedTimelock.grantRole(PROPOSER_ROLE, shiftCtrlGovernor);
        delayedTimelock.grantRole(CANCELLER_ROLE, shiftCtrlGovernor);
        delayedTimelock.grantRole(TIMELOCK_ADMIN_ROLE, shiftCtrlGovernor);

        emergencyTimelock.grantRole(EXECUTOR_ROLE, shiftCtrlEmergencyGovernor);
        emergencyTimelock.grantRole(PROPOSER_ROLE, shiftCtrlEmergencyGovernor);
        emergencyTimelock.grantRole(CANCELLER_ROLE, shiftCtrlEmergencyGovernor);
        emergencyTimelock.grantRole(TIMELOCK_ADMIN_ROLE, shiftCtrlEmergencyGovernor);

        delayedTimelock.revokeRole(EXECUTOR_ROLE, deployer);
        delayedTimelock.revokeRole(PROPOSER_ROLE, deployer);
        delayedTimelock.revokeRole(CANCELLER_ROLE, deployer);
        delayedTimelock.revokeRole(TIMELOCK_ADMIN_ROLE, deployer);
        
        emergencyTimelock.revokeRole(EXECUTOR_ROLE, deployer);
        emergencyTimelock.revokeRole(PROPOSER_ROLE, deployer);
        emergencyTimelock.revokeRole(CANCELLER_ROLE, deployer);
        emergencyTimelock.revokeRole(TIMELOCK_ADMIN_ROLE, deployer);

        console.log("GovernanceTimelockController: ", governanceTimelockController);
        console.log("GovernanceEmergencyTimelockController: ", emergencyTimelockController);
        console.log("ShiftCtrlGovernor: ", shiftCtrlGovernor);
        console.log("ShiftCtrlEmergencyGovernor: ", shiftCtrlEmergencyGovernor);

        cBTCProxyAdmin = address(new TabProxyAdmin(deployer));
        cBTC = deployCBTC(governanceTimelockController, emergencyTimelockController, deployer, cBTCProxyAdmin);
        console.log("cBTC Proxy Admin: ", cBTCProxyAdmin);
        console.log("cBTC: ", cBTC);

        governanceAction = deployGovernanceAction(governanceTimelockController, emergencyTimelockController, deployer, tabProxyAdmin);
        console.log("GovernanceAction: ", governanceAction);
        
        vaultManager = deployVaultManager(governanceTimelockController, emergencyTimelockController, deployer, tabProxyAdmin);
        console.log("VaultManager: ", vaultManager);

        tabRegistry = address(new TabRegistry(governanceTimelockController, emergencyTimelockController, governanceAction, deployer, KEEPER_RELAYER, vaultManager, tabProxyAdmin));
        console.log("TabRegistry: ", tabRegistry);
        TabRegistry(tabRegistry).setGovernanceAction(governanceAction);

        // tabFactory = address(new TabFactory(governanceTimelockController, tabRegistry));

        // Given same deployer address, expected TabFactory to be deployed on same address in EVM chains
        // Tab addresses created from TabFactory are expected to be consistent on EVM chains
        // Expect TabFactory address: 0x99eff83A66284459946Ff36E4c8eAa92f07d6782 by deployer 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56
        tabFactory = ISkybitCreate3Factory(skybitCreate3Factory).deploy(
            keccak256(abi.encodePacked("shiftCTRL TabFactory_v1")), 
            abi.encodePacked(type(TabFactory).creationCode, abi.encode(governanceTimelockController, tabRegistry))
        );

        TabRegistry(tabRegistry).setTabFactory(tabFactory);
        console.log("TabFactory: ", tabFactory);

        reserveRegistry = address(new ReserveRegistry(governanceTimelockController, emergencyTimelockController, governanceAction, deployer));
        console.log("ReserveRegistry: ", reserveRegistry);

        reserveSafe = address(new ReserveSafe(governanceTimelockController, emergencyTimelockController, vaultManager, cBTC));
        ReserveRegistry(reserveRegistry).addReserve(reserve_cBTC, cBTC, reserveSafe);
        console.log("ReserveSafe: ", reserveSafe);

        auctionManager = address(new AuctionManager(governanceTimelockController, emergencyTimelockController, vaultManager, reserveRegistry));
        console.log("AuctionManager: ", auctionManager);

        config = address(new Config(governanceTimelockController, emergencyTimelockController, governanceAction, deployer, TREASURY, tabRegistry, auctionManager));
        TabRegistry(tabRegistry).setConfigAddress(config);
        console.log("Config: ", config);

        vaultUtils = address(new VaultUtils(vaultManager, reserveRegistry, config));
        console.log("VaultUtils: ", vaultUtils);

        priceOracleManager = deployPriceOracleManager(governanceTimelockController, emergencyTimelockController, governanceAction, deployer, tabRegistry, tabProxyAdmin);
        console.log("PriceOracleManager: ", priceOracleManager);

        priceOracle = address(new PriceOracle(governanceTimelockController, emergencyTimelockController, vaultManager, priceOracleManager, tabRegistry));
        console.log("PriceOracle: ", priceOracle);
        PriceOracleManager(priceOracleManager).setPriceOracle(priceOracle);

        vaultKeeper = deployVaultKeeper(governanceTimelockController, emergencyTimelockController, deployer, vaultManager, config, tabProxyAdmin);
        console.log("VaultKeeper: ", vaultKeeper);

        VaultManager(vaultManager).configContractAddress(
            config, reserveRegistry, tabRegistry, priceOracle, vaultKeeper
        ); 
        GovernanceAction(governanceAction).setContractAddress(
            config, tabRegistry, reserveRegistry, priceOracleManager
        );
        Config(config).setVaultKeeperAddress(vaultKeeper);
        TabRegistry(tabRegistry).setPriceOracleManagerAddress(priceOracleManager);

        bytes32[] memory reserve = new bytes32[](1);
        reserve[0] = reserve_cBTC;
        uint256[] memory processFeeRate = new uint256[](1);
        processFeeRate[0] = 0;
        uint256[] memory minReserveRatio = new uint256[](1);
        minReserveRatio[0] = 180;
        uint256[] memory liquidationRatio = new uint256[](1);
        liquidationRatio[0] = 120;
        Config(config).setReserveParams(reserve, processFeeRate, minReserveRatio, liquidationRatio);

        // DEPLOY IN FUTURE BASED ON GOVERNANCE DECISION
        // protocolVault = deployProtocolVault(deployer, vaultManager, reserveRegistry, tabProxyAdmin);
        // TabRegistry(tabRegistry).setProtocolVaultAddress(protocolVault);
        // AccessControlInterface(tabRegistry.tabs(tab10[i])).grantRole(MINTER_ROLE, protocolVaultAddr);
        // console.log("ProtocolVault: ", protocolVault);

        // Revokes permission
        VaultManager(vaultManager).renounceRole(keccak256("DEPLOYER_ROLE"), deployer);

        GovernanceAction(governanceAction).renounceRole(keccak256("MAINTAINER_ROLE"), deployer);

        CTRL(ctrl).grantRole(keccak256("UPGRADER_ROLE"), governanceTimelockController);
        CTRL(ctrl).grantRole(keccak256("UPGRADER_ROLE"), emergencyTimelockController);
        CTRL(ctrl).beginDefaultAdminTransfer(governanceTimelockController);
            // governance to call acceptDefaultAdminTransfer
            // governance to call TabRegistry(tabRegistry).grantRole(USER_ROLE, UI_USER);

        vm.stopBroadcast();
    }

    function deployCtrl(address _deployer, address _ctrlProxyAdmin) internal returns(address) {
        address ctrlImplementation = address(new CTRL());
        bytes memory ctrlInitData = abi.encodeWithSignature("initialize(address)", _deployer);
        return (
            address(new TransparentUpgradeableProxy(ctrlImplementation, _ctrlProxyAdmin, ctrlInitData))
        );
    }

    function deployCBTC(address _governanceTimelockController, address _governanceAction, address _deployer, address _cBTCProxyAdmin) internal returns(address) {
        address cBTCImplementation = address(new CBTC());
        bytes memory cBtcInitData = abi.encodeWithSignature("initialize(address,address,address)", _governanceTimelockController, _governanceAction, _deployer);
        return (
            address(new TransparentUpgradeableProxy(cBTCImplementation, _cBTCProxyAdmin, cBtcInitData))
        );
    }

    function deployGovernanceAction(address _governanceTimelockController, address _emergencyTimelockController, address _deployer, address _tabProxyAdmin) internal returns(address) {
        bytes memory governanceActionInitData = abi.encodeWithSignature("initialize(address,address,address)", _governanceTimelockController, _emergencyTimelockController, _deployer);
        GovernanceAction governanceActionImpl = new GovernanceAction(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(governanceActionImpl), _tabProxyAdmin, governanceActionInitData)
        );
    }

    function deployVaultManager(address _governanceTimelockController, address _emergencyTimelockController, address _deployer, address _tabProxyAdmin) internal returns(address) {
        bytes memory vaultManagerInitData =
            abi.encodeWithSignature("initialize(address,address,address)", _governanceTimelockController, _emergencyTimelockController, _deployer);
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
        bytes memory priceOracleManagerInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)", _governanceTimelockController, _emergencyTimelockController, _governanceAction, _deployer, PRICE_RELAYER, _tabRegistry
        );
        PriceOracleManager priceOracleManagerImpl = new PriceOracleManager(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(priceOracleManagerImpl), _tabProxyAdmin, priceOracleManagerInitData)
        );
    }

    function deployVaultKeeper(address _governanceTimelockController, address _emergencyTimelockController, address _deployer, address _vaultManager, address _config, address _tabProxyAdmin) internal returns(address) {
        bytes memory vaultKeeperInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)", _governanceTimelockController, _emergencyTimelockController, _deployer, KEEPER_RELAYER, _vaultManager, _config
        );
        VaultKeeper vaultKeeperImpl = new VaultKeeper(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(vaultKeeperImpl), _tabProxyAdmin, vaultKeeperInitData)
        );
    }

    // function deployProtocolVault(address _governanceTimelockController, address _vaultManager, address _reserveRegistry, address _tabProxyAdmin) internal returns(address) {
    //     bytes memory initData = abi.encodeWithSignature("initialize(address,address,address)", _governanceTimelockController, _vaultManager, _reserveRegistry);
    //     return address(new TransparentUpgradeableProxy(address(new ProtocolVault()), _tabProxyAdmin, initData));
    // }


}