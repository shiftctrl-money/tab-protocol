// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/token/TabERC20.sol";
import "../contracts/TabProxyAdmin.sol";
import "../contracts/token/CTRL.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "../contracts/token/CBTC.sol";
import "../contracts/governance/TimelockController.sol";
import "../contracts/governance/ShiftCtrlGovernor.sol";
import "../contracts/governance/ShiftCtrlEmergencyGovernor.sol";
import "../contracts/governance/interfaces/IGovernanceAction.sol";
import "../contracts/governance/GovernanceAction.sol";
import "../contracts/VaultManager.sol";
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
    address governanceAction;
    address vaultManager;
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
        ctrl = deployCtrl(deployer, ctrlProxyAdmin); // TODO: review role/permission
        console.log("CTRL Proxy Admin: ", ctrlProxyAdmin);
        console.log("CTRL: ", ctrl);

        tabProxyAdmin = address(new TabProxyAdmin(deployer));
        console.log("TabProxyAdmin: ", tabProxyAdmin);

        address[] memory tempAddrs = new address[](0);
        TimelockController timelockController = new TimelockController(0, tempAddrs, tempAddrs, deployer);
        governanceTimelockController = address(timelockController);
        TabProxyAdmin(tabProxyAdmin).transferOwnership(governanceTimelockController);
        
        ShiftCtrlGovernor governor = new ShiftCtrlGovernor(IVotes(ctrl), timelockController);
        shiftCtrlGovernor = address(governor);
        ShiftCtrlEmergencyGovernor emergencyGovernor = new ShiftCtrlEmergencyGovernor(IVotes(ctrl), timelockController);
        shiftCtrlEmergencyGovernor = address(emergencyGovernor);
        
        timelockController.grantRole(EXECUTOR_ROLE, shiftCtrlGovernor);
        timelockController.grantRole(PROPOSER_ROLE, shiftCtrlGovernor);
        timelockController.grantRole(CANCELLER_ROLE, shiftCtrlGovernor);
        timelockController.grantRole(TIMELOCK_ADMIN_ROLE, shiftCtrlGovernor);

        timelockController.grantRole(EXECUTOR_ROLE, shiftCtrlEmergencyGovernor);
        timelockController.grantRole(PROPOSER_ROLE, shiftCtrlEmergencyGovernor);
        timelockController.grantRole(CANCELLER_ROLE, shiftCtrlEmergencyGovernor);
        timelockController.grantRole(TIMELOCK_ADMIN_ROLE, shiftCtrlEmergencyGovernor);

        timelockController.revokeRole(EXECUTOR_ROLE, deployer);
        timelockController.revokeRole(PROPOSER_ROLE, deployer);
        timelockController.revokeRole(CANCELLER_ROLE, deployer);
        timelockController.revokeRole(TIMELOCK_ADMIN_ROLE, deployer);

        console.log("TimelockController: ", governanceTimelockController);
        console.log("ShiftCtrlGovernor: ", shiftCtrlGovernor);
        console.log("ShiftCtrlEmergencyGovernor: ", shiftCtrlEmergencyGovernor);

        cBTCProxyAdmin = address(new TabProxyAdmin(deployer));
        cBTC = deployCBTC(governanceTimelockController, governanceAction, deployer, cBTCProxyAdmin); // TODO: review role/permission
        console.log("cBTC Proxy Admin: ", cBTCProxyAdmin);
        console.log("cBTC: ", cBTC);

        governanceAction = deployGovernanceAction(governanceTimelockController, deployer, tabProxyAdmin);
        console.log("GovernanceAction: ", governanceAction);
        
        vaultManager = deployVaultManager(governanceTimelockController, deployer, tabProxyAdmin);
        console.log("VaultManager: ", vaultManager);

        tabRegistry = address(new TabRegistry(governanceTimelockController, governanceAction, deployer, KEEPER_RELAYER, vaultManager, tabProxyAdmin));
        console.log("TabRegistry: ", tabRegistry);
        TabRegistry(tabRegistry).setGovernanceAction(governanceAction);

        tabFactory = address(new TabFactory(governanceTimelockController, tabRegistry));
        TabRegistry(tabRegistry).setTabFactory(tabFactory);
        console.log("TabFactory: ", tabFactory);

        auctionManager = address(new AuctionManager(governanceTimelockController, governanceAction, vaultManager));
        console.log("AuctionManager: ", auctionManager);

        config = address(new Config(governanceTimelockController, governanceAction, deployer, TREASURY, tabRegistry, auctionManager));
        TabRegistry(tabRegistry).setConfigAddress(config);
        console.log("Config: ", config);

        reserveRegistry = address(new ReserveRegistry(governanceTimelockController, governanceAction, deployer));
        console.log("ReserveRegistry: ", reserveRegistry);

        reserveSafe = address(new ReserveSafe(governanceTimelockController, vaultManager, cBTC));
        ReserveRegistry(reserveRegistry).addReserve(reserve_cBTC, cBTC, reserveSafe);
        console.log("ReserveSafe: ", reserveSafe);

        priceOracleManager = deployPriceOracleManager(governanceTimelockController, governanceAction, deployer, tabRegistry, tabProxyAdmin);
        console.log("PriceOracleManager: ", priceOracleManager);

        priceOracle = address(new PriceOracle(governanceTimelockController, vaultManager, priceOracleManager, tabRegistry));
        console.log("PriceOracle: ", priceOracle);
        PriceOracleManager(priceOracleManager).setPriceOracle(priceOracle);

        vaultKeeper = deployVaultKeeper(governanceTimelockController, deployer, vaultManager, config, tabProxyAdmin);
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

        // protocolVault = deployProtocolVault(deployer, vaultManager, tabProxyAdmin);
        // TabRegistry(tabRegistry).setProtocolVaultAddress(protocolVault);
        // AccessControlInterface(tabRegistry.tabs(tab10[i])).grantRole(MINTER_ROLE, protocolVaultAddr);
        // console.log("ProtocolVault: ", protocolVault);

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

    function deployGovernanceAction(address _governanceTimelockController, address _deployer, address _tabProxyAdmin) internal returns(address) {
        bytes memory governanceActionInitData = abi.encodeWithSignature("initialize(address,address)", _governanceTimelockController, _deployer);
        GovernanceAction governanceActionImpl = new GovernanceAction(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(governanceActionImpl), _tabProxyAdmin, governanceActionInitData)
        );
    }

    function deployVaultManager(address _governanceTimelockController, address _deployer, address _tabProxyAdmin) internal returns(address) {
        bytes memory vaultManagerInitData =
            abi.encodeWithSignature("initialize(address,address,address)", _governanceTimelockController, _deployer, UI_USER);
        VaultManager vaultManagerImpl = new VaultManager(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(vaultManagerImpl), _tabProxyAdmin, vaultManagerInitData)
        );
    }

    function deployPriceOracleManager(
        address _governanceTimelockController, 
        address _governanceAction, 
        address _deployer, 
        address _tabRegistry, 
        address _tabProxyAdmin
    ) internal returns(address) {
        bytes memory priceOracleManagerInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address)", _governanceTimelockController, _governanceAction, _deployer, PRICE_RELAYER, _tabRegistry
        );
        PriceOracleManager priceOracleManagerImpl = new PriceOracleManager(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(priceOracleManagerImpl), _tabProxyAdmin, priceOracleManagerInitData)
        );
    }

    function deployVaultKeeper(address _governanceTimelockController, address _deployer, address _vaultManager, address _config, address _tabProxyAdmin) internal returns(address) {
        bytes memory vaultKeeperInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address)", _governanceTimelockController, _deployer, KEEPER_RELAYER, _vaultManager, _config
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