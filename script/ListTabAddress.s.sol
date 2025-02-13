// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";

/// @dev NOT FOR DEPLOYMENT. 
/// Simulate Tab deployment and list all supported Tab addresses.
contract ListTabAddress is Script {
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;
    address tabFactoryAddr = 0x9F440e98dD11a44AeDC8CA88bb7cA3756fdfFED1;
    address governanceTimelockController = 0x4e41d11Cb9540891a55B9744a59025E5382DDeCF;
    address vaultManagerAddr = 0x11276132F98756673d66DBfb424d0ae0510d9219;

    TabFactory tabFactory;

    error EmptyCharacter();

    /**
     * Execution logs:
        AED:  0x573C70BDA571f0Dd550e2396cabbb254f9A46D94
        AFN:  0x038B897628530baC896DedEcEf8a615E8eb9765b
        ALL:  0x754eaBe5251950A6B50A1b2765113D048aE617F2
        AMD:  0x881aFB407fDe208E72A2f3a1CB9AbFDBDb56102D
        ANG:  0x05118C5d03B7cb8aD04d472DE99BB06C1dd7687F
        AOA:  0x29e6941e69583478e7Dc91f17500168923F7bE82
        ARS:  0x0510E16C7e051e39403Aef447381486C90D33D32
        AUD:  0x00C87C40625f55e4e288a174eDE1A76c73D761C1
        AWG:  0xBA4f53Df54Cf7390aFe6449B7F7b7fD8bF324B67
        AZN:  0x789f32B8F80c05e9D5Fc88afC5EE3FDcf47dE952
        BAM:  0xe1AC707f021441541C3e0B5C2B7AC609e371Cb7d
        BBD:  0x9100000e6a915e72C634B1195EB3288D49cd869d
        BDT:  0x01B1362E60DfA9B6BaE806637013D018AdA7416a
        BGN:  0x8E691d584c46cb6FCab86717ffefe6d0aE52dEaE
        BHD:  0x1d3C1eF28a1C057A409DfB9C2284e104F93fEC29
        BIF:  0x4d6fD05BF07404D46e54e189BAa2C57AefA94DA2
        BMD:  0xb95c6db25162378Af4822aa20BC04E4F89ce00b8
        BND:  0xb946047E6e578c867D8295bE7EEb49Cb099641D3
        BOB:  0x4DC657D8Ad06d379228e8eFB24e0f9E8def064eA
        BRL:  0x9bC7159218C2e4843458dc45Fbd83B43d7f819CC
        BSD:  0x3DBb55B9c1b0d4ed1A69eadEdb0f3F375cC3F896
        BTN:  0x84AeA2E58541b9dc0273ec76bCB03A95FB1F4FC4
        BWP:  0xA099AF6Ec61eF8E2cF3A28253a5FDCB16201B083
        BYN:  0x0d2CC873551Fe39e7192201518bA388012A93Ca1
        BZD:  0xe8897f16e538325014441b2Db5E626c66d9D4cca
        CAD:  0x2adeC7cB234D7517230f8f26A2E62c78197e50AA
        CDF:  0xBD8bfeA17878eCCC60cA1F1bA884BdA8179082c9
        CHF:  0xCb4Eb19085fbF9b37A9E6F2B2957d416FCAa1256
        CLP:  0x0a95b4285CBC200CbAD98e71158ed26677DB5445
        CNY:  0x4a779de862a92D7dD5d51F1655e05D157eB21ec8
        COP:  0xaEA7982450FB4D5315eDEa5DEB5497E2a2B63A97
        CRC:  0xFE8fB453e07473f2Ed5bC93E7Eaf75636f6b1312
        CUP:  0x8b72a9567F2B1E22377c69F65B34a921b9aABf6A
        CVE:  0xb300DC0395d05fCeDF7962E5299F49CE75625C73
        CZK:  0x3213526201621D3DD5D337eb998b3e71D95b94B6
        DJF:  0x791B5c51801B8D82c1C56973B8BF383012c514DB
        DKK:  0x4f2509f1172f1D2bEDf873348bCF88eEFD6E9C81
        DOP:  0x5058b86F9E261E45c2085443b537a5eCCac99243
        DZD:  0x503c5019562C0f9167809dC7B8B8A344705260b3
        EGP:  0x4EbAde0c7FF47B6bDA1Ed38198336615e7928D97
        ERN:  0x8eAaaa3593D6a9a6fA2443c97f90A292b0A2aA14
        ETB:  0x1B2dE9e6fe1749047A71cF576bC4C15C00f37c11
        EUR:  0x7b5A1aedE20Ff10c58e0a16DCA2F42f65661A2D7
        FJD:  0x077da518Dd6692f5B44571c1A306D2A95D7Da301
        FKP:  0x684220EC6123757909024DED82b331265943eA43
        GBP:  0x2966E31037e807C151A44aBe6781DB49196c9aD5
        GEL:  0x6a4B04936fC495207793e7F1b2F7E6E9Ab767c51
        GGP:  0xa89e2B9bcAc5a6d29C20C0DB86E89B0BF2ACAE4C
        GHS:  0x919fd1069b8a7d69d6F9a0ba9f4A9E8956f82081
        GIP:  0x6ed8E4FE9079d3b1F3509ea07b90718CeD778035
        GMD:  0x3e234ED951fC47C8E06da6B91F3Ce380AaDe7EF3
        GNF:  0xAD77115e0f73ab3d23f2B5D1E41F6d3fc3967F6c
        GTQ:  0x9c2eFD0CD34B25c891168B35d402Eafe24cbAf14
        GYD:  0x0B53320b1ee311dEC124574CC28B2BeDeC0E870b
        HKD:  0x47Fe5b99421Ef1D1902D93952f4CB5a413d5941c
        HNL:  0xC510e7A994b40B80c00c4d140B40d1B11732fE99
        HRK:  0x7bF34a9420a4d57A0A981B970aF8aB1EB4d61a3c
        HTG:  0xD59BFB7A0d9448536b882AEEB3c3A7FC427673aE
        HUF:  0xd96620985F71D253f62E2EE386084dE4f162D7B6
        IDR:  0x948AFB881560CA4AFE1aBCAE4B7A73B6eED25F37
        ILS:  0x000357566507D095C5c9de021F814567394509Fd
        IMP:  0x438897086123E91dC66E413a887f70990f2C35cE
        INR:  0xef426d7E917Ac006c2a553727E063B3b6bd5E571
        IQD:  0x96e0b9eacFC7539a46Cc3DE4Ae014eD427072fb0
        IRR:  0x39bB30C78205007D5919589D581927057559e467
        ISK:  0x714954715380Bdd100bD7B460addD97952fCb63a
        JEP:  0x60971e59A669b98d0089120Ba2462C396355ab5E
        JMD:  0x3Dc0f43F58944eEd99f0C910A9f4B20Aa8F79cd6
        JOD:  0x224640A2471c9f1200Bd526C3BeD6Dfe2BB2EC97
        JPY:  0x6354D92B986E7EcAB3Acd8532bb15c272bb64A10
        KES:  0x33B8b519874965E4E954746bCFF64890beac24F2
        KGS:  0xcbF2116622D367fB9FDD68ECb2aF83a11ACA7269
        KHR:  0x3523Bf87f7C11F5092b1Cb83076Edf8582523E56
        KMF:  0x2c85e179FE8B640c4852268444b7C769E124Ca32
        KRW:  0xbb0BCA220834A73475a92AF71a7bf1722c9F0830
        KWD:  0x42c8EeA1c5529C734279F71Dc1BDFfA01Ff95866
        KYD:  0x627e0c3FA686Fe418d444A07744b54c3509ecE07
        KZT:  0x5aFA340B8559A0BF47C91bE2b63AB5b33ee56551
        LAK:  0x84676E4EDC745c768cC565e4f1A46280747Ef92e
        LBP:  0x6375AC34EE21418107072446e7C681C8C6Ea11ca
        LKR:  0x1d453c1CA37a16E1462a7a0Ae43a7b4bF7F19a2a
        LRD:  0xE3ef932cAa717bB9935D97cc1Ee34f88ee221c9a
        LSL:  0x1db460B4a9443DEe9A2bE35F7d4A85213adC21c4
        LYD:  0xe3a19c93882f990F650A2906286758DF9D51160A
        MAD:  0xCc4a21aE6b38d6612606FC93D7aA525c43dB0D36
        MDL:  0x96dA16ed642BA4768b8B9DB2062Da25B952282C6
        MGA:  0x659A2Ce1D75F2324650035cF3EF31a8395c12694
        MKD:  0x5B34fEE054e3E9924fB07AF78117cE08a385A1C8
        MMK:  0x2A3E5E4c998b2EEa54535D708Cce32dAAC55AB77
        MNT:  0x6dee61e753ae9CB32c4d97E734515D916dF9B6Ba
        MOP:  0x02f2Ca08299C74EB0A9AA64c2cDBE0d31E56FB68
        MRU:  0xf320d87562aBd78cddca6fBEB712A2A91F6749Dc
        MUR:  0x7d1bDda341A57C27Bb5b9AAfD0765Dfb41A14122
        MVR:  0x41161797480cb5Ec96Caef6027651fc94a82a8Bb
        MWK:  0xe39856a21708F718eeB58e46c0091c43Af324F71
        MXN:  0xd84E678a613Af1Cc75F6D54b026bae378C261046
        MYR:  0x5F95f05e6fEd90Ab485af6163a37C819C1E4F2b2
        MZN:  0x08eeA9aE1Bd072A6de3c7046Fc02C086cAB2099E
        NAD:  0x656eFD6Bd484F7047BF77998cc425DE2f0A03204
        NGN:  0x702EE87E37080847072f9DB4D68EB67C55a43e5f
        NIO:  0xF8F8e3e38bfa8E0B5a549e7915D0B0B010a03C42
        NOK:  0xAeA6A33842AD16E11982D57e04a7b998C39c9460
        NPR:  0x1840D4D8020d0f658299380f583db6160C3954a8
        NZD:  0xD4F5CC6316203669E6B20b58534Fc08494dE71B2
        OMR:  0x3f9E863a686e680E578eE4Af42216EF6E98B1648
        PAB:  0x003857C0B121558fE46655Fe36bF07f1856c7aC2
        PEN:  0xF9B57704de766CEb5ca14851cAa8252c29362C6f
        PGK:  0x420a16FE0892126D5bedA06532a40d07F81C2dCD
        PHP:  0x804150B8DD7F2c663445CA043bAA3182c3Da59a8
        PKR:  0xA5e1Fca87883ad39176Ae7A4fcd90C6A3e1BAf62
        PLN:  0x8609EE837Ef762A6a85a48153Df0904f435E6E32
        PYG:  0x866d507140A31e7f56284236d03aa67188d54Ca4
        QAR:  0xD1d47E8F8352771fE8bE808224647240c373fbe8
        RON:  0x1247Dc3363AA8C7C97234D808E097eDe2A18369d
        RSD:  0xB374e823576caE5821085407052112f6be5B3E5f
        RUB:  0x0EEabA89F4402b0941806842d3824bCA0261f94e
        RWF:  0xaa8F58533b8dBdF4575fDb8298f7C50fB07B80C8
        SAR:  0x7b928eaBc416eB7220D684d8101593023a3972c8
        SBD:  0x22aEAfc2e522097e1AF437510BD8F604c326b9e7
        SCR:  0x2a52B71E53a9a259Cf031a4D721CF61F0648578c
        SDG:  0x2b5F29b1104Fcf78f1E15CBa5E3606C2421656D3
        SEK:  0xD8Ef9db0Fc640506933d3a7eF7704FC1C9810AA4
        SGD:  0x066757B81b0714174f389B4E6B813E17bBe70387
        SHP:  0x979C06f3705d07b857DbFB46E0F90c0534159236
        SLL:  0xA3Ad2577C40B60C50DAba99bcd55b993E0F1f685
        SOS:  0x437B5B59BFAdDfB62C3d3e243cF88857cC9F2d9e
        SRD:  0x15f049ec7e14bA506E7bbc906ceB49001788AD74
        SYP:  0x3aC3A92Dc144f61132EB0263F8eaD0B2B710F808
        SZL:  0xddA2dbB309695a1C7ecbcf7FCA5069830118165e
        THB:  0xF955c0e5B6c3305F240B1d0CEBF19C81fFB3DFF1
        TJS:  0x5Ff82C0bFFafc5aB6386c60FAbdE4c6f064b005b
        TMT:  0x936e0F93F2d09a8b1E4BCE6c05aeAB9098E9B5A8
        TND:  0x4D0aD248b9AB1DCc5a71304eFf5Ddcc1D92D864b
        TOP:  0xFDeE9dCE4abA7C74C10e49E136cb3CddC911B17d
        TRY:  0x9C45fBC3583BB8D61AFDd383F1859D4453b745E7
        TTD:  0x0CFB19DAAd02331DaE72257a89fC9Ae50bC33f6b
        TWD:  0xd273ddC9D4609d24C3bb1e36D39164cbc75d4670
        TZS:  0x26a9bF9bAd26d480910942B8A72Ef3A1D1151032
        UAH:  0xa3A58F40C36286c6445De52525d0A9e6f05d614F
        UGX:  0x6f30DD8C53D3600aF2AC137BA991A93EC4130692
        USD:  0xDe4939dE5a808038643a6fF2953c52C59612077c
        UYU:  0x7AC0cd56bed7b5d44216a48971B2947132D6dd5D
        UZS:  0x3556772c2F9f6A505cB80f1047629Ea07582574A
        VES:  0xba1A9FaD6f76BD5A76E9d91A2284e33c894889aB
        VND:  0x94B02abf0633e541373fad96ba5a93f06fe7a39e
        VUV:  0xCE5106303c9Adf20B6141029363Bc47bBc93Fe36
        WST:  0x0c3D8d394385C94fc76C3B720F896bC60206b265
        XAF:  0xc5683FaaD11DA61E8992c89906e682FCe73D6912
        XCD:  0x8b7082Ce1F14E8EDca68dDF4ecdd6E7FC600E79F
        XOF:  0x123B71AE036afeea69fe19701646be8eD34a2A9e
        XPF:  0x6eBB9803b4B300D9fcd6cC88B73dA62998bb8cc0
        YER:  0x2a9314742491728e5215D50d342a727C9294eCFA
        ZAR:  0x19D890f3cf2faE9FD515A86fe91ef418F5012283
        ZMW:  0x0A53A2817B1cD505ccd0d81Eed6894b3FC7B4535
        ZWL:  0x2e44c2096D3144Ff94B7B62B91a80c70a0F0399A
     */
    function run() external {
        vm.startBroadcast(deployer);
        
        tabFactory = TabFactory(tabFactoryAddr);
        console.log("TabFactory existed at:", address(tabFactory));

        // Setting permission to call `createTab` in next step
        tabFactory.updateTabRegistry(deployer);
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
        return tabFactory.createTab(governanceTimelockController, vaultManagerAddr, _name, _symbol);
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