// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniTabOperation {
    function setGateway(address gatewayAddress) external;

    function setZrc20GasToken(address zrc20) external;

    function setUniversal(address contractAddress) external;

    function setRevertGasLimit(uint256 _gasLimit) external;

    function setUniTab(address _uniTab) external;

    function tabKey(bytes3 tab) external pure returns (bytes32);
    
    event UpdatedZetaUniversal(
        address indexed oldUniversal,
        address indexed newUniversal
    );

    event UpdatedGateway(
        address indexed oldGateway,
        address indexed newGateway
    );

    event UpdatedZrc20GasToken(
        address indexed oldZrc20,
        address indexed newZrc20
    );

    event UpdatedGasLimit(
        uint256 oldGasLimit, 
        uint256 newGasLimit
    );

    event UpdatedUniTab(
        address indexed oldUniTab,
        address indexed newUniTab
    );
    
    error InvalidAddress();

    error InvalidGasLimit();

    error Unauthorized();

    error EmptyPriceSignature();
}

interface IPriceData {
    struct UpdatePriceData {
        address signer;         // authorized price signer
        address updater;        // user, usually vault owner
        uint256 chainID;        // user chain id
        bytes3 tab;
        uint256 price;
        uint256 timestamp;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
}