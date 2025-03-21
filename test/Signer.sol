// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
// import "forge-std/console.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IPriceOracle} from "../contracts/interfaces/IPriceOracle.sol";

// PriceOracle signer
contract Signer is Test {
    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 _DATA_TYPEHASH = keccak256("UpdatePriceData(address owner,address updater,bytes3 tab,uint256 price,uint256 timestamp,uint256 nonce)");

    string name;
    string version;
    uint256 chainid;

    address public authorizedAddr;
    address public priceOracle;
    address public updater;
    
    uint256 priKey;

    constructor(address _priceOracle, address _updater) {
        authorizedAddr = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        priceOracle = _priceOracle;
        updater = _updater;
        // Authorized price provider 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        priKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        (,name,version,chainid,,,) = EIP712(priceOracle).eip712Domain();
    }

    function updateSigner(address _addr, uint256 _prikey) external {
        authorizedAddr = _addr;
        priKey = _prikey;
    }

    function updateUpdater(address _updater) external {
        updater = _updater;
    }

    function getUpdatePriceSignature(
        bytes3 _tab, 
        uint256 _price, 
        uint256 _timestamp
    )
        external  
        returns(IPriceOracle.UpdatePriceData memory priceData) 
    {
        // (,address updater,) = vm.readCallers();
        updater = msg.sender;
        bytes32 structHash = keccak256(abi.encode(
            _DATA_TYPEHASH, 
            authorizedAddr,
            updater,
            _tab,
            _price,
            _timestamp,
            IPriceOracle(priceOracle).nonces(updater)
        ));
        bytes32 digest = MessageHashUtils.toTypedDataHash(_buildDomainSeparator(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(priKey, digest);
        priceData = IPriceOracle.UpdatePriceData(
            authorizedAddr,
            updater,
            _tab,
            _price,
            _timestamp,
            v,
            r,
            s
        );
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(_TYPE_HASH, keccak256(bytes(name)), keccak256(bytes(version)), chainid, priceOracle));
    }

}