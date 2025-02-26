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
     * Execution logs:
        AED:  0x4F25782ee4799F09FD7fc230a87AB5FDBda33dc4
        AFN:  0x93D9eF0FA083F22716486E254D179909436699Ff
        ALL:  0x3Ec5dB4eb6b86a319e45A763eDf037e02d6E389b
        AMD:  0xd96c7D29cbfE07B3b447f343485b71B596f82167
        ANG:  0x0307f9205E39911777980E172713C34b27E56CFf
        AOA:  0xEa47e0dde0d86d1a72A7e3a435A9ae3349DA6597
        ARS:  0x29226F79ba19D81e3CEE13214eCa8C6b04aDB3B2
        AUD:  0x77EE2019D73B8cfe179BEe76325EBA04a04A87fb
        AWG:  0x31d12e6a79677e3066e40EaeB422E66cd4abC02B
        AZN:  0x77d42A2Ddc2dB3032216ac78D721b5f473747CE8
        BAM:  0x25b61e92a3175e87e182E33fE670C05Ee9C6500c
        BBD:  0x4a9359fb1752B95A9875333050F3D24D80D24eAe
        BDT:  0x5B337F3fCcC9B23A3eDc7ec59fb546B3A7Ce359e
        BGN:  0x4b223C88b2Ed45A3853De87CC77E94Aaa3f711E3
        BHD:  0x899611D3FEA346977Af51e070a5671C784070000
        BIF:  0x028026E827480E2C44036db2Cb0455f3995B262F
        BMD:  0x7B3e898dD70Be7fae5bec66b1460c9d87586a7d0
        BND:  0xC31Ee3B6317A1413C12D5fcB5965213850a0b7b9
        BOB:  0x34d2F438445d122829C675a82c6E17aE4738Af7D
        BRL:  0x063526EE351792Cba73c13A18318c854E4C403d6
        BSD:  0x9557763712C4B069C1CA9050A0dcbf2Af443e9EC
        BTN:  0xbB245ED310ff386585A238C295c9299f73d5fba2
        BWP:  0xa4F4d7c8D488cE53E64ebC7Bd34c97C45EbF5c07
        BYN:  0x4B00834a05FC58abF99dF112B37Ea12bBD733f69
        BZD:  0x8869Ab94c5FD6D1113a06D9cf326969bb998cF09
        CAD:  0xF5EA8eADD8FC5dfEaeC54fD57Bca2b6e7b9021fd
        CDF:  0x3019bC45456885eEfC9bb3F683F0Ff73a918e1e1
        CHF:  0x1cec719bb8339b59b1db8fDd58B457E1BA99F77d
        CLP:  0xf2C42c870C7725f8E6072E77B500452FCcc6EeDe
        CNY:  0x1eC854b1D5276226E89FaAD3aB1385f8BB79C8B9
        COP:  0xa0801649726bf463eD79d6D18d59fD4fE4dD82C5
        CRC:  0x7DEa180a57e6B5215618BDB5005c15a4E09811Cb
        CUP:  0x0122ad2Ff8D19fee01627D0c0ACeA49050a26CA5
        CVE:  0x5947B4A002abADeB5d2a00F2766f907dbE349c3E
        CZK:  0x211248921997985cFE86792E093E4777ad68E5D4
        DJF:  0x3E13e11287b6EcC943AB9bb91C94E2e8Cfa7A8D2
        DKK:  0xBf9cF3e41FB293aD2d99750d90EeCfeE18c13e8c
        DOP:  0x4842fa510495C9c81bCb1B934F06d63e4D8C3B38
        DZD:  0x6c8bc4E8E95d3bd1bAEd5c2f1bD3224c77C02a72
        EGP:  0x1D487C545C70CF309F687aE0fA6703Ad9422D925
        ERN:  0x00D39ecf24de32A97D824b8A10F75405c8C5A3F6
        ETB:  0xFe1174c1F24F23E5F3d85f0Ab9d36a9d9F63F189
        EUR:  0xf42f613608Ff5Bb1B6B584243101552E11A58c7F
        FJD:  0x08a8B72a1EDb900bBE06F37350C7D59778F21834
        FKP:  0xC7725Bb48f97D94142690D7E6bcb5C49a1a421f9
        GBP:  0xF358eb7de3e0ac429Ed5F624f24F619381a0E5B8
        GEL:  0x47C5d45f1D78Ba6843f80F9DbeAc572C2484DD2C
        GGP:  0xbbFF59EB51aF6A7B7552De584c7E01569679D968
        GHS:  0xD888d78e8D147302cc8930C98eaB17706EE22e17
        GIP:  0xEfC3D87DB32f75221b629fb379b7493602D7e41C
        GMD:  0x395A69C741D0645271526CC958Bb875Be4d91008
        GNF:  0x5d57Bb2C28A0121214CFE70255509120ec6185Ff
        GTQ:  0xBb0F8214A41D073fcF5F2a7709cD30Fb7DA04d1c
        GYD:  0x3E49E9f15B3F56B1AF1f530633929ee4944Bfb06
        HKD:  0xdD9436E4B0EE1968F07dA2e6197F7103e9f7e6Ec
        HNL:  0x7b2E31bF343ed516b8cED5ea03885bB6B10F7bf8
        HRK:  0xc7DB90f93831A7e15d4F15E09d6Da63904Cc1619
        HTG:  0x91122160634E45fc1D3611BBEF0C6A91aF61668D
        HUF:  0xFFc85D81456B03F4c097Bc68336AAC8d2C827F54
        IDR:  0x5c28926918ff523dfAc80ee545198ac16265C229
        ILS:  0x601a37B5A05D238Fbd04FC0c83C276e681106d08
        IMP:  0xB164072bC26F17Cf3f71B4ddFA9fE2865bbdc480
        INR:  0x16437883CD39E96cE1e531e103a8356185B12168
        IQD:  0xF2e53b0B455CDeA24C3c13A4EE0aEaA25460d128
        IRR:  0xce360353420C0a515d0BB808E0AB0E28B9A52419
        ISK:  0xD2764D8C4c7f9E0BE38cE4D98016dc8deA2605d1
        JEP:  0xd7c6aA2810839e66a7f4c3Fa358cA41E5aCB13C3
        JMD:  0xAb37386131805C6AaDE93aF13363530F3ee01405
        JOD:  0x976cB4f39dECfe6834208c52CB1cdBAd5AE33Ab3
        JPY:  0x60e513F41aF473D447244076F8c3bF65152646a8
        KES:  0xf3F09676e600FD5a27d6d016133625EFbC315b7B
        KGS:  0x084e21f1840156783Ac3183DEb84fA1D6240BBac
        KHR:  0x9d36A0cfc40DfDd35B6D5784D5b9FA4aA122a774
        KMF:  0x4A4F13Eb8Ff3956437780be94F3f407732B3c5D4
        KRW:  0x2015a7B28229EFdBB0C4E170519A4CbbF1E19816
        KWD:  0x42C39d8a9b1bc4f65ACd1fAe31D449437b9C1083
        KYD:  0x98A55e3Fd590BcA3C5d6A833A0dFac3f137411a0
        KZT:  0xa7E4C375a8c9eDbFf2E04Bb88D1ceE274b878f22
        LAK:  0xeEb33363162fC6C7E37f54A76FC938e343B4a6F7
        LBP:  0x7227F69f1CA321e153697CD9C28012253FF2b7d4
        LKR:  0x31eFd70663b542364FFF735d44F60266CBa0453c
        LRD:  0x2DC02F41B9e6073735085457523cC6929B68Ea66
        LSL:  0x4316998651B4F0C8c4F9FDF736FE2dD1f0431B6C
        LYD:  0x442bcC90313b02Bfc702f7b04245e45AFee8399C
        MAD:  0x30d5b4aA150cdccBbB7dF4F9530cB736383677dB
        MDL:  0x36EFF6AAeab143Ec1CabfD5c6f0E7e2603Be77Fa
        MGA:  0x64D018453dd2332A22e73178DEe9F39cE0472755
        MKD:  0x26A2d3DB016FBcd5b38FdDCc5CcB4af3CA31f6ad
        MMK:  0xDdb064874eb42f95782bD07c847b5F46347cA828
        MNT:  0x940B0428D768D8994E386A8531D77Bd405E99776
        MOP:  0x1620342Cef00c06Adb772672C3b98b89F8b1Fd46
        MRU:  0xed5e373D2265E931FAEe1E9E10ef50eC03561eff
        MUR:  0xEba3a13C73e646965A331e3134dAAa7AcF4a4dc7
        MVR:  0x5Ec9E18af53AD656B392e78c34C3A722af353F57
        MWK:  0x1cc4211dd3ebcfFc4E8aE6e3e64eDCBA61b17417
        MXN:  0xB6Fd1dfB4dcf7b560AC779abE6C06FF21c7983be
        MYR:  0xcdFeE312e0d126dd41B9A7808D7107D3dA5aF4b8
        MZN:  0x0034049656fAF7A770d747178950Ab48f3aF7050
        NAD:  0x031237fd1512CA4840a7fA97CD3F0C08783e4d90
        NGN:  0xe843acD8292633e45E9f6B53893FE97BaF574Db5
        NIO:  0xDFA119B461A7bDaEA98B3620434C3bC510078A6E
        NOK:  0x225d2C44E8DD09eeBDDf32Ea2c022c0b29278C64
        NPR:  0x24D2181F41407947f45fEfAfe6eE69ecb0F286F9
        NZD:  0x78e13a057A2E1d7BAB41444dbEF289beE27EC98F
        OMR:  0x6Ee88eE54cfC49f2d7D5140E37d8d8a754cA6453
        PAB:  0x8F6890220fe0B330f8D4159d46bB8014F884678d
        PEN:  0x22c60574De448EF1DC5AD115E63D45f51F1332DA
        PGK:  0x0D0D7DAA088F7d5b0aEcd853349ED7e0A7468744
        PHP:  0xb1f3889f7E01ecC36be7EC714e4dF196E9830507
        PKR:  0xA494A36fbb7f3a4a3c8c8e99D00E00BBFbDB6df2
        PLN:  0x4AfbbAc1E68B8Ef3aFcE397BbAFA60AF4e537aDF
        PYG:  0x6840aEeaf7b9Ef2FDD10EDac184127A2dD050187
        QAR:  0xEa4bF2b25036a4700B92fA08AA28a4cC1107e106
        RON:  0x3849923b496d193544A0df8587F68e4782762bb9
        RSD:  0xce02d05caa530D581e4B467b8798671AAF6D5aDC
        RUB:  0xBB627C64cC54b5b89E2873774f377b181a553fe1
        RWF:  0x87EB7AffC1c6175C2A1bB5118FC300D0e174A853
        SAR:  0xba0aB9F7FBAB9048B16e6DaE300634C8e758FE3d
        SBD:  0x23a6c42f696FDc91587478aC09DA10092187470C
        SCR:  0x832B5F6B16eba4876F94E960B3ae719D19bf294F
        SDG:  0x177812DAdD477562dfCE8DD2f9bb29b2265Fbb65
        SEK:  0xfC6a2aAEBBC60E1800dC48a020fa5288B683C894
        SGD:  0xe6Fb588839F9946A88096d9432f719ab7741D058
        SHP:  0x962F135A9d02e2130F8b18B53B00851c61F2A700
        SLL:  0xCafD8F3A4F8e1c8BC9AE859e1E673Ddfcc6a3C4b
        SOS:  0xB315B2262aA7bbE9100c59A3D42E3dE3bc8cf8b2
        SRD:  0xEDDe221d4FCEEC5815cB023E08db4e9712c8d5a8
        SYP:  0xF1d88a1284e4b605Df3D773c9ae627A0Ee5df6C5
        SZL:  0xaa08495943a8bc9eEFaacF1A3FA18875a0F557a2
        THB:  0xC74C68D088878DF87b545915dCB06847473FD8F0
        TJS:  0x0Aa7Afa84BfE97690E133e85D4Fb3a7eca564add
        TMT:  0x01BE26260160561b0C5749f9B9920Fa4db8DEcE3
        TND:  0x3f567398F08bDB7cBdF944bAaf3d1F19eD3FeB9c
        TOP:  0xA1A06015f2225bD83301C3D42e962d7AB5e1FC94
        TRY:  0x0158750fb8AD1c9fE9a876D2C0Ae0c8a1317159f
        TTD:  0xB27FB67706A2bE674ab3CA3f728fe8C0edB94d9a
        TWD:  0x3Fb9ac3DAfd4Fc09fD9cE09387d697A84B76DcE2
        TZS:  0xe66395af6377B8D319692720D1aB79dB5f56f48A
        UAH:  0xa42842E75bD0c92b112D5E3C5DB7096EE54fD7a3
        UGX:  0x79823fd587abd79Be8dACf18F7dA30Dd89c10721
        USD:  0xc99E6c8Fb2cD8adA848FFcDfafC46d2D300B443b
        UYU:  0x23D4b7306DDfDD9De68D057030555974A729296e
        UZS:  0xD362C8DeC11C6add0967aD428Db1DcC6a3c19D03
        VES:  0x7FA4D3ffd282B8e78ad559dB91Bb2c5972557cBB
        VND:  0xDC9f26513beD80B984984184E0293C959688D33C
        VUV:  0xdd010B8440cFf305a8FdC98824d5e09f2f3380Ea
        WST:  0x0f9FDBa0bd9d0E0A7b011F67483331437b307314
        XAF:  0xf43FBb879b022cefb80E7736885642593E5121BA
        XCD:  0xe4a1BC4e9870959D360fB955179B86fE57D2f263
        XOF:  0x4AC8cbc6355Acb417cDc4286548bFef97F7CdD8B
        XPF:  0xdF801c54FE93c751BFA48666C7ad3b0736083461
        YER:  0x82aD7339Be78f83dD6f08ad984f743FE70038187
        ZAR:  0x6Db95a472EeC89FAeb1Db957499dA58Bd84d578A
        ZMW:  0x1B372AC6F032294af0C6f870538B10DA4E9018cA
        ZWL:  0xEcf47f431aeE0D066379144Dc6351c6739131B15
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