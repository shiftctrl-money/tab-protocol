// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment
interface ISkybitCreate3Factory {
    function deploy(
        bytes32 salt,
        bytes memory creationCode
    ) external payable returns (address);

    function getDeployed(
        address deployer,
        bytes32 salt
    ) external view returns (address); 
}