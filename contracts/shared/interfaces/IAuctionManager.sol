// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAuctionManager {

    function vaultManagerAddr() external view returns (address);

    function auctionDetails(uint256)
        external
        view
        returns (
            address reserve,
            uint256 reserveQty,
            address tab,
            uint256 osTabAmt,
            uint256 startPrice,
            uint256 auctionStepPriceDiscount,
            uint256 auctionStepDurationInSec,
            uint256 startTimestamp,
            uint256 lastStepTimestamp
        );

    function getAuctionState(uint256)
        external
        view
        returns (uint256 reserveQty, uint256 auctionAvailableQty, uint256 osTabAmt, uint256 auctionPrice);

    function auctionBid(
        uint256,
        uint256
    )
        external
        view
        returns (address bidder, uint256 bidTimestamp, uint256 bidPrice, uint256 bidQty);

    function auctionCount() external view returns (uint256);

    function auctionVaultIds(uint256) external view returns (uint256);

    function setVaultManager(address) external;

    function setMaxStep(uint256) external;

    function createAuction(
        uint256 vaultId,
        address reserve,
        uint256 reserveQty,
        address tab,
        uint256 osTabAmt,
        uint256 startPrice,
        uint256 auctionStepPriceDiscount,
        uint256 auctionStepDurationInSec
    )
        external;

    function bid(uint256 auctionId, uint256 bidQty) external;

    struct AuctionStep {
        uint256 startTime;
        uint256 stepPrice;
    }

    function getAuctionPrice(
        uint256 auctionId,
        uint256 timestamp
    )
        external
        view
        returns (AuctionStep memory auctionStep, uint256 lastStepTimestamp);

    function getAuctionSteps(uint256 auctionId) external view returns (AuctionStep[] memory);

}
