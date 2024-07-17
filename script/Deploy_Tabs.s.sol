// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../contracts/token/WBTC.sol";
import "../contracts/Config.sol";
import "../contracts/ReserveRegistry.sol";
import "../contracts/ReserveSafe.sol";
import "../contracts/TabRegistry.sol";
import "../contracts/token/TabERC20.sol";

// To run in testnet only
contract DeployTabs is Script {
    bytes32 reserve_WBTC = keccak256("WBTC");
    
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    address skybitCreate3Factory = 0xA8D5D2166B1FB90F70DF5Cc70EA7a1087bCF1750;
    address wbtc;
    address tabProxyAdmin = 0xE546f1d0671D79319C71edC1B42089f913bc9971;
    address governanceTimelockController = 0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46;
    address emergencyTimelockController = 0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F;
    address vaultManager = 0x6aA52f8b0bDf627f59E635dA95c735232881c93b;
    address config = 0x1a13d6a511A9551eC1A493C26362836e80aC4d65;
    address reserveRegistry = 0x666A895b1fcda4272A29d67c40b91a15e469F442;
    address reserveSafe; // for WBTC
    address tabRegistry = 0x5B2949601CDD3721FF11bF55419F427c9C118e2c;

    function run() external {
        vm.startBroadcast(0xf581CDc96bEb07beE51175Ef5dc391cd90E7313e); // UI_USER

        TabRegistry tr = TabRegistry(tabRegistry);
        // tr.createTab(bytes3(abi.encodePacked("AED")));
        // tr.createTab(bytes3(abi.encodePacked("AFN")));
        // tr.createTab(bytes3(abi.encodePacked("ALL")));
        tr.createTab(bytes3(abi.encodePacked("AMD")));
        tr.createTab(bytes3(abi.encodePacked("ANG")));
        // tr.createTab(bytes3(abi.encodePacked("AOA")));
        tr.createTab(bytes3(abi.encodePacked("ARS")));
        // tr.createTab(bytes3(abi.encodePacked("AUD")));
        tr.createTab(bytes3(abi.encodePacked("AWG")));
        tr.createTab(bytes3(abi.encodePacked("AZN")));
        // tr.createTab(bytes3(abi.encodePacked("BAM")));
        tr.createTab(bytes3(abi.encodePacked("BBD")));
        tr.createTab(bytes3(abi.encodePacked("BDT"))); // count 20
        tr.createTab(bytes3(abi.encodePacked("BGN")));
        tr.createTab(bytes3(abi.encodePacked("BHD")));
        tr.createTab(bytes3(abi.encodePacked("BIF")));
        tr.createTab(bytes3(abi.encodePacked("BMD")));
        tr.createTab(bytes3(abi.encodePacked("BND")));
        tr.createTab(bytes3(abi.encodePacked("BOB")));
        tr.createTab(bytes3(abi.encodePacked("BRL")));
        tr.createTab(bytes3(abi.encodePacked("BSD")));
        tr.createTab(bytes3(abi.encodePacked("BTN")));
        tr.createTab(bytes3(abi.encodePacked("BWP"))); // 30
        tr.createTab(bytes3(abi.encodePacked("BYN")));
        tr.createTab(bytes3(abi.encodePacked("BZD")));
        tr.createTab(bytes3(abi.encodePacked("CAD")));
        tr.createTab(bytes3(abi.encodePacked("CDF")));
        tr.createTab(bytes3(abi.encodePacked("CHF")));
        tr.createTab(bytes3(abi.encodePacked("CLP")));
        tr.createTab(bytes3(abi.encodePacked("CNY")));
        tr.createTab(bytes3(abi.encodePacked("COP")));
        tr.createTab(bytes3(abi.encodePacked("CRC")));
        tr.createTab(bytes3(abi.encodePacked("CUP"))); // 40
        tr.createTab(bytes3(abi.encodePacked("CVE")));
        tr.createTab(bytes3(abi.encodePacked("CZK")));
        tr.createTab(bytes3(abi.encodePacked("DJF")));
        tr.createTab(bytes3(abi.encodePacked("DKK")));
        tr.createTab(bytes3(abi.encodePacked("DOP")));
        tr.createTab(bytes3(abi.encodePacked("DZD")));
        tr.createTab(bytes3(abi.encodePacked("EGP")));
        tr.createTab(bytes3(abi.encodePacked("ERN")));
        tr.createTab(bytes3(abi.encodePacked("ETB")));
        // tr.createTab(bytes3(abi.encodePacked("EUR")));
        tr.createTab(bytes3(abi.encodePacked("FJD"))); // 50

        bytes3 lastTab = tr.tabList(49);
        console.log(TabERC20(tr.tabs(lastTab)).symbol()); // sFJD

        tr.createTab(bytes3(abi.encodePacked("FKP")));
        tr.createTab(bytes3(abi.encodePacked("GBP")));
        tr.createTab(bytes3(abi.encodePacked("GEL")));
        tr.createTab(bytes3(abi.encodePacked("GGP")));
        tr.createTab(bytes3(abi.encodePacked("GHS")));
        tr.createTab(bytes3(abi.encodePacked("GIP")));
        tr.createTab(bytes3(abi.encodePacked("GMD")));
        tr.createTab(bytes3(abi.encodePacked("GNF")));
        tr.createTab(bytes3(abi.encodePacked("GTQ")));
        tr.createTab(bytes3(abi.encodePacked("GYD"))); // 60
        tr.createTab(bytes3(abi.encodePacked("HKD")));
        tr.createTab(bytes3(abi.encodePacked("HNL")));
        tr.createTab(bytes3(abi.encodePacked("HRK")));
        tr.createTab(bytes3(abi.encodePacked("HTG")));
        tr.createTab(bytes3(abi.encodePacked("HUF")));
        tr.createTab(bytes3(abi.encodePacked("IDR")));
        tr.createTab(bytes3(abi.encodePacked("ILS")));
        tr.createTab(bytes3(abi.encodePacked("IMP")));
        // tr.createTab(bytes3(abi.encodePacked("INR")));
        tr.createTab(bytes3(abi.encodePacked("IQD")));
        tr.createTab(bytes3(abi.encodePacked("IRR"))); // 70
        tr.createTab(bytes3(abi.encodePacked("ISK")));
        tr.createTab(bytes3(abi.encodePacked("JEP")));
        tr.createTab(bytes3(abi.encodePacked("JMD")));
        tr.createTab(bytes3(abi.encodePacked("JOD")));
        // tr.createTab(bytes3(abi.encodePacked("JPY")));
        tr.createTab(bytes3(abi.encodePacked("KES")));
        tr.createTab(bytes3(abi.encodePacked("KGS")));
        tr.createTab(bytes3(abi.encodePacked("KHR")));
        tr.createTab(bytes3(abi.encodePacked("KMF")));
        tr.createTab(bytes3(abi.encodePacked("KRW")));
        tr.createTab(bytes3(abi.encodePacked("KWD"))); // 80
        tr.createTab(bytes3(abi.encodePacked("KYD")));
        tr.createTab(bytes3(abi.encodePacked("KZT")));
        tr.createTab(bytes3(abi.encodePacked("LAK")));
        tr.createTab(bytes3(abi.encodePacked("LBP")));
        tr.createTab(bytes3(abi.encodePacked("LKR")));
        tr.createTab(bytes3(abi.encodePacked("LRD")));
        tr.createTab(bytes3(abi.encodePacked("LSL")));
        tr.createTab(bytes3(abi.encodePacked("LYD")));
        tr.createTab(bytes3(abi.encodePacked("MAD")));
        tr.createTab(bytes3(abi.encodePacked("MDL"))); // 90
        tr.createTab(bytes3(abi.encodePacked("MGA")));
        tr.createTab(bytes3(abi.encodePacked("MKD")));
        tr.createTab(bytes3(abi.encodePacked("MMK")));
        tr.createTab(bytes3(abi.encodePacked("MNT")));
        tr.createTab(bytes3(abi.encodePacked("MOP")));
        tr.createTab(bytes3(abi.encodePacked("MRU")));
        tr.createTab(bytes3(abi.encodePacked("MUR")));
        tr.createTab(bytes3(abi.encodePacked("MVR")));
        tr.createTab(bytes3(abi.encodePacked("MWK")));
        tr.createTab(bytes3(abi.encodePacked("MXN"))); // 100
        // tr.createTab(bytes3(abi.encodePacked("MYR")));
        // tr.createTab(bytes3(abi.encodePacked("MZN")));

        lastTab = tr.tabList(99);
        console.log(TabERC20(tr.tabs(lastTab)).symbol()); // sMXN

        tr.createTab(bytes3(abi.encodePacked("NAD")));
        tr.createTab(bytes3(abi.encodePacked("NGN")));
        tr.createTab(bytes3(abi.encodePacked("NIO")));
        tr.createTab(bytes3(abi.encodePacked("NOK")));
        tr.createTab(bytes3(abi.encodePacked("NPR")));
        tr.createTab(bytes3(abi.encodePacked("NZD")));
        tr.createTab(bytes3(abi.encodePacked("OMR")));
        tr.createTab(bytes3(abi.encodePacked("PAB")));
        tr.createTab(bytes3(abi.encodePacked("PEN")));
        tr.createTab(bytes3(abi.encodePacked("PGK"))); // 110
        tr.createTab(bytes3(abi.encodePacked("PHP")));
        tr.createTab(bytes3(abi.encodePacked("PKR")));
        tr.createTab(bytes3(abi.encodePacked("PLN")));
        tr.createTab(bytes3(abi.encodePacked("PYG")));
        tr.createTab(bytes3(abi.encodePacked("QAR")));
        tr.createTab(bytes3(abi.encodePacked("RON")));
        tr.createTab(bytes3(abi.encodePacked("RSD")));
        tr.createTab(bytes3(abi.encodePacked("RUB")));
        tr.createTab(bytes3(abi.encodePacked("RWF")));
        tr.createTab(bytes3(abi.encodePacked("SAR"))); // 120
        tr.createTab(bytes3(abi.encodePacked("SBD")));
        tr.createTab(bytes3(abi.encodePacked("SCR")));
        tr.createTab(bytes3(abi.encodePacked("SDG")));
        tr.createTab(bytes3(abi.encodePacked("SEK")));
        tr.createTab(bytes3(abi.encodePacked("SGD")));
        tr.createTab(bytes3(abi.encodePacked("SHP")));
        tr.createTab(bytes3(abi.encodePacked("SLL")));
        tr.createTab(bytes3(abi.encodePacked("SOS")));
        tr.createTab(bytes3(abi.encodePacked("SRD")));
        tr.createTab(bytes3(abi.encodePacked("SYP"))); // 130
        tr.createTab(bytes3(abi.encodePacked("SZL")));
        tr.createTab(bytes3(abi.encodePacked("THB")));
        tr.createTab(bytes3(abi.encodePacked("TJS")));
        tr.createTab(bytes3(abi.encodePacked("TMT")));
        tr.createTab(bytes3(abi.encodePacked("TND")));
        tr.createTab(bytes3(abi.encodePacked("TOP")));
        tr.createTab(bytes3(abi.encodePacked("TRY")));
        // tr.createTab(bytes3(abi.encodePacked("TTD")));
        tr.createTab(bytes3(abi.encodePacked("TWD")));
        tr.createTab(bytes3(abi.encodePacked("TZS")));
        tr.createTab(bytes3(abi.encodePacked("UAH"))); // 140
        tr.createTab(bytes3(abi.encodePacked("UGX")));
        // tr.createTab(bytes3(abi.encodePacked("USD")));
        tr.createTab(bytes3(abi.encodePacked("UYU")));
        tr.createTab(bytes3(abi.encodePacked("UZS")));
        tr.createTab(bytes3(abi.encodePacked("VES")));
        tr.createTab(bytes3(abi.encodePacked("VND")));
        tr.createTab(bytes3(abi.encodePacked("VUV")));
        tr.createTab(bytes3(abi.encodePacked("WST")));
        tr.createTab(bytes3(abi.encodePacked("XAF")));
        tr.createTab(bytes3(abi.encodePacked("XCD")));
        tr.createTab(bytes3(abi.encodePacked("XOF"))); // 150
        tr.createTab(bytes3(abi.encodePacked("XPF")));
        tr.createTab(bytes3(abi.encodePacked("YER")));
        tr.createTab(bytes3(abi.encodePacked("ZAR")));
        tr.createTab(bytes3(abi.encodePacked("ZMW")));
        tr.createTab(bytes3(abi.encodePacked("ZWL"))); // 155

        lastTab = tr.tabList(154);
        console.log(TabERC20(tr.tabs(lastTab)).symbol()); // sZWL

        vm.stopBroadcast();
    }

}