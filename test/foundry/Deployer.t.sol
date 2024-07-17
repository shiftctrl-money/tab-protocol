// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
// import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
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

interface CheatCodes {

    // Gets address for a given private key, (privateKey) => (address)
    function addr(uint256) external returns (address);

}

abstract contract Deployer {

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    address public owner;
    Signer signer;
    address[] public eoa_accounts;

    TabProxyAdmin cBTCProxyAdmin;
    TabProxyAdmin ctrlProxyAdmin;
    CBTC cBTC;
    WBTC wBTC;
    CTRL ctrl;
    TimelockController timelockController;
    ShiftCtrlGovernor shiftCtrlGovernor;
    ShiftCtrlEmergencyGovernor shiftCtrlEmergencyGovernor;
    address governanceActionAddr;
    TabERC20 tabERC20;
    TabProxyAdmin tabProxyAdmin;
    address vaultManagerAddr;
    VaultManager vaultManager;
    Config config;
    ReserveRegistry reserveRegistry;
    ReserveSafe reserveSafe;
    ReserveSafe wBTCReserveSafe;
    TabRegistry tabRegistry;
    TabFactory tabFactory;
    PriceOracle priceOracle;
    address priceOracleManagerAddr;
    VaultKeeper vaultKeeper;
    address vaultKeeperAddr;
    AuctionManager auctionManager;
    address auctionManagerAddr;

    constructor() {
        CheatCodes cheats = CheatCodes(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        owner = address(this);
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

    function test_deploy() public {
        console.log("Deploying protocol contracts...");
        // refer https://forum.openzeppelin.com/t/uups-upgrades-using-foundry/37065/2 for UUPS upgrade deployment
        // reference

        cBTCProxyAdmin = new TabProxyAdmin(owner);
        ctrlProxyAdmin = new TabProxyAdmin(owner);

        // deploy reserve token: cBTC
        address cBTCImplementation = address(new CBTC());
        bytes memory cBtcInitData = abi.encodeWithSignature("initialize(address,address,address)", owner, owner, owner);
        address cBTCAddr =
            address(new TransparentUpgradeableProxy(cBTCImplementation, address(cBTCProxyAdmin), cBtcInitData));
        cBTC = CBTC(cBTCAddr);

        address wBTCImplementation = address(new WBTC());
        wBTC = WBTC(address(new TransparentUpgradeableProxy(wBTCImplementation, address(cBTCProxyAdmin), cBtcInitData)));

        // deploy governance token: CTRL
        address ctrlImplementation = address(new CTRL());
        bytes memory ctrlInitData = abi.encodeWithSignature("initialize(address)", owner);
        address ctrlAddr =
            address(new TransparentUpgradeableProxy(ctrlImplementation, address(ctrlProxyAdmin), ctrlInitData));
        ctrl = CTRL(ctrlAddr);

        // governance
        address[] memory owners = new address[](1);
        owners[0] = owner;
        timelockController = new TimelockController(0, owners, owners, owner);
        shiftCtrlGovernor = new ShiftCtrlGovernor(IVotes(address(ctrl)), timelockController);
        address shiftCtrlGovernorAddr = address(shiftCtrlGovernor);
        shiftCtrlEmergencyGovernor = new ShiftCtrlEmergencyGovernor(IVotes(address(ctrl)), timelockController);
        address shiftCtrlEmergencyGovernorAddr = address(shiftCtrlEmergencyGovernor);

        timelockController.grantRole(EXECUTOR_ROLE, shiftCtrlGovernorAddr);
        timelockController.grantRole(PROPOSER_ROLE, shiftCtrlGovernorAddr);
        timelockController.grantRole(CANCELLER_ROLE, shiftCtrlGovernorAddr);
        timelockController.grantRole(TIMELOCK_ADMIN_ROLE, shiftCtrlGovernorAddr);

        timelockController.grantRole(EXECUTOR_ROLE, shiftCtrlEmergencyGovernorAddr);
        timelockController.grantRole(PROPOSER_ROLE, shiftCtrlEmergencyGovernorAddr);
        timelockController.grantRole(CANCELLER_ROLE, shiftCtrlEmergencyGovernorAddr);
        timelockController.grantRole(TIMELOCK_ADMIN_ROLE, shiftCtrlEmergencyGovernorAddr);

        timelockController.revokeRole(EXECUTOR_ROLE, owner);
        timelockController.revokeRole(PROPOSER_ROLE, owner);
        timelockController.revokeRole(CANCELLER_ROLE, owner);
        timelockController.revokeRole(TIMELOCK_ADMIN_ROLE, owner);

        // TAB token base code: TabERC20
        tabERC20 = new TabERC20();

        // TabProxyAdmin
        tabProxyAdmin = new TabProxyAdmin(address(timelockController));

        // VaultManager
        bytes memory vaultManagerInitData =
            abi.encodeWithSignature("initialize(address,address,address)", owner, owner, owner);
        VaultManager vaultManagerImpl = new VaultManager(); // implementation
        vaultManagerAddr = address(
            new TransparentUpgradeableProxy(address(vaultManagerImpl), address(tabProxyAdmin), vaultManagerInitData)
        );
        vaultManager = VaultManager(vaultManagerAddr);

        // TabRegistry
        tabRegistry = new TabRegistry(owner, owner, owner, owner, owner, address(vaultManager), address(tabProxyAdmin));

        tabFactory = new TabFactory(owner, address(tabRegistry));
        tabRegistry.setTabFactory(address(tabFactory));

        bytes32 res_cBTC = keccak256("CBTC");
        bytes32 res_wBTC = keccak256("WBTC");

        // ReserveRegistry
        reserveRegistry = new ReserveRegistry(owner, owner, owner, owner);

        // ReserveSafe
        reserveSafe = new ReserveSafe(owner, owner, address(vaultManager), address(cBTC));
        reserveRegistry.addReserve(res_cBTC, address(cBTC), address(reserveSafe));
        wBTCReserveSafe = new ReserveSafe(owner, owner, address(vaultManager), address(wBTC));
        reserveRegistry.addReserve(res_wBTC, address(wBTC), address(wBTCReserveSafe));

        // AuctionManager
        auctionManager = new AuctionManager(owner, owner, vaultManagerAddr, address(reserveRegistry));
        auctionManagerAddr = address(auctionManager);

        // Governance Action
        bytes memory governanceActionInitData =
            abi.encodeWithSignature("initialize(address,address,address)", owner, owner, owner);
        GovernanceAction governanceActionImpl = new GovernanceAction(); // implementation
        governanceActionAddr = address(
            new TransparentUpgradeableProxy(
                address(governanceActionImpl), address(tabProxyAdmin), governanceActionInitData
            )
        );
        tabRegistry.setGovernanceAction(governanceActionAddr);

        // Config
        address treasuryAddr = 0x7045CC042c0571F671236db73ba93BD1B82b2326;
        config = new Config(
            owner, owner, governanceActionAddr, owner, treasuryAddr, address(tabRegistry), auctionManagerAddr
        );
        tabRegistry.setConfigAddress(address(config));

        // PriceOracle
        bytes memory priceOracleManagerInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)",
            owner,
            owner,
            governanceActionAddr,
            owner,
            owner,
            address(tabRegistry)
        );
        PriceOracleManager priceOracleManagerImpl = new PriceOracleManager(); // implementation
        priceOracleManagerAddr = address(
            new TransparentUpgradeableProxy(
                address(priceOracleManagerImpl), address(tabProxyAdmin), priceOracleManagerInitData
            )
        );

        priceOracle = new PriceOracle(owner, owner, address(vaultManager), priceOracleManagerAddr, address(tabRegistry));

        IPriceOracleManager(priceOracleManagerAddr).setPriceOracle(address(priceOracle));

        bytes3[] memory _tabs = new bytes3[](3);
        _tabs[0] = 0x555344; // USD
        _tabs[1] = 0x4D5952; // MYR
        _tabs[2] = 0x4A5059; // JPY
        uint256[] memory _prices = new uint256[](3);
        _prices[0] = 0x0000000000000000000000000000000000000000000005815e55ed50a7120000; // BTC/USD 25998.26
        _prices[1] = 0x0000000000000000000000000000000000000000000019932eb5d23b0b67d000; // BTC/MYR 120774.199278024
        _prices[2] = 0x0000000000000000000000000000000000000000000327528f703dab9edda000; // BTC/JPY 3812472.7205188
        uint256[] memory _timestamps = new uint256[](3);
        _timestamps[0] = block.timestamp;
        _timestamps[1] = block.timestamp;
        _timestamps[2] = block.timestamp;
        priceOracle.setPrice(_tabs, _prices, _timestamps);

        priceOracle.grantRole(USER_ROLE, owner);

        // oracle & keeper
        bytes memory vaultKeeperInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)",
            owner,
            owner,
            owner,
            owner,
            address(vaultManager),
            address(config) // replace address(timelockController) with owner
        );
        VaultKeeper vaultKeeperImpl = new VaultKeeper(); // implementation
        vaultKeeperAddr = address(
            new TransparentUpgradeableProxy(address(vaultKeeperImpl), address(tabProxyAdmin), vaultKeeperInitData)
        );
        vaultKeeper = VaultKeeper(vaultKeeperAddr);
        // vaultKeeper.updateVaultManagerAddress(vaultManagerAddr);
        // vaultManager.grantRole(keccak256("KEEPER_ROLE"), vaultKeeperAddr);

        vaultManager.configContractAddress(
            address(config), address(reserveRegistry), address(tabRegistry), address(priceOracle), vaultKeeperAddr
        );
        console.log("Deployed VaultManager...");

        IGovernanceAction(governanceActionAddr).setContractAddress(
            address(config), address(tabRegistry), address(reserveRegistry), priceOracleManagerAddr
        );
        console.log("Deployment is completed...");

        config.setVaultKeeperAddress(vaultKeeperAddr);
        tabRegistry.setPriceOracleManagerAddress(priceOracleManagerAddr);

        bytes32[] memory res = new bytes32[](1);
        res[0] = res_cBTC;
        uint256[] memory processFeeRate = new uint256[](1);
        processFeeRate[0] = 0;
        uint256[] memory minReserveRatio = new uint256[](1);
        minReserveRatio[0] = 180;
        uint256[] memory liquidationRatio = new uint256[](1);
        liquidationRatio[0] = 120;
        config.setReserveParams(res, processFeeRate, minReserveRatio, liquidationRatio);

        res[0] = res_wBTC;
        config.setReserveParams(res, processFeeRate, minReserveRatio, liquidationRatio);

        signer = new Signer(address(priceOracle));
    }

}
