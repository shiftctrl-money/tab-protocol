// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IZUniTab {
    function gasLimitAmounts(address) external view returns(uint256);

    function tabAddresses(address, bytes32) external view returns(address);

    function setConnected(
        address[] calldata zrc20,
        address[] calldata universalTab
    ) external;

    function setGasLimit(address[] calldata destination, uint256[] calldata gasLimit) external;

    function setTabAddress(
        address zrc20GasToken, 
        bytes32[] calldata tabKeys, 
        address[] calldata destToken
    ) external;

    function setGateway(address gatewayAddress) external;

    function setUniswapRouter(address uniswapRouterAddress) external;

    function transferCrossChain(
        address tabAddress,
        address destination,
        address payingTokenAsGas,
        uint256 payingTokenAmount,
        address receiver,
        uint256 amount
    ) external payable;
    
    event SetConnected(address indexed zrc20, address indexed universalTab);
    event SetAuthorizedSender(address indexed universalTab, bool isAuthorized);
    event UpdatedGasLimit(
        address indexed destination, 
        uint256 gasLimit
    );
    event UpdatedTabAddress(
        address indexed zrc20GasToken, 
        uint256 numberOfTabUpdated
    );
    event SetGateway(
        address indexed oldGateway, 
        address indexed newGateway
    );
    event SetUniswapRouter(
        address indexed oldRouter, 
        address indexed newRouter
    );
    event TokenTransfer(
        address indexed tabAddress,
        address indexed destination,
        address indexed receiver,
        uint256 amount
    );
    event TokenMinted(address indexed to, address indexed tokenAddress, uint256 amount);
    event TokenTransferToDestination(
        address indexed destination,
        address indexed sender,
        address indexed receiver,
        address tabAddress,
        uint256 amount
    );
    event TokenTransferReverted(
        address indexed tabAddress,
        address indexed sender,
        address indexed gasToken,
        uint256 amount,
        uint256 gasAmount
    );
    event TokenTransferAborted(
        address indexed tabAddress,
        address indexed sender,
        address indexed gasToken,
        uint256 amount,
        uint256 gasAmount
    );
    
    error InvalidAddress();
    error ZeroMsgValue();
    error InvalidGasLimit();
    error InvalidLength();
    error Unauthorized();
    error UnsupportedDestination();
    error ApproveFailed();
    error UnsupportedTabAddress();
    error InsufficientGasFee();
    error GasTransferFailed();
    error ExecutionFailed();
}
