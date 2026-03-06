// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";

/// @dev NOT FOR DEPLOYMENT. 
/// Simulate Tab deployment and list all supported Tab addresses.
contract ListTabAddress is Script {
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    address tabFactoryAddr = 0x83F19d560935F5299E7DE4296e7cb7adA0417525;
    address governanceTimelockController = 0x783bDAF73E8F40672421204d6FF3f448767d72c6;
    address vaultManagerAddr = 0xeAf6aB024D4a7192322090Fea1C402a5555cD107;

    TabFactory tabFactory;

    error EmptyCharacter();

    /**
    Base testnet:
  AED:  0x0c25716b5400DDcdD68dBFDcE52a7D090750F8a7
  AFN:  0x262936c150734Ce280bA544f66F148F800CaDB35
  ALL:  0xc55cb1581837EC5bf95F61E68C087F66DDA0184f
  AMD:  0x3De6E32E5C1220ffCbd8D313f36a2eD335A6d7A4
  ANG:  0x299ccF50f67d21972Dac00Db9566715D53a475cf
  AOA:  0xDf0d18482E3C85ebfbB1e32f8E45A2663F111c50
  ARS:  0x2beC369ce12A60857f91A38F1d9f4475EcAf7AA0
  AUD:  0xEE16BBA74B33f3405853aA3c80FD1cbc0e22d9E7
  AWG:  0x91fEdB3e7151b5Ec9541f97671be6678129b4A63
  AZN:  0xbeCc040fDF4EF43f9b5690abc22Db4fb986596B6
  BAM:  0x20c6f332cF946CcD7404202E40A8D0475200e854
  BBD:  0xA2613Cb2A22906F1ad5D6967e9973453e8A6D292
  BDT:  0x282Ff0bfbC930FF11334ab9D8784C57EfC551e9b
  BGN:  0xe68D889ED043439Eec6552769A444563ea73938a
  BHD:  0xaFeF35C805a0DC5668FB239d5651Cb788b7B0084
  BIF:  0x3A022Fd846EAf8Ed65c84475E75Ce4f3C5B1095a
  BMD:  0xC43b78618Cb169B051B443E3a02bB774AD83E2B6
  BND:  0x66E45C84C9bDCf5B35f02de9F2142a6566bc42a5
  BOB:  0xb0dF5adCD2E1fD7d0744783809b077fC3cAfFB45
  BRL:  0xA33fEd5336cF0c085937Af9EAa453227Dd399eB6
  BSD:  0x4495dcad057Cac5256603D6751787f6366f669de
  BTN:  0x162b2f92B0627ae1072E1F500993A45c37196A90
  BWP:  0x5B2C65199b9Bd03e307950aE6CcEb4FD8d6Be4d8
  BYN:  0x65B4a30693984273D0Bc4E7b72E181b8F9740DA2
  BZD:  0x732dC2857f0b320a20F502f5cAA6B602B428d186
  CAD:  0x29e029AAf11EB13651202924D287D98E1eD0CfEA
  CDF:  0x18b1AF6957671fC377558Bf495EAc91225e97286
  CHF:  0x16f3668FeeB62f3a7c96652a286713C09c5Fd9e1
  CLP:  0x287987973AEaB3855f69b850723829265aF8c34f
  CNY:  0x3040ea7cE89Bc9beE838a4Ad68Da0CF110768c2e
  COP:  0x8eAceF18d249d4fbF06C42aeE795d31Ba6c7D447
  CRC:  0x0c1d9272fc7c7bd3016E21f3bd26f1af2C60f45D
  CUP:  0x099624134E7A13402aF37196e021918a218ac141
  CVE:  0x2fd9bB3c623AE45AB17Be85Ad728b8D007f7fd43
  CZK:  0xcA4DB2F437Ecd30B793f64D287B8785d525C45c7
  DJF:  0x0b8e8ED32b930A88745e87aDa19168f5FAe485E5
  DKK:  0x661F0749771d879BF9B30a4fFEb973F57c2049Cf
  DOP:  0xD1840660594456ae3aaDB4189ADF67989F1f8876
  DZD:  0xFc19D1D9f4D2cC355bf3E71b0aB25f1A2a97aBFd
  EGP:  0x0052aD7ff76D1088FF901eec300E212EB5f72729
  ERN:  0x7F6B944a5f3353EA4c6431E620a75976b65b44b3
  ETB:  0x077B94bff698601F9692cB96B02570fa68d8f893
  EUR:  0xAFC46f4bc6C583e532029fBeA39e845B0E460D9C
  FJD:  0x2b9f54C504E72d23Dacc472A57eFe8bff7d88Dc4
  FKP:  0x4BE742cabB4A96127e1F400a9bB6730b3CFffbC8
  GBP:  0xEFCa6167b7c57B7d01DaA4B8bF7259b6de6cEAC3
  GEL:  0x12b81ee1719C6B9DD6756BE016C1bF09B49B0c1F
  GGP:  0x2E652cf77c8961150c0BB4Ba67975D80d69d5Ff7
  GHS:  0xe82213617e4D93d10BA7620970245441d327251D
  GIP:  0xb2b9880D93f17493dc5a691A2b003bFfb8D03D66
  GMD:  0xe0B52Eff9888aB26675B789B6bEBEa24Bf53bcA3
  GNF:  0x5afB01d8AC8042Ec3D318Db79244010C469A379A
  GTQ:  0x1f28323c2a61d5BB2B450dD3623f0Bda56fc4a02
  GYD:  0x11596ccc7Df70c29CfBDD72A0C210dbCE8B3b2b9
  HKD:  0x3948C7acddb216614d391bC2C69173982d716557
  HNL:  0x98ACCd1e0027e5e08420F53cEc08AC15a0d4AD39
  HRK:  0x47580499d47693C41684a659EFB194903F5e5396
  HTG:  0x4C3A5ABca343f78Ee766c25F37892A2bd908E35E
  HUF:  0x61b951d191E99A13f118f2E3664E94CBe345Ed14
  IDR:  0x5ae4597Dce48196a4D575174A278458a7A979081
  ILS:  0x93B72dEACA4733f7F5dB1284881DCc2D0A123834
  IMP:  0x948ff2D2ac018D3264fd506de83D2631752C8648
  INR:  0xD980b13eB7abF9c342567D890EB68cB23dcF605F
  IQD:  0x071C353bd4b812Df51934aB06c665568F93e751B
  IRR:  0x5Db074f323751C62b4436309f876F9e5d8A8d1Bf
  ISK:  0x10cD9CB80Dc2270f97B498A665cb688F2d313330
  JEP:  0x08571895C16314C63D68177896B6FAB1a2f23084
  JMD:  0x022C819f1D8cd99A2D1047EA53AD26BE8A150304
  JOD:  0x1Cb9a458f6df2B26f0a86B985c36F34Fc32D0616
  JPY:  0xE5982507419290a88462e3b83cc469A4883d30Df
  KES:  0x9BBaf572a50Ef35E7cF65d04845Feb3c9CB2baE3
  KGS:  0x9b7F8bBe7233863ee1652ceDd34e853D9a08D183
  KHR:  0x4fD4a45f860D0BDb3B814ef715DFB441EE875539
  KMF:  0xb636b39e045ac7cC50a2Fa39Dcc00B66CbC68f8C
  KRW:  0x74f7C2a234029b2DaF903DeEa73Cb896BC8ECA90
  KWD:  0xBE880D87605c8F32c4a2dBB5EB13413eDA60117A
  KYD:  0xFdd0EF12853270Be42BC564DB743071509262f0c
  KZT:  0xd19e1B8c2a490F687adCD51798a2E7Adf314e8EF
  LAK:  0xA423413953CB1aFf1A9b0Cf5E24d547b50d25F0c
  LBP:  0x6f0EcAF0bC75500cD5e39c572D9Ca51e536c0AE1
  LKR:  0x4bF7159D5eB24B7a0D9469A633995251B4c1ffCc
  LRD:  0x621132a2A703FA6B61a208cc9620D4A14DEaf34e
  LSL:  0x00295bF84de98BDa0DaD65eB0D9D292c1F8704B0
  LYD:  0x0aD3A503903143Dd4159b36b553A4ae05bE29054
  MAD:  0xd73eF97da63644D63A0F5bC56a187c229eFb4293
  MDL:  0x47158C9b308fBaaAB2825241CcC4f4Ff57668050
  MGA:  0xc14C8CbAd31BB3Dba07ab4Ed3cD6b70e4c1B6fF5
  MKD:  0x515E7cC3A664B668B06099cC3618bCfDE6013906
  MMK:  0x0581561694B583e02Ec18C01b2Ff2Aa090032dac
  MNT:  0xc8ae925C365109F5b7ed271e116aD09C3c952708
  MOP:  0x91165823AE47408E9543c2536c2fB3D1CBC9A5A4
  MRU:  0x32FBdeb5D2754FfC894bE8d118A9A85FB953bD9E
  MUR:  0x719c1dB168F38B312FE3C71eeFd7b5535dd870bA
  MVR:  0xDa1Df19F3E808cc279aD0E8d92F5287BAc37cC2A
  MWK:  0xe62691Cdb8664A4AA43d3644bdE1B386dfe73ea0
  MXN:  0xa29d8002DB5Ee7bd529956125A0275d5570Abc3d
  MYR:  0x1ef63DC63a436804cA505c10Bf0258c1Cd9a53d7
  MZN:  0x3ecD16fC562DBb9928623fe415C9DEbDe667e10c
  NAD:  0x2642CAf68D85b8d9AbF3903a861c5b68c36cf101
  NGN:  0x44655242f5eB29f42bEfAa8A5D1ba9496FFa0459
  NIO:  0x6B23744a918363f0946e4AFf920f728F550166DD
  NOK:  0x9d1C766a1149E89cf8F5a83E7483f4Ebcc9Ba83e
  NPR:  0x033B5DC4bB2B355A4A784A1f76768AbDc565495A
  NZD:  0x6EbC3c5a53A7268FF3d1f9cB558Ce9C7d0f78a3f
  OMR:  0x1AbF1336B157be0e075BABd6D918BCBA43678e45
  PAB:  0x251BD2Be532c1d1D5dA0ac94A5B9F978B5BAb345
  PEN:  0x00748C8C2d46a9cDF505dd3d4ff5cEc184515055
  PGK:  0x18c1454446506293602b70F72982F199B7aad1Ec
  PHP:  0xE8a122eb498110F7bA520310F9762A423dB0a0ea
  PKR:  0x41cFA2314c01B8d8F2E5159C247F1bBaEB5E3335
  PLN:  0xE0a374f6c1d84B17F3c57675356849a6deC78d75
  PYG:  0x7c067c543Ef82b6aEd0548F2AC29a512FAd8ebFD
  QAR:  0x667130ACF60d26328436ecD8F444511E13208119
  RON:  0xC106a48883Eb618D3f57675Dbdd866e33a8785A9
  RSD:  0xE07924f2B5d507Cf2deA1070e213D00E2AE18151
  RUB:  0x609cCd3BEEdE2d6b610667348F7131939a8E19B2
  RWF:  0x43bf09F412dDbc465494fC3F5D4A66b42947637a
  SAR:  0xbd4E6164c97DCEE457E90C31773D125Bfe2B284D
  SBD:  0xdF5c2b3B7C2da832F5B25878B906e159b8853a27
  SCR:  0xFa61BA015E2628Cb41c704Bbf41f2d3Eb6e67Fe7
  SDG:  0xB7F6bc17C36E4A92A646FE7bC99951c27711C1c4
  SEK:  0x4FeDdA7f9Da457A3AC97dCCc0c5e8d4999Bc0A95
  SGD:  0x61390eFC188117Ca4B6D6E2Bf170987a04e1Ee17
  SHP:  0x3ebF50eb03265D255C38ba7395fFBf2da0F3bDc6
  SLL:  0xb263FC05560d7eC5e6178c1C019D8abA58ca8131
  SOS:  0xF8ca08613153Bed4a4fE46991F8b416880A29C99
  SRD:  0x73f3D735454f5e11911b12b5A6592e7cbcC1d274
  SYP:  0x7786F4E65D6E01FF1b47798d45d9183Da88C2Fbd
  SZL:  0x8CBd3348dAd85ea44DE3c0A2CB1B059206155b77
  THB:  0xDb6EB5B7ddA428D3cC5fb78B3d2868e2EEE01446
  TJS:  0xC2B3FEA32F77EAb6D156CA38A77E4bC09B1b90bB
  TMT:  0xffE497D78Cea618449E6Ec0Ae8d0aA2F8C576df4
  TND:  0x6593ECee054B78f74340B9f949CBbfbEE3d4c815
  TOP:  0x34608820267E838BF39C117f3a4D25A0bDC3A798
  TRY:  0xE6059Dee269Aac0A4790e5e377cdbcAC73DA0fCB
  TTD:  0x15ff479F1cD03AeE2dD6CF0cB4647B96950B5AaA
  TWD:  0x245b7889D15E138EFd07Bf3Ff2E96f29B057Ac86
  TZS:  0x2c59174AbE51E4F6206b2F8Ddf3D8dD66F8F6Bc2
  UAH:  0x03236aeeba126545FC648004ab2d378A32d49Af6
  UGX:  0xdD65cB20f575a0d19b6FCfb84A8d6Fe0C0A82EE6
  USD:  0x8838Af86EC345838393de780bb6885681737dd7E
  UYU:  0x2222B9807a586E52542b2B7F9F6baad107c38d6C
  UZS:  0xa6a4b5fF2d96C2c10FB53afFd263916388A0c42A
  VES:  0x0509bB074451D4B7f944d279b67e8496939c092D
  VND:  0x17bb0B8a53B44DcCF163B0531dB9D6a773ccbB09
  VUV:  0xedC5EE7caDe7Ad7C5A43D84d6EaA1833775d8361
  WST:  0x682a5b0ef5841F97284a45A06e516F84ed4F6169
  XAF:  0x69ba1B22bd8A102151BBd90ca8fEC718A7Dd86c6
  XCD:  0x5bf53Ba577cF1a9ce17A29a989801882c79c0a32
  XOF:  0x9CAc930E30612e6E896142a15A07dB87E0826642
  XPF:  0x4FD1488281bf01ED9417d484E18e1ED142f3ED99
  YER:  0x10F64470B6bb7bdF9dbAa77d5F9FD437e1D0B668
  ZAR:  0xE1Ac164290FD94d8A4949aa28B4341fD26322f56
  ZMW:  0xf1dAE7491887a47d56E5d39501321976Bf6F7F28
  ZWL:  0xd4b1f6Cf342208fB4B37fa17843a3686b236B8d2
     */
    function run() external {
        vm.startBroadcast(deployer);
        
        tabFactory = TabFactory(tabFactoryAddr);
        console.log("TabFactory existed at:", address(tabFactory));

        // Setting permission to call `createTab` in next step
        tabFactory.updateCreator(deployer);
        console.log("TabRegistry is updated to:", deployer);

        console.log("AED: ", deployTab(bytes3(abi.encodePacked("AED"))));
        console.log("AFN: ", deployTab(bytes3(abi.encodePacked("AFN"))));
        console.log("ALL: ", deployTab(bytes3(abi.encodePacked("ALL"))));
        console.log("AMD: ", deployTab(bytes3(abi.encodePacked("AMD"))));
        console.log("ANG: ", deployTab(bytes3(abi.encodePacked("ANG"))));
        console.log("AOA: ", deployTab(bytes3(abi.encodePacked("AOA"))));
        console.log("ARS: ", deployTab(bytes3(abi.encodePacked("ARS"))));
        console.log("AUD: ", deployTab(bytes3(abi.encodePacked("AUD"))));
        console.log("AWG: ", deployTab(bytes3(abi.encodePacked("AWG"))));
        console.log("AZN: ", deployTab(bytes3(abi.encodePacked("AZN"))));
        console.log("BAM: ", deployTab(bytes3(abi.encodePacked("BAM"))));
        console.log("BBD: ", deployTab(bytes3(abi.encodePacked("BBD"))));
        console.log("BDT: ", deployTab(bytes3(abi.encodePacked("BDT"))));
        console.log("BGN: ", deployTab(bytes3(abi.encodePacked("BGN"))));
        console.log("BHD: ", deployTab(bytes3(abi.encodePacked("BHD"))));
        console.log("BIF: ", deployTab(bytes3(abi.encodePacked("BIF"))));
        console.log("BMD: ", deployTab(bytes3(abi.encodePacked("BMD"))));
        console.log("BND: ", deployTab(bytes3(abi.encodePacked("BND"))));
        console.log("BOB: ", deployTab(bytes3(abi.encodePacked("BOB"))));
        console.log("BRL: ", deployTab(bytes3(abi.encodePacked("BRL"))));
        console.log("BSD: ", deployTab(bytes3(abi.encodePacked("BSD"))));
        console.log("BTN: ", deployTab(bytes3(abi.encodePacked("BTN"))));
        console.log("BWP: ", deployTab(bytes3(abi.encodePacked("BWP"))));
        console.log("BYN: ", deployTab(bytes3(abi.encodePacked("BYN"))));
        console.log("BZD: ", deployTab(bytes3(abi.encodePacked("BZD"))));
        console.log("CAD: ", deployTab(bytes3(abi.encodePacked("CAD"))));
        console.log("CDF: ", deployTab(bytes3(abi.encodePacked("CDF"))));
        console.log("CHF: ", deployTab(bytes3(abi.encodePacked("CHF"))));
        console.log("CLP: ", deployTab(bytes3(abi.encodePacked("CLP"))));
        console.log("CNY: ", deployTab(bytes3(abi.encodePacked("CNY"))));
        console.log("COP: ", deployTab(bytes3(abi.encodePacked("COP"))));
        console.log("CRC: ", deployTab(bytes3(abi.encodePacked("CRC"))));
        console.log("CUP: ", deployTab(bytes3(abi.encodePacked("CUP"))));
        console.log("CVE: ", deployTab(bytes3(abi.encodePacked("CVE"))));
        console.log("CZK: ", deployTab(bytes3(abi.encodePacked("CZK"))));
        console.log("DJF: ", deployTab(bytes3(abi.encodePacked("DJF"))));
        console.log("DKK: ", deployTab(bytes3(abi.encodePacked("DKK"))));
        console.log("DOP: ", deployTab(bytes3(abi.encodePacked("DOP"))));
        console.log("DZD: ", deployTab(bytes3(abi.encodePacked("DZD"))));
        console.log("EGP: ", deployTab(bytes3(abi.encodePacked("EGP"))));
        console.log("ERN: ", deployTab(bytes3(abi.encodePacked("ERN"))));
        console.log("ETB: ", deployTab(bytes3(abi.encodePacked("ETB"))));
        console.log("EUR: ", deployTab(bytes3(abi.encodePacked("EUR"))));
        console.log("FJD: ", deployTab(bytes3(abi.encodePacked("FJD"))));
        console.log("FKP: ", deployTab(bytes3(abi.encodePacked("FKP"))));
        console.log("GBP: ", deployTab(bytes3(abi.encodePacked("GBP"))));
        console.log("GEL: ", deployTab(bytes3(abi.encodePacked("GEL"))));
        console.log("GGP: ", deployTab(bytes3(abi.encodePacked("GGP"))));
        console.log("GHS: ", deployTab(bytes3(abi.encodePacked("GHS"))));
        console.log("GIP: ", deployTab(bytes3(abi.encodePacked("GIP"))));
        console.log("GMD: ", deployTab(bytes3(abi.encodePacked("GMD"))));
        console.log("GNF: ", deployTab(bytes3(abi.encodePacked("GNF"))));
        console.log("GTQ: ", deployTab(bytes3(abi.encodePacked("GTQ"))));
        console.log("GYD: ", deployTab(bytes3(abi.encodePacked("GYD"))));
        console.log("HKD: ", deployTab(bytes3(abi.encodePacked("HKD"))));
        console.log("HNL: ", deployTab(bytes3(abi.encodePacked("HNL"))));
        console.log("HRK: ", deployTab(bytes3(abi.encodePacked("HRK"))));
        console.log("HTG: ", deployTab(bytes3(abi.encodePacked("HTG"))));
        console.log("HUF: ", deployTab(bytes3(abi.encodePacked("HUF"))));
        console.log("IDR: ", deployTab(bytes3(abi.encodePacked("IDR"))));
        console.log("ILS: ", deployTab(bytes3(abi.encodePacked("ILS"))));
        console.log("IMP: ", deployTab(bytes3(abi.encodePacked("IMP"))));
        console.log("INR: ", deployTab(bytes3(abi.encodePacked("INR"))));
        console.log("IQD: ", deployTab(bytes3(abi.encodePacked("IQD"))));
        console.log("IRR: ", deployTab(bytes3(abi.encodePacked("IRR"))));
        console.log("ISK: ", deployTab(bytes3(abi.encodePacked("ISK"))));
        console.log("JEP: ", deployTab(bytes3(abi.encodePacked("JEP"))));
        console.log("JMD: ", deployTab(bytes3(abi.encodePacked("JMD"))));
        console.log("JOD: ", deployTab(bytes3(abi.encodePacked("JOD"))));
        console.log("JPY: ", deployTab(bytes3(abi.encodePacked("JPY"))));
        console.log("KES: ", deployTab(bytes3(abi.encodePacked("KES"))));
        console.log("KGS: ", deployTab(bytes3(abi.encodePacked("KGS"))));
        console.log("KHR: ", deployTab(bytes3(abi.encodePacked("KHR"))));
        console.log("KMF: ", deployTab(bytes3(abi.encodePacked("KMF"))));
        console.log("KRW: ", deployTab(bytes3(abi.encodePacked("KRW"))));
        console.log("KWD: ", deployTab(bytes3(abi.encodePacked("KWD"))));
        console.log("KYD: ", deployTab(bytes3(abi.encodePacked("KYD"))));
        console.log("KZT: ", deployTab(bytes3(abi.encodePacked("KZT"))));
        console.log("LAK: ", deployTab(bytes3(abi.encodePacked("LAK"))));
        console.log("LBP: ", deployTab(bytes3(abi.encodePacked("LBP"))));
        console.log("LKR: ", deployTab(bytes3(abi.encodePacked("LKR"))));
        console.log("LRD: ", deployTab(bytes3(abi.encodePacked("LRD"))));
        console.log("LSL: ", deployTab(bytes3(abi.encodePacked("LSL"))));
        console.log("LYD: ", deployTab(bytes3(abi.encodePacked("LYD"))));
        console.log("MAD: ", deployTab(bytes3(abi.encodePacked("MAD"))));
        console.log("MDL: ", deployTab(bytes3(abi.encodePacked("MDL"))));
        console.log("MGA: ", deployTab(bytes3(abi.encodePacked("MGA"))));
        console.log("MKD: ", deployTab(bytes3(abi.encodePacked("MKD"))));
        console.log("MMK: ", deployTab(bytes3(abi.encodePacked("MMK"))));
        console.log("MNT: ", deployTab(bytes3(abi.encodePacked("MNT"))));
        console.log("MOP: ", deployTab(bytes3(abi.encodePacked("MOP"))));
        console.log("MRU: ", deployTab(bytes3(abi.encodePacked("MRU"))));
        console.log("MUR: ", deployTab(bytes3(abi.encodePacked("MUR"))));
        console.log("MVR: ", deployTab(bytes3(abi.encodePacked("MVR"))));
        console.log("MWK: ", deployTab(bytes3(abi.encodePacked("MWK"))));
        console.log("MXN: ", deployTab(bytes3(abi.encodePacked("MXN"))));
        console.log("MYR: ", deployTab(bytes3(abi.encodePacked("MYR"))));
        console.log("MZN: ", deployTab(bytes3(abi.encodePacked("MZN"))));
        console.log("NAD: ", deployTab(bytes3(abi.encodePacked("NAD"))));
        console.log("NGN: ", deployTab(bytes3(abi.encodePacked("NGN"))));
        console.log("NIO: ", deployTab(bytes3(abi.encodePacked("NIO"))));
        console.log("NOK: ", deployTab(bytes3(abi.encodePacked("NOK"))));
        console.log("NPR: ", deployTab(bytes3(abi.encodePacked("NPR"))));
        console.log("NZD: ", deployTab(bytes3(abi.encodePacked("NZD"))));
        console.log("OMR: ", deployTab(bytes3(abi.encodePacked("OMR"))));
        console.log("PAB: ", deployTab(bytes3(abi.encodePacked("PAB"))));
        console.log("PEN: ", deployTab(bytes3(abi.encodePacked("PEN"))));
        console.log("PGK: ", deployTab(bytes3(abi.encodePacked("PGK"))));
        console.log("PHP: ", deployTab(bytes3(abi.encodePacked("PHP"))));
        console.log("PKR: ", deployTab(bytes3(abi.encodePacked("PKR"))));
        console.log("PLN: ", deployTab(bytes3(abi.encodePacked("PLN"))));
        console.log("PYG: ", deployTab(bytes3(abi.encodePacked("PYG"))));
        console.log("QAR: ", deployTab(bytes3(abi.encodePacked("QAR"))));
        console.log("RON: ", deployTab(bytes3(abi.encodePacked("RON"))));
        console.log("RSD: ", deployTab(bytes3(abi.encodePacked("RSD"))));
        console.log("RUB: ", deployTab(bytes3(abi.encodePacked("RUB"))));
        console.log("RWF: ", deployTab(bytes3(abi.encodePacked("RWF"))));
        console.log("SAR: ", deployTab(bytes3(abi.encodePacked("SAR"))));
        console.log("SBD: ", deployTab(bytes3(abi.encodePacked("SBD"))));
        console.log("SCR: ", deployTab(bytes3(abi.encodePacked("SCR"))));
        console.log("SDG: ", deployTab(bytes3(abi.encodePacked("SDG"))));
        console.log("SEK: ", deployTab(bytes3(abi.encodePacked("SEK"))));
        console.log("SGD: ", deployTab(bytes3(abi.encodePacked("SGD"))));
        console.log("SHP: ", deployTab(bytes3(abi.encodePacked("SHP"))));
        console.log("SLL: ", deployTab(bytes3(abi.encodePacked("SLL"))));
        console.log("SOS: ", deployTab(bytes3(abi.encodePacked("SOS"))));
        console.log("SRD: ", deployTab(bytes3(abi.encodePacked("SRD"))));
        console.log("SYP: ", deployTab(bytes3(abi.encodePacked("SYP"))));
        console.log("SZL: ", deployTab(bytes3(abi.encodePacked("SZL"))));
        console.log("THB: ", deployTab(bytes3(abi.encodePacked("THB"))));
        console.log("TJS: ", deployTab(bytes3(abi.encodePacked("TJS"))));
        console.log("TMT: ", deployTab(bytes3(abi.encodePacked("TMT"))));
        console.log("TND: ", deployTab(bytes3(abi.encodePacked("TND"))));
        console.log("TOP: ", deployTab(bytes3(abi.encodePacked("TOP"))));
        console.log("TRY: ", deployTab(bytes3(abi.encodePacked("TRY"))));
        console.log("TTD: ", deployTab(bytes3(abi.encodePacked("TTD"))));
        console.log("TWD: ", deployTab(bytes3(abi.encodePacked("TWD"))));
        console.log("TZS: ", deployTab(bytes3(abi.encodePacked("TZS"))));
        console.log("UAH: ", deployTab(bytes3(abi.encodePacked("UAH"))));
        console.log("UGX: ", deployTab(bytes3(abi.encodePacked("UGX"))));
        console.log("USD: ", deployTab(bytes3(abi.encodePacked("USD"))));
        console.log("UYU: ", deployTab(bytes3(abi.encodePacked("UYU"))));
        console.log("UZS: ", deployTab(bytes3(abi.encodePacked("UZS"))));
        console.log("VES: ", deployTab(bytes3(abi.encodePacked("VES"))));
        console.log("VND: ", deployTab(bytes3(abi.encodePacked("VND"))));
        console.log("VUV: ", deployTab(bytes3(abi.encodePacked("VUV"))));
        console.log("WST: ", deployTab(bytes3(abi.encodePacked("WST"))));
        console.log("XAF: ", deployTab(bytes3(abi.encodePacked("XAF"))));
        console.log("XCD: ", deployTab(bytes3(abi.encodePacked("XCD"))));
        console.log("XOF: ", deployTab(bytes3(abi.encodePacked("XOF"))));
        console.log("XPF: ", deployTab(bytes3(abi.encodePacked("XPF"))));
        console.log("YER: ", deployTab(bytes3(abi.encodePacked("YER"))));
        console.log("ZAR: ", deployTab(bytes3(abi.encodePacked("ZAR"))));
        console.log("ZMW: ", deployTab(bytes3(abi.encodePacked("ZMW"))));
        console.log("ZWL: ", deployTab(bytes3(abi.encodePacked("ZWL"))));

        vm.stopBroadcast();
    }

    function deployTab(bytes3 _tab) internal returns(address){
        string memory _symbol = _addTabCodePrefix(_tab);
        string memory _name = string(abi.encodePacked("Sound ", _tab));
        return tabFactory.createTab(governanceTimelockController, vaultManagerAddr, _name, _symbol, _tab);
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
}