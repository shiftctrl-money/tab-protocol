// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ICREATE3Factory} from "../contracts/interfaces/ICREATE3Factory.sol";
import {CRFXUSD} from "../contracts/token/CRFXUSD.sol";
import {CRFXMYR} from "../contracts/token/CRFXMYR.sol";
import {CRFXJPY} from "../contracts/token/CRFXJPY.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev CRFX USD/JPY/MYR deployment script.

Deploying on chain:  84532
  crfxUSD implementation:  0xF6c4495426562932301D1D3BF232a4b0C06d6bB4
  crfxMYR implementation:  0xd19FfA56e845B95B3b2A994793e3a06f19641EdD
  crfxJPY implementation:  0xBE9d98177b57df85Aa8d7BB8d17a78eE29a785c4
  crfxUSD:  0x3F6e6e7d099F8de56A9b89D61d5B58672583193C
  crfxMYR:  0x7Fa2aA45af3655854c06051A7e9B2Af9fcFE0B22
  crfxJPY:  0xEA3066Ae0fd7E0e53EB276954fF3Da75eA1f58E1

Deploying on chain:  8453
  crfxUSD implementation:  0x6B0643CdB5E78088DBe6C11FaEc614Ece2240Ca1
  crfxMYR implementation:  0xF6c4495426562932301D1D3BF232a4b0C06d6bB4
  crfxJPY implementation:  0xd19FfA56e845B95B3b2A994793e3a06f19641EdD
  crfxUSD:  0x3F6e6e7d099F8de56A9b89D61d5B58672583193C
  crfxMYR:  0x7Fa2aA45af3655854c06051A7e9B2Af9fcFE0B22
  crfxJPY:  0xEA3066Ae0fd7E0e53EB276954fF3Da75eA1f58E1

 */
contract DeployCRFXTokens is Script {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address deployer = 0x8C102845dD3E6EF2df43E4Eb76b61616b9178Bc4; // committee member 1
    address stablecoinAdmin = 0xbFD6Ebd2F3e5fe05E9a87EBd9FBbaA4dF0cA707b;
    address safeWallet = 0xf2aE4C9e46B135de9581Fa7C17a8863eadB26eC5;
    
    // refer https://github.com/ZeframLou/create3-factory
    address create3Factory;
    CRFXUSD crfxUSD;
    CRFXMYR crfxMYR;
    CRFXJPY crfxJPY;

    function run() external {
        vm.startBroadcast(deployer);

        console.log("Deploying on chain: ", block.chainid);

        if (block.chainid == 84532) { // base testnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
        } else if (block.chainid == 8453) { // base mainnet
            create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
        }

        crfxUSD = new CRFXUSD();
        console.log("crfxUSD implementation: ", address(crfxUSD));
        crfxMYR = new CRFXMYR();
        console.log("crfxMYR implementation: ", address(crfxMYR));
        crfxJPY = new CRFXJPY();
        console.log("crfxJPY implementation: ", address(crfxJPY));

        // defaultAdmin: stablecoinAdmin
        // pauser: stablecoinAdmin
        // minter: safeWallet
        // upgrader: stablecoinAdmin
        bytes memory usdInitData = abi.encodeWithSignature("initialize(address,address,address,address)", 
            stablecoinAdmin, stablecoinAdmin, safeWallet, stablecoinAdmin);
        address usd = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("CRFX USD v1.0.0")), 
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(crfxUSD), usdInitData))
        );
        console.log("crfxUSD: ", usd);

        bytes memory myrInitData = abi.encodeWithSignature("initialize(address,address,address,address)", 
            stablecoinAdmin, stablecoinAdmin, safeWallet, stablecoinAdmin);
        address myr = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("CRFX MYR v1.0.0")), 
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(crfxMYR), myrInitData))
        );
        console.log("crfxMYR: ", myr);

        bytes memory jpyInitData = abi.encodeWithSignature("initialize(address,address,address,address)", 
            stablecoinAdmin, stablecoinAdmin, safeWallet, stablecoinAdmin);
        address jpy = ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("CRFX JPY v1.0.0")), 
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(crfxJPY), jpyInitData))
        ); 
        console.log("crfxJPY: ", jpy);

        // address(0xD2013f34Ed59b8236870EdF76b7a30eaCbc98615).call{value: 1000000000000000}(""); // Committee member 2
        // address(0x47EfB2228eCEad7060CAc6A5AdC0717125bc44B0).call{value: 1000000000000000}(""); // Committee member 3
        // address(0x9154D20E57B050226f2390B0BadAAA9E4cEbBB15).call{value: 1000000000000000}(""); // Committee member 4
        // address(0x9Dd78a3df981a4b371320a490b27016b47F3eF01).call{value: 1000000000000000}(""); // Proposer 1
        // address(0xD5CFf936CCb57873723E49eD9995FA74063e7dAf).call{value: 2000000000000000}(""); // Finance 1
        // address(0xA97E2D0ee21c72b9Ecd1b05783E53c6d6C5E7723).call{value: 2000000000000000}(""); // Finance 2
        // address(0xE38B7dA9CEbeB0190Acf8D02aCa76ec65846d862).call{value: 2000000000000000}(""); // Finance 3
        // address(0x0DFB92A20d09036FF520A0b9276cA2d0CbD84041).call{value: 2000000000000000}(""); // Finance 4
        // address(0xbFD6Ebd2F3e5fe05E9a87EBd9FBbaA4dF0cA707b).call{value: 2000000000000000}(""); // stablecoinAdmin

        vm.stopBroadcast();
    }

    function _upgrade() internal {
        address usd = 0x3F6e6e7d099F8de56A9b89D61d5B58672583193C;
        CRFXUSD newCfx = new CRFXUSD();
        CRFXUSD(usd).upgradeToAndCall(
            address(newCfx),
            ""
        );
        console.log("upgraded, implementation: ", address(newCfx));
    }
}