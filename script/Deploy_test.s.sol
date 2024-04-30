// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
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
import "../contracts/ProtocolVault.sol";

// https://www.0xdev.co/how-to-write-scripts-in-solidity-using-foundry/
// FOR LOCAL TEST ONLY
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
    address emergencyTimelockController;
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

    // cast wallet new
    address[] providers = [
        0x480e42Bc01eC92547e7b3E2034CCFdEd5fCfE944,
        0xaac63F8Bbbab775087C7903be493d4B57374Eb8a,
        0x3a611d4f9C9949bb02C636279272762971d51d1A,
        0xa520041DAAa6D44c62eEc048509c909d077f7053,
        0x1de2320Ee1a59bd8ca44618ee3727f5F5ed7B77d,
        0x98bFb8D7b646D3D182a936747C8C2a65Cf74933f,
        0xfFB0A46e3560207355f0b924341054c4b56884A1,
        0x2711AfaA1B054C714fADeAE2c789f430D00B86Dc,
        0xbF88abeBA03e2026f438e3c758F521C0e6d76Cf2,
        0x7339e9eECbD33949ac8F0A48eB2957e77E979140,
        0x716A72B0e6115f81905d499281361f327000E9Ea,
        0x31627aB133046CDf3774e0882625c6225E68600b
    ];
    // address provider1 = 0x480e42Bc01eC92547e7b3E2034CCFdEd5fCfE944; // 0x2b97cb7b54500b63605b62d07e9bacefea5b55baade816b2c72046b34023ba18
    // address provider2 = 0xaac63F8Bbbab775087C7903be493d4B57374Eb8a; // 0xc4baf5377d715b33c2ffaeb408616da193b01fc4b5525167fae38b1fbe2a0084
    // address provider3 = 0x3a611d4f9C9949bb02C636279272762971d51d1A; // 0xf0e219234384219bde8350740a47313a3b2cdb4182d2e6e43b2cb092f9bc3d4b
    // address provider4 = 0xa520041DAAa6D44c62eEc048509c909d077f7053; // 0x2d25f9b63c47dba60b6f7b007341287a6d97912f3e6b78aa6f6704fe3fe2a909
    // address provider5 = 0x1de2320Ee1a59bd8ca44618ee3727f5F5ed7B77d; // 0x3fb32a212a749b95eca04ffdcb2ad0131d9181f44a27ee3f8979a21741642738
    // address provider6 = 0x98bFb8D7b646D3D182a936747C8C2a65Cf74933f; // 0xbcb9210943b99ddd8de171517e9ff971067de39bf42bc1b3d11ef266f7a03249
    // address provider7 = 0xfFB0A46e3560207355f0b924341054c4b56884A1; // 0xa8aaaa46de3f793dba4558706d6e04d1dedf06d3bb0a7a85498720771ebfca41
    // address provider8 = 0x2711AfaA1B054C714fADeAE2c789f430D00B86Dc; // 0x1144df101c59b2a04410b2cfbb3d2870e614d0bea22eaf0ffbb34dde436c82b2
    // address provider9 = 0xbF88abeBA03e2026f438e3c758F521C0e6d76Cf2; // 0x8d0d7a90a084019caa2220b40fdf2c801697c8594fbc1d2c74f19ff0533fd4fe
    // address provider10 = 0x7339e9eECbD33949ac8F0A48eB2957e77E979140; // 0xbea19a33dd9cd87c6999489e3f96d1bd913aa918a19798540221ebc9887a7bb1
    // address provider11 = 0x716A72B0e6115f81905d499281361f327000E9Ea; // 0x2d157dba25236a595078f5611de7c56bfc7cdb299ad946a9bcb0d14cdc69f22c
    // address provider12 = 0x31627aB133046CDf3774e0882625c6225E68600b; // 0x0bd0f8732b535cef0b567d1680bd98025018183f40d58490cc17ff7dd81735ee

    function run() external {
        // uint256 deployer = vm.envUint("PRIVATE_KEY");
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
        ShiftCtrlEmergencyGovernor emergencyGovernor = new ShiftCtrlEmergencyGovernor(IVotes(ctrl), delayedTimelock);
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
        cBTC = deployCBTC(deployer, deployer, deployer, cBTCProxyAdmin);
        console.log("cBTC Proxy Admin: ", cBTCProxyAdmin);
        console.log("cBTC: ", cBTC);

        governanceAction = deployGovernanceAction(deployer, deployer, deployer, tabProxyAdmin);
        console.log("GovernanceAction: ", governanceAction);
        
        vaultManager = deployVaultManager(deployer, deployer, deployer, tabProxyAdmin);
        console.log("VaultManager: ", vaultManager);

        tabRegistry = address(new TabRegistry(deployer, deployer, deployer, deployer, deployer, vaultManager, tabProxyAdmin));
        console.log("TabRegistry: ", tabRegistry);
        TabRegistry(tabRegistry).setGovernanceAction(governanceAction);

        tabFactory = address(new TabFactory(deployer, tabRegistry));
        TabRegistry(tabRegistry).setTabFactory(tabFactory);
        console.log("TabFactory: ", address(tabFactory));

        auctionManager = address(new AuctionManager(deployer, deployer, vaultManager));
        console.log("AuctionManager: ", auctionManager);

        config = address(new Config(deployer, deployer, deployer, deployer, TREASURY, tabRegistry, auctionManager));
        TabRegistry(tabRegistry).setConfigAddress(config);
        console.log("Config: ", config);

        reserveRegistry = address(new ReserveRegistry(deployer, deployer, deployer, deployer));
        console.log("ReserveRegistry: ", reserveRegistry);

        reserveSafe = address(new ReserveSafe(deployer, deployer, vaultManager, cBTC));
        ReserveRegistry(reserveRegistry).addReserve(reserve_cBTC, cBTC, reserveSafe);
        console.log("ReserveSafe: ", reserveSafe);

        priceOracleManager = deployPriceOracleManager(deployer, deployer, governanceAction, deployer, tabRegistry, tabProxyAdmin);
        console.log("PriceOracleManager: ", priceOracleManager);

        priceOracle = address(new PriceOracle(deployer, deployer, vaultManager, priceOracleManager, tabRegistry));
        console.log("PriceOracle: ", priceOracle);
        PriceOracleManager(priceOracleManager).setPriceOracle(priceOracle);

        vaultKeeper = deployVaultKeeper(deployer, deployer, deployer, vaultManager, config, tabProxyAdmin);
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

        // ------------------------------------------- POST-DEPLOYMENT CUSTOM TEST -------------------------------------//

        protocolVault = deployProtocolVault(deployer, vaultManager, reserveRegistry, tabProxyAdmin);
        TabRegistry(tabRegistry).setProtocolVaultAddress(protocolVault);
        // AccessControlInterface(tabRegistry.tabs(tab10[i])).grantRole(MINTER_ROLE, protocolVaultAddr);
        console.log("ProtocolVault: ", protocolVault);

        customExec();

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
            abi.encodeWithSignature("initialize(address,address,address,address)", _governanceTimelockController, _emergencyTimelockController, _deployer, _deployer);
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
            "initialize(address,address,address,address,address,address)", _governanceTimelockController, _emergencyTimelockController, _governanceAction, _deployer, _deployer, _tabRegistry
        );
        PriceOracleManager priceOracleManagerImpl = new PriceOracleManager(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(priceOracleManagerImpl), _tabProxyAdmin, priceOracleManagerInitData)
        );
    }

    function deployVaultKeeper(address _governanceTimelockController, address _emergencyTimelockController, address _deployer, address _vaultManager, address _config, address _tabProxyAdmin) internal returns(address) {
        bytes memory vaultKeeperInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)", _governanceTimelockController, _emergencyTimelockController, _deployer, _deployer, _vaultManager, _config
        );
        VaultKeeper vaultKeeperImpl = new VaultKeeper(); // implementation
        return address(
            new TransparentUpgradeableProxy(address(vaultKeeperImpl), _tabProxyAdmin, vaultKeeperInitData)
        );
    }

    function deployProtocolVault(address _governanceTimelockController, address _vaultManager, address _reserveRegisty, address _tabProxyAdmin) internal returns(address) {
        bytes memory initData = abi.encodeWithSignature("initialize(address,address,address)", _governanceTimelockController, _vaultManager, _reserveRegisty);
        return address(new TransparentUpgradeableProxy(address(new ProtocolVault()), _tabProxyAdmin, initData));
    }

    /// @dev Only used for local testing
    function customExec() internal {
        
        CBTC(cBTC).mint(deployer, 100e18);
        CBTC(cBTC).mint(UI_USER, 100e18);
        CBTC(cBTC).mint(TREASURY, 100e18);
        CBTC(cBTC).approve(vaultManager, 100e18);

        bytes3 sUSD = bytes3(abi.encodePacked("USD"));
        bytes3 sMYR = bytes3(abi.encodePacked("MYR"));
        
        GovernanceAction(governanceAction).createNewTab(sUSD);
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("JPY")));
        GovernanceAction(governanceAction).createNewTab(sMYR);

        // test multiple submissions of price (exceeded 10 price per submission)
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("STD")));
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("XAU")));
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("CLF")));
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("JEP")));
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("KPW")));
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("BMD")));
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("IRR")));
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("SLL")));
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("EUR")));
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("ARS")));
        GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("IDR")));
        
        // GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("GBP")));
        // GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("HKD")));
        // GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("HUF")));
        // GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("IDR")));
        // GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("ILS")));
        // GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("INR")));
        // GovernanceAction(governanceAction).createNewTab(bytes3(abi.encodePacked("ISK")));

        PriceOracle(priceOracle).setDirectPrice(sUSD, 37086793778438155432848, block.timestamp);
        PriceOracle(priceOracle).setDirectPrice(sMYR, 174603438331485931421445, block.timestamp);
        
        VaultManager(vaultManager).createVault(reserve_cBTC, 1e18, sUSD, 1e18);
        VaultManager(vaultManager).createVault(reserve_cBTC, 1e18, sMYR, 1e18);

        bytes memory grantRoleData = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            keccak256("MINTER_ROLE"),
            protocolVault
        );
        Address.functionCall(TabRegistry(tabRegistry).tabs(sUSD), grantRoleData);
        Address.functionCall(TabRegistry(tabRegistry).tabs(sMYR), grantRoleData);

        VaultKeeper(vaultKeeper).setRiskPenaltyFrameInSecond(24 hours);

        // GovernanceAction(governanceAction).ctrlAltDel(sUSD, 37000000000000000000000);
        // GovernanceAction(governanceAction).ctrlAltDel(sMYR, 170000000000000000000000);
        
        GovernanceAction(governanceAction).addPriceOracleProvider(
            providers[0],
            ctrl,
            1e18,
            300,
            168,
            "127.0.0.1"
        );

        GovernanceAction(governanceAction).addPriceOracleProvider(
            providers[1],
            ctrl,
            1e18,
            300,
            168,
            "127.0.0.1,192.168.222.333"
        );

        GovernanceAction(governanceAction).addPriceOracleProvider(
            providers[2],
            ctrl,
            1e18,
            300,
            1,
            "127.0.0.1,192.168.222.333"
        );

        GovernanceAction(governanceAction).addPriceOracleProvider(
            providers[3],
            ctrl,
            1e18,
            300,
            1,
            "127.0.0.1,192.168.222.333"
        );

        for(uint256 n=4; n < providers.length; n++) {
            GovernanceAction(governanceAction).addPriceOracleProvider(
                providers[n],
                ctrl,
                1e18,
                300,
                1,
                "127.0.0.1,192.168.1.25"
            );
        }
    }

}