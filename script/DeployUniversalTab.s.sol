// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ICREATE3Factory} from "../contracts/interfaces/ICREATE3Factory.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {UniTab} from "../contracts/token/UniTab.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} 
    from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @dev Deploy Tab Factory, Tabs, and UniTab on supported chains.
 * Expect CREATE3 factory to be ready in the deployment chain.
 */
contract DeployUniversalTab is Script {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    
    // refer https://github.com/ZeframLou/create3-factory
    address create3Factory;
    address governanceController = deployer;
    address emergencyGov = deployer;
    address upgrader = deployer;
    address gatewayAddress; // local side gateway
    address zetaToken; // ZetaChain zetaToken
    address baseZrc20;
    address arbitrumZrc20;
    address ethereumZrc20;
    address avalancheZrc20;

    TabFactory tabFactory;
    TabERC20 tabERC20;
    ProxyAdmin proxyAdmin;
    UniTab universalTab;

    error EmptyCharacter();

    function run() external {
        vm.startBroadcast(deployer);

        console.log("Deploying on chain: ", block.chainid);

        if (block.chainid == 84532) { // base testnet
            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
            governanceController = deployer;
            emergencyGov = deployer;
            gatewayAddress = 0x0c487a766110c85d301D96E33579C5B317Fa4995;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 8453) { // base mainnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
            governanceController = deployer;
            emergencyGov = deployer;
            gatewayAddress = 0x48B9AACC350b20147001f88821d31731Ba4C30ed;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 11155111) { // ethereum testnet
            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
            governanceController = deployer;
            emergencyGov = deployer;
            gatewayAddress = 0x0c487a766110c85d301D96E33579C5B317Fa4995;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 1) { // ethereum mainnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
            governanceController = deployer;
            emergencyGov = deployer;
            gatewayAddress = 0x48B9AACC350b20147001f88821d31731Ba4C30ed;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 421614) { // arbitrum testnet
            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
            governanceController = deployer;
            emergencyGov = deployer;
            gatewayAddress = 0x0dA86Dc3F9B71F84a0E97B0e2291e50B7a5df10f;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 42161) { // arbitrum mainnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
            governanceController = deployer;
            emergencyGov = deployer;
            gatewayAddress = 0x1C53e188Bc2E471f9D4A4762CFf843d32C2C8549;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 43113) { // avalanche Fuji testnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf; // TODO
            governanceController = deployer;
            emergencyGov = deployer;
            gatewayAddress = 0x0dA86Dc3F9B71F84a0E97B0e2291e50B7a5df10f;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 43114) { // avalanche C-chain mainnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
            governanceController = deployer;
            emergencyGov = deployer;
            gatewayAddress = 0x1C53e188Bc2E471f9D4A4762CFf843d32C2C8549;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        }

        if (block.chainid == 84532 || 
            block.chainid == 11155111 || 
            block.chainid == 421614 ||
            block.chainid == 43113
        ) {
            baseZrc20 = 0x236b0DE675cC8F46AE186897fCCeFe3370C9eDeD;
            arbitrumZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            ethereumZrc20 = 0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0;
            avalancheZrc20 = 0xEe9CC614D03e7Dbe994b514079f4914a605B4719;
        } else {
            baseZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            arbitrumZrc20 = 0xA614Aebf7924A3Eb4D066aDCA5595E4980407f1d;
            ethereumZrc20 = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891;
            avalancheZrc20 = 0xE8d7796535F1cd63F0fe8D631E68eACe6839869B;
        }

        // _upgrade();
        // vm.stopBroadcast();
        // return;

        tabERC20 = new TabERC20();
        console.log("TabERC20 deployed at:", address(tabERC20));

        tabFactory = TabFactory(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.000: TabFactory")), 
            abi.encodePacked(type(TabFactory).creationCode, abi.encode(address(tabERC20), deployer))
        ));
        console.log("TabFactory deployed at:", address(tabFactory));
        console.log("TabFactory TabERC20 implementation:", tabFactory.implementation());

        upgrader = governanceController;

        address universalTabImplementation = address(new UniTab());
        console.log("universalTabImplementation: ", universalTabImplementation);
        bytes memory initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            governanceController, emergencyGov, upgrader, deployer, gatewayAddress, zetaToken);
        address payable universalTabAddr = payable(address (TabFactory(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.000: UniversalTab")), 
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(universalTabImplementation, initData))
        ))));
        universalTab = UniTab(universalTabAddr);
        console.log("uniTab: ", universalTabAddr);

        // TODO to replace with real TabRegistry address
        tabFactory.updateCreator(deployer);

        address sUsd = deployTab(bytes3(abi.encodePacked("USD"))); // sUSD
        console.log("sUsd: ", sUsd);
        address sAud = deployTab(bytes3(abi.encodePacked("AUD"))); // sAUD
        console.log("sAud: ", sAud);
        address sMyr = deployTab(bytes3(abi.encodePacked("MYR"))); // sMYR
        console.log("sMyr: ", sMyr);

        universalTab.setRevertGasLimit(120000);

        // TODO Set this if Old to New Tab is required
        // address[] memory tabs = new address[](3);
        // tabs[0] = sUsd;
        // tabs[1] = sAud; 
        // tabs[2] = sMyr;
        // bool[] isAuthorized = new bool[](3);
        // isAuthorized[0] = true;
        // isAuthorized[1] = true;
        // isAuthorized[2] = true;
        // universalTab.setAuthorizedTab(tabs, isAuthorized);

        universalTab.setUniversal(0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933);

        // Testnet only
        TabERC20(sUsd).grantRole(MINTER_ROLE, deployer);
        TabERC20(sAud).grantRole(MINTER_ROLE, deployer);
        TabERC20(sMyr).grantRole(MINTER_ROLE, deployer);
        TabERC20(sUsd).mint(deployer, 1000e18);
        TabERC20(sAud).mint(deployer, 1000e18);
        TabERC20(sMyr).mint(deployer, 1000e18);

        // TODO mainnet only
        // tabFactory.updateVaultManager(vaultManagerAddr);
        // tabFactory.transferOwnership(governanceController);

        vm.stopBroadcast();
    }

    function deployTab(bytes3 _tab) internal returns(address){
        string memory _symbol = _addTabCodePrefix(_tab);
        string memory _name = string(abi.encodePacked("Sound ", _tab));
        return tabFactory.createTab(governanceController, address(universalTab), _name, _symbol, _tab);
    }

    function _addTabCodePrefix(bytes3 _tab) internal pure returns (string memory) {
        bytes memory b = new bytes(4);
        b[0] = hex"73"; // prefix s
        if (_tab[0] == 0x0)
            revert EmptyCharacter();
        b[1] = _tab[0];
        if (_tab[1] == 0x0)
            revert EmptyCharacter();
        b[2] = _tab[1];
        if (_tab[2] == 0x0)
            revert EmptyCharacter();
        b[3] = _tab[2];
        return string(b);
    }

    function _upgrade2() internal {
        address payable universalTabAddr = payable(0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933);
        UniTab newUniTab = new UniTab();
        UniTab(universalTabAddr).upgradeToAndCall(
            address(newUniTab),
            ""
        );
        console.log("upgraded, new implementation: ", address(newUniTab));
        universalTab = UniTab(payable(universalTabAddr));
        universalTab.updateDebugSuccess(true, true, true);
    }
}

/*

Deploying on chain:  84532
  TabERC20 deployed at: 0x31F70fd588F18D38C0a4c575617339cBE5C91102
  TabFactory deployed at: 0x93c51a8F9EABaAE8b3618bd82b0208BfCB69d3d9
  TabFactory TabERC20 implementation: 0x31F70fd588F18D38C0a4c575617339cBE5C91102
  universalTabImplementation:  0x35B3Fa29B55923e4AD4d001819E3bf554119A206
  uniTab:  0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933
  sUsd:  0x25698AcdfC0A3C3dBbBD352afF212CEB256bcfCd
  sAud:  0xEbb42c2eD11aBA266da245e6e1B815Ab86A3A967
  sMyr:  0x22D0579c3944609012Ed8d0EC6ECb40836CfAe24

Deploying on chain:  421614
  TabERC20 deployed at: 0x627a30472F104F527E142e89105deEAEFFdb2290
  TabFactory deployed at: 0x93c51a8F9EABaAE8b3618bd82b0208BfCB69d3d9
  TabFactory TabERC20 implementation: 0x627a30472F104F527E142e89105deEAEFFdb2290
  universalTabImplementation:  0x366b9635e943dc6917639ea53F0428966523AC0A
  uniTab:  0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933
  sUsd:  0x25698AcdfC0A3C3dBbBD352afF212CEB256bcfCd
  sAud:  0xEbb42c2eD11aBA266da245e6e1B815Ab86A3A967
  sMyr:  0x22D0579c3944609012Ed8d0EC6ECb40836CfAe24

Deploying on chain:  11155111
  TabERC20 deployed at: 0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46
  TabFactory deployed at: 0x93c51a8F9EABaAE8b3618bd82b0208BfCB69d3d9
  TabFactory TabERC20 implementation: 0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46
  universalTabImplementation:  0xf6dD022b6404454fe75Bc0276A8E98DEF9D0Fb03
  universalTab:  0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933
  sUsd:  0x25698AcdfC0A3C3dBbBD352afF212CEB256bcfCd
  sAud:  0xEbb42c2eD11aBA266da245e6e1B815Ab86A3A967
  sMyr:  0x22D0579c3944609012Ed8d0EC6ECb40836CfAe24


*/