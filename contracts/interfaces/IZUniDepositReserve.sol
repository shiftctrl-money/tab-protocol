// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IZUniDepositReserve {
    event UpdatedBitcoinChainID(uint256 oldChainID, uint256 newChainID);
    
    event ZDepositReserve(
        address indexed vaultOwner,
        uint256 vaultId,
        address sourceSendToken,
        uint256 sourceSendAmount,
        uint256 btcReserveAmount
    );

    error InvalidChainID();
    error InvalidVault(address vaultOwner, uint256 vaultId);
    error ApproveFailed();
    error AmbiguousAsset(address token, uint256 tokenAmt, uint256 nativeAmt);
    error RequiredAssetAddress();
    error RequiredAssetAmount();

}