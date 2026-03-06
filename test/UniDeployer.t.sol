// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
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
import {UniGovernance} from "../contracts/governance/UniGovernance.sol";
import {ZUniGovernance} from "../contracts/governance/ZUniGovernance.sol";
import {PriceOracle} from "../contracts/oracle/PriceOracle.sol";
import {IPriceOracle} from "../contracts/interfaces/IPriceOracle.sol";
import {IPriceData} from "../contracts/interfaces/IUniTabOperation.sol";
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
import {UniTab} from "../contracts/token/UniTab.sol";
import {ZUniTab} from "../contracts/token/ZUniTab.sol";
import {UniCreateVault} from "../contracts/core/UniCreateVault.sol";
import {ZUniCreateVault} from "../contracts/core/ZUniCreateVault.sol";
import {UniDepositReserve} from "../contracts/core/UniDepositReserve.sol";
import {ZUniDepositReserve} from "../contracts/core/ZUniDepositReserve.sol";
import {UniWithdrawReserve} from "../contracts/core/UniWithdrawReserve.sol";
import {ZUniWithdrawReserve} from "../contracts/core/ZUniWithdrawReserve.sol";
import {UniPaybackTab} from "../contracts/core/UniPaybackTab.sol";
import {UniWithdrawTab} from "../contracts/core/UniWithdrawTab.sol";
import {ZUniWithdrawTab} from "../contracts/core/ZUniWithdrawTab.sol";
import {UniAuctionBid} from "../contracts/core/UniAuctionBid.sol";
import {UniProtocolVaultBuyTab} from "../contracts/core/UniProtocolVaultBuyTab.sol";
import {ZUniProtocolVaultBuyTab} from "../contracts/core/ZUniProtocolVaultBuyTab.sol";
import {UniProtocolVaultSellTab} from "../contracts/core/UniProtocolVaultSellTab.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface CheatCodes {

    // Gets address for a given private key, (privateKey) => (address)
    function addr(uint256) external returns (address);

}

interface ICBBTC {
    function masterMinter() external returns (address);
    function configureMinter(address,uint256) external returns (bool);
}

/**
 * @dev Use command `npx zetachain@latest localnet start` to run localnet.
 * 
[LOCALNET] EVM default wallet address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
[LOCALNET] EVM default wallet private key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
[LOCALNET] Default wallet mnemonic: test test test test test test test test test test test junk

Ethereum (11155112)
┌───────────────┬────────────────────────────────────────────┐
│ Contract      │ Address                                    │
├───────────────┼────────────────────────────────────────────┤
│ erc20Custody  │ 0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f │
├───────────────┼────────────────────────────────────────────┤
│ gateway       │ 0x09635F643e140090A9A8Dcd712eD6285858ceBef │
├───────────────┼────────────────────────────────────────────┤
│ zetaConnector │ 0x67d269191c92Caf3cD7723F116c85e6E9bf55933 │
├───────────────┼────────────────────────────────────────────┤
│ zetaToken     │ 0x7a2088a1bFc9d81c55368AE168C2C02570cB814F │
├───────────────┼────────────────────────────────────────────┤
│ USDC.ETH      │ 0x1fA02b2d6A771842690194Cf62D91bdd92BfE28d │
└───────────────┴────────────────────────────────────────────┘

ZetaChain (31337)
┌───────────────────┬────────────────────────────────────────────┐
│ Contract          │ Address                                    │
├───────────────────┼────────────────────────────────────────────┤
│ gateway           │ 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e │
├───────────────────┼────────────────────────────────────────────┤
│ uniswapV2Factory  │ 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 │
├───────────────────┼────────────────────────────────────────────┤
│ uniswapV2Router02 │ 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 │
├───────────────────┼────────────────────────────────────────────┤
│ uniswapV3Factory  │ 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 │
├───────────────────┼────────────────────────────────────────────┤
│ uniswapV3Router   │ 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853 │
├───────────────────┼────────────────────────────────────────────┤
│ zetaToken         │ 0x5FbDB2315678afecb367f032d93F642f64180aa3 │
├───────────────────┼────────────────────────────────────────────┤
│ ZRC-20 ETH.ETH    │ 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe │
├───────────────────┼────────────────────────────────────────────┤
│ ZRC-20 USDC.ETH   │ 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891 │
├───────────────────┼────────────────────────────────────────────┤
│ ZRC-20 BNB.BNB    │ 0x65a45c57636f9BcCeD4fe193A602008578BcA90b │
├───────────────────┼────────────────────────────────────────────┤
│ ZRC-20 USDC.BNB   │ 0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0 │
└───────────────────┴────────────────────────────────────────────┘

BNB (98)
┌───────────────┬────────────────────────────────────────────┐
│ Contract      │ Address                                    │
├───────────────┼────────────────────────────────────────────┤
│ erc20Custody  │ 0x70e0bA845a1A0F2DA3359C97E0285013525FFC49 │
├───────────────┼────────────────────────────────────────────┤
│ gateway       │ 0x0E801D84Fa97b50751Dbf25036d067dCf18858bF │
├───────────────┼────────────────────────────────────────────┤
│ zetaConnector │ 0x9d4454B023096f34B160D6B654540c56A1F81688 │
├───────────────┼────────────────────────────────────────────┤
│ zetaToken     │ 0x99bbA657f2BbC93c02D617f8bA121cB8Fc104Acf │
├───────────────┼────────────────────────────────────────────┤
│ USDC.BNB      │ 0xf953b3A269d80e3eB0F2947630Da976B896A8C5b │
└───────────────┴────────────────────────────────────────────┘
 */
abstract contract UniDeployer is Test {

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public owner;
    address public deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    // Signer signer;
    // address signerAuthorizedAddr = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // anvil first test acct
    address secureSignerAddr; // replace private key in Signer util.
    address oracleRelayerSignerAddr = 0x6cC15689B28227d97481Fac73614cD8D35ede6D2; 
    address oracleProviderPerformanceSignerAddr = 0x92b6153228B61324cAdCAab510FB38c6661b992e;
    address tabRegistryFreezerAddr = 0x6DA75E7831c14810C285e49D3219bEA63bDf5C14;
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
    IPriceData.UpdatePriceData priceData;
    
    address uniswapV2Router;
    address bnbZrc20;
    address bnbGateway;
    address bnbUsdc;
    address ethereumGateway;
    address ethereumZrc20;
    address ethereumUsdc;
    address zetaZrc20;
    address zetaGateway;
    address zetaEthereumUsdc;
    address zetaBnbUsdc;
    UniGovernance uniGovernance1;
    UniGovernance uniGovernance2;
    ZUniGovernance zUniGovernance;
    UniTab uniTab1;
    UniTab uniTab2;
    ZUniTab zUniTab;
    UniCreateVault uniCreateVault;
    ZUniCreateVault zUniCreateVault;
    UniDepositReserve uniDepositReserve;
    ZUniDepositReserve zUniDepositReserve;
    UniWithdrawReserve uniWithdrawReserve;
    ZUniWithdrawReserve zUniWithdrawReserve;
    UniPaybackTab uniPaybackTab;
    UniWithdrawTab uniWithdrawTab;
    ZUniWithdrawTab zUniWithdrawTab;
    UniAuctionBid uniAuctionBid;
    UniProtocolVaultBuyTab uniProtocolVaultBuyTab;
    ZUniProtocolVaultBuyTab zUniProtocolVaultBuyTab;
    UniProtocolVaultSellTab uniProtocolVaultSellTab;
    CBBTC btcBtc; // BTC.BTC ZRC-20 token on ZetaChain
    
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

        if (block.chainid == 7001) { // ZetaChain Testnet
            tabProxyAdmin = ProxyAdmin(0xF44013D4BE0F452938B0b805Bc5Bf0D3Fbd4102c);
            cbBTC = CBBTC(0x7eC62ECbE14B6E3A8B70942dFDf302B4dd9d6a51);
            ctrl = CTRL(0x193410b8cdeD8F4D63E43D0f2AeD99bd862ed1Bc);
            governanceTimelockController = TimelockController(payable(0x783bDAF73E8F40672421204d6FF3f448767d72c6));
            emergencyTimelockController = TimelockController(payable(0x997275213b66AEAAb4042dF9457F2913969368f2));
            shiftCtrlGovernor = ShiftCTRLGovernor(payable(0x89E7068cf18F22765D1F2902d1BaB8C839B8d013));
            shiftCtrlEmergencyGovernor = ShiftCTRLEmergencyGovernor(payable(0xcb41b90E53C227241cdB018e87797afcE158d061));
            governanceAction = GovernanceAction(0xE1a5CC4599DA4bd2D25F57442222647Fe1B69Dda);
            vaultManager = VaultManager(0xeAf6aB024D4a7192322090Fea1C402a5555cD107);
            tabRegistry = TabRegistry(0x9b2F93f5be029Fbb4Cb51491951943f7368b2f1C);
            tabERC20 = TabERC20(0xE914B685a2912C2F5016EF5b29C7cD7Ec7904815);
            tabFactory = TabFactory(0x83F19d560935F5299E7DE4296e7cb7adA0417525);
            reserveRegistry = ReserveRegistry(0xDA8A64cDFaeb08b3f28b072b0d4aC371953F5B6E);
            reserveSafe = ReserveSafe(0xE8a28176Bed3a53CBF2Bc65B597811909F1A1389);
            auctionManager = AuctionManager(0xB93cb66DFaa0cDA61D83BF9f39A076EA2fa2827B);
            config = Config(0x25B9982A32106EeB2Aa052319011De58A7d33457);
            vaultUtils = VaultUtils(0x99843f8306AecdDC8EE6d47F1A144836D332a5B4);
            priceOracleManager = PriceOracleManager(0xBdFd9503f62A23092504eD072158092B6B3342ac);
            priceOracle = PriceOracle(0x7a65f5f7b2ba2F15468688c8e98835A3f9be2520);
            vaultKeeper = VaultKeeper(0x303818F385f1675BBB07dDE155987f6b7041753c);
            protocolVault = ProtocolVault(0xBC6bef5A3a1211B033322F3730e8DFf2f81AcA84);

            uniswapV2Router = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
            ethereumZrc20 = 0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0;

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
        } else if (block.chainid == 7000) { // ZetaChain Mainnet
            deployer = owner;
            treasuryAddr = 0xC325719B907e2F739d956fB082Fa6De9Fc9d85fD;
            oracleRelayerSignerAddr = 0x7A50C47A1594318dfBFFA26F56c2B47E0d4e113b;
            oracleProviderPerformanceSignerAddr = 0xEC5082fbd4B4FE790F5837cb38B2e30566526485;
            tabRegistryFreezerAddr = 0xc812DEBDe11a4995C657002D67A8D4761BD3EDdA;
            keeperAddr = 0xd16E103f592Db4e6887a835Ac4a7Dc680Bd78500;

            tabProxyAdmin = ProxyAdmin(0x65FB1EF0f9C15b2653421D9008fd7E55889890E2);
            cbBTC = CBBTC(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf); // mainnet existing cbBTC
            vm.startPrank(ICBBTC(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf).masterMinter());
            ICBBTC(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf).configureMinter(address(this), type(uint256).max); // allow tester to mint
            vm.stopPrank();
            cbBTC.mint(deployer, 100e8); // follow default mint amount in simulated local CBBTC
            ctrl = CTRL(0x505568c65fF95E5e97Ca97B476BEb0db64F91499);
            governanceTimelockController = TimelockController(payable(0x75977C03b7AFc9B0E645A6402B2b46E438F146D5));
            emergencyTimelockController = TimelockController(payable(0x4bedAa52B64A4b8aff01a5354516c2897ecEf58B));
            shiftCtrlGovernor = ShiftCTRLGovernor(payable(0x747E429c1ceb8b0FB576650BEd6623785eAb0348));
            shiftCtrlEmergencyGovernor = ShiftCTRLEmergencyGovernor(payable(0x95205Ed4F55a012DCfd1497aEecc3C3A66496b22));
            governanceAction = GovernanceAction(0xEBf09013763412Eb1108257fde050545F780D09c);
            vaultManager = VaultManager(0x11138452B689fd55d5Ad3991A6166dbBb6C2A774);
            tabRegistry = TabRegistry(0x01D988944c3Bb067f56e600619345C3dB161f444);
            tabERC20 = TabERC20(0xf0ab89867c3053f91ebeD2b0dBe44B47BE2A0C13);
            tabFactory = TabFactory(0x83F19d560935F5299E7DE4296e7cb7adA0417525);
            reserveRegistry = ReserveRegistry(0xb59B6ba5426255B669C3966261aC4b2D59A76943);
            reserveSafe = ReserveSafe(0x6cdEB78a62bD94f2c08D6AbB0f1412B0F959a9A0);
            auctionManager = AuctionManager(0x731D9aD52663c2767A48303D09a668F9cE3aecc4);
            config = Config(0xC81455d98AD16db5043c775bD1eCd2677E39e670);
            vaultUtils = VaultUtils(0x4034a758F7CFB316f5923B7a2568D8ff21ea998a);
            priceOracleManager = PriceOracleManager(0x5f6c5A786a1Aa89d3B18606f93Dc6bfA011a2fBC);
            priceOracle = PriceOracle(0x8c3Fd83a9dFEC3D5e389aea60cA980A2e72A9A5A);
            vaultKeeper = VaultKeeper(0xBbFD14d040b7E3b3cC3eef52DCB1E84Cb3E397C5);

            uniswapV2Router = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
            ethereumZrc20 = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891;
            zUniGovernance = ZUniGovernance(payable(0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891)); // TODO

            bytes memory protocolVaultInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                address(zUniGovernance),       // Governance controller
                address(zUniGovernance),       // upgrader
                address(vaultManager),         // Vault manager
                address(reserveSafe)
            );
            ProtocolVault protocolVaultImpl = new ProtocolVault(); // implementation
            address protocolVaultAddr = address(
                new ERC1967Proxy(
                    address(protocolVaultImpl), protocolVaultInitData
                )
            );
            protocolVault = ProtocolVault(protocolVaultAddr);
            vm.startPrank(address(governanceTimelockController));
            tabRegistry.setProtocolVaultAddress(protocolVaultAddr);
            vm.stopPrank();
            console.log("protocolVault: ", address(protocolVault));
            
            signer = new Signer(address(priceOracle), address(this));
            vm.startPrank(address(governanceTimelockController));
            priceOracle.grantRole(keccak256("SIGNER_ROLE"), 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
            vm.stopPrank();
        
            vm.startPrank(address(governanceTimelockController));
            vaultKeeper.grantRole(keccak256("EXECUTOR_ROLE"), 0xd16E103f592Db4e6887a835Ac4a7Dc680Bd78500);
            vaultKeeper.grantRole(keccak256("MAINTAINER_ROLE"), 0xd16E103f592Db4e6887a835Ac4a7Dc680Bd78500);
            vm.stopPrank();

            // remove permissions
            address mainnetDeployer = 0x553A9FB9B5590EE27d8ddc589005afca99D51aa3;
            vm.startPrank(mainnetDeployer);
            tabFactory.transferOwnership(address(governanceTimelockController));
            vaultManager.renounceRole(keccak256("DEPLOYER_ROLE"), mainnetDeployer);
            governanceAction.renounceRole(MAINTAINER_ROLE, mainnetDeployer);
            tabRegistry.renounceRole(MAINTAINER_ROLE, mainnetDeployer);
            reserveRegistry.renounceRole(MAINTAINER_ROLE, mainnetDeployer);
            config.renounceRole(MAINTAINER_ROLE, mainnetDeployer);
            priceOracleManager.renounceRole(MAINTAINER_ROLE, mainnetDeployer);

            ctrl.grantRole(keccak256("MINTER_ROLE"), address(this));
            ctrl.grantRole(UPGRADER_ROLE, address(governanceTimelockController));
            ctrl.grantRole(UPGRADER_ROLE, address(emergencyTimelockController));
            ctrl.beginDefaultAdminTransfer(address(governanceTimelockController));
            vm.stopPrank();
        
            console.log("Skipped deployment, using existing contracts on mainnet.");
        } else { // e.g. anvil, 31337
            deployer = owner;
            oracleRelayerSignerAddr = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

            uniswapV2Router = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0; // uniswapRouterInstance
            bnbZrc20 = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b;
            bnbGateway = 0x0E801D84Fa97b50751Dbf25036d067dCf18858bF;
            bnbUsdc = 0xf953b3A269d80e3eB0F2947630Da976B896A8C5b;
            ethereumGateway = 0x09635F643e140090A9A8Dcd712eD6285858ceBef;
            ethereumZrc20 = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
            ethereumUsdc = 0x1fA02b2d6A771842690194Cf62D91bdd92BfE28d;
            zetaZrc20 = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
            zetaGateway = 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e;
            zetaEthereumUsdc = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891;
            zetaBnbUsdc = 0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0;

            // Single ProxyAdmin used in all upgradeable contracts in the protocol
            tabProxyAdmin = new ProxyAdmin(owner);
            console.log("tabProxyAdmin: ", address(tabProxyAdmin));
            
            // Deploy reserve token: cbBTC
            cbBTC = new CBBTC(owner, "TestCBBTC", "CBBTC");
            console.log("cbBTC: ", address(cbBTC));

            // Deploy governance token: CTRL
            address ctrlImplementation = address(new CTRL());
            bytes memory ctrlInitData = abi.encodeWithSignature("initialize(address,address,address)", owner, owner, owner);
            address ctrlAddr = address(new ERC1967Proxy(
                ctrlImplementation, 
                ctrlInitData
            ));
            ctrl = CTRL(ctrlAddr);
            console.log("CTRL: ", address(ctrl));

            // Governance
            address[] memory tempAddrs = new address[](1);
            tempAddrs[0] = owner;
            governanceTimelockController = new TimelockController(2 days, tempAddrs, tempAddrs, owner);
            emergencyTimelockController = new TimelockController(0, tempAddrs, tempAddrs, owner);

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

            // Base chain UniGovernance: calllable by governanceTimelockController and emergencyTimelockController
            bytes memory uniGovernanceInitData = 
                abi.encodeWithSignature("initialize(address,address,address,address,address,bool)", governance, emergencyGov, governance, owner, ethereumGateway, true);
            UniGovernance uniGovernanceImpl = new UniGovernance();
            address payable uniGovernanceAddr = payable(address(new ERC1967Proxy(
                address(uniGovernanceImpl),
                uniGovernanceInitData
            )));
            uniGovernance1 = UniGovernance(uniGovernanceAddr);
            console.log("UniGovernance1: ", address(uniGovernance1));

            // ZetaChain ZUniGovernance: callable by Base chain UniGovernance contract only
            bytes memory zUniGovernanceInitData = 
                abi.encodeWithSignature("initialize(address,address,address,address,address)", owner, owner, owner, zetaGateway, uniswapV2Router);
            ZUniGovernance zUniGovernanceImpl = new ZUniGovernance();
            address payable zUniGovernanceAddr = payable(address(new ERC1967Proxy(
                address(zUniGovernanceImpl),
                zUniGovernanceInitData
            )));
            zUniGovernance = ZUniGovernance(zUniGovernanceAddr);
            console.log("ZUniGovernance: ", address(zUniGovernance));
            zUniGovernance.grantRole(UPGRADER_ROLE, zUniGovernanceAddr); // able to call itself to upgrade

            // Governance controllers BASE chain execute UniGovernance executeRemote() function
            governance = zUniGovernanceAddr;
            emergencyGov = zUniGovernanceAddr;
            tabProxyAdmin.transferOwnership(zUniGovernanceAddr);

            // Supported chains UniGovernance: callable by ZetaChain ZUniGovernance contract only
            uniGovernanceInitData = 
                abi.encodeWithSignature("initialize(address,address,address,address,address,bool)", governance, emergencyGov, governance, owner, bnbGateway, false);
            uniGovernanceAddr = payable(address(new ERC1967Proxy(
                address(uniGovernanceImpl),
                uniGovernanceInitData
            )));
            uniGovernance2 = UniGovernance(uniGovernanceAddr);
            console.log("UniGovernance2: ", address(uniGovernance2));

            uniGovernance1.setUniversal(zUniGovernanceAddr);
            uniGovernance2.setUniversal(zUniGovernanceAddr);

            address[] memory zrc20 = new address[](3);
            zrc20[0] = ethereumZrc20;
            zrc20[1] = bnbZrc20;
            zrc20[2] = zetaZrc20;
            address[] memory uniGov = new address[](3);
            uniGov[0] = address(uniGovernance1);
            uniGov[1] = address(uniGovernance2);
            uniGov[2] = address(zUniGovernance);
            zUniGovernance.setConnected(zrc20, uniGov); // Destination UniGovernance contract to call on connected chains

            address[] memory senders = new address[](1);
            senders[0] = address(uniGovernance1);
            bool[] memory govIsAuthorized = new bool[](1);
            govIsAuthorized[0] = true;
            zUniGovernance.setAuthorizedSender(senders, govIsAuthorized); // authorized call from UniGovernance1 (governance source chain) only

// TODO - to be deleted / replaced by UniGovernance
bytes memory governanceActionInitData = abi.encodeWithSignature("initialize(address,address,address,address)", 
    address(governanceTimelockController), address(emergencyTimelockController), owner, owner);
GovernanceAction governanceActionImpl = new GovernanceAction(); // implementation
address governanceActionAddr = address(new ERC1967Proxy(
    address(governanceActionImpl), 
    governanceActionInitData
));
governanceAction = GovernanceAction(governanceActionAddr);
console.log("governanceAction: ", address(governanceAction));

            // VaultManager
            bytes memory vaultManagerInitData =
                abi.encodeWithSignature("initialize(address,address,address,address)", governance, emergencyGov, governance, owner);
            VaultManager vaultManagerImpl = new VaultManager(); // implementation
            address vaultManagerAddr = address(new ERC1967Proxy(
                address(vaultManagerImpl), 
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
                tabRegistryFreezerAddr,    // Permission to freeze tab
                address(vaultManager)      // Vault Manager
            );
            console.log("tabRegistry: ", address(tabRegistry));

            // TAB token implementation code: TabERC20
            tabERC20 = new TabERC20();
            console.log("tabERC20: ", address(tabERC20));

            tabFactory = new TabFactory(address(tabERC20), owner); 
            tabFactory.updateCreator(address(tabRegistry));
            console.log("tabFactory: ", address(tabFactory));
            
            tabRegistry.setTabFactory(address(tabFactory));

            // UniTab on Ethereum 
            UniTab uniTabImpl = new UniTab();
            bytes memory uniTabInitData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
                address(uniGovernance1), address(uniGovernance1), address(uniGovernance1), deployer, ethereumGateway, zetaZrc20);
            address payable universalTabAddr = payable(address(new ERC1967Proxy(
                address(uniTabImpl),
                uniTabInitData
            )));
            uniTab1 = UniTab(universalTabAddr);
            console.log("UniTab1: ", address(uniTab1));
            uniTab1.setRevertGasLimit(120000);
            uniTab1.updateDebugSuccess(true, true, true);

            // UniTab on BNB
            uniTabInitData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
                address(uniGovernance2), address(uniGovernance2), address(uniGovernance2), deployer, bnbGateway, zetaZrc20);
            universalTabAddr = payable(address(new ERC1967Proxy(
                address(uniTabImpl),
                uniTabInitData
            )));
            uniTab2 = UniTab(universalTabAddr);
            console.log("UniTab2: ", address(uniTab2));
            uniTab2.setRevertGasLimit(120000);
            uniTab2.updateDebugSuccess(true, true, true);

            // ZUniTab on ZetaChain
            ZUniTab zUniTabImpl = new ZUniTab();
            bytes memory zUniTabinitData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
                zUniGovernanceAddr, zUniGovernanceAddr, zUniGovernanceAddr, deployer, zetaGateway, uniswapV2Router);
            address payable zetaUniversalTabAddr = payable(address(new ERC1967Proxy(
                address(zUniTabImpl),
                zUniTabinitData
            )));
            zUniTab = ZUniTab(zetaUniversalTabAddr);
            console.log("ZUniTab: ", zetaUniversalTabAddr);
            uniTab1.setUniversal(zetaUniversalTabAddr);
            uniTab2.setUniversal(zetaUniversalTabAddr);

            address[] memory zrc20s = new address[](3);
            zrc20s[0] = ethereumZrc20;
            zrc20s[1] = bnbZrc20;
            zrc20s[2] = zetaZrc20;
            address[] memory universals = new address[](3);
            universals[0] = address(uniTab1);
            universals[1] = address(uniTab2);
            universals[2] = zetaUniversalTabAddr;
            zUniTab.setConnected(zrc20s, universals);

            bool[] memory isAuthorized = new bool[](3);
            isAuthorized[0] = true;
            isAuthorized[1] = true;
            isAuthorized[2] = true;
            zUniTab.setAuthorizedSender(universals, isAuthorized);
            
            address[] memory destinations = new address[](3);
            destinations[0] = ethereumZrc20;
            destinations[1] = bnbZrc20;
            destinations[2] = zetaZrc20;
            uint256[] memory gasLimit = new uint256[](3);
            gasLimit[0] = 120000;
            gasLimit[1] = 120000;
            gasLimit[2] = 120000;
            zUniTab.setGasLimit(destinations, gasLimit);

            zUniTab.updateDebugSuccess(true, true, true);
            
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
                governance,                 // Upgrader
                oracleProviderPerformanceSignerAddr,       // Authorized tab-oracle module caller
                address(tabRegistry)        // Tab registry
            );
            PriceOracleManager priceOracleManagerImpl = new PriceOracleManager(); // implementation
            address priceOracleManagerAddr = address(
                new ERC1967Proxy(
                    address(priceOracleManagerImpl), priceOracleManagerInitData
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
                governance,                 // Upgrader
                keeperAddr,                 // Tab-keeper module caller
                address(vaultManager),      // Vault manager
                address(config)             // Config
            );
            VaultKeeper vaultKeeperImpl = new VaultKeeper(); // implementation
            address vaultKeeperAddr = address(
                new ERC1967Proxy(address(vaultKeeperImpl), vaultKeeperInitData)
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

            // Create Tabs
            tabFactory.updateZUniTab(address(zUniTab));
            address sUsd = tabRegistry.createTab(bytes3(abi.encodePacked("USD")));
            console.log("sUsd: ", sUsd);
            address sAud = tabRegistry.createTab(bytes3(abi.encodePacked("AUD")));
            console.log("sAud: ", sAud);
            address sMyr = tabRegistry.createTab(bytes3(abi.encodePacked("MYR")));
            console.log("sMyr: ", sMyr);
            // ZetaChain: set destination Tabs address - assumed destination chains having same Tab addresses with CREATE3 deployer
            bytes32[] memory tabKeys = new bytes32[](3); 
            tabKeys[0] = TabERC20(sUsd).tabKey();
            tabKeys[1] = TabERC20(sAud).tabKey();
            tabKeys[2] = TabERC20(sMyr).tabKey();
            address[] memory destToken = new address[](3);
            destToken[0] = address(sUsd); // assume same address on all supported EVM chains
            destToken[1] = address(sAud);
            destToken[2] = address(sMyr);
            zUniTab.setTabAddress(ethereumZrc20, tabKeys, destToken);
            zUniTab.setTabAddress(bnbZrc20, tabKeys, destToken);
            zUniTab.setTabAddress(zetaZrc20, tabKeys, destToken);

            // ProtocolVault
            bytes memory protocolVaultInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                governance,                 // Governance controller
                governance,                 // upgrader
                vaultManagerAddr,           // Vault manager
                address(reserveSafe)
            );
            ProtocolVault protocolVaultImpl = new ProtocolVault(); // implementation
            address protocolVaultAddr = address(
                new ERC1967Proxy(
                    address(protocolVaultImpl), protocolVaultInitData
                )
            );
            protocolVault = ProtocolVault(protocolVaultAddr);
            // Todo (before executing ctrlAltDel operation): 
            // Revoke MINTER_ROLE from VaultManager on targeted tab.
            // Grant MINTER_ROLE to ProtocolVault on targeted tab.

            tabRegistry.setProtocolVaultAddress(protocolVaultAddr);

            console.log("protocolVault: ", address(protocolVault));

            priceOracleManager.addProvider(
                block.number,
                block.timestamp,
                0x346Ed1282B89D8c948b404C3c3599f8D8ba2AA0e, // provider
                address(ctrl), // paymentTokenAddress: CTRL address
                1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
                150,        // blockCountPerFeed
                10,         // feedSize: minimum number of currency pairs sent by provider
                bytes32(0)  // whitelistedIPAddr: allow sending from any IP
            );
            priceOracleManager.addProvider(
                block.number,
                block.timestamp,
                0xE728C3436836d980AeCd7DcB2935dc808c2E5a5f, // provider
                address(ctrl), // paymentTokenAddress: CTRL address
                1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
                150,        // blockCountPerFeed
                10,         // feedSize: minimum number of currency pairs sent by provider
                bytes32(0)  // whitelistedIPAddr: allow sending from any IP
            );
            priceOracleManager.addProvider(
                block.number,
                block.timestamp,
                0x6EeA49a87c6e46c8EC6C74C9870717eFF8616C3B, // provider
                address(ctrl), // paymentTokenAddress: CTRL address
                1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
                150,        // blockCountPerFeed
                10,         // feedSize: minimum number of currency pairs sent by provider
                bytes32(0)  // whitelistedIPAddr: allow sending from any IP
            );

            signer = new Signer(address(priceOracle), oracleRelayerSignerAddr);

            // remove permissions
            tabFactory.transferOwnership(governance);
            vaultManager.renounceRole(keccak256("DEPLOYER_ROLE"), owner);
            governanceAction.renounceRole(MAINTAINER_ROLE, owner);
            tabRegistry.renounceRole(MAINTAINER_ROLE, owner);
            reserveRegistry.renounceRole(MAINTAINER_ROLE, owner);
            config.renounceRole(MAINTAINER_ROLE, owner);
            priceOracleManager.renounceRole(MAINTAINER_ROLE, owner);

            ctrl.grantRole(UPGRADER_ROLE, address(governanceTimelockController));
            ctrl.grantRole(UPGRADER_ROLE, address(emergencyTimelockController));
            ctrl.beginDefaultAdminTransfer(address(governanceTimelockController));
            // After 1 day grace period, call: governanceController.acceptDefaultAdminTransfer()
        }
    }

    /// @dev Dependency on deploy() function.
    function deployUniWrapper() public {
        btcBtc = new CBBTC(
            owner,
            "ZetaChain ZRC20 BTC on Bitcoin",
            "BTC.BTC"
        );
        vm.startPrank(address(zUniGovernance));
        reserveRegistry.addReserve(address(btcBtc), address(reserveSafe));
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        IERC20(ethereumZrc20).transfer(owner, 60e18);
        IERC20(bnbZrc20).transfer(owner, 150e18);
        IERC20(zetaEthereumUsdc).transfer(owner, 200e18);
        vm.stopPrank();
        btcBtc.mint(owner, 100e8);
        btcBtc.approve(uniswapV2Router, 100e8);
        IERC20(ethereumZrc20).approve(uniswapV2Router, 60e18);
        IERC20(bnbZrc20).approve(uniswapV2Router, 150e18);
        IERC20(zetaEthereumUsdc).approve(uniswapV2Router, 200e18);

        // Dependency on Localnet 
        if (ethereumGateway.code.length > 0 && uniswapV2Router.code.length > 0) {  
            uint256 zetaAmt = 3000000e18; // BTC/ZETA = 60000
            // (uint amountToken, uint amountETH, uint liquidity) = IUniswapV2Router01(uniswapV2Router).addLiquidityETH{value:zetaAmt}(
            IUniswapV2Router01(uniswapV2Router).addLiquidityETH{value:zetaAmt}(
                address(btcBtc),     // token
                5e8,                 // amountTokenDesired
                5e8,                 // amountTokenMin
                zetaAmt,             // amountETHMin
                owner,
                block.timestamp + 1 hours
            ); // 500000000 3000000000000000000000000 38729833462073168
            // console.log("Added liquidity BTC.BTC-ETH:", amountToken, amountETH, liquidity); 

            // (uint amountA, uint amountB, uint liquidity2) = IUniswapV2Router02(uniswapV2Router).addLiquidity(
            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                ethereumZrc20,       // tokenA
                address(btcBtc),     // tokenB
                50e18,               // tokenADesired
                2e8,                 // tokenBDesired
                50e18,               // amountAMin  
                2e8,                 // amountBMin
                owner,               // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            ); // 50000000000000000000 [5e19], 200000000 [2e8], 99999999999000 [9.999e13]
            // console.log("Added liquidity ZETAETH-BTC.BTC:", amountA, amountB, liquidity2); 

            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                ethereumZrc20,       // tokenA
                bnbZrc20,            // tokenB
                10e18,               // tokenADesired
                50e18,               // tokenBDesired
                10e18,               // amountAMin  
                50e18,               // amountBMin
                owner,               // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            );

            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                zetaEthereumUsdc,    // tokenA
                bnbZrc20,            // tokenB
                100e18,              // tokenADesired
                100e18,              // tokenBDesired
                100e18,              // amountAMin  
                50e18,               // amountBMin
                owner,               // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            );

            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                zetaEthereumUsdc,    // tokenA
                address(btcBtc),     // tokenB
                100e18,              // tokenADesired
                100000,              // tokenBDesired
                100e18,              // amountAMin  
                100000,              // amountBMin
                owner,               // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            );
        }

        // Create Vault
        bytes memory initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance1), 
                deployer, 
                deployer, 
                ethereumGateway,
                ethereumZrc20);
        UniCreateVault uniCreateVaultImpl = new UniCreateVault();
        address payable deployedProxyAddr = payable(address(new ERC1967Proxy(address(uniCreateVaultImpl), initData)));
        uniCreateVault = UniCreateVault(deployedProxyAddr);
        console.log("uniCreateVault: ", deployedProxyAddr);

        address[] memory zrc20Addrs = new address[](3);
        zrc20Addrs[0] = ethereumZrc20;
        zrc20Addrs[1] = bnbZrc20;
        zrc20Addrs[2] = zetaZrc20;
        bool[] memory isAuthorized = new bool[](3);
        isAuthorized[0] = true;
        isAuthorized[1] = true;
        isAuthorized[2] = true;
        uniCreateVault.setAuthorizedDestinations(zrc20Addrs, isAuthorized);
        
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address,address,uint256)", 
                address(zUniGovernance), 
                deployer, 
                deployer, 
                zetaGateway,
                address(btcBtc), // BTC.BTC
                deployer, // executor
                uniswapV2Router,
                10333); // _bitcoinChainID
        ZUniCreateVault zUniCreateVaultImpl = new ZUniCreateVault();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(zUniCreateVaultImpl), initData)));
        zUniCreateVault = ZUniCreateVault(deployedProxyAddr);
        console.log("zUniCreateVault: ", deployedProxyAddr);
        
        uint32[] memory chainIds = new uint32[](3);
        chainIds[0] = 11155112;
        chainIds[1] = 98;
        chainIds[2] = 31337; // localnet
        zUniCreateVault.setChainIdToZrc20(chainIds, zrc20Addrs);

        zUniCreateVault.setVaultManager(address(vaultManager));
        zUniCreateVault.setZUniTab(address(zUniTab));
        address[] memory callers = new address[](1);
        callers[0] = address(uniCreateVault);
        bool[] memory authorized = new bool[](1);
        authorized[0] = true;
        zUniCreateVault.setAuthorizedUniCaller(callers, authorized);
        
        uniCreateVault.setRevertGasLimit(120000);
        uniCreateVault.setUniversal(address(zUniCreateVault));

        // Deposit Reserve
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance1), 
                deployer, 
                deployer, 
                ethereumGateway,
                ethereumZrc20);
        UniDepositReserve uniDepositReserveImpl = new UniDepositReserve();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(uniDepositReserveImpl), initData)));
        uniDepositReserve = UniDepositReserve(deployedProxyAddr);
        console.log("uniDepositReserve: ", deployedProxyAddr);
        uniDepositReserve.setRevertGasLimit(120000);
        
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address,uint256)", 
                address(zUniGovernance), 
                deployer, 
                deployer, 
                zetaGateway,
                address(btcBtc), // BTC.BTC
                uniswapV2Router,
                10333); // _bitcoinChainID
        ZUniDepositReserve zUniDepositReserveImpl = new ZUniDepositReserve();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(zUniDepositReserveImpl), initData)));
        zUniDepositReserve = ZUniDepositReserve(deployedProxyAddr);
        console.log("zUniDepositReserve: ", deployedProxyAddr);
        
        zUniDepositReserve.setVaultManager(address(vaultManager));
        callers[0] = address(uniDepositReserve);
        authorized[0] = true;
        zUniDepositReserve.setAuthorizedUniCaller(callers, authorized);
        uniDepositReserve.setUniversal(address(zUniDepositReserve));

        // Withdraw Reserve
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance1), 
                deployer, 
                deployer, 
                ethereumGateway,
                ethereumZrc20);
        UniWithdrawReserve uniWithdrawReserveImpl = new UniWithdrawReserve();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(uniWithdrawReserveImpl), initData)));
        uniWithdrawReserve = UniWithdrawReserve(deployedProxyAddr);
        console.log("uniWithdrawReserve: ", deployedProxyAddr);
        uniWithdrawReserve.setAuthorizedDestinations(zrc20Addrs, isAuthorized);
        
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
                address(zUniGovernance), 
                deployer, 
                deployer, 
                zetaGateway,
                address(btcBtc), // BTC.BTC
                uniswapV2Router);
        ZUniWithdrawReserve zUniWithdrawReserveImpl = new ZUniWithdrawReserve();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(zUniWithdrawReserveImpl), initData)));
        zUniWithdrawReserve = ZUniWithdrawReserve(deployedProxyAddr);
        console.log("zUniWithdrawReserve: ", deployedProxyAddr);
        
        zUniWithdrawReserve.setVaultManager(address(vaultManager));
        callers[0] = address(uniWithdrawReserve);
        authorized[0] = true;
        zUniWithdrawReserve.setAuthorizedUniCaller(callers, authorized);
        uniWithdrawReserve.setUniversal(address(zUniWithdrawReserve));

        // Payback Tab
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance1), 
                deployer, 
                deployer, 
                ethereumGateway,
                ethereumZrc20);
        UniPaybackTab uniPaybackTabImpl = new UniPaybackTab();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(uniPaybackTabImpl), initData)));
        uniPaybackTab = UniPaybackTab(deployedProxyAddr);
        console.log("uniPaybackTab: ", deployedProxyAddr);
        uniPaybackTab.updateZetaToken(zetaZrc20);
        uniPaybackTab.updateVaultManager(address(vaultManager));
        uniPaybackTab.setUniversal(address(zUniTab));
        uniPaybackTab.setUniTab(address(uniTab1));

        // Withdraw Tab
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance1), 
                deployer, 
                deployer, 
                ethereumGateway,
                ethereumZrc20);
        UniWithdrawTab uniWithdrawTabImpl = new UniWithdrawTab();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(uniWithdrawTabImpl), initData)));
        uniWithdrawTab = UniWithdrawTab(deployedProxyAddr);
        console.log("uniWithdrawTab: ", deployedProxyAddr);
        uniWithdrawTab.setAuthorizedDestinations(zrc20Addrs, isAuthorized);
        
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
                address(zUniGovernance), 
                deployer, 
                deployer, 
                zetaGateway,
                address(btcBtc), // BTC.BTC
                uniswapV2Router);
        ZUniWithdrawTab zUniWithdrawTabImpl = new ZUniWithdrawTab();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(zUniWithdrawTabImpl), initData)));
        zUniWithdrawTab = ZUniWithdrawTab(deployedProxyAddr);
        console.log("zUniWithdrawTab: ", deployedProxyAddr);
        
        zUniWithdrawTab.setVaultManager(address(vaultManager));
        callers[0] = address(uniWithdrawTab);
        authorized[0] = true;
        zUniWithdrawTab.setAuthorizedUniCaller(callers, authorized);
        zUniWithdrawTab.setZUniTab(address(zUniTab));
        uniWithdrawTab.setUniversal(address(zUniWithdrawTab));

        // Auction Bid
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance1), 
                deployer, 
                deployer, 
                ethereumGateway,
                ethereumZrc20);
        UniAuctionBid uniAuctionBidImpl = new UniAuctionBid();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(uniAuctionBidImpl), initData)));
        uniAuctionBid = UniAuctionBid(deployedProxyAddr);
        console.log("uniAuctionBid: ", deployedProxyAddr);
        uniAuctionBid.updateZetaToken(zetaZrc20);
        uniAuctionBid.updateAuctionManager(address(auctionManager));
        uniAuctionBid.setUniversal(address(zUniTab));
        uniAuctionBid.setUniTab(address(uniTab1));

        // Buy Tab from Protocol Vault
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance1), 
                deployer, 
                deployer, 
                ethereumGateway,
                ethereumZrc20);
        UniProtocolVaultBuyTab uniProtocolVaultBuyTabImpl = new UniProtocolVaultBuyTab();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(uniProtocolVaultBuyTabImpl), initData)));
        uniProtocolVaultBuyTab = UniProtocolVaultBuyTab(deployedProxyAddr);
        console.log("uniProtocolVaultBuyTab: ", deployedProxyAddr);
        uniProtocolVaultBuyTab.setAuthorizedDestinations(zrc20Addrs, isAuthorized);
        
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
                address(zUniGovernance), 
                deployer, 
                deployer, 
                zetaGateway,
                address(btcBtc), // BTC.BTC
                uniswapV2Router);
        ZUniProtocolVaultBuyTab zUniProtocolVaultBuyTabImpl = new ZUniProtocolVaultBuyTab();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(zUniProtocolVaultBuyTabImpl), initData)));
        zUniProtocolVaultBuyTab = ZUniProtocolVaultBuyTab(deployedProxyAddr);
        console.log("zUniProtocolVaultBuyTab: ", deployedProxyAddr);
        
        zUniProtocolVaultBuyTab.updateProtocolVault(address(protocolVault));
        callers[0] = address(uniProtocolVaultBuyTab);
        authorized[0] = true;
        zUniProtocolVaultBuyTab.setAuthorizedUniCaller(callers, authorized);
        zUniProtocolVaultBuyTab.setZUniTab(address(zUniTab));
        uniProtocolVaultBuyTab.setUniversal(address(zUniProtocolVaultBuyTab));

        // Sell Tab to Protocol Vault
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance1), 
                deployer, 
                deployer, 
                ethereumGateway,
                ethereumZrc20);
        UniProtocolVaultSellTab uniProtocolVaultSellTabImpl = new UniProtocolVaultSellTab();
        deployedProxyAddr = payable(address(new ERC1967Proxy(address(uniProtocolVaultSellTabImpl), initData)));
        uniProtocolVaultSellTab = UniProtocolVaultSellTab(deployedProxyAddr);
        console.log("uniProtocolVaultSellTab: ", deployedProxyAddr);
        uniProtocolVaultSellTab.updateZetaToken(zetaZrc20);
        uniProtocolVaultSellTab.updateProtocolVault(address(protocolVault));
        uniProtocolVaultSellTab.setUniversal(address(zUniTab));
        uniProtocolVaultSellTab.setUniTab(address(uniTab1));

        // zUniTab to authorize additional callers on all chains
        address[] memory universals = new address[](3);
        universals[0] = address(uniPaybackTab);
        universals[1] = address(uniAuctionBid);
        universals[2] = address(uniProtocolVaultSellTab);
        zUniTab.setAuthorizedSender(universals, isAuthorized);
    }

}
