// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/solady/src/utils/FixedPointMathLib.sol";

contract RateSimulator {

    bytes3[] _tabs;
    uint256[] _prices;

    constructor() {
        _tabs = new bytes3[](180);
        _prices = new uint256[](180);

        // USDBTC: 0.000026963776
        // BTCUSD: 37086.79377843815543284753233983458329306408598417115365577571567339326523

        _tabs[0] = bytes3(abi.encodePacked("AED"));
        _prices[0] = 136218495510421100881726; // 3.672965 * BTCUSD * 1ether
        _tabs[1] = bytes3(abi.encodePacked("AFN"));
        _prices[1] = 2723892714432874789425858; // 73.446433 * BTCUSD * 1ether
        _tabs[2] = bytes3(abi.encodePacked("ALL"));
        _prices[2] = 3624800547223059694688378; // 97.73831 * BTCUSD * 1ether
        _tabs[3] = bytes3(abi.encodePacked("AMD"));
        _prices[3] = 14919116892233492869097469; // 402.275726 * BTCUSD * 1ether
        _tabs[4] = bytes3(abi.encodePacked("ANG"));
        _prices[4] = 66780928605845123293592; // 1.800666 * BTCUSD * 1ether
        _tabs[5] = bytes3(abi.encodePacked("AOA"));
        _prices[5] = 30837665281005155644748869; // 831.499899 * BTCUSD * 1ether
        _tabs[6] = bytes3(abi.encodePacked("ARS"));
        _prices[6] = 12973375798701191046517985; // 349.811199 * BTCUSD * 1ether
        _tabs[7] = bytes3(abi.encodePacked("AUD"));
        _prices[7] = 58354326931064850628748; // 1.573453 * BTCUSD * 1ether
        _tabs[8] = bytes3(abi.encodePacked("AWG"));
        _prices[8] = 66848945785634774838311; // 1.8025 * BTCUSD * 1ether
        _tabs[9] = bytes3(abi.encodePacked("AZN"));
        _prices[9] = 62880250896610330601575; // 1.695489 * BTCUSD * 1ether
        _tabs[10] = bytes3(abi.encodePacked("BAM"));
        _prices[10] = 67691038525167995859810; // 1.825206 * BTCUSD * 1ether
        _tabs[11] = bytes3(abi.encodePacked("BBD"));
        _prices[11] = 74814224832605051991649; // 2.017274 * BTCUSD * 1ether
        _tabs[12] = bytes3(abi.encodePacked("BDT"));
        _prices[12] = 4084971518825850335803762; // 110.146257 * BTCUSD * 1ether
        _tabs[13] = bytes3(abi.encodePacked("BGN"));
        _prices[13] = 67691038525167995859810; // 1.825206 * BTCUSD * 1ether
        _tabs[14] = bytes3(abi.encodePacked("BHD"));
        _prices[14] = 13968221661535834085807; // 0.376636 * BTCUSD * 1ether
        _tabs[15] = bytes3(abi.encodePacked("BIF"));
        _prices[15] = 105255918903939875006053609; // 2838.09702 * BTCUSD * 1ether
        _tabs[16] = bytes3(abi.encodePacked("BMD"));
        _prices[16] = 37086793778438155432848; // 1 * BTCUSD * 1ether
        _tabs[17] = bytes3(abi.encodePacked("BND"));
        _prices[17] = 50395167205068014685364; // 1.358844 * BTCUSD * 1ether
        _tabs[18] = bytes3(abi.encodePacked("BOB"));
        _prices[18] = 256043849348103173493269; // 6.903909 * BTCUSD * 1ether
        _tabs[19] = bytes3(abi.encodePacked("BRL"));
        _prices[19] = 182344972751590884614619; // 4.916709 * BTCUSD * 1ether
        _tabs[20] = bytes3(abi.encodePacked("BSD"));
        _prices[20] = 37053118969687332849602; // 0.999092 * BTCUSD * 1ether
        _tabs[21] = bytes3(abi.encodePacked("USD"));
        _prices[21] = 37086793778438155432848; // 0.000026963776 * BTCUSD * 1ether
        _tabs[22] = bytes3(abi.encodePacked("BTN"));
        _prices[22] = 3086379741472410946718912; // 83.220452 * BTCUSD * 1ether
        _tabs[23] = bytes3(abi.encodePacked("BWP"));
        _prices[23] = 505149278795373504240563; // 13.620732 * BTCUSD * 1ether
        _tabs[24] = bytes3(abi.encodePacked("BYN"));
        _prices[24] = 122073703623706115997257; // 3.291568 * BTCUSD * 1ether
        _tabs[25] = bytes3(abi.encodePacked("BYR"));
        _prices[25] = 726901158057387846483811634; // 19600 * BTCUSD * 1ether
        _tabs[26] = bytes3(abi.encodePacked("BZD"));
        _prices[26] = 74689279424365487266490; // 2.013905 * BTCUSD * 1ether
        _tabs[27] = bytes3(abi.encodePacked("CAD"));
        _prices[27] = 51250425756392576919814; // 1.381905 * BTCUSD * 1ether
        _tabs[28] = bytes3(abi.encodePacked("CDF"));
        _prices[28] = 98094556749025070348883754; // 2644.999655 * BTCUSD * 1ether
        _tabs[29] = bytes3(abi.encodePacked("CHF"));
        _prices[29] = 33471943988853790441352; // 0.90253 * BTCUSD * 1ether
        _tabs[30] = bytes3(abi.encodePacked("CLF"));
        _prices[30] = 1232505417638835169530; // 0.033233 * BTCUSD * 1ether
        _tabs[31] = bytes3(abi.encodePacked("CLP"));
        _prices[31] = 34008970702026305401059570; // 917.010268 * BTCUSD * 1ether
        _tabs[32] = bytes3(abi.encodePacked("CNY"));
        _prices[32] = 268675277527895231263210; // 7.2445 * BTCUSD * 1ether
        _tabs[33] = bytes3(abi.encodePacked("COP"));
        _prices[33] = 149812474335938721347800123; // 4039.51 * BTCUSD * 1ether
        _tabs[34] = bytes3(abi.encodePacked("CRC"));
        _prices[34] = 19673522580813606879680315; // 530.472456 * BTCUSD * 1ether
        _tabs[35] = bytes3(abi.encodePacked("CUC"));
        _prices[35] = 37086793778438155432848; // 1 * BTCUSD * 1ether
        _tabs[36] = bytes3(abi.encodePacked("CUP"));
        _prices[36] = 982800035128611118970460; // 26.5 * BTCUSD * 1ether
        _tabs[37] = bytes3(abi.encodePacked("CVE"));
        _prices[37] = 3826602512941807827723823; // 103.179653 * BTCUSD * 1ether
        _tabs[38] = bytes3(abi.encodePacked("CZK"));
        _prices[38] = 853219519402623753003333; // 23.00602 * BTCUSD * 1ether
        _tabs[39] = bytes3(abi.encodePacked("DJF"));
        _prices[39] = 6597171701767586486746549; // 177.88466 * BTCUSD * 1ether
        _tabs[40] = bytes3(abi.encodePacked("DKK"));
        _prices[40] = 258913847971441411618919; // 6.981295 * BTCUSD * 1ether
        _tabs[41] = bytes3(abi.encodePacked("DOP"));
        _prices[41] = 2106861108770522503398844; // 56.808931 * BTCUSD * 1ether
        _tabs[42] = bytes3(abi.encodePacked("DZD"));
        _prices[42] = 4991955355214344295413363; // 134.601966 * BTCUSD * 1ether
        _tabs[43] = bytes3(abi.encodePacked("EGP"));
        _prices[43] = 1145455221108497668529935; // 30.885798 * BTCUSD * 1ether
        _tabs[44] = bytes3(abi.encodePacked("ERN"));
        _prices[44] = 556301906676572331492713; // 15 * BTCUSD * 1ether
        _tabs[45] = bytes3(abi.encodePacked("ETB"));
        _prices[45] = 2071626429473379528282586; // 55.858871 * BTCUSD * 1ether
        _tabs[46] = bytes3(abi.encodePacked("EUR"));
        _prices[46] = 34716910569202179396947; // 0.936099 * BTCUSD * 1ether
        _tabs[47] = bytes3(abi.encodePacked("FJD"));
        _prices[47] = 84482714883850092961152; // 2.277973 * BTCUSD * 1ether
        _tabs[48] = bytes3(abi.encodePacked("FKP"));
        _prices[48] = 30342189461891391683419; // 0.81814 * BTCUSD * 1ether
        _tabs[49] = bytes3(abi.encodePacked("GBP"));
        _prices[49] = 30339445039151786573981; // 0.818066 * BTCUSD * 1ether
        _tabs[50] = bytes3(abi.encodePacked("GEL"));
        _prices[50] = 99950170183879301414381; // 2.695034 * BTCUSD * 1ether
        _tabs[51] = bytes3(abi.encodePacked("GGP"));
        _prices[51] = 30342189461891391683419; // 0.81814 * BTCUSD * 1ether
        _tabs[52] = bytes3(abi.encodePacked("GHS"));
        _prices[52] = 442402651616746878925563; // 11.928846 * BTCUSD * 1ether
        _tabs[53] = bytes3(abi.encodePacked("GIP"));
        _prices[53] = 30342189461891391683419; // 0.81814 * BTCUSD * 1ether
        _tabs[54] = bytes3(abi.encodePacked("GMD"));
        _prices[54] = 2495014793180302394723996; // 67.27502 * BTCUSD * 1ether
        _tabs[55] = bytes3(abi.encodePacked("GNF"));
        _prices[55] = 318336960261055468768366979; // 8583.566489 * BTCUSD * 1ether
        _tabs[56] = bytes3(abi.encodePacked("GTQ"));
        _prices[56] = 289949337956226913397555; // 7.818129 * BTCUSD * 1ether
        _tabs[57] = bytes3(abi.encodePacked("GYD"));
        _prices[57] = 7752110572347137547374739; // 209.026173 * BTCUSD * 1ether
        _tabs[58] = bytes3(abi.encodePacked("HKD"));
        _prices[58] = 289671965825557973935552; // 7.81065 * BTCUSD * 1ether
        _tabs[59] = bytes3(abi.encodePacked("HNL"));
        _prices[59] = 915309858678547106227655; // 24.68021 * BTCUSD * 1ether
        _tabs[60] = bytes3(abi.encodePacked("HRK"));
        _prices[60] = 261562141741572120306236; // 7.052703 * BTCUSD * 1ether
        _tabs[61] = bytes3(abi.encodePacked("HTG"));
        _prices[61] = 4915296989561106043094730; // 132.534967 * BTCUSD * 1ether
        _tabs[62] = bytes3(abi.encodePacked("HUF"));
        _prices[62] = 13104633787196571781206474; // 353.35041 * BTCUSD * 1ether
        _tabs[63] = bytes3(abi.encodePacked("IDR"));
        _prices[63] = 582707703846820298160900428; // 15712 * BTCUSD * 1ether
        _tabs[64] = bytes3(abi.encodePacked("ILS"));
        _prices[64] = 143637523171828754501802; // 3.87301 * BTCUSD * 1ether
        _tabs[65] = bytes3(abi.encodePacked("IMP"));
        _prices[65] = 30342189461891391683419; // 0.81814 * BTCUSD * 1ether
        _tabs[66] = bytes3(abi.encodePacked("INR"));
        _prices[66] = 3089600618251687183708299; // 83.307299 * BTCUSD * 1ether
        _tabs[67] = bytes3(abi.encodePacked("IQD"));
        _prices[67] = 48540280115069940365987722; // 1308.82924 * BTCUSD * 1ether
        _tabs[68] = bytes3(abi.encodePacked("IRR"));
        _prices[68] = 1567380464813236848192594401; // 42262.49576 * BTCUSD * 1ether
        _tabs[69] = bytes3(abi.encodePacked("ISK"));
        _prices[69] = 5273522521474737860358535; // 142.19408 * BTCUSD * 1ether
        _tabs[70] = bytes3(abi.encodePacked("JEP"));
        _prices[70] = 30342189461891391683419; // 0.81814 * BTCUSD * 1ether
        _tabs[71] = bytes3(abi.encodePacked("JMD"));
        _prices[71] = 5761596335765435662598215; // 155.354393 * BTCUSD * 1ether
        _tabs[72] = bytes3(abi.encodePacked("JOD"));
        _prices[72] = 26305551566664846676264; // 0.709297 * BTCUSD * 1ether
        _tabs[73] = bytes3(abi.encodePacked("JPY"));
        _prices[73] = 5625398423425562149718350; // 151.681983 * BTCUSD * 1ether
        _tabs[74] = bytes3(abi.encodePacked("KES"));
        _prices[74] = 5643140782655960406909193; // 152.160384 * BTCUSD * 1ether
        _tabs[75] = bytes3(abi.encodePacked("KGS"));
        _prices[75] = 3312570724515735895919781; // 89.319415 * BTCUSD * 1ether
        _tabs[76] = bytes3(abi.encodePacked("KHR"));
        _prices[76] = 152739922553873777274212147; // 4118.445058 * BTCUSD * 1ether
        _tabs[77] = bytes3(abi.encodePacked("KMF"));
        _prices[77] = 17115437689439343289373959; // 461.496828 * BTCUSD * 1ether
        _tabs[78] = bytes3(abi.encodePacked("KPW"));
        _prices[78] = 33377863953475953972841691; // 899.993247 * BTCUSD * 1ether
        _tabs[79] = bytes3(abi.encodePacked("KRW"));
        _prices[79] = 49120713656722265565501945; // 1324.47992 * BTCUSD * 1ether
        _tabs[80] = bytes3(abi.encodePacked("KWD"));
        _prices[80] = 11450176711154996643278; // 0.30874 * BTCUSD * 1ether
        _tabs[81] = bytes3(abi.encodePacked("KYD"));
        _prices[81] = 30879502930153405770605; // 0.832628 * BTCUSD * 1ether
        _tabs[82] = bytes3(abi.encodePacked("KZT"));
        _prices[82] = 17319999283483145544058484; // 467.012581 * BTCUSD * 1ether
        _tabs[83] = bytes3(abi.encodePacked("LAK"));
        _prices[83] = 766966870552551663671941449; // 20680.322897 * BTCUSD * 1ether
        _tabs[84] = bytes3(abi.encodePacked("LBP"));
        _prices[84] = 556907486102836631320941877; // 15016.328708 * BTCUSD * 1ether
        _tabs[85] = bytes3(abi.encodePacked("LKR"));
        _prices[85] = 12135590579004958357753897; // 327.221346 * BTCUSD * 1ether
        _tabs[86] = bytes3(abi.encodePacked("LRD"));
        _prices[86] = 6959352206456544586823678; // 187.650414 * BTCUSD * 1ether
        _tabs[87] = bytes3(abi.encodePacked("LSL"));
        _prices[87] = 692766806844857346035795; // 18.679609 * BTCUSD * 1ether
        _tabs[88] = bytes3(abi.encodePacked("LTL"));
        _prices[88] = 109507659461345476116120; // 2.95274 * BTCUSD * 1ether
        _tabs[89] = bytes3(abi.encodePacked("LVL"));
        _prices[89] = 22433430688639457277263; // 0.60489 * BTCUSD * 1ether
        _tabs[90] = bytes3(abi.encodePacked("LYD"));
        _prices[90] = 180424507309362008389585; // 4.864926 * BTCUSD * 1ether
        _tabs[91] = bytes3(abi.encodePacked("MAD"));
        _prices[91] = 379429349954546443487751; // 10.230848 * BTCUSD * 1ether
        _tabs[92] = bytes3(abi.encodePacked("MDL"));
        _prices[92] = 663256956295735420943823; // 17.883912 * BTCUSD * 1ether
        _tabs[93] = bytes3(abi.encodePacked("MGA"));
        _prices[93] = 168070763308521790418715055; // 4531.822414 * BTCUSD * 1ether
        _tabs[94] = bytes3(abi.encodePacked("MKD"));
        _prices[94] = 2138267948821411401214771; // 57.655778 * BTCUSD * 1ether
        _tabs[95] = bytes3(abi.encodePacked("MMK"));
        _prices[95] = 77812616637966430567089839; // 2098.121965 * BTCUSD * 1ether
        _tabs[96] = bytes3(abi.encodePacked("MNT"));
        _prices[96] = 127806265635792262003269037; // 3446.139518 * BTCUSD * 1ether
        _tabs[97] = bytes3(abi.encodePacked("MOP"));
        _prices[97] = 298029771497879270750923; // 8.036008 * BTCUSD * 1ether
        _tabs[98] = bytes3(abi.encodePacked("MRO"));
        _prices[98] = 13239978999973890838288933; // 356.999828 * BTCUSD * 1ether
        _tabs[99] = bytes3(abi.encodePacked("MUR"));
        _prices[99] = 1639988813139524874573401; // 44.220291 * BTCUSD * 1ether
        _tabs[100] = bytes3(abi.encodePacked("MVR"));
        _prices[100] = 568174724489626399700549; // 15.320136 * BTCUSD * 1ether
        _tabs[101] = bytes3(abi.encodePacked("MWK"));
        _prices[101] = 62373528025154936205322440; // 1681.825838 * BTCUSD * 1ether
        _tabs[102] = bytes3(abi.encodePacked("MXN"));
        _prices[102] = 654899744012114695021294; // 17.65857 * BTCUSD * 1ether
        _tabs[103] = bytes3(abi.encodePacked("MYR"));
        _prices[103] = 174603438331485931421445; // 4.707968 * BTCUSD * 1ether
        _tabs[104] = bytes3(abi.encodePacked("MZN"));
        _prices[104] = 2345737852146524347662142; // 63.24995 * BTCUSD * 1ether
        _tabs[105] = bytes3(abi.encodePacked("NAD"));
        _prices[105] = 692050030381501451845874; // 18.660282 * BTCUSD * 1ether
        _tabs[106] = bytes3(abi.encodePacked("NGN"));
        _prices[106] = 29755097876499198526973639; // 802.309794 * BTCUSD * 1ether
        _tabs[107] = bytes3(abi.encodePacked("NIO"));
        _prices[107] = 1356220248974030925016071; // 36.568819 * BTCUSD * 1ether
        _tabs[108] = bytes3(abi.encodePacked("NOK"));
        _prices[108] = 412686079279103965451601; // 11.127575 * BTCUSD * 1ether
        _tabs[109] = bytes3(abi.encodePacked("NPR"));
        _prices[109] = 4938196452900365509438920; // 133.152423 * BTCUSD * 1ether
        _tabs[110] = bytes3(abi.encodePacked("NZD"));
        _prices[110] = 62980051458668107638844; // 1.69818 * BTCUSD * 1ether
        _tabs[111] = bytes3(abi.encodePacked("OMR"));
        _prices[111] = 14263210019249529731493; // 0.38459 * BTCUSD * 1ether
        _tabs[112] = bytes3(abi.encodePacked("PAB"));
        _prices[112] = 37053118969687332849602; // 0.999092 * BTCUSD * 1ether
        _tabs[113] = bytes3(abi.encodePacked("PEN"));
        _prices[113] = 140855346076157879878173; // 3.797992 * BTCUSD * 1ether
        _tabs[114] = bytes3(abi.encodePacked("PGK"));
        _prices[114] = 137634840164819660277801; // 3.711155 * BTCUSD * 1ether
        _tabs[115] = bytes3(abi.encodePacked("PHP"));
        _prices[115] = 2080958505218260239554755; // 56.110499 * BTCUSD * 1ether
        _tabs[116] = bytes3(abi.encodePacked("PKR"));
        _prices[116] = 10489795049476751239738278; // 282.844484 * BTCUSD * 1ether
        _tabs[117] = bytes3(abi.encodePacked("PLN"));
        _prices[117] = 153830457573894704382428; // 4.14785 * BTCUSD * 1ether
        _tabs[118] = bytes3(abi.encodePacked("PYG"));
        _prices[118] = 275824938428504990235323627; // 7437.281855 * BTCUSD * 1ether
        _tabs[119] = bytes3(abi.encodePacked("QAR"));
        _prices[119] = 135023744448848720057766; // 3.64075 * BTCUSD * 1ether
        _tabs[120] = bytes3(abi.encodePacked("RON"));
        _prices[120] = 172616661701981227924100; // 4.654397 * BTCUSD * 1ether
        _tabs[121] = bytes3(abi.encodePacked("RSD"));
        _prices[121] = 4066250550368019914494310; // 109.641469 * BTCUSD * 1ether
        _tabs[122] = bytes3(abi.encodePacked("RUB"));
        _prices[122] = 3422182931648742563326768; // 92.274974 * BTCUSD * 1ether
        _tabs[123] = bytes3(abi.encodePacked("RWF"));
        _prices[123] = 45559005941897756986700834; // 1228.442831 * BTCUSD * 1ether
        _tabs[124] = bytes3(abi.encodePacked("SAR"));
        _prices[124] = 139113676066734877377647; // 3.75103 * BTCUSD * 1ether
        _tabs[125] = bytes3(abi.encodePacked("SBD"));
        _prices[125] = 310485630795924135821278; // 8.371865 * BTCUSD * 1ether
        _tabs[126] = bytes3(abi.encodePacked("SCR"));
        _prices[126] = 493153332826975005271581; // 13.297276 * BTCUSD * 1ether
        _tabs[127] = bytes3(abi.encodePacked("SDG"));
        _prices[127] = 22233435628600388084262062; // 599.497378 * BTCUSD * 1ether
        _tabs[128] = bytes3(abi.encodePacked("SEK"));
        _prices[128] = 404694987823663902467069; // 10.912105 * BTCUSD * 1ether
        _tabs[129] = bytes3(abi.encodePacked("SGD"));
        _prices[129] = 50488848446152350512679; // 1.36137 * BTCUSD * 1ether
        _tabs[130] = bytes3(abi.encodePacked("SHP"));
        _prices[130] = 45125356329914625557038; // 1.21675 * BTCUSD * 1ether
        _tabs[131] = bytes3(abi.encodePacked("SLE"));
        _prices[131] = 819058206091016360549136; // 22.084902 * BTCUSD * 1ether
        _tabs[132] = bytes3(abi.encodePacked("SLL"));
        _prices[132] = 732464188064757795357510896; // 19750.000295 * BTCUSD * 1ether
        _tabs[133] = bytes3(abi.encodePacked("SOS"));
        _prices[133] = 21176549493661422351284475; // 570.999737 * BTCUSD * 1ether
        _tabs[134] = bytes3(abi.encodePacked("SRD"));
        _prices[134] = 1407684999311669103477339; // 37.956503 * BTCUSD * 1ether
        _tabs[135] = bytes3(abi.encodePacked("STD"));
        _prices[135] = 767621753273725457937364506; // 20697.981008 * BTCUSD * 1ether
        _tabs[136] = bytes3(abi.encodePacked("SYP"));
        _prices[136] = 482197120054698563077348491; // 13001.855133 * BTCUSD * 1ether
        _tabs[137] = bytes3(abi.encodePacked("SZL"));
        _prices[137] = 694320001768298299978289; // 18.721489 * BTCUSD * 1ether
        _tabs[138] = bytes3(abi.encodePacked("THB"));
        _prices[138] = 1337535996442041480363243; // 36.065021 * BTCUSD * 1ether
        _tabs[139] = bytes3(abi.encodePacked("TJS"));
        _prices[139] = 406473930060834240679022; // 10.960072 * BTCUSD * 1ether
        _tabs[140] = bytes3(abi.encodePacked("TMT"));
        _prices[140] = 130174646162317917663769; // 3.51 * BTCUSD * 1ether
        _tabs[141] = bytes3(abi.encodePacked("TND"));
        _prices[141] = 117120131839101475448553; // 3.158001 * BTCUSD * 1ether
        _tabs[142] = bytes3(abi.encodePacked("TOP"));
        _prices[142] = 88741205979459260720315; // 2.392798 * BTCUSD * 1ether
        _tabs[143] = bytes3(abi.encodePacked("TRY"));
        _prices[143] = 1059080263832484000628582; // 28.556803 * BTCUSD * 1ether
        _tabs[144] = bytes3(abi.encodePacked("TTD"));
        _prices[144] = 251707068030827731986857; // 6.786973 * BTCUSD * 1ether
        _tabs[145] = bytes3(abi.encodePacked("TWD"));
        _prices[145] = 1200618303608515303448410; // 32.373203 * BTCUSD * 1ether
        _tabs[146] = bytes3(abi.encodePacked("TZS"));
        _prices[146] = 92634577145278167092615737; // 2497.777988 * BTCUSD * 1ether
        _tabs[147] = bytes3(abi.encodePacked("UAH"));
        _prices[147] = 1337909237934627676427760; // 36.075085 * BTCUSD * 1ether
        _tabs[148] = bytes3(abi.encodePacked("UGX"));
        _prices[148] = 139682357471001096435081771; // 3766.363798 * BTCUSD * 1ether
        _tabs[149] = bytes3(abi.encodePacked("UYU"));
        _prices[149] = 1480459487573254032251248; // 39.918778 * BTCUSD * 1ether
        _tabs[150] = bytes3(abi.encodePacked("UZS"));
        _prices[150] = 454655186869969590589075383; // 12259.220616 * BTCUSD * 1ether
        _tabs[151] = bytes3(abi.encodePacked("VEF"));
        _prices[151] = 130741596377747685414488653039; // 3525287.118612 * BTCUSD * 1ether
        _tabs[152] = bytes3(abi.encodePacked("VES"));
        _prices[152] = 1305521192580742353862597; // 35.201781 * BTCUSD * 1ether
        _tabs[153] = bytes3(abi.encodePacked("VND"));
        _prices[153] = 903619730411645657121330125; // 24365 * BTCUSD * 1ether
        _tabs[154] = bytes3(abi.encodePacked("VUV"));
        _prices[154] = 4506813845360531334473441; // 121.520719 * BTCUSD * 1ether
        _tabs[155] = bytes3(abi.encodePacked("WST"));
        _prices[155] = 103622875371758030144436; // 2.794064 * BTCUSD * 1ether
        _tabs[156] = bytes3(abi.encodePacked("XAF"));
        _prices[156] = 22764129215433328338516006; // 613.806881 * BTCUSD * 1ether
        _tabs[157] = bytes3(abi.encodePacked("XAG"));
        _prices[157] = 1685557690436235848111; // 0.045449 * BTCUSD * 1ether
        _tabs[158] = bytes3(abi.encodePacked("XAU"));
        _prices[158] = 19173872383452525986; // 0.000517 * BTCUSD * 1ether
        _tabs[159] = bytes3(abi.encodePacked("XCD"));
        _prices[159] = 100228914525918037254911; // 2.70255 * BTCUSD * 1ether
        _tabs[160] = bytes3(abi.encodePacked("XDR"));
        _prices[160] = 28186482486725895053068; // 0.760014 * BTCUSD * 1ether
        _tabs[161] = bytes3(abi.encodePacked("XOF"));
        _prices[161] = 22764129215433328338516006; // 613.806881 * BTCUSD * 1ether
        _tabs[162] = bytes3(abi.encodePacked("XPF"));
        _prices[162] = 4166711813656959914906037; // 112.350284 * BTCUSD * 1ether
        _tabs[163] = bytes3(abi.encodePacked("YER"));
        _prices[163] = 9283008507413798509801323; // 250.304962 * BTCUSD * 1ether
        _tabs[164] = bytes3(abi.encodePacked("ZAR"));
        _prices[164] = 696005077330415499541482; // 18.766925 * BTCUSD * 1ether
        _tabs[165] = bytes3(abi.encodePacked("ZMK"));
        _prices[165] = 333825783970316337419678589; // 9001.203662 * BTCUSD * 1ether
        _tabs[166] = bytes3(abi.encodePacked("ZMW"));
        _prices[166] = 845728951316017489602117; // 22.804046 * BTCUSD * 1ether
        _tabs[167] = bytes3(abi.encodePacked("ZWL"));
        _prices[167] = 11941932465245224703229173; // 321.999592 * BTCUSD * 1ether
    }

    // return X number of tab and prices
    function retrieveX(uint256 x, uint256 diff) public view returns (bytes3[] memory t, uint256[] memory p) {
        require(x <= 168, "Exceeded maximum supported tab count!");
        t = new bytes3[](x);
        p = new uint256[](x);
        for (uint256 i = 0; i < x; i++) {
            t[i] = _tabs[i];
            p[i] = FixedPointMathLib.fullMulDiv(_prices[i], diff, 100);
        }
    }

    function retrieve10(uint256 diff) public view returns (bytes3[10] memory t, uint256[10] memory p) {
        for (uint256 i = 0; i < 10; i++) {
            t[i] = _tabs[i];
            p[i] = FixedPointMathLib.fullMulDiv(_prices[i], diff, 100);
        }
    }

    function retrieve20(uint256 diff) public view returns (bytes3[20] memory t, uint256[20] memory p) {
        for (uint256 i = 0; i < 20; i++) {
            t[i] = _tabs[i];
            p[i] = FixedPointMathLib.fullMulDiv(_prices[i], diff, 100);
        }
    }

    function retrieve100(uint256 diff) public view returns (bytes3[100] memory t, uint256[100] memory p) {
        for (uint256 i = 0; i < 100; i++) {
            t[i] = _tabs[i];
            p[i] = FixedPointMathLib.fullMulDiv(_prices[i], diff, 100);
        }
    }

    function retrieve140(uint256 diff) public view returns (bytes3[140] memory t, uint256[140] memory p) {
        for (uint256 i = 0; i < 140; i++) {
            t[i] = _tabs[i];
            p[i] = FixedPointMathLib.fullMulDiv(_prices[i], diff, 100);
        }
    }

    function retrieve160(uint256 diff) public view returns (bytes3[160] memory t, uint256[160] memory p) {
        for (uint256 i = 0; i < 160; i++) {
            t[i] = _tabs[i];
            p[i] = FixedPointMathLib.fullMulDiv(_prices[i], diff, 100);
        }
    }

}
