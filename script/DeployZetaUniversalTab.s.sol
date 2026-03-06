// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ICREATE3Factory} from "../contracts/interfaces/ICREATE3Factory.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {ZUniTab} from "../contracts/token/ZUniTab.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev Deploy Tab Factory, Tabs, and ZUniTab on supported chains.
 * Expect CREATE3 factory to be ready in the deployment chain.
 */
contract DeployZetaUniversalTab is Script {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
    
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    address governanceController;
    address emergencyGov;
    address upgrader;
    address gatewayAddress; // local side gateway
    address zetaToken; // ZetaChain zetaToken
    address uniswapV2Router;

    address baseZrc20;
    address arbitrumZrc20;
    address ethereumZrc20;
    address avalancheZrc20;

    TabFactory tabFactory;
    TabERC20 tabERC20;
    ZUniTab zetaUniversalTab;

    error EmptyCharacter();

    function run() external {
        vm.startBroadcast(deployer);

        console.log("Deploying on chain: ", block.chainid);

        if (block.chainid == 7001) { // zeta testnet
            governanceController = deployer;
            emergencyGov = deployer;
            gatewayAddress = 0x6c533f7fE93fAE114d0954697069Df33C9B74fD7;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
            uniswapV2Router = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;

            baseZrc20 = 0x236b0DE675cC8F46AE186897fCCeFe3370C9eDeD;
            arbitrumZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            ethereumZrc20 = 0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0;
            avalancheZrc20 = 0xEe9CC614D03e7Dbe994b514079f4914a605B4719;
        } else if (block.chainid == 7000) { // zeta mainnet
            governanceController = deployer;
            emergencyGov = deployer;
            gatewayAddress = 0xfEDD7A6e3Ef1cC470fbfbF955a22D793dDC0F44E;
            zetaToken = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
            uniswapV2Router = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;

            baseZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            arbitrumZrc20 = 0xA614Aebf7924A3Eb4D066aDCA5595E4980407f1d;
            ethereumZrc20 = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891;
            avalancheZrc20 = 0xE8d7796535F1cd63F0fe8D631E68eACe6839869B;
        }

        // _upgrade2();
        // vm.stopBroadcast();
        // return;

        // _exec();
        // return;


        tabERC20 = new TabERC20(); // implementation contract
        console.log("TabERC20 deployed at:", address(tabERC20));

        tabFactory = TabFactory(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.000: TabFactory")), 
            abi.encodePacked(type(TabFactory).creationCode, abi.encode(address(tabERC20), deployer))
        ));
        console.log("TabFactory deployed at:", address(tabFactory));
        console.log("TabFactory TabERC20 implementation:", tabFactory.implementation());
        
        // TODO to replace with real TabRegistry address
        tabFactory.updateCreator(deployer);

        upgrader = governanceController;

        address zetaUniversalTabImplementation = address(new ZUniTab());
        console.log("zetaUniversalTabImplementation: ", zetaUniversalTabImplementation);
        bytes memory initData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            governanceController, emergencyGov, upgrader, deployer, gatewayAddress, uniswapV2Router);
        address payable zetaUniversalTabAddr = payable(address(TabFactory(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.000: UniversalTab")), 
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(zetaUniversalTabImplementation, initData))
        ))));
        zetaUniversalTab = ZUniTab(zetaUniversalTabAddr);
        console.log("zetaUniversalTab: ", zetaUniversalTabAddr);

        address sUsd = deployTab(bytes3(abi.encodePacked("USD"))); // sUSD
        console.log("sUsd: ", sUsd);
        address sAud = deployTab(bytes3(abi.encodePacked("AUD"))); // sAUD
        console.log("sAud: ", sAud);
        address sMyr = deployTab(bytes3(abi.encodePacked("MYR"))); // sMyr
        console.log("sMyr: ", sMyr);

        address[] memory zrc20s = new address[](4); // https://www.zetachain.com/docs/developers/evm/zrc20/
        zrc20s[0] = baseZrc20;
        zrc20s[1] = arbitrumZrc20;
        zrc20s[2] = ethereumZrc20;
        zrc20s[3] = zetaToken;
        address[] memory universals = new address[](4);
        universals[0] = 0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933;
        universals[1] = 0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933;
        universals[2] = 0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933;
        universals[3] = address(zetaUniversalTab);
        zetaUniversalTab.setConnected(zrc20s, universals);

        bool[] memory isAuthorized = new bool[](4);
        isAuthorized[0] = true;
        isAuthorized[1] = true;
        isAuthorized[2] = true;
        isAuthorized[3] = true;
        zetaUniversalTab.setAuthorizedSender(universals, isAuthorized);
        
        address[] memory destinations = new address[](4);
        destinations[0] = baseZrc20;
        destinations[1] = arbitrumZrc20;
        destinations[2] = zetaToken;
        destinations[3] = ethereumZrc20;
        uint256[] memory gasLimit = new uint256[](4);
        gasLimit[0] = 120000;
        gasLimit[1] = 120000;
        gasLimit[2] = 120000;
        gasLimit[3] = 120000;
        zetaUniversalTab.setGasLimit(destinations, gasLimit);
        
        bytes32[] memory tabKeys = new bytes32[](3); 
        tabKeys[0] = TabERC20(sUsd).tabKey();
        tabKeys[1] = TabERC20(sAud).tabKey();
        tabKeys[2] = TabERC20(sMyr).tabKey();
        address[] memory destToken = new address[](3);
        destToken[0] = 0x25698AcdfC0A3C3dBbBD352afF212CEB256bcfCd;
        destToken[1] = 0xEbb42c2eD11aBA266da245e6e1B815Ab86A3A967;
        destToken[2] = 0x22D0579c3944609012Ed8d0EC6ECb40836CfAe24;
        zetaUniversalTab.setTabAddress(baseZrc20, tabKeys, destToken);
        zetaUniversalTab.setTabAddress(arbitrumZrc20, tabKeys, destToken);
        zetaUniversalTab.setTabAddress(zetaToken, tabKeys, destToken);
        zetaUniversalTab.setTabAddress(ethereumZrc20, tabKeys, destToken);

        // Testnet only
        TabERC20(sUsd).grantRole(MINTER_ROLE, deployer);
        TabERC20(sAud).grantRole(MINTER_ROLE, deployer);
        TabERC20(sMyr).grantRole(MINTER_ROLE, deployer);
        TabERC20(sUsd).mint(deployer, 1000e18);
        TabERC20(sAud).mint(deployer, 1000e18);
        TabERC20(sMyr).mint(deployer, 1000e18);

        // TODO mainnet only
        // tabFactory.transferOwnership(governanceController);

        vm.stopBroadcast();
    }

    function deployTab(bytes3 _tab) internal returns(address){
        string memory _symbol = _addTabCodePrefix(_tab);
        string memory _name = string(abi.encodePacked("Sound ", _tab));
        return tabFactory.createTab(governanceController, address(zetaUniversalTab), _name, _symbol, _tab);
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

    function _upgrade() internal {
        address payable zetaUniversalTabAddr = payable(0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933);
        ZUniTab newUniTab = new ZUniTab();
        ZUniTab(zetaUniversalTabAddr).upgradeToAndCall(
            address(newUniTab),
            ""
        );
        console.log("upgraded, new implementation: ", address(newUniTab));
        zetaUniversalTab = ZUniTab(payable(zetaUniversalTabAddr));
        zetaUniversalTab.updateDebugSuccess(true, true, true);
    }

    function _exec() internal {
        zetaUniversalTab = ZUniTab(payable(0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933)); // proxy
        // bytes32[] memory tabKeys = new bytes32[](3); 
        // tabKeys[0] = TabERC20(0x25698AcdfC0A3C3dBbBD352afF212CEB256bcfCd).tabKey();
        // tabKeys[1] = TabERC20(0xEbb42c2eD11aBA266da245e6e1B815Ab86A3A967).tabKey();
        // tabKeys[2] = TabERC20(0x22D0579c3944609012Ed8d0EC6ECb40836CfAe24).tabKey();
        // address[] memory destToken = new address[](3);
        // destToken[0] = 0x25698AcdfC0A3C3dBbBD352afF212CEB256bcfCd;
        // destToken[1] = 0xEbb42c2eD11aBA266da245e6e1B815Ab86A3A967;
        // destToken[2] = 0x22D0579c3944609012Ed8d0EC6ECb40836CfAe24;
        // zetaUniversalTab.setTabAddress(ethereumZrc20, tabKeys, destToken);

        address[] memory destinations = new address[](4);
        destinations[0] = baseZrc20;
        destinations[1] = arbitrumZrc20;
        destinations[2] = zetaToken;
        destinations[3] = ethereumZrc20;
        uint256[] memory gasLimit = new uint256[](4);
        gasLimit[0] = 145000;
        gasLimit[1] = 145000;
        gasLimit[2] = 145000;
        gasLimit[3] = 145000;
        zetaUniversalTab.setGasLimit(destinations, gasLimit);
    }
}

/*
Deploying on chain:  7001
  TabERC20 deployed at: 0xE546f1d0671D79319C71edC1B42089f913bc9971
  TabFactory deployed at: 0x93c51a8F9EABaAE8b3618bd82b0208BfCB69d3d9
  TabFactory TabERC20 implementation: 0xE546f1d0671D79319C71edC1B42089f913bc9971
  zetaUniversalTabImplementation:  0xf6dD022b6404454fe75Bc0276A8E98DEF9D0Fb03  0x7fF4db790028F4Df8392366d94a6Dfe24143b7b7
  zetaUniversalTab:  0x0AE9C2E94ADC5a2Cf3a762ab6b480f05DDc8c933
  sUsd:  0x25698AcdfC0A3C3dBbBD352afF212CEB256bcfCd
  sAud:  0xEbb42c2eD11aBA266da245e6e1B815Ab86A3A967
  sMyr:  0x22D0579c3944609012Ed8d0EC6ECb40836CfAe24

*/