// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {CREATE3} from "lib/solady/src/utils/CREATE3.sol";

import {ICREATE3Factory} from "../contracts/interfaces/ICREATE3Factory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CTRL} from "../contracts/token/CTRL.sol";
import {CBBTC} from "../contracts/token/CBBTC.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
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

import {ZUniGovernance} from "../contracts/governance/ZUniGovernance.sol";
import {ZUniTab} from "../contracts/token/ZUniTab.sol";
import {ZUniCreateVault} from "../contracts/core/ZUniCreateVault.sol";
import {ZUniDepositReserve} from "../contracts/core/ZUniDepositReserve.sol";
import {ZUniWithdrawReserve} from "../contracts/core/ZUniWithdrawReserve.sol";
import {ZUniWithdrawTab} from "../contracts/core/ZUniWithdrawTab.sol";
import {ZUniProtocolVaultBuyTab} from "../contracts/core/ZUniProtocolVaultBuyTab.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {SwapHelperLib} from "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @dev To deploy core Tab Protocol contracts to ZetaChain (testnet or mainnet).
 * 
  LocalNet chainId 31337:
  TestCBBTC:  0x2316584D04B025EC90Ae7FAd236C152cAfb6754C
  ZUniGovernance:  0x5d412eF840a56f252060b11192D2441EcfD9137A
  Determined address for  ShiftCTRL_v1.01.001: UniGovernance :  0xfD08512a1EDAcE7EDab28429a05cAe108501cc56
  zUniTab:  0x4d8107756C322134cCDfB33579BC3e3921040E29
  Determined address for  ShiftCTRL_v1.01.001: UniTab :  0xEb8173CDc1fbBF190DF03DF10D066e0703c9e08c
  Determined address for  ShiftCTRL_v1.01.001: UniPaybackTab :  0x61477fD0C27be7648bB5bE99268ecBCd51527a9C
  Determined address for  ShiftCTRL_v1.01.001: UniAuctionBid :  0x383f719Dad554bc535C31539E9F7700EA9587560
  vaultManagerImpl:  0xBB6F0a372cb8104e2898d5e7c052e5637fAF9b4f
  vaultManager:  0x0046fFc38C0Cc854A56b6daeF66946F04d61639B
  tabRegistry:  0xFBE4da9950eddA7F43be8bD49B1F9966B786C542
  TabFactory:  0x02E89328C7B07a1eFE410eaa604A9b5A3C2556de
  TabFactory TabERC20 implementation: 0x9C93FAa3F264f8B099aaEC940a82F1972e8de3ef
  reserveRegistry:  0x3cD93D91fc5Df61A10c86145d27574878136CDFe
  reserveSafe:  0x26200d45B70cB5901b46371E1a0370277530eCa6
  auctionManager:  0x13A0E137Bae4C88A243a48E2d10c1F7227f7f22C
  config:  0x293E347F2e0651a1ddbec114E9bD0Df9Ef223195
  vaultUtils:  0xA4b7eB0F7180f153cD2D6d9A0c09595e01F120aD
  priceOracleManagerImpl:  0x7375C23a3815455D673c7366C2102e3685537B20
  priceOracleManager:  0xB0f26c400f1a8897b44B3c13C916d581aDA230F0
  priceOracle:  0x4D8A74539F8Ab69bb20D0aa51b2b587040861286
  vaultKeeperImpl:  0x8188C7fc2f746998f4b00709C08661caE22b5fa0
  vaultKeeper:  0x9E5d2D8E86067B76B0eC8599Cd17aD9C77775ee3
  zUniCreateVault:  0x79842c65b050ce9e45835261BD50a707Dc0FB25C
  Determined address for  ShiftCTRL_v1.01.001: UniCreateVault :  0xb4BE521b1D2e89a0f40eD10D3615b60f7413CEE8
  zUniDepositReserve:  0x796805d483e6592Ef9977CDA7DD8A8Bc02fD0411
  Determined address for  ShiftCTRL_v1.01.001: UniDepositReserve :  0x30aC390cc81A4A7EBd42c00C87d2229b25370BA8
  zUniWithdrawReserve:  0xe295A65Aa0B41D3BC6c517a61Cbeaf89f647E9c9
  Determined address for  ShiftCTRL_v1.01.001: UniWithdrawReserve :  0xc437dfC119984C8d90E83436DfE90E68F1586ff8
  zUniWithdrawTab:  0x5E0B3463ABA1e685AC7c8Bd5B04dbf6db75B5B04
  Determined address for  ShiftCTRL_v1.01.001: UniWithdrawTab :  0xD7D541788550e2b2f51C46eE299B539342feD4E3
  CTRL:  0xfD0c816B8e028DD5F0F04f9bF58e785325D83D2f
 */
contract DeployCore is Script {
    using Strings for uint256;

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address owner; // deployer
    address create3Factory;
    address btcBtc;
    address sbtcBtc;
    address tbtcBtc;
    address uniGovernance;
    address ethereumZrc20;
    address arbitrumZrc20;
    address baseZrc20;

    address faucetAddr = 0xe23492593e019AbC07255755B2ae813E3DD76F31;
    address treasuryAddr;
    address tabRegistryFreezerAddr;
    address oracleProviderPerformanceSignerAddr;
    address oracleRelayerSignerAddr; // Note: adjust `Signer.sol` to match configured oracle signer to run test.
    address keeperAddr;
    address nativeBtcExecutor;
    uint256 bitcoinChainID;
    
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
    CTRL ctrl;

    address uniswapV2Router;
    address zetaZrc20;
    address zetaGateway;
    ZUniGovernance zUniGovernance;
    ZUniTab zUniTab;
    address uniTab;
    ZUniCreateVault zUniCreateVault;
    ZUniDepositReserve zUniDepositReserve;
    ZUniWithdrawReserve zUniWithdrawReserve;
    ZUniWithdrawTab zUniWithdrawTab;
    ZUniProtocolVaultBuyTab zUniProtocolVaultBuyTab;

    bytes32[] tabKeys;
    address[] destToken;
    
    function run() external {
        uint32[] memory chainIds;

        if (block.chainid == 7000) { // mainnet
            owner = 0x553A9FB9B5590EE27d8ddc589005afca99D51aa3;
            vm.startBroadcast(owner);

            console.log("Deploying contracts to ZetaChain mainnet, chainid: ", block.chainid);
            
            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
            btcBtc = 0x13A0c5930C028511Dc02665E7285134B6d11A5f4;
            ethereumZrc20 = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891;
            arbitrumZrc20 = 0xA614Aebf7924A3Eb4D066aDCA5595E4980407f1d;
            baseZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            zetaGateway = 0xfEDD7A6e3Ef1cC470fbfbF955a22D793dDC0F44E;
            uniswapV2Router = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
            zetaZrc20 = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;

            treasuryAddr = 0x9a5B446FBE216ba583B516BF95B9488174aA78aA;
            tabRegistryFreezerAddr = 0xc812DEBDe11a4995C657002D67A8D4761BD3EDdA;
            oracleProviderPerformanceSignerAddr = 0xEC5082fbd4B4FE790F5837cb38B2e30566526485;
            oracleRelayerSignerAddr = 0x7A50C47A1594318dfBFFA26F56c2B47E0d4e113b;
            keeperAddr = 0xd16E103f592Db4e6887a835Ac4a7Dc680Bd78500;
            nativeBtcExecutor = 0x4d1536512b4c09EBcc371AB8D4A91Be00eE15D5d;
            bitcoinChainID = 8332;
            chainIds = new uint32[](4);
            chainIds[0] = 1;        // Ethereum
            chainIds[1] = 42161;    // Arbitrum
            chainIds[2] = 8453;     // Base
            chainIds[3] = 7000;     // ZetaChain

        } else if (block.chainid == 7001) { // testnet
            owner = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
            vm.startBroadcast(owner);
            
            console.log("Deploying contracts to ZetaChain testnet, chainid: ", block.chainid);
            
            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;

            // Testnet BTC Faucet 
            btcBtc = address(new CBBTC(owner, "TestCBBTC", "CBBTC"));
            console.log("TestCBBTC: ", btcBtc);
            CBBTC(btcBtc).mint(faucetAddr, 1e18);   // 10,000,000,000 btcBTc
            CBBTC(btcBtc).mint(0x16601e7dBf2642bF7832053417eE0E17C9c49f93, 10e8); // tester1

            sbtcBtc = 0xdbfF6471a79E5374d771922F2194eccc42210B9F;
            tbtcBtc = 0xfC9201f4116aE6b054722E10b98D904829b469c3;
            ethereumZrc20 = 0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0;
            arbitrumZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            baseZrc20 = 0x236b0DE675cC8F46AE186897fCCeFe3370C9eDeD;
            zetaZrc20 = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
            uniswapV2Router = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
            zetaGateway = 0x6c533f7fE93fAE114d0954697069Df33C9B74fD7;

            treasuryAddr = 0x8e7b315E8c1565aA5caf5cB3Ad6Fa8eDE945307C;
            tabRegistryFreezerAddr = 0x6DA75E7831c14810C285e49D3219bEA63bDf5C14;
            oracleProviderPerformanceSignerAddr = 0x92b6153228B61324cAdCAab510FB38c6661b992e;
            oracleRelayerSignerAddr = 0x6cC15689B28227d97481Fac73614cD8D35ede6D2;
            keeperAddr = 0x930718756DeE144963697D6EB532c9a6Cf10d0F6;
            nativeBtcExecutor = 0x4d1536512b4c09EBcc371AB8D4A91Be00eE15D5d;
            bitcoinChainID = 18334; // 10333 btc_signet_testnet, 18334 btc_testnet4
            chainIds = new uint32[](4);
            chainIds[0] = 11155112;
            chainIds[1] = 421614;
            chainIds[2] = 84532;
            chainIds[3] = 7001;

        } else if (block.chainid == 31337) { // localnet
            owner = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
            vm.startBroadcast(owner);

            console.log("Deploying contracts to ZetaChain localnet, chainid: ", block.chainid);

            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;

            // Testnet BTC Faucet 
            btcBtc= ICREATE3Factory(create3Factory).deploy(
                keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: CBBTC")),
                abi.encodePacked(type(CBBTC).creationCode, abi.encode(owner, "TestCBBTC", "CBBTC"))
            );
            console.log("TestCBBTC: ", btcBtc);
            CBBTC(btcBtc).mint(faucetAddr, 1e18);   // 10,000,000,000 btcBTc
            CBBTC(btcBtc).mint(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 1e18); // localnet 10,000,000,000 btcBTc
            CBBTC(btcBtc).mint(0x16601e7dBf2642bF7832053417eE0E17C9c49f93, 10e8); // tester1

            sbtcBtc = address(0);
            tbtcBtc = address(0);
            ethereumZrc20 = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
            arbitrumZrc20 = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
            baseZrc20 = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b; // ZRC-20 BNB.BNB
            zetaZrc20 = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
            uniswapV2Router = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
            zetaGateway = 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e;

            treasuryAddr = 0x7045CC042c0571F671236db73ba93BD1B82b2326;
            tabRegistryFreezerAddr = 0x6DA75E7831c14810C285e49D3219bEA63bDf5C14;
            oracleProviderPerformanceSignerAddr = 0x92b6153228B61324cAdCAab510FB38c6661b992e;
            oracleRelayerSignerAddr = 0x6cC15689B28227d97481Fac73614cD8D35ede6D2;
            keeperAddr = 0x930718756DeE144963697D6EB532c9a6Cf10d0F6;
            nativeBtcExecutor = 0x4d1536512b4c09EBcc371AB8D4A91Be00eE15D5d;
            bitcoinChainID = 18334; // 10333 btc_signet_testnet, 18334 btc_testnet4
            chainIds = new uint32[](4);
            chainIds[0] = 11155112; // ethereum sepolia testnet
            chainIds[1] = 98;       // bnb localnet testnet
            chainIds[2] = 98;       // bnb localnet testnet
            chainIds[3] = 31337;    // zetachain localnet testnet

        } else {
            console.log("Unsupported chainid: ", block.chainid);
            return;
        }

        // ZetaChain ZUniGovernance: callable by Base chain UniGovernance contract only
        bytes memory zUniGovernanceInitData = 
            abi.encodeWithSignature("initialize(address,address,address,address,address)", owner, owner, owner, zetaGateway, uniswapV2Router);
        ZUniGovernance zUniGovernanceImpl = new ZUniGovernance();
        address payable zUniGovernanceAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ZUniGovernance")), 
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(zUniGovernanceImpl), zUniGovernanceInitData))
        ));
        zUniGovernance = ZUniGovernance(zUniGovernanceAddr);
        console.log("ZUniGovernance: ", address(zUniGovernance));
        zUniGovernance.grantRole(UPGRADER_ROLE, zUniGovernanceAddr); // able to call itself to upgrade

        address governance = zUniGovernanceAddr;
        address emergencyGov = zUniGovernanceAddr;

        // Destination UniGovernance contract to call on connected chains
        uniGovernance = _determinedContractAddress("ShiftCTRL_v1.01.001: UniGovernance");
        address[] memory zrc20 = new address[](4);
        zrc20[0] = ethereumZrc20;
        zrc20[1] = arbitrumZrc20;
        zrc20[2] = baseZrc20;
        zrc20[3] = zetaZrc20;
        address[] memory uniGov = new address[](4);
        uniGov[0] = uniGovernance;
        uniGov[1] = uniGovernance;
        uniGov[2] = uniGovernance;
        uniGov[3] = address(zUniGovernance);
        zUniGovernance.setConnected(zrc20, uniGov);

        // Authorized caller from supported chains. 
        // Assumed same UniGovernance contract address so only set one address
        address[] memory senders = new address[](1);
        senders[0] = uniGovernance;
        bool[] memory govIsAuthorized = new bool[](1);
        govIsAuthorized[0] = true;
        zUniGovernance.setAuthorizedSender(senders, govIsAuthorized);

        // ZUniTab
        ZUniTab zUniTabImpl = new ZUniTab();
        bytes memory zUniTabinitData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            governance, governance, governance, owner, zetaGateway, uniswapV2Router);
        address payable zetaUniversalTabAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ZUniTab")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(zUniTabImpl), zUniTabinitData))
        ));
        zUniTab = ZUniTab(zetaUniversalTabAddr);
        console.log("zUniTab: ", zetaUniversalTabAddr);
        uniTab = _determinedContractAddress("ShiftCTRL_v1.01.001: UniTab");
        
        // zUniTab to authorize additional callers on all chains
        address[] memory universals = new address[](3);
        universals[0] = uniTab;
        universals[1] = _determinedContractAddress("ShiftCTRL_v1.01.001: UniPaybackTab");
        universals[2] = _determinedContractAddress("ShiftCTRL_v1.01.001: UniAuctionBid");
        bool[] memory isAuthorized = new bool[](3);
        isAuthorized[0] = true;
        isAuthorized[1] = true;
        isAuthorized[2] = true;
        zUniTab.setAuthorizedSender(universals, isAuthorized);
        if (block.chainid == 7001) { // for testnet, authorized UniProtocolVault 
            address[] memory authSender = new address[](1);
            authSender[0] = _determinedContractAddress("ShiftCTRL_v1.01.001: UniProtocolVaultSellTab");
            bool[] memory auth = new bool[](1);
            auth[0] = true;
            zUniTab.setAuthorizedSender(authSender, auth);
        }

        // set connected destination uniTab
        address[] memory uniTabs = new address[](4);
        uniTabs[0] = uniTab;
        uniTabs[1] = uniTab;
        uniTabs[2] = uniTab;
        uniTabs[3] = zetaUniversalTabAddr;
        zUniTab.setConnected(zrc20, uniTabs);

        // connected uniTab gas limit
        uint256[] memory gasLimit = new uint256[](4);
        gasLimit[0] = 130000;
        gasLimit[1] = 130000;
        gasLimit[2] = 130000;
        gasLimit[3] = 130000;
        zUniTab.setGasLimit(zrc20, gasLimit);
        zUniTab.updateDebugSuccess(true, true, true);

        // VaultManager
        bytes memory vaultManagerInitData =
            abi.encodeWithSignature("initialize(address,address,address,address)", governance, emergencyGov, emergencyGov, owner);
        VaultManager vaultManagerImpl = new VaultManager(); // implementation
        console.log("vaultManagerImpl: ", address(vaultManagerImpl));
        address vaultManagerAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: VaultManager")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(vaultManagerImpl), vaultManagerInitData))
        );
        vaultManager = VaultManager(vaultManagerAddr);
        console.log("vaultManager: ", address(vaultManager));

        // TabRegistry
        address tabRegistryAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: TabRegistry")),
            abi.encodePacked(type(TabRegistry).creationCode, abi.encode(
                block.chainid == 31337? owner : governance,                // Governance controller
                emergencyGov,              // Emergency governance controller
                governance,                // Governance action
                owner,                     // Deployer
                tabRegistryFreezerAddr,    // Tab freezer
                address(vaultManager)      // Vault Manager
            ))
        );
        tabRegistry = TabRegistry(tabRegistryAddr);
        console.log("tabRegistry: ", address(tabRegistry));

        // TabFactory
        tabFactory = TabFactory(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: TabFactory")), 
            abi.encodePacked(type(TabFactory).creationCode, abi.encode(address(new TabERC20()), owner))
        ));
        console.log("TabFactory: ", address(tabFactory));
        console.log("TabFactory TabERC20 implementation:", tabFactory.implementation());
        
        tabFactory.updateCreator(address(tabRegistry));
        tabFactory.updateZUniTab(address(zUniTab));
        
        tabRegistry.setTabFactory(address(tabFactory));

        // ReserveRegistry
        address reserveRegistryAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ReserveRegistry")),
            abi.encodePacked(type(ReserveRegistry).creationCode, abi.encode(governance, emergencyGov, governance, owner))
        );
        reserveRegistry = ReserveRegistry(reserveRegistryAddr);
        console.log("reserveRegistry: ", address(reserveRegistry));

        // ReserveSafe
        address reserveSafeAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ReserveSafe")),
            abi.encodePacked(type(ReserveSafe).creationCode, abi.encode(governance, emergencyGov, address(vaultManager), address(reserveRegistry)))
        );
        reserveSafe = ReserveSafe(reserveSafeAddr);
        reserveRegistry.updateReserveSafe(address(reserveSafe));
        reserveRegistry.addReserve(btcBtc, address(reserveSafe));
        if (block.chainid == 7001) { // testnet
            reserveRegistry.addReserve(sbtcBtc, address(reserveSafe));
            reserveRegistry.addReserve(tbtcBtc, address(reserveSafe));
        }
        console.log("reserveSafe: ", address(reserveSafe));

        // AuctionManager
        address auctionManagerAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: AuctionManager")),
            abi.encodePacked(type(AuctionManager).creationCode, abi.encode(governance, emergencyGov, address(vaultManager), address(reserveSafe)))
        );
        auctionManager = AuctionManager(auctionManagerAddr);
        console.log("auctionManager: ", address(auctionManager));

        // Config
        address configAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: Config")),
            abi.encodePacked(type(Config).creationCode, abi.encode(
                governance,                 // Governance controller
                emergencyGov,               // Emergency governance controller
                governance,                 // Governance action
                owner,                      // Deployer
                treasuryAddr,               // Treasury
                address(tabRegistry),       // Tab registry
                address(auctionManager)     // Auction manager
            ))
        );
        config = Config(configAddr);
        tabRegistry.setConfigAddress(address(config));
        console.log("config: ", address(config));

        // VaultUtils
        address vaultUtilsAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: VaultUtils")),
            abi.encodePacked(type(VaultUtils).creationCode, abi.encode(governance, vaultManagerAddr, address(config)))
        );
        vaultUtils = VaultUtils(vaultUtilsAddr);
        console.log("vaultUtils: ", address(vaultUtils));

        // PriceOracleManager
        bytes memory priceOracleManagerInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address,address)",
            governance,                 // Governance controller
            emergencyGov,               // Emergency governance controller
            governance,                 // Governance action
            owner,                      // Deployer
            emergencyGov,               // Upgrader
            oracleProviderPerformanceSignerAddr, // Provider feed count submission
            address(tabRegistry)        // Tab registry
        );
        PriceOracleManager priceOracleManagerImpl = new PriceOracleManager(); // implementation
        console.log("priceOracleManagerImpl: ", address(priceOracleManagerImpl));
        address priceOracleManagerAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: PriceOracleManager")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(new PriceOracleManager()), priceOracleManagerInitData))
        );
        priceOracleManager = PriceOracleManager(priceOracleManagerAddr);
        tabRegistry.setPriceOracleManagerAddress(priceOracleManagerAddr);
        console.log("priceOracleManager: ", address(priceOracleManager));

        // PriceOracle
        address priceOracleAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: PriceOracle")),
            abi.encodePacked(type(PriceOracle).creationCode, abi.encode(
                governance,                 // Governance action
                emergencyGov,               // Emergency governance action
                address(vaultManager),      // Vault manager
                priceOracleManagerAddr,     // Price oracle manager
                address(tabRegistry),       // Tab registry
                oracleRelayerSignerAddr     // Oracle price signer
            ))
        );
        priceOracle = PriceOracle(priceOracleAddr);
        priceOracleManager.setPriceOracle(address(priceOracle));
        console.log("priceOracle: ", address(priceOracle));

        // Vault keeper
        bytes memory vaultKeeperInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)",
            governance,                 // Governance controller
            emergencyGov,               // Emergency governance controller
            emergencyGov,               // Upgrader
            keeperAddr,                 // Tab-keeper module caller
            address(vaultManager),      // Vault manager
            address(config)             // Config
        );
        VaultKeeper vaultKeeperImpl = new VaultKeeper(); // implementation
        console.log("vaultKeeperImpl: ", address(vaultKeeperImpl));
        address vaultKeeperAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: VaultKeeper")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(vaultKeeperImpl), vaultKeeperInitData))
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
        if (block.chainid == 7001) { // testnet only
            bytes memory protocolVaultInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                governance,                 // Governance controller
                emergencyGov,               // upgrader
                vaultManagerAddr,           // Vault manager
                address(reserveSafe)
            );
            ProtocolVault protocolVaultImpl = new ProtocolVault(); // implementation
            console.log("protocolVaultImpl: ", address(protocolVaultImpl));
            address protocolVaultAddr = ICREATE3Factory(create3Factory).deploy(
                keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ProtocolVault")),
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(protocolVaultImpl), protocolVaultInitData))
            );
            protocolVault = ProtocolVault(protocolVaultAddr);
            // Todo (before executing ctrlAltDel operation): 
            // Revoke MINTER_ROLE from VaultManager on targeted tab.
            // Grant MINTER_ROLE to ProtocolVault on targeted tab.

            tabRegistry.setProtocolVaultAddress(protocolVaultAddr);

            console.log("protocolVault: ", address(protocolVault));
        }

        // ZUniCreateVault
        bytes memory initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address,address,uint256)", 
                governance, 
                owner, 
                owner, 
                zetaGateway,
                btcBtc,            // BTC.BTC
                nativeBtcExecutor, // executor
                uniswapV2Router,
                bitcoinChainID);   // _bitcoinChainID
        ZUniCreateVault zUniCreateVaultImpl = new ZUniCreateVault();
        address payable deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ZUniCreateVault")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(zUniCreateVaultImpl), initData))
        ));
        zUniCreateVault = ZUniCreateVault(deployedProxyAddr);
        console.log("zUniCreateVault: ", deployedProxyAddr);
        
        zUniCreateVault.setChainIdToZrc20(chainIds, zrc20);

        zUniCreateVault.setVaultManager(address(vaultManager));
        zUniCreateVault.setZUniTab(address(zUniTab));
        address[] memory callers = new address[](1);
        callers[0] = _determinedContractAddress("ShiftCTRL_v1.01.001: UniCreateVault");
        bool[] memory authorized = new bool[](1);
        authorized[0] = true;
        zUniCreateVault.setAuthorizedUniCaller(callers, authorized);
        
        // ZUniDepositReserve
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address,uint256)", 
                governance, 
                owner, 
                owner, 
                zetaGateway,
                btcBtc, // BTC.BTC
                uniswapV2Router,
                bitcoinChainID); // _bitcoinChainID
        ZUniDepositReserve zUniDepositReserveImpl = new ZUniDepositReserve();
        deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ZUniDepositReserve")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(zUniDepositReserveImpl), initData))
        ));
        zUniDepositReserve = ZUniDepositReserve(deployedProxyAddr);
        console.log("zUniDepositReserve: ", deployedProxyAddr);
        
        zUniDepositReserve.setVaultManager(address(vaultManager));
        callers[0] = _determinedContractAddress("ShiftCTRL_v1.01.001: UniDepositReserve");
        zUniDepositReserve.setAuthorizedUniCaller(callers, authorized);
        
        // ZUniWithdrawReserve
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
                governance, 
                owner, 
                owner, 
                zetaGateway,
                btcBtc, // BTC.BTC
                uniswapV2Router);
        ZUniWithdrawReserve zUniWithdrawReserveImpl = new ZUniWithdrawReserve();
        deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ZUniWithdrawReserve")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(zUniWithdrawReserveImpl), initData))
        ));
        zUniWithdrawReserve = ZUniWithdrawReserve(deployedProxyAddr);
        console.log("zUniWithdrawReserve: ", deployedProxyAddr);
        
        zUniWithdrawReserve.setVaultManager(address(vaultManager));
        callers[0] = _determinedContractAddress("ShiftCTRL_v1.01.001: UniWithdrawReserve");
        zUniWithdrawReserve.setAuthorizedUniCaller(callers, authorized);
        
        // ZUniWithdrawTab
        initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
                governance, 
                owner, 
                owner, 
                zetaGateway,
                btcBtc, // BTC.BTC
                uniswapV2Router);
        ZUniWithdrawTab zUniWithdrawTabImpl = new ZUniWithdrawTab();
        deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ZUniWithdrawTab")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(zUniWithdrawTabImpl), initData))
        ));
        zUniWithdrawTab = ZUniWithdrawTab(deployedProxyAddr);
        console.log("zUniWithdrawTab: ", deployedProxyAddr);
        
        zUniWithdrawTab.setVaultManager(address(vaultManager));
        callers[0] = _determinedContractAddress("ShiftCTRL_v1.01.001: UniWithdrawTab");
        zUniWithdrawTab.setAuthorizedUniCaller(callers, authorized);
        zUniWithdrawTab.setZUniTab(address(zUniTab));
        
        if (block.chainid == 7001) {
            // ZUniProtocolVaultBuyTab
            initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
                    governance, 
                    owner, 
                    owner, 
                    zetaGateway,
                    btcBtc, // BTC.BTC
                    uniswapV2Router);
            ZUniProtocolVaultBuyTab zUniProtocolVaultBuyTabImpl = new ZUniProtocolVaultBuyTab();
            deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
                keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: ZUniProtocolVaultBuyTab")),
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(zUniProtocolVaultBuyTabImpl), initData))
            ));
            zUniProtocolVaultBuyTab = ZUniProtocolVaultBuyTab(deployedProxyAddr);
            console.log("zUniProtocolVaultBuyTab: ", deployedProxyAddr);
            
            zUniProtocolVaultBuyTab.updateProtocolVault(address(protocolVault));
            callers[0] = _determinedContractAddress("ShiftCTRL_v1.01.001: UniProtocolVaultBuyTab");
            zUniProtocolVaultBuyTab.setAuthorizedUniCaller(callers, authorized);
            zUniProtocolVaultBuyTab.setZUniTab(address(zUniTab));
        }

        // CTRL token should be minted in BASE chain (for governance) and transfer cross-chain as needed.
        address ctrlImplementation = address(new CTRL());
        bytes memory ctrlInitData = abi.encodeWithSignature("initialize(address,address,address)", owner, owner, governance);
        address ctrlAddr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: CTRL")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(ctrlImplementation), ctrlInitData))
        );
        ctrl = CTRL(ctrlAddr);
        console.log("CTRL: ", address(ctrl));
        ctrl.grantRole(MINTER_ROLE, address(zUniTab));

        // Default 3 oracle providers
        // Assume 5-min feed interval and 4s block gen. time,
        // each feed is expected to arrive within 60/4 * 5 = 75 blocks.
        priceOracleManager.addProvider(
            block.number,
            block.timestamp,
            0x346Ed1282B89D8c948b404C3c3599f8D8ba2AA0e, // provider
            ctrlAddr,   // paymentTokenAddress: CTRL address
            1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
            75,         // blockCountPerFeed
            10,         // feedSize: minimum number of currency pairs sent by provider
            bytes32(0)  // whitelistedIPAddr: allow sending from any IP
        );
        priceOracleManager.addProvider(
            block.number,
            block.timestamp,
            0xE728C3436836d980AeCd7DcB2935dc808c2E5a5f, // provider
            ctrlAddr,   // paymentTokenAddress: CTRL address
            1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
            75,         // blockCountPerFeed
            10,         // feedSize: minimum number of currency pairs sent by provider
            bytes32(0)  // whitelistedIPAddr: allow sending from any IP
        );
        priceOracleManager.addProvider(
            block.number,
            block.timestamp,
            0x6EeA49a87c6e46c8EC6C74C9870717eFF8616C3B, // provider
            ctrlAddr,   // paymentTokenAddress: CTRL address
            1e16,       // paymentAmtPerFeed: 0.01 CTRL for each feed
            75,         // blockCountPerFeed
            10,         // feedSize: minimum number of currency pairs sent by provider
            bytes32(0)  // whitelistedIPAddr: allow sending from any IP
        );

        if (block.chainid == 7000) { // mainnet only
            tabFactory.transferOwnership(governance);

            vaultManager.renounceRole(DEPLOYER_ROLE, owner);
            tabRegistry.renounceRole(MAINTAINER_ROLE, owner);
            reserveRegistry.renounceRole(MAINTAINER_ROLE, owner);
            config.renounceRole(MAINTAINER_ROLE, owner);
            priceOracleManager.renounceRole(MAINTAINER_ROLE, owner);   

            ctrl.mint(owner, 1000000e18); // 1,000,000 CTRL default governance allocation
            ctrl.beginDefaultAdminTransfer(governance);
            // TODO governance.acceptDefaultAdminTransfer()
        } else if (block.chainid == 7001) {
            // Testnet CTRL Faucet
            ctrl.mint(faucetAddr, 100000000e18);    // 100,000,000 CTRL
            ctrl.mint(owner,      100000000e18);    // 100,000,000 CTRL
        }

        _createTabs(); // create all 155 Tabs and perform zUniTab.setTabAddress on supported chains

        console.log("Tab Protocol deployment is completed.");
        vm.stopBroadcast();

        if (block.chainid == 31337) { // localnet
            console.log("Setting up uniswap v2 pools.");
            address localnetDeployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
            vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

            address bnbZrc20 = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b;
            address usdcEthZrc20 = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891;

            console.log("BTC/Zeta pool.");
            IERC20(btcBtc).approve(uniswapV2Router, 100e8);
            IUniswapV2Router01(uniswapV2Router).addLiquidityETH{value:500e18}(
                address(btcBtc),     // token
                1e8,                 // amountTokenDesired
                1e8,                 // amountTokenMin
                500e18,               // amountETHMin
                localnetDeployer,
                block.timestamp + 1 hours
            );
            
            console.log("BTC/ETH pool.");
            IERC20(ethereumZrc20).approve(uniswapV2Router, 60e18);     // ZRC-20 ETH.ETH
            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                address(btcBtc),     // tokenA
                ethereumZrc20,       // tokenB
                2e8,                 // tokenADesired
                50e18,               // tokenBDesired
                2e8,                 // amountAMin  
                50e18,               // amountBMin
                localnetDeployer,    // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            );

            console.log("ETH/BNB pool.");
            IERC20(bnbZrc20).approve(uniswapV2Router, 170e18);         // ZRC-20 BNB.BNB
            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                ethereumZrc20,       // tokenA
                bnbZrc20,            // tokenB
                10e18,               // tokenADesired
                50e18,               // tokenBDesired
                10e18,               // amountAMin  
                50e18,               // amountBMin
                localnetDeployer,    // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            );

            console.log("USDC/BNB pool.");
            IERC20(usdcEthZrc20).approve(uniswapV2Router, 350e18);     // ZRC-20 USDC.ETH
            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                usdcEthZrc20,        // tokenA
                bnbZrc20,            // tokenB
                50e18,               // tokenADesired
                100e18,              // tokenBDesired
                50e18,               // amountAMin  
                50e18,               // amountBMin
                localnetDeployer,    // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            );

            console.log("ZETA/BNB pool.");
            IERC20(zetaZrc20).approve(uniswapV2Router, 10e18);
            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                zetaZrc20,           // tokenA
                bnbZrc20,            // tokenB
                10e18,               // tokenADesired
                10e18,               // tokenBDesired
                10e18,               // amountAMin  
                10e18,               // amountBMin
                localnetDeployer,    // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            );

            console.log("BNB/BTC pool.");
            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                bnbZrc20,            // tokenA
                address(btcBtc),     // tokenB
                10e18,               // tokenADesired
                1e6,                 // tokenBDesired
                10e18,               // amountAMin  
                1e6,                 // amountBMin
                localnetDeployer,    // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            );

            console.log("USDC/BTC pool.");
            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                usdcEthZrc20,        // tokenA
                address(btcBtc),     // tokenB
                200e18,              // tokenADesired
                100000,              // tokenBDesired
                200e18,              // amountAMin  
                100000,              // amountBMin
                localnetDeployer,    // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            );

            console.log("USDC/ETH pool.");
            IERC20(usdcEthZrc20).approve(uniswapV2Router, 100e18);
            IERC20(ethereumZrc20).approve(uniswapV2Router, 25e15);
            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                usdcEthZrc20,        // tokenA
                ethereumZrc20,       // tokenB
                100e18,              // tokenADesired
                25e15,               // tokenBDesired
                100e18,              // amountAMin  
                25e15,               // amountBMin
                localnetDeployer,    // to, recipient of liquidity tokens
                block.timestamp + 1 hours // deadline
            );

            vm.stopBroadcast();
        }
    }

    function _determinedContractAddress(string memory strSalt) internal view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(strSalt));
        address determined = ICREATE3Factory(create3Factory).getDeployed(owner, salt);
        console.log("Determined address for ", strSalt, ": ", determined);
        return determined;
    }

    function tabKey(bytes3 tabCode) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(tabCode));
    }

    function _deployTab(uint256 _i, bytes3 _t) internal returns(address) {
        tabKeys[_i] = tabKey(_t);
        destToken[_i] = tabRegistry.createTab(_t);
        if (block.chainid == 31337) // Localnet 
            TabERC20(destToken[_i]).grantRole(MINTER_ROLE, uniTab);
        return destToken[_i];
    }

    // 155 currency codes
    function _createTabs() internal {
        tabKeys = new bytes32[](30); 
        destToken = new address[](30);

        console.log("ethereumZrc20: ", ethereumZrc20);
        console.log("arbitrumZrc20: ", arbitrumZrc20);
        console.log("baseZrc20: ", baseZrc20);
        console.log("zetaZrc20: ", zetaZrc20);

        console.log("Group 1");
        console.log("AED: ", _deployTab(0, bytes3(abi.encodePacked("AED"))));
        console.log("AFN: ", _deployTab(1, bytes3(abi.encodePacked("AFN"))));
        console.log("ALL: ", _deployTab(2, bytes3(abi.encodePacked("ALL"))));
        console.log("AMD: ", _deployTab(3, bytes3(abi.encodePacked("AMD"))));
        console.log("ANG: ", _deployTab(4, bytes3(abi.encodePacked("ANG"))));
        console.log("AOA: ", _deployTab(5, bytes3(abi.encodePacked("AOA"))));
        console.log("ARS: ", _deployTab(6, bytes3(abi.encodePacked("ARS"))));
        console.log("AUD: ", _deployTab(7, bytes3(abi.encodePacked("AUD"))));
        console.log("AWG: ", _deployTab(8, bytes3(abi.encodePacked("AWG"))));
        console.log("AZN: ", _deployTab(9, bytes3(abi.encodePacked("AZN"))));
        console.log("BAM: ", _deployTab(10, bytes3(abi.encodePacked("BAM"))));
        console.log("BBD: ", _deployTab(11, bytes3(abi.encodePacked("BBD"))));
        console.log("BDT: ", _deployTab(12, bytes3(abi.encodePacked("BDT"))));
        console.log("BGN: ", _deployTab(13, bytes3(abi.encodePacked("BGN"))));
        console.log("BHD: ", _deployTab(14, bytes3(abi.encodePacked("BHD"))));
        console.log("BIF: ", _deployTab(15, bytes3(abi.encodePacked("BIF"))));
        console.log("BMD: ", _deployTab(16, bytes3(abi.encodePacked("BMD"))));
        console.log("BND: ", _deployTab(17, bytes3(abi.encodePacked("BND"))));
        console.log("BOB: ", _deployTab(18, bytes3(abi.encodePacked("BOB"))));
        console.log("BRL: ", _deployTab(19, bytes3(abi.encodePacked("BRL"))));
        console.log("BSD: ", _deployTab(20, bytes3(abi.encodePacked("BSD"))));
        console.log("BTN: ", _deployTab(21, bytes3(abi.encodePacked("BTN"))));
        console.log("BWP: ", _deployTab(22, bytes3(abi.encodePacked("BWP"))));
        console.log("BYN: ", _deployTab(23, bytes3(abi.encodePacked("BYN"))));
        console.log("BZD: ", _deployTab(24, bytes3(abi.encodePacked("BZD"))));
        console.log("CAD: ", _deployTab(25, bytes3(abi.encodePacked("CAD"))));
        console.log("CDF: ", _deployTab(26, bytes3(abi.encodePacked("CDF"))));
        console.log("CHF: ", _deployTab(27, bytes3(abi.encodePacked("CHF"))));
        console.log("CLP: ", _deployTab(28, bytes3(abi.encodePacked("CLP"))));
        console.log("CNY: ", _deployTab(29, bytes3(abi.encodePacked("CNY"))));

        zUniTab.setTabAddress(ethereumZrc20, tabKeys, destToken);
        // zUniTab.setTabAddress(arbitrumZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(baseZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(zetaZrc20, tabKeys, destToken);
        
        tabKeys = new bytes32[](30); 
        destToken = new address[](30);

        console.log("Group 2");
        console.log("COP: ", _deployTab(0, bytes3(abi.encodePacked("COP"))));
        console.log("CRC: ", _deployTab(1, bytes3(abi.encodePacked("CRC"))));
        console.log("CUP: ", _deployTab(2, bytes3(abi.encodePacked("CUP"))));
        console.log("CVE: ", _deployTab(3, bytes3(abi.encodePacked("CVE"))));
        console.log("CZK: ", _deployTab(4, bytes3(abi.encodePacked("CZK"))));
        console.log("DJF: ", _deployTab(5, bytes3(abi.encodePacked("DJF"))));
        console.log("DKK: ", _deployTab(6, bytes3(abi.encodePacked("DKK"))));
        console.log("DOP: ", _deployTab(7, bytes3(abi.encodePacked("DOP"))));
        console.log("DZD: ", _deployTab(8, bytes3(abi.encodePacked("DZD"))));
        console.log("EGP: ", _deployTab(9, bytes3(abi.encodePacked("EGP"))));
        console.log("ERN: ", _deployTab(10, bytes3(abi.encodePacked("ERN"))));
        console.log("ETB: ", _deployTab(11, bytes3(abi.encodePacked("ETB"))));
        console.log("EUR: ", _deployTab(12, bytes3(abi.encodePacked("EUR"))));
        console.log("FJD: ", _deployTab(13, bytes3(abi.encodePacked("FJD"))));
        console.log("FKP: ", _deployTab(14, bytes3(abi.encodePacked("FKP"))));
        console.log("GBP: ", _deployTab(15, bytes3(abi.encodePacked("GBP"))));
        console.log("GEL: ", _deployTab(16, bytes3(abi.encodePacked("GEL"))));
        console.log("GGP: ", _deployTab(17, bytes3(abi.encodePacked("GGP"))));
        console.log("GHS: ", _deployTab(18, bytes3(abi.encodePacked("GHS"))));
        console.log("GIP: ", _deployTab(19, bytes3(abi.encodePacked("GIP"))));
        console.log("GMD: ", _deployTab(20, bytes3(abi.encodePacked("GMD"))));
        console.log("GNF: ", _deployTab(21, bytes3(abi.encodePacked("GNF"))));
        console.log("GTQ: ", _deployTab(22, bytes3(abi.encodePacked("GTQ"))));
        console.log("GYD: ", _deployTab(23, bytes3(abi.encodePacked("GYD"))));
        console.log("HKD: ", _deployTab(24, bytes3(abi.encodePacked("HKD"))));
        console.log("HNL: ", _deployTab(25, bytes3(abi.encodePacked("HNL"))));
        console.log("HRK: ", _deployTab(26, bytes3(abi.encodePacked("HRK"))));
        console.log("HTG: ", _deployTab(27, bytes3(abi.encodePacked("HTG"))));
        console.log("HUF: ", _deployTab(28, bytes3(abi.encodePacked("HUF"))));
        console.log("IDR: ", _deployTab(29, bytes3(abi.encodePacked("IDR"))));

        zUniTab.setTabAddress(ethereumZrc20, tabKeys, destToken);
        // zUniTab.setTabAddress(arbitrumZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(baseZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(zetaZrc20, tabKeys, destToken);
        
        tabKeys = new bytes32[](30); 
        destToken = new address[](30);

        console.log("Group 3");
        console.log("ILS: ", _deployTab(0, bytes3(abi.encodePacked("ILS"))));
        console.log("IMP: ", _deployTab(1, bytes3(abi.encodePacked("IMP"))));
        console.log("INR: ", _deployTab(2, bytes3(abi.encodePacked("INR"))));
        console.log("IQD: ", _deployTab(3, bytes3(abi.encodePacked("IQD"))));
        console.log("IRR: ", _deployTab(4, bytes3(abi.encodePacked("IRR"))));
        console.log("ISK: ", _deployTab(5, bytes3(abi.encodePacked("ISK"))));
        console.log("JEP: ", _deployTab(6, bytes3(abi.encodePacked("JEP"))));
        console.log("JMD: ", _deployTab(7, bytes3(abi.encodePacked("JMD"))));
        console.log("JOD: ", _deployTab(8, bytes3(abi.encodePacked("JOD"))));
        console.log("JPY: ", _deployTab(9, bytes3(abi.encodePacked("JPY"))));
        console.log("KES: ", _deployTab(10, bytes3(abi.encodePacked("KES"))));
        console.log("KGS: ", _deployTab(11, bytes3(abi.encodePacked("KGS"))));
        console.log("KHR: ", _deployTab(12, bytes3(abi.encodePacked("KHR"))));
        console.log("KMF: ", _deployTab(13, bytes3(abi.encodePacked("KMF"))));
        console.log("KRW: ", _deployTab(14, bytes3(abi.encodePacked("KRW"))));
        console.log("KWD: ", _deployTab(15, bytes3(abi.encodePacked("KWD"))));
        console.log("KYD: ", _deployTab(16, bytes3(abi.encodePacked("KYD"))));
        console.log("KZT: ", _deployTab(17, bytes3(abi.encodePacked("KZT"))));
        console.log("LAK: ", _deployTab(18, bytes3(abi.encodePacked("LAK"))));
        console.log("LBP: ", _deployTab(19, bytes3(abi.encodePacked("LBP"))));
        console.log("LKR: ", _deployTab(20, bytes3(abi.encodePacked("LKR"))));
        console.log("LRD: ", _deployTab(21, bytes3(abi.encodePacked("LRD"))));
        console.log("LSL: ", _deployTab(22, bytes3(abi.encodePacked("LSL"))));
        console.log("LYD: ", _deployTab(23, bytes3(abi.encodePacked("LYD"))));
        console.log("MAD: ", _deployTab(24, bytes3(abi.encodePacked("MAD"))));
        console.log("MDL: ", _deployTab(25, bytes3(abi.encodePacked("MDL"))));
        console.log("MGA: ", _deployTab(26, bytes3(abi.encodePacked("MGA"))));
        console.log("MKD: ", _deployTab(27, bytes3(abi.encodePacked("MKD"))));
        console.log("MMK: ", _deployTab(28, bytes3(abi.encodePacked("MMK"))));
        console.log("MNT: ", _deployTab(29, bytes3(abi.encodePacked("MNT"))));

        zUniTab.setTabAddress(ethereumZrc20, tabKeys, destToken);
        // zUniTab.setTabAddress(arbitrumZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(baseZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(zetaZrc20, tabKeys, destToken);

        tabKeys = new bytes32[](30); 
        destToken = new address[](30);

        console.log("Group 4");
        console.log("MOP: ", _deployTab(0, bytes3(abi.encodePacked("MOP"))));
        console.log("MRU: ", _deployTab(1, bytes3(abi.encodePacked("MRU"))));
        console.log("MUR: ", _deployTab(2, bytes3(abi.encodePacked("MUR"))));
        console.log("MVR: ", _deployTab(3, bytes3(abi.encodePacked("MVR"))));
        console.log("MWK: ", _deployTab(4, bytes3(abi.encodePacked("MWK"))));
        console.log("MXN: ", _deployTab(5, bytes3(abi.encodePacked("MXN"))));
        console.log("MYR: ", _deployTab(6, bytes3(abi.encodePacked("MYR"))));
        console.log("MZN: ", _deployTab(7, bytes3(abi.encodePacked("MZN"))));
        console.log("NAD: ", _deployTab(8, bytes3(abi.encodePacked("NAD"))));
        console.log("NGN: ", _deployTab(9, bytes3(abi.encodePacked("NGN"))));
        console.log("NIO: ", _deployTab(10, bytes3(abi.encodePacked("NIO"))));
        console.log("NOK: ", _deployTab(11, bytes3(abi.encodePacked("NOK"))));
        console.log("NPR: ", _deployTab(12, bytes3(abi.encodePacked("NPR"))));
        console.log("NZD: ", _deployTab(13, bytes3(abi.encodePacked("NZD"))));
        console.log("OMR: ", _deployTab(14, bytes3(abi.encodePacked("OMR"))));
        console.log("PAB: ", _deployTab(15, bytes3(abi.encodePacked("PAB"))));
        console.log("PEN: ", _deployTab(16, bytes3(abi.encodePacked("PEN"))));
        console.log("PGK: ", _deployTab(17, bytes3(abi.encodePacked("PGK"))));
        console.log("PHP: ", _deployTab(18, bytes3(abi.encodePacked("PHP"))));
        console.log("PKR: ", _deployTab(19, bytes3(abi.encodePacked("PKR"))));
        console.log("PLN: ", _deployTab(20, bytes3(abi.encodePacked("PLN"))));
        console.log("PYG: ", _deployTab(21, bytes3(abi.encodePacked("PYG"))));
        console.log("QAR: ", _deployTab(22, bytes3(abi.encodePacked("QAR"))));
        console.log("RON: ", _deployTab(23, bytes3(abi.encodePacked("RON"))));
        console.log("RSD: ", _deployTab(24, bytes3(abi.encodePacked("RSD"))));
        console.log("RUB: ", _deployTab(25, bytes3(abi.encodePacked("RUB"))));
        console.log("RWF: ", _deployTab(26, bytes3(abi.encodePacked("RWF"))));
        console.log("SAR: ", _deployTab(27, bytes3(abi.encodePacked("SAR"))));
        console.log("SBD: ", _deployTab(28, bytes3(abi.encodePacked("SBD"))));
        console.log("SCR: ", _deployTab(29, bytes3(abi.encodePacked("SCR"))));

        zUniTab.setTabAddress(ethereumZrc20, tabKeys, destToken);
        // zUniTab.setTabAddress(arbitrumZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(baseZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(zetaZrc20, tabKeys, destToken);

        tabKeys = new bytes32[](30); 
        destToken = new address[](30);

        console.log("Group 5");
        console.log("SDG: ", _deployTab(0, bytes3(abi.encodePacked("SDG"))));
        console.log("SEK: ", _deployTab(1, bytes3(abi.encodePacked("SEK"))));
        console.log("SGD: ", _deployTab(2, bytes3(abi.encodePacked("SGD"))));
        console.log("SHP: ", _deployTab(3, bytes3(abi.encodePacked("SHP"))));
        console.log("SLL: ", _deployTab(4, bytes3(abi.encodePacked("SLL"))));
        console.log("SOS: ", _deployTab(5, bytes3(abi.encodePacked("SOS"))));
        console.log("SRD: ", _deployTab(6, bytes3(abi.encodePacked("SRD"))));
        console.log("SYP: ", _deployTab(7, bytes3(abi.encodePacked("SYP"))));
        console.log("SZL: ", _deployTab(8, bytes3(abi.encodePacked("SZL"))));
        console.log("THB: ", _deployTab(9, bytes3(abi.encodePacked("THB"))));
        console.log("TJS: ", _deployTab(10, bytes3(abi.encodePacked("TJS"))));
        console.log("TMT: ", _deployTab(11, bytes3(abi.encodePacked("TMT"))));
        console.log("TND: ", _deployTab(12, bytes3(abi.encodePacked("TND"))));
        console.log("TOP: ", _deployTab(13, bytes3(abi.encodePacked("TOP"))));
        console.log("TRY: ", _deployTab(14, bytes3(abi.encodePacked("TRY"))));
        console.log("TTD: ", _deployTab(15, bytes3(abi.encodePacked("TTD"))));
        console.log("TWD: ", _deployTab(16, bytes3(abi.encodePacked("TWD"))));
        console.log("TZS: ", _deployTab(17, bytes3(abi.encodePacked("TZS"))));
        console.log("UAH: ", _deployTab(18, bytes3(abi.encodePacked("UAH"))));
        console.log("UGX: ", _deployTab(19, bytes3(abi.encodePacked("UGX"))));
        console.log("USD: ", _deployTab(20, bytes3(abi.encodePacked("USD"))));
        console.log("UYU: ", _deployTab(21, bytes3(abi.encodePacked("UYU"))));
        console.log("UZS: ", _deployTab(22, bytes3(abi.encodePacked("UZS"))));
        console.log("VES: ", _deployTab(23, bytes3(abi.encodePacked("VES"))));
        console.log("VND: ", _deployTab(24, bytes3(abi.encodePacked("VND"))));
        console.log("VUV: ", _deployTab(25, bytes3(abi.encodePacked("VUV"))));
        console.log("WST: ", _deployTab(26, bytes3(abi.encodePacked("WST"))));
        console.log("XAF: ", _deployTab(27, bytes3(abi.encodePacked("XAF"))));
        console.log("XCD: ", _deployTab(28, bytes3(abi.encodePacked("XCD"))));
        console.log("XOF: ", _deployTab(29, bytes3(abi.encodePacked("XOF"))));

        zUniTab.setTabAddress(ethereumZrc20, tabKeys, destToken);
        // zUniTab.setTabAddress(arbitrumZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(baseZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(zetaZrc20, tabKeys, destToken);

        console.log("Group 6");
        tabKeys = new bytes32[](5); 
        destToken = new address[](5);
        console.log("XPF: ", _deployTab(0, bytes3(abi.encodePacked("XPF"))));
        console.log("YER: ", _deployTab(1, bytes3(abi.encodePacked("YER"))));
        console.log("ZAR: ", _deployTab(2, bytes3(abi.encodePacked("ZAR"))));
        console.log("ZMW: ", _deployTab(3, bytes3(abi.encodePacked("ZMW"))));
        console.log("ZWL: ", _deployTab(4, bytes3(abi.encodePacked("ZWL"))));

        zUniTab.setTabAddress(ethereumZrc20, tabKeys, destToken);
        // zUniTab.setTabAddress(arbitrumZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(baseZrc20, tabKeys, destToken);
        zUniTab.setTabAddress(zetaZrc20, tabKeys, destToken);
    }
}