// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IZUniGovernance {
    function setGateway(address gatewayAddress) external;
    function setConnected(
        address[] calldata zrc20,
        address[] calldata uniGov
    ) external;
    function setAuthorizedSender(
        address[] calldata uniGov,
        bool[] calldata isAuthorized
    ) external;
    function setUniswapRouter(
        address uniswapRouterAddress
    ) external;
    
    event SetGateway(address indexed previousGateway, address indexed newGateway);
    event SetConnected(address indexed zrc20, address indexed uniGov);
    event SetAuthorizedSender(address indexed uniGov, bool isAuthorized);
    event SetUniswapRouter(address indexed previousRouter, address indexed newRouter);
    event ExecutedLocalAction(address indexed target);
    event ExecutingRemoteAction(address indexed destination, address indexed target);

    error InvalidAddress();
    error InvalidLength();
    error Unauthorized();
    error UnsupportedDestination();
    error ExecutionFailed();
    error InsufficientGasFee();
    error ApproveFailed();
}