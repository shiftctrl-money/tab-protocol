// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPriceData} from "../interfaces/IUniTabOperation.sol";

interface IZUniCreateVault {
    function zCreateVault(
        address zrc20,
        uint256 amount,
        address destination,
        address receiver,
        uint256 receiveTabAmount,
        uint256 receiveGasAmt,
        uint256 btcOutMin,
        IPriceData.UpdatePriceData memory sigPrice
    ) 
        external 
        payable;

    struct NativeCreateVaultRequest {
        bytes sender;             // Bitcoin sender
        uint256 chainID;          // Owner chain ID
        address receiver;         // Vault owner / receiver
        address destination;      // Destination chain zrc20 gas address
        uint16 reserveRatio;      // max 65,535
        bytes32 tabKey;           // Tab currency
        uint256 depositAmt;       // BTC reserve amount BTC.BTC received from bitcoin network
        uint256 depositTimestamp; // block.timestamp when request is recorded
        uint256 createdTimestamp; // block.timestamp when vault is created successfully
    }

    event UpdatedBitcoinChainID(uint256 oldChainID, uint256 newChainID);

    event UpdatedChainIdToZrc20(
        uint32 chainId,
        address oldZrc20,
        address newZrc20
    );

    event InvalidCreateVaultRequest(
        address indexed receiver,
        uint32 chainId,
        bytes32 tabKey,
        uint16 reserveRatio,
        uint256 depositAmt
    );

    event NativeCreateVaultReq(
        bytes32 indexed senderKey,
        bytes32 indexed requestKey,
        address indexed receiver,
        address destination,
        bytes32 tabKey,
        uint16 reserveRatio,
        uint256 depositAmt
    );

    event NativeCreatedVault(
        bytes32 indexed senderKey,
        bytes32 indexed requestKey,
        address indexed receiver,
        address destination,
        bytes32 tabKey,
        uint256 tabAmount,
        uint256 depositAmt
    );

    event NativeCreateVaultRefund(
        bytes32 indexed senderKey,
        bytes32 indexed requestKey,
        address indexed receiver,
        address token,
        uint256 depositAmt
    );

    event ZCreateVault(
        address indexed owner,
        address indexed receiver,
        uint256 chainId,
        address sourceReserveToken,
        uint256 sourceReserveAmount,
        uint256 btcReserveAmount,
        uint256 receiveGasAmount,
        bytes32 tabKey,
        uint256 receiveTabAmount
    );

    error InvalidChainID();
    error InvalidReceiver();
    error InvalidRequest();
    error InvalidSigUpdater(address invalid, address expected);
    error InvalidSigChainID(uint256 invalid, uint256 expected);
    error ZeroTabAmount(uint256 price, uint256 depositAmt, uint256 ratio);
    error GasTransferFailed();
    error AmbiguousAsset(address token, uint256 tokenAmt, uint256 nativeAmt);
    error RequiredAssetAddress();
    error RequiredAssetAmount();
    error RequiredDestination();
    error RequiredReceiver();
    error ZeroMintTabAmount();

}