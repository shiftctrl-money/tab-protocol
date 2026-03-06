// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ICREATE3Factory} from "../contracts/interfaces/ICREATE3Factory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
import {UniGovernance} from "../contracts/governance/UniGovernance.sol";
import {UniTab} from "../contracts/token/UniTab.sol";
import {UniCreateVault} from "../contracts/core/UniCreateVault.sol";
import {UniDepositReserve} from "../contracts/core/UniDepositReserve.sol";
import {UniWithdrawReserve} from "../contracts/core/UniWithdrawReserve.sol";
import {UniPaybackTab} from "../contracts/core/UniPaybackTab.sol";
import {UniWithdrawTab} from "../contracts/core/UniWithdrawTab.sol";
import {UniAuctionBid} from "../contracts/core/UniAuctionBid.sol";
import {UniProtocolVaultBuyTab} from "../contracts/core/UniProtocolVaultBuyTab.sol";
import {UniProtocolVaultSellTab} from "../contracts/core/UniProtocolVaultSellTab.sol";

/**
 * @dev To deploy Universal Tab Protocol contracts on supported EVM chains.
 * 
  Determined address for  ShiftCTRL_v1.01.001: VaultManager :  0x0046fFc38C0Cc854A56b6daeF66946F04d61639B
  Determined address for  ShiftCTRL_v1.01.001: AuctionManager :  0x13A0E137Bae4C88A243a48E2d10c1F7227f7f22C
  Determined address for  ShiftCTRL_v1.01.001: ZUniTab :  0x4d8107756C322134cCDfB33579BC3e3921040E29
  Determined address for  ShiftCTRL_v1.01.001: ZUniGovernance :  0x5d412eF840a56f252060b11192D2441EcfD9137A
  UniGovernance:  0xfD08512a1EDAcE7EDab28429a05cAe108501cc56
  UniTab:  0xEb8173CDc1fbBF190DF03DF10D066e0703c9e08c
  TabFactory:  0x02E89328C7B07a1eFE410eaa604A9b5A3C2556de
  TabFactory TabERC20 implementation: 0x6293F612c528c21797fe9e29a3cf9846f9d94f76
  uniCreateVault:  0xb4BE521b1D2e89a0f40eD10D3615b60f7413CEE8
  Determined address for  ShiftCTRL_v1.01.001: ZUniCreateVault :  0x79842c65b050ce9e45835261BD50a707Dc0FB25C
  Determined address for  ShiftCTRL_v1.01.001: ZUniDepositReserve :  0x796805d483e6592Ef9977CDA7DD8A8Bc02fD0411
  uniDepositReserve:  0x30aC390cc81A4A7EBd42c00C87d2229b25370BA8
  Determined address for  ShiftCTRL_v1.01.001: ZUniWithdrawReserve :  0xe295A65Aa0B41D3BC6c517a61Cbeaf89f647E9c9
  uniWithdrawReserve:  0xc437dfC119984C8d90E83436DfE90E68F1586ff8
  uniPaybackTab:  0x61477fD0C27be7648bB5bE99268ecBCd51527a9C
  Determined address for  ShiftCTRL_v1.01.001: ZUniWithdrawTab :  0x5E0B3463ABA1e685AC7c8Bd5B04dbf6db75B5B04
  uniWithdrawTab:  0xD7D541788550e2b2f51C46eE299B539342feD4E3
  uniAuctionBid:  0x383f719Dad554bc535C31539E9F7700EA9587560
  
  uniProtocolVaultBuyTab:  0x9173450d84368FE7e79B115EA8aF72BF774309C2
  Determined address for  ShiftCTRL_v1.01.001: ZUniProtocolVaultBuyTab :  0xb2637Ac71aF04f7BF783dfB6dc3A2a47fa81f826
  uniProtocolVaultSellTab:  0x4B50d2002368b209Aa05ebF8310C9ec9FFD8d4a8
  Determined address for  ShiftCTRL_v1.01.001: ProtocolVault :  0x2012C92c17E3d6cD7b1BbD0C7438D3d767301eF2 
 */
contract DeployArbitrum is Script {
    TabFactory tabFactory;
    UniGovernance uniGovernance;
    UniTab uniTab;
    UniCreateVault uniCreateVault;
    UniDepositReserve uniDepositReserve;
    UniWithdrawReserve uniWithdrawReserve;
    UniPaybackTab uniPaybackTab;
    UniWithdrawTab uniWithdrawTab;
    UniAuctionBid uniAuctionBid;
    UniProtocolVaultBuyTab uniProtocolVaultBuyTab;
    UniProtocolVaultSellTab uniProtocolVaultSellTab;

    address owner;
    address create3Factory;
    address uniswapV2Router;
    address nativeZrc20;
    address gateway;
    address ethereumZrc20;
    address arbitrumZrc20;
    address baseZrc20;
    address zetaZrc20;
    
    address vaultManager;
    address auctionManager;
    address zUniTab;

    error EmptyCharacter();

    function run() external {
        if (block.chainid == 42161) { // mainnet
            console.log("Deploying contracts to mainnet, chainid: ", block.chainid);
            
            owner = 0x553A9FB9B5590EE27d8ddc589005afca99D51aa3;
            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
            nativeZrc20 = 0xA614Aebf7924A3Eb4D066aDCA5595E4980407f1d; // ETH.ARB
            gateway = 0x1C53e188Bc2E471f9D4A4762CFf843d32C2C8549;
            ethereumZrc20 = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891; 
            arbitrumZrc20 = 0xA614Aebf7924A3Eb4D066aDCA5595E4980407f1d;
            baseZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            zetaZrc20 = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else if (block.chainid == 421614) { // testnet
            console.log("Deploying contracts to testnet, chainid: ", block.chainid);
            
            owner = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
            create3Factory = 0x02d0344090301E0FBA51864CC78da6e3987a6C51;
            nativeZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677; // ETH.ARBSEP
            gateway = 0x0dA86Dc3F9B71F84a0E97B0e2291e50B7a5df10f;
            ethereumZrc20 = 0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0;
            arbitrumZrc20 = 0x1de70f3e971B62A0707dA18100392af14f7fB677;
            baseZrc20 = 0x236b0DE675cC8F46AE186897fCCeFe3370C9eDeD;
            zetaZrc20 = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
        } else {
            console.log("Unsupported chainid: ", block.chainid);
            return;
        }

        vm.startBroadcast(owner);

        vaultManager = _determinedContractAddress("ShiftCTRL_v1.01.001: VaultManager");
        auctionManager = _determinedContractAddress("ShiftCTRL_v1.01.001: AuctionManager");
        zUniTab = _determinedContractAddress("ShiftCTRL_v1.01.001: ZUniTab");

        // UniGovernance: calllable by ZUniGovernance on ZetaChain only
        bytes memory uniGovernanceInitData = 
            abi.encodeWithSignature("initialize(address,address,address,address,address,bool)", owner, owner, owner, owner, gateway, false);
        UniGovernance uniGovernanceImpl = new UniGovernance();
        address payable uniGovernanceAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: UniGovernance")), 
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(uniGovernanceImpl), uniGovernanceInitData))
        ));
        uniGovernance = UniGovernance(uniGovernanceAddr);
        uniGovernance.setUniversal(_determinedContractAddress("ShiftCTRL_v1.01.001: ZUniGovernance")); // zUniGovernance
        console.log("UniGovernance: ", address(uniGovernance));

        // UniTab
        UniTab uniTabImpl = new UniTab();
        bytes memory uniTabInitData = abi.encodeWithSignature("initialize(address,address,address,address,address,address)", 
            address(uniGovernance), address(uniGovernance), address(uniGovernance), owner, gateway, zetaZrc20);
        address payable universalTabAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: UniTab")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(uniTabImpl), uniTabInitData))
        ));
        uniTab = UniTab(universalTabAddr);
        console.log("UniTab: ", address(uniTab));
        uniTab.setRevertGasLimit(120000);
        uniTab.setUniversal(zUniTab);
        if (block.chainid == 421614)
            uniTab.updateDebugSuccess(true, true, true);

        // TabFactory
        tabFactory = TabFactory(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: TabFactory")), 
            abi.encodePacked(type(TabFactory).creationCode, abi.encode(address(new TabERC20()), owner))
        ));
        console.log("TabFactory: ", address(tabFactory));
        console.log("TabFactory TabERC20 implementation:", tabFactory.implementation());
        
        uniTab.setTabFactory(address(tabFactory));
        tabFactory.updateCreator(owner); // grant to create tabs in this script, restore to uniTab later
        tabFactory.updateZUniTab(address(uniTab));

        // Create Vault
        bytes memory initData = abi.encodeWithSignature("initialize(address,address,address,address,address)", 
            address(uniGovernance), 
            owner, 
            owner, 
            gateway,
            nativeZrc20
        );
        UniCreateVault uniCreateVaultImpl = new UniCreateVault();
        address payable deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: UniCreateVault")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(uniCreateVaultImpl), initData))
        ));
        uniCreateVault = UniCreateVault(deployedProxyAddr);
        console.log("uniCreateVault: ", deployedProxyAddr);

        address[] memory zrc20Addrs = new address[](4);
        zrc20Addrs[0] = ethereumZrc20;
        zrc20Addrs[1] = arbitrumZrc20;
        zrc20Addrs[2] = baseZrc20;
        zrc20Addrs[3] = zetaZrc20;
        bool[] memory isAuthorized = new bool[](4);
        isAuthorized[0] = true;
        isAuthorized[1] = true;
        isAuthorized[2] = true;
        isAuthorized[3] = true;
        uniCreateVault.setAuthorizedDestinations(zrc20Addrs, isAuthorized);
        uniCreateVault.setRevertGasLimit(120000);
        uniCreateVault.setUniversal(_determinedContractAddress("ShiftCTRL_v1.01.001: ZUniCreateVault")); // zUniCreateVault

        // Deposit Reserve
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance), 
                owner, 
                owner, 
                gateway,
                nativeZrc20);
        UniDepositReserve uniDepositReserveImpl = new UniDepositReserve();
        deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: UniDepositReserve")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(uniDepositReserveImpl), initData))
        ));
        uniDepositReserve = UniDepositReserve(deployedProxyAddr);
        uniDepositReserve.setRevertGasLimit(120000);
        uniDepositReserve.setUniversal(_determinedContractAddress("ShiftCTRL_v1.01.001: ZUniDepositReserve")); // zUniDepositReserve
        console.log("uniDepositReserve: ", deployedProxyAddr);

        // Withdraw Reserve
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance), 
                owner, 
                owner, 
                gateway,
                nativeZrc20);
        UniWithdrawReserve uniWithdrawReserveImpl = new UniWithdrawReserve();
        deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: UniWithdrawReserve")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(uniWithdrawReserveImpl), initData))
        ));
        uniWithdrawReserve = UniWithdrawReserve(deployedProxyAddr);
        uniWithdrawReserve.setAuthorizedDestinations(zrc20Addrs, isAuthorized);
        uniWithdrawReserve.setUniversal(_determinedContractAddress("ShiftCTRL_v1.01.001: ZUniWithdrawReserve")); // zUniWithdrawReserve
        console.log("uniWithdrawReserve: ", deployedProxyAddr);

        // Payback Tab
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance), 
                owner, 
                owner, 
                gateway,
                nativeZrc20);
        UniPaybackTab uniPaybackTabImpl = new UniPaybackTab();
        deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: UniPaybackTab")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(uniPaybackTabImpl), initData))
        ));
        uniPaybackTab = UniPaybackTab(deployedProxyAddr);
        uniPaybackTab.updateZetaToken(zetaZrc20);
        uniPaybackTab.updateVaultManager(vaultManager);
        uniPaybackTab.setUniversal(zUniTab);
        uniPaybackTab.setUniTab(address(uniTab));
        console.log("uniPaybackTab: ", deployedProxyAddr);
        
        // Withdraw Tab
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance), 
                owner, 
                owner, 
                gateway,
                nativeZrc20);
        UniWithdrawTab uniWithdrawTabImpl = new UniWithdrawTab();
        deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: UniWithdrawTab")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(uniWithdrawTabImpl), initData))
        ));
        uniWithdrawTab = UniWithdrawTab(deployedProxyAddr);
        uniWithdrawTab.setAuthorizedDestinations(zrc20Addrs, isAuthorized);
        uniWithdrawTab.setUniversal(_determinedContractAddress("ShiftCTRL_v1.01.001: ZUniWithdrawTab")); // zUniWithdrawTab
        console.log("uniWithdrawTab: ", deployedProxyAddr);
        
        // Auction Bid
        initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance), 
                owner, 
                owner, 
                gateway,
                nativeZrc20);
        UniAuctionBid uniAuctionBidImpl = new UniAuctionBid();
        deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: UniAuctionBid")),
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(uniAuctionBidImpl), initData))
        ));
        uniAuctionBid = UniAuctionBid(deployedProxyAddr);
        uniAuctionBid.updateZetaToken(zetaZrc20);
        uniAuctionBid.updateAuctionManager(auctionManager);
        uniAuctionBid.setUniversal(zUniTab);
        uniAuctionBid.setUniTab(address(uniTab));
        console.log("uniAuctionBid: ", deployedProxyAddr);

        if (block.chainid == 421614) { // testnet only
            initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance), 
                owner, 
                owner, 
                gateway,
                nativeZrc20);
            UniProtocolVaultBuyTab uniProtocolVaultBuyTabImpl = new UniProtocolVaultBuyTab();
            deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
                keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: UniProtocolVaultBuyTab")),
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(uniProtocolVaultBuyTabImpl), initData))
            ));
            uniProtocolVaultBuyTab = UniProtocolVaultBuyTab(deployedProxyAddr);
            console.log("uniProtocolVaultBuyTab: ", deployedProxyAddr);
            uniProtocolVaultBuyTab.setAuthorizedDestinations(zrc20Addrs, isAuthorized);
            uniProtocolVaultBuyTab.setUniversal(_determinedContractAddress("ShiftCTRL_v1.01.001: ZUniProtocolVaultBuyTab"));

            initData =
                abi.encodeWithSignature("initialize(address,address,address,address,address)", 
                address(uniGovernance), 
                owner, 
                owner, 
                gateway,
                nativeZrc20);
            UniProtocolVaultSellTab uniProtocolVaultSellTabImpl = new UniProtocolVaultSellTab();
            deployedProxyAddr = payable(ICREATE3Factory(create3Factory).deploy(
                keccak256(abi.encodePacked("ShiftCTRL_v1.01.001: UniProtocolVaultSellTab")),
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(uniProtocolVaultSellTabImpl), initData))
            ));
            uniProtocolVaultSellTab = UniProtocolVaultSellTab(deployedProxyAddr);
            console.log("uniProtocolVaultSellTab: ", deployedProxyAddr);
            uniProtocolVaultSellTab.updateZetaToken(zetaZrc20);
            uniProtocolVaultSellTab.updateProtocolVault(_determinedContractAddress("ShiftCTRL_v1.01.001: ProtocolVault"));
            uniProtocolVaultSellTab.setUniversal(zUniTab);
            uniProtocolVaultSellTab.setUniTab(address(uniTab));
        }   

        _createTabs();

        if (block.chainid == 42161) { // mainnet permission reset
            tabFactory.transferOwnership(address(uniGovernance));
        }

        tabFactory.updateCreator(address(uniTab));
        
        console.log("Deployment is completed.");

        vm.stopBroadcast();
    }

    function _determinedContractAddress(string memory strSalt) internal view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(strSalt));
        address determined = ICREATE3Factory(create3Factory).getDeployed(owner, salt);
        console.log("Determined address for ", strSalt, ": ", determined);
        return determined;
    }

    function _deployTab(bytes3 _tab) internal returns(address){
        return tabFactory.createTab(address(uniGovernance), address(uniTab), address(uniTab), _tab);
    }

    function _createTabs() internal {
        // 155 currency codes
        console.log("AED: ", _deployTab(bytes3(abi.encodePacked("AED"))));
        console.log("AFN: ", _deployTab(bytes3(abi.encodePacked("AFN"))));
        console.log("ALL: ", _deployTab(bytes3(abi.encodePacked("ALL"))));
        console.log("AMD: ", _deployTab(bytes3(abi.encodePacked("AMD"))));
        console.log("ANG: ", _deployTab(bytes3(abi.encodePacked("ANG"))));
        console.log("AOA: ", _deployTab(bytes3(abi.encodePacked("AOA"))));
        console.log("ARS: ", _deployTab(bytes3(abi.encodePacked("ARS"))));
        console.log("AUD: ", _deployTab(bytes3(abi.encodePacked("AUD"))));
        console.log("AWG: ", _deployTab(bytes3(abi.encodePacked("AWG"))));
        console.log("AZN: ", _deployTab(bytes3(abi.encodePacked("AZN"))));
        console.log("BAM: ", _deployTab(bytes3(abi.encodePacked("BAM"))));
        console.log("BBD: ", _deployTab(bytes3(abi.encodePacked("BBD"))));
        console.log("BDT: ", _deployTab(bytes3(abi.encodePacked("BDT"))));
        console.log("BGN: ", _deployTab(bytes3(abi.encodePacked("BGN"))));
        console.log("BHD: ", _deployTab(bytes3(abi.encodePacked("BHD"))));
        console.log("BIF: ", _deployTab(bytes3(abi.encodePacked("BIF"))));
        console.log("BMD: ", _deployTab(bytes3(abi.encodePacked("BMD"))));
        console.log("BND: ", _deployTab(bytes3(abi.encodePacked("BND"))));
        console.log("BOB: ", _deployTab(bytes3(abi.encodePacked("BOB"))));
        console.log("BRL: ", _deployTab(bytes3(abi.encodePacked("BRL"))));
        console.log("BSD: ", _deployTab(bytes3(abi.encodePacked("BSD"))));
        console.log("BTN: ", _deployTab(bytes3(abi.encodePacked("BTN"))));
        console.log("BWP: ", _deployTab(bytes3(abi.encodePacked("BWP"))));
        console.log("BYN: ", _deployTab(bytes3(abi.encodePacked("BYN"))));
        console.log("BZD: ", _deployTab(bytes3(abi.encodePacked("BZD"))));
        console.log("CAD: ", _deployTab(bytes3(abi.encodePacked("CAD"))));
        console.log("CDF: ", _deployTab(bytes3(abi.encodePacked("CDF"))));
        console.log("CHF: ", _deployTab(bytes3(abi.encodePacked("CHF"))));
        console.log("CLP: ", _deployTab(bytes3(abi.encodePacked("CLP"))));
        console.log("CNY: ", _deployTab(bytes3(abi.encodePacked("CNY"))));
        console.log("COP: ", _deployTab(bytes3(abi.encodePacked("COP"))));
        console.log("CRC: ", _deployTab(bytes3(abi.encodePacked("CRC"))));
        console.log("CUP: ", _deployTab(bytes3(abi.encodePacked("CUP"))));
        console.log("CVE: ", _deployTab(bytes3(abi.encodePacked("CVE"))));
        console.log("CZK: ", _deployTab(bytes3(abi.encodePacked("CZK"))));
        console.log("DJF: ", _deployTab(bytes3(abi.encodePacked("DJF"))));
        console.log("DKK: ", _deployTab(bytes3(abi.encodePacked("DKK"))));
        console.log("DOP: ", _deployTab(bytes3(abi.encodePacked("DOP"))));
        console.log("DZD: ", _deployTab(bytes3(abi.encodePacked("DZD"))));
        console.log("EGP: ", _deployTab(bytes3(abi.encodePacked("EGP"))));
        console.log("ERN: ", _deployTab(bytes3(abi.encodePacked("ERN"))));
        console.log("ETB: ", _deployTab(bytes3(abi.encodePacked("ETB"))));
        console.log("EUR: ", _deployTab(bytes3(abi.encodePacked("EUR"))));
        console.log("FJD: ", _deployTab(bytes3(abi.encodePacked("FJD"))));
        console.log("FKP: ", _deployTab(bytes3(abi.encodePacked("FKP"))));
        console.log("GBP: ", _deployTab(bytes3(abi.encodePacked("GBP"))));
        console.log("GEL: ", _deployTab(bytes3(abi.encodePacked("GEL"))));
        console.log("GGP: ", _deployTab(bytes3(abi.encodePacked("GGP"))));
        console.log("GHS: ", _deployTab(bytes3(abi.encodePacked("GHS"))));
        console.log("GIP: ", _deployTab(bytes3(abi.encodePacked("GIP"))));
        console.log("GMD: ", _deployTab(bytes3(abi.encodePacked("GMD"))));
        console.log("GNF: ", _deployTab(bytes3(abi.encodePacked("GNF"))));
        console.log("GTQ: ", _deployTab(bytes3(abi.encodePacked("GTQ"))));
        console.log("GYD: ", _deployTab(bytes3(abi.encodePacked("GYD"))));
        console.log("HKD: ", _deployTab(bytes3(abi.encodePacked("HKD"))));
        console.log("HNL: ", _deployTab(bytes3(abi.encodePacked("HNL"))));
        console.log("HRK: ", _deployTab(bytes3(abi.encodePacked("HRK"))));
        console.log("HTG: ", _deployTab(bytes3(abi.encodePacked("HTG"))));
        console.log("HUF: ", _deployTab(bytes3(abi.encodePacked("HUF"))));
        console.log("IDR: ", _deployTab(bytes3(abi.encodePacked("IDR"))));
        console.log("ILS: ", _deployTab(bytes3(abi.encodePacked("ILS"))));
        console.log("IMP: ", _deployTab(bytes3(abi.encodePacked("IMP"))));
        console.log("INR: ", _deployTab(bytes3(abi.encodePacked("INR"))));
        console.log("IQD: ", _deployTab(bytes3(abi.encodePacked("IQD"))));
        console.log("IRR: ", _deployTab(bytes3(abi.encodePacked("IRR"))));
        console.log("ISK: ", _deployTab(bytes3(abi.encodePacked("ISK"))));
        console.log("JEP: ", _deployTab(bytes3(abi.encodePacked("JEP"))));
        console.log("JMD: ", _deployTab(bytes3(abi.encodePacked("JMD"))));
        console.log("JOD: ", _deployTab(bytes3(abi.encodePacked("JOD"))));
        console.log("JPY: ", _deployTab(bytes3(abi.encodePacked("JPY"))));
        console.log("KES: ", _deployTab(bytes3(abi.encodePacked("KES"))));
        console.log("KGS: ", _deployTab(bytes3(abi.encodePacked("KGS"))));
        console.log("KHR: ", _deployTab(bytes3(abi.encodePacked("KHR"))));
        console.log("KMF: ", _deployTab(bytes3(abi.encodePacked("KMF"))));
        console.log("KRW: ", _deployTab(bytes3(abi.encodePacked("KRW"))));
        console.log("KWD: ", _deployTab(bytes3(abi.encodePacked("KWD"))));
        console.log("KYD: ", _deployTab(bytes3(abi.encodePacked("KYD"))));
        console.log("KZT: ", _deployTab(bytes3(abi.encodePacked("KZT"))));
        console.log("LAK: ", _deployTab(bytes3(abi.encodePacked("LAK"))));
        console.log("LBP: ", _deployTab(bytes3(abi.encodePacked("LBP"))));
        console.log("LKR: ", _deployTab(bytes3(abi.encodePacked("LKR"))));
        console.log("LRD: ", _deployTab(bytes3(abi.encodePacked("LRD"))));
        console.log("LSL: ", _deployTab(bytes3(abi.encodePacked("LSL"))));
        console.log("LYD: ", _deployTab(bytes3(abi.encodePacked("LYD"))));
        console.log("MAD: ", _deployTab(bytes3(abi.encodePacked("MAD"))));
        console.log("MDL: ", _deployTab(bytes3(abi.encodePacked("MDL"))));
        console.log("MGA: ", _deployTab(bytes3(abi.encodePacked("MGA"))));
        console.log("MKD: ", _deployTab(bytes3(abi.encodePacked("MKD"))));
        console.log("MMK: ", _deployTab(bytes3(abi.encodePacked("MMK"))));
        console.log("MNT: ", _deployTab(bytes3(abi.encodePacked("MNT"))));
        console.log("MOP: ", _deployTab(bytes3(abi.encodePacked("MOP"))));
        console.log("MRU: ", _deployTab(bytes3(abi.encodePacked("MRU"))));
        console.log("MUR: ", _deployTab(bytes3(abi.encodePacked("MUR"))));
        console.log("MVR: ", _deployTab(bytes3(abi.encodePacked("MVR"))));
        console.log("MWK: ", _deployTab(bytes3(abi.encodePacked("MWK"))));
        console.log("MXN: ", _deployTab(bytes3(abi.encodePacked("MXN"))));
        console.log("MYR: ", _deployTab(bytes3(abi.encodePacked("MYR"))));
        console.log("MZN: ", _deployTab(bytes3(abi.encodePacked("MZN"))));
        console.log("NAD: ", _deployTab(bytes3(abi.encodePacked("NAD"))));
        console.log("NGN: ", _deployTab(bytes3(abi.encodePacked("NGN"))));
        console.log("NIO: ", _deployTab(bytes3(abi.encodePacked("NIO"))));
        console.log("NOK: ", _deployTab(bytes3(abi.encodePacked("NOK"))));
        console.log("NPR: ", _deployTab(bytes3(abi.encodePacked("NPR"))));
        console.log("NZD: ", _deployTab(bytes3(abi.encodePacked("NZD"))));
        console.log("OMR: ", _deployTab(bytes3(abi.encodePacked("OMR"))));
        console.log("PAB: ", _deployTab(bytes3(abi.encodePacked("PAB"))));
        console.log("PEN: ", _deployTab(bytes3(abi.encodePacked("PEN"))));
        console.log("PGK: ", _deployTab(bytes3(abi.encodePacked("PGK"))));
        console.log("PHP: ", _deployTab(bytes3(abi.encodePacked("PHP"))));
        console.log("PKR: ", _deployTab(bytes3(abi.encodePacked("PKR"))));
        console.log("PLN: ", _deployTab(bytes3(abi.encodePacked("PLN"))));
        console.log("PYG: ", _deployTab(bytes3(abi.encodePacked("PYG"))));
        console.log("QAR: ", _deployTab(bytes3(abi.encodePacked("QAR"))));
        console.log("RON: ", _deployTab(bytes3(abi.encodePacked("RON"))));
        console.log("RSD: ", _deployTab(bytes3(abi.encodePacked("RSD"))));
        console.log("RUB: ", _deployTab(bytes3(abi.encodePacked("RUB"))));
        console.log("RWF: ", _deployTab(bytes3(abi.encodePacked("RWF"))));
        console.log("SAR: ", _deployTab(bytes3(abi.encodePacked("SAR"))));
        console.log("SBD: ", _deployTab(bytes3(abi.encodePacked("SBD"))));
        console.log("SCR: ", _deployTab(bytes3(abi.encodePacked("SCR"))));
        console.log("SDG: ", _deployTab(bytes3(abi.encodePacked("SDG"))));
        console.log("SEK: ", _deployTab(bytes3(abi.encodePacked("SEK"))));
        console.log("SGD: ", _deployTab(bytes3(abi.encodePacked("SGD"))));
        console.log("SHP: ", _deployTab(bytes3(abi.encodePacked("SHP"))));
        console.log("SLL: ", _deployTab(bytes3(abi.encodePacked("SLL"))));
        console.log("SOS: ", _deployTab(bytes3(abi.encodePacked("SOS"))));
        console.log("SRD: ", _deployTab(bytes3(abi.encodePacked("SRD"))));
        console.log("SYP: ", _deployTab(bytes3(abi.encodePacked("SYP"))));
        console.log("SZL: ", _deployTab(bytes3(abi.encodePacked("SZL"))));
        console.log("THB: ", _deployTab(bytes3(abi.encodePacked("THB"))));
        console.log("TJS: ", _deployTab(bytes3(abi.encodePacked("TJS"))));
        console.log("TMT: ", _deployTab(bytes3(abi.encodePacked("TMT"))));
        console.log("TND: ", _deployTab(bytes3(abi.encodePacked("TND"))));
        console.log("TOP: ", _deployTab(bytes3(abi.encodePacked("TOP"))));
        console.log("TRY: ", _deployTab(bytes3(abi.encodePacked("TRY"))));
        console.log("TTD: ", _deployTab(bytes3(abi.encodePacked("TTD"))));
        console.log("TWD: ", _deployTab(bytes3(abi.encodePacked("TWD"))));
        console.log("TZS: ", _deployTab(bytes3(abi.encodePacked("TZS"))));
        console.log("UAH: ", _deployTab(bytes3(abi.encodePacked("UAH"))));
        console.log("UGX: ", _deployTab(bytes3(abi.encodePacked("UGX"))));
        console.log("USD: ", _deployTab(bytes3(abi.encodePacked("USD"))));
        console.log("UYU: ", _deployTab(bytes3(abi.encodePacked("UYU"))));
        console.log("UZS: ", _deployTab(bytes3(abi.encodePacked("UZS"))));
        console.log("VES: ", _deployTab(bytes3(abi.encodePacked("VES"))));
        console.log("VND: ", _deployTab(bytes3(abi.encodePacked("VND"))));
        console.log("VUV: ", _deployTab(bytes3(abi.encodePacked("VUV"))));
        console.log("WST: ", _deployTab(bytes3(abi.encodePacked("WST"))));
        console.log("XAF: ", _deployTab(bytes3(abi.encodePacked("XAF"))));
        console.log("XCD: ", _deployTab(bytes3(abi.encodePacked("XCD"))));
        console.log("XOF: ", _deployTab(bytes3(abi.encodePacked("XOF"))));
        console.log("XPF: ", _deployTab(bytes3(abi.encodePacked("XPF"))));
        console.log("YER: ", _deployTab(bytes3(abi.encodePacked("YER"))));
        console.log("ZAR: ", _deployTab(bytes3(abi.encodePacked("ZAR"))));
        console.log("ZMW: ", _deployTab(bytes3(abi.encodePacked("ZMW"))));
        console.log("ZWL: ", _deployTab(bytes3(abi.encodePacked("ZWL"))));
    }

}