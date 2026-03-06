// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniGovernance {
    function setUniversal(address contractAddress) external;
    function setGateway(address gatewayAddress) external;
    function execute(address target, bytes calldata data) external;
    function executeRemote(
        address destination, 
        address target, 
        bytes calldata data,
        uint256 gasLimitAmount
    ) external payable;
    
    event UpdatedZetaUniversal(address indexed previousUniversal, address indexed newUniversal);
    event UpdatedGateway(address indexed previousGateway, address indexed newGateway);
    event ExecutedLocalAction(address indexed target);
    event CalledRemoteAction(address indexed destination, address indexed target);
    event ExecutedRemoteAction(address indexed destination, address indexed target);

    error InvalidAddress();
    error GovExecutionFailed();
    error Unauthorized();
    error RequiredGovSourceChain();
}