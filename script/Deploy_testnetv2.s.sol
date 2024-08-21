// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/token/TabERC20.sol";
import "../contracts/TabProxyAdmin.sol";
import "../contracts/token/CTRL.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
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

/// @dev testnet rc02, redeploy contracts for on-demand rate related changes
contract DeployTestnetv2 is Script {
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bytes32 reserve_cBTC = keccak256("CBTC");

    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    // deploy from deployKeylessly-Create3Factory.js, factoryToDeploy = `SKYBITSolady`
    address skybitCreate3Factory = 0xA8D5D2166B1FB90F70DF5Cc70EA7a1087bCF1750;
    address UI_USER = 0xf581CDc96bEb07beE51175Ef5dc391cd90E7313e;
    address TREASURY = 0x8e7b315E8c1565aA5caf5cB3Ad6Fa8eDE945307C;
    address PRICE_RELAYER = 0xD3a4079989d39A2994D471650f68E3ec6094c003;
    address KEEPER_RELAYER = 0x930718756DeE144963697D6EB532c9a6Cf10d0F6;

    address cBTCProxyAdmin = 0x6E7fEcDb7c833EA10DC47B34dD15b1e1EdFA8449;
    address cBTC = 0x538a7C3b36315554DDa6B1f8321c2e50fd95a271;
    address ctrlProxyAdmin = 0xf0ab89867c3053f91ebeD2b0dBe44B47BE2A0C13;
    address ctrl = 0xa2e9A36e4535E1c832A6c54aEA4b9954889342d3;
    address tabProxyAdmin = 0xE546f1d0671D79319C71edC1B42089f913bc9971;
    address shiftCtrlGovernor = 0xf6dD022b6404454fe75Bc0276A8E98DEF9D0Fb03;
    address shiftCtrlEmergencyGovernor = 0xF9C8F1ECc0e701204616033f1d52Ff30B83009bB;
    address governanceTimelockController = 0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46;
    address emergencyTimelockController = 0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F;
    address governanceAction = 0x7375C23a3815455D673c7366C2102e3685537B20;
    address vaultManager = 0x6aA52f8b0bDf627f59E635dA95c735232881c93b; // v2
    address vaultUtils = 0xd84E8dfD237D4c8ab47B2291441b1d4826EBDf01; // v2
    address tabRegistry = 0x5B2949601CDD3721FF11bF55419F427c9C118e2c;
    address tabFactory = 0x99eff83A66284459946Ff36E4c8eAa92f07d6782;
    address auctionManager = 0x26aD608DF36147a4fFB43dF8b1509F1093E77121; // v2
    address config = 0x1a13d6a511A9551eC1A493C26362836e80aC4d65;
    address reserveRegistry = 0x666A895b1fcda4272A29d67c40b91a15e469F442;
    address reserveSafe = 0x9120c1Cb0c5eBa7946865E1EEa2C584f2865821C; // v2
    address priceOracleManager = 0xcfE44C253C9b37FDD54d36C600D33Cbf3edfA5B7; // v2
    address priceOracle = 0x4a6D701F5CD7605be2eC9EA1D945f07D8DdbD1f0; // v2
    address vaultKeeper = 0xd67937ca4d249a4caC262B18c3cCB747042Dd51B; // v2
    address protocolVault = 0x67E332459A81F3d64142829541b6fec608356B63;


    function run() external {
        // deployer = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployer);

        vaultManager = deployVaultManager(governanceTimelockController, emergencyTimelockController, deployer, tabProxyAdmin);
        console.log("VaultManager: ", vaultManager);

        TabRegistry(tabRegistry).setVaultManagerAddress(vaultManager);
        TabRegistry(tabRegistry).grantRole(USER_ROLE, vaultManager); // permission to call createTab (retrieve tab address)
        TabRegistry(tabRegistry).grantRole(USER_ROLE, UI_USER); // UI creates tab if needed

        auctionManager = address(new AuctionManager(governanceTimelockController, emergencyTimelockController, vaultManager, reserveRegistry));
        console.log("AuctionManager: ", auctionManager);

        Config(config).setAuctionParams(90, 97, 60, auctionManager);

        reserveSafe = address(new ReserveSafe(governanceTimelockController, emergencyTimelockController, vaultManager, cBTC));
        ReserveRegistry(reserveRegistry).addReserve(reserve_cBTC, cBTC, reserveSafe);
        console.log("ReserveSafe: ", reserveSafe);

        vaultUtils = address(new VaultUtils(vaultManager, reserveRegistry, config));
        console.log("VaultUtils: ", vaultUtils);

        priceOracleManager = deployPriceOracleManager(governanceTimelockController, emergencyTimelockController, governanceAction, deployer, tabRegistry, tabProxyAdmin);
        console.log("PriceOracleManager: ", priceOracleManager);
        PriceOracleManager(priceOracleManager).setDefBlockGenerationTimeInSecond(1);
        // TODO (emergencyGovernor): GovernanceAction.setDefBlockGenerationTimeInSecond(1)

        priceOracle = address(new PriceOracle(governanceTimelockController, emergencyTimelockController, vaultManager, priceOracleManager, tabRegistry, PRICE_RELAYER));
        console.log("PriceOracle: ", priceOracle);
        PriceOracleManager(priceOracleManager).setPriceOracle(priceOracle);

        vaultKeeper = deployVaultKeeper(governanceTimelockController, emergencyTimelockController, deployer, vaultManager, config, tabProxyAdmin);
        console.log("VaultKeeper: ", vaultKeeper);

        VaultManager(vaultManager).configContractAddress(
            config, reserveRegistry, tabRegistry, priceOracle, vaultKeeper
        ); 
        // TODO (emergencyGovernor):
        // GovernanceAction(governanceAction).setContractAddress(
        //     config, tabRegistry, reserveRegistry, priceOracleManager
        // );
        Config(config).setVaultKeeperAddress(vaultKeeper);
        TabRegistry(tabRegistry).setPriceOracleManagerAddress(priceOracleManager);

        // TODO:
        // regularGovernor: restore exiting/created tabs
            // All existing tabs: grantRole(MINTER_ROLE, vaultManager) 
            // optional: PriceOracleManager(priceOracleManager).addNewTab()

        // Use governance to configure redeployed contracts
        proposeEmergency();
        proposeRegularGovernance();

        PriceOracleManager(priceOracleManager).addProvider(
            5944772,
            1716252865,
            0x346Ed1282B89D8c948b404C3c3599f8D8ba2AA0e, 
            0xa2e9A36e4535E1c832A6c54aEA4b9954889342d3, 
            2314814814814814, 
            300, 
            10, 
            bytes32(0)
        );
        PriceOracleManager(priceOracleManager).addProvider(
            5944772,
            1716252865,
            0xE728C3436836d980AeCd7DcB2935dc808c2E5a5f, 
            0xa2e9A36e4535E1c832A6c54aEA4b9954889342d3, 
            2314814814814814, 
            300, 
            10, 
            bytes32(0)
        );
        PriceOracleManager(priceOracleManager).addProvider(
            5944772,
            1716252865,
            0x6EeA49a87c6e46c8EC6C74C9870717eFF8616C3B, 
            0xa2e9A36e4535E1c832A6c54aEA4b9954889342d3, 
            2314814814814814, 
            300, 
            10, 
            bytes32(0)
        );

        vm.stopBroadcast();
    }

    function proposeEmergency() internal {
        address[] memory targets = new address[](1);
        targets[0] = governanceAction;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setContractAddress(address,address,address,address)", config, tabRegistry, reserveRegistry, priceOracleManager);
        IGovernor(shiftCtrlEmergencyGovernor).propose(targets, values, calldatas, "testnetv2-emergency-step1");

        targets = new address[](1);
        targets[0] = governanceAction;
        values = new uint256[](1);
        values[0] = 0;
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setDefBlockGenerationTimeInSecond(uint256)", 1);
        IGovernor(shiftCtrlEmergencyGovernor).propose(targets, values, calldatas, "testnetv2-emergency-step2");
    }

    function proposeRegularGovernance() internal {
        address[] memory targets = new address[](11);
        targets[0] = 0x5cA67204795a100be96f0925c7ED23835E2391c7; // 0x555344   USD
        targets[1] = 0xf70A793d114E95732De23a83a4E44e70203749DB; // 0x41464e   AFN
        targets[2] = 0xBE66de3002BC69989dcADcD70BFed47Eb46E442C; // 0x414544   AED
        targets[3] = 0x80bB8EF4B448F54F7Cc732cb67E362B128FbfE02; // 0x414c4c   ALL
        targets[4] = 0x7F6b8B77a1dBfC40fF337355229aDb13CdcEfd4A; // 0x494e52   INR
        targets[5] = 0xc685A18b03e42dF2cb5E93c51c53Aa38Ff84d8d1; // 0x4d5a4e   MZN
        targets[6] = 0xb6b2D46C7f0e7ed2c677d97AcBE3394994D5330B; // 0x415544   AUD
        targets[7] = 0x9fb50Fe7c3430bbE14425A0ff1CbE36989464d1a; // 0x4d5952   MYR
        targets[8] = 0xfA62ecfe6415bEB90A5A2D7e47a831884DB7C0B5; // 0x545444   TTD
        targets[9] = 0x5708f84945650DCEE2c0771042f7803511215eaF; // 0x414f41   AOA
        targets[10] = 0x23B7B6B34c1AAbf50964371f1d0ccA61700682B3; // 0x42414d  BAM
        uint256 i = 0;
        uint256[] memory values = new uint256[](11);
        for(; i < 11; i++)
            values[i] = 0;
        bytes[] memory calldatas = new bytes[](11);
        calldatas[0] = abi.encodeWithSignature("grantRole(bytes32,address)", MINTER_ROLE, vaultManager);
        for(i = 1; i < 11; i++)
            calldatas[i] = calldatas[0];

        IGovernor(shiftCtrlGovernor).propose(targets, values, calldatas, "testnetv2-regular");
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