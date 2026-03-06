// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {RevertContext} from "@zetachain/protocol-contracts/contracts/Revert.sol";
import {MessageContext} from "@zetachain/protocol-contracts/contracts/evm/interfaces/IGatewayEVM.sol";

interface IUniTab {
    function revertGasLimit() external view returns(uint256);
    function setRevertGasLimit(uint256 _gasLimit) external;
    function setAuthorizedTab(address[] calldata tabAddress, bool[] calldata isAuthorized) external;
    function setUniversal(address contractAddress) external;
    function setTabFactory(address _tabFactory) external;
    function setGateway(address gatewayAddress) external;
    function setZetaToken(address _zetaToken) external;
    
    function setOldToNewTabAddress(
        address oldTabAddress, 
        address newTabAddress
    ) 
        external;
    
    function burnAndMintNewTab(address tabAddress, uint256 amount) external;
    
    function transferCrossChain(
        address tabAddress,
        address destination,
        address receiver,
        uint256 amount
    ) external payable;
    
    function onCall(
        MessageContext calldata context,
        bytes calldata message
    ) external payable returns (bytes4);

    function onRevert(RevertContext calldata revertContext) external;
    
    event UpdatedGasLimit(
        uint256 oldGasLimit, 
        uint256 newGasLimit
    );
    event AuthorizedTab(
        address indexed tabAddress,
        bool isAuthorized
    );
    event UpdatedZetaUniversal(
        address indexed oldUniversal,
        address indexed newUniversal
    );
    event UpdatedTabFactory(
        address indexed oldTabFactory,
        address indexed newTabFactory
    );
    event UpdatedGateway(
        address indexed oldGateway,
        address indexed newGateway
    );
    event UpdatedZetaToken(
        address indexed oldZetaToken,
        address indexed newZetaToken
    );
    event MappedOldToNewTab(
        address indexed oldTabAddress,
        address indexed newTabAddress
    );
    event ConvertedOldToNewTab(
        address indexed oldTabAddress,
        address indexed newTabAddress,
        address indexed receiver,
        uint256 amount
    );
    event TokenTransfer(
        address indexed tabAddress,
        address indexed destination,
        address indexed receiver,
        uint256 amount
    );
    event TokenTransferReceived(
        address indexed tabAddress, 
        address indexed receiver, 
        uint256 amount,
        uint256 gasAmount
    );
    event TokenTransferReverted(
        address indexed tabAddress,
        address indexed sender,
        address indexed gasToken,
        uint256 amount,
        uint256 gasAmount
    );

    error InvalidAddress();
    error InvalidGasLimit();
    error InvalidLength();
    error ZeroAmount();
    error UnauthorizedTab();
    error Unauthorized();
    error GasTokenTransferFailed();
    error GasTokenRefundFailed();
    error RequiredCrossChainGas();
}
