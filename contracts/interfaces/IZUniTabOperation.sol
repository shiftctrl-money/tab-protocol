// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IGatewayZEVMToken {
    function zetaToken() external view returns(address);
}

interface IZUniTabOperation {
    function setGateway(address gatewayAddress) external;

    function setVaultManager(address vmanager) external;

    function setZUniTab(address uniTab) external;

    function setDexRouter(address dex) external;

    function setBTCBTC(address btc) external;

    function setAuthorizedUniCaller(address[] calldata caller, bool[] calldata authorized) external;

    function tabKey(bytes3 tab) external pure returns (bytes32);

    event UpdatedGateway(
        address indexed oldGateway,
        address indexed newGateway
    );

    event UpdatedVaultManager(
        address indexed oldVaultManager,
        address indexed newVaultManager
    );

    event UpdatedZUniTab(
        address indexed oldAddr,
        address indexed newAddr
    );

    event UpdatedDexRouter(
        address indexed oldAddr,
        address indexed newAddr
    );

    event UpdatedBTCBTC(
        address indexed oldBTC,
        address indexed newBTC
    );

    event UpdatedAuthorizedUniCaller(
        address indexed uniCaller,
        bool isAuthorized
    );

    error InvalidLength();
    
    error InvalidAddress();

    error Unauthorized();
}
