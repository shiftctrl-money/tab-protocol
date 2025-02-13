// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAuctionManager {

    struct AuctionDetails {
        address reserve;
        uint256 reserveQty;
        address tab;
        uint256 osTabAmt;
        uint256 startPrice; // auction start price
        uint256 auctionStepPriceDiscount;
        uint256 auctionStepDurationInSec;
        uint256 startTimestamp;
        uint256 lastStepTimestamp;
    }

    struct AuctionState {
        uint256 reserveQty;
        uint256 auctionAvailableQty; // quantity available to bid
        uint256 osTabAmt;
        uint256 auctionPrice;
    }

    struct AuctionBid {
        address bidder;
        uint256 bidTimestamp;
        uint256 bidPrice; // reserve bid price = AuctionState.auctionPrice
        uint256 bidQty;
    }

    struct AuctionStep {
        uint256 startTime;
        uint256 stepPrice;
    }

    function vaultManagerAddr() external view returns(address);
    function getAuctionDetails(uint256) external view returns(AuctionDetails memory);
    function getAuctionBid(uint256) external view returns(AuctionBid[] memory);
    function auctionCount() external view returns(uint256);
    function auctionVaultIds(uint256) external view returns(uint256);
    function maxStep() external view returns(uint256);
    
    function setVaultManagerAddr(address) external;

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

    function getAuctionState(
        uint256 auctionId
    ) 
        external 
        view 
        returns (AuctionState memory state);

    function getAuctionPrice(
        uint256 auctionId,
        uint256 timestamp
    )
        external
        view
        returns (AuctionStep memory auctionStep, uint256 lastStepTimestamp);

    function getAuctionSteps(
        uint256 auctionId
    ) 
        external 
        view 
        returns (AuctionStep[] memory auctionSteps);

    event UpdatedVaultManagerAddr(address oldValue, address newValue);

    event UpdatedReserveSafeAddr(address oldValue, address newValue);

    event UpdatedMaxStep(uint256 oldValue, uint256 newValue);

    event ActiveAuction(
        uint256 indexed auctionId,
        address reserve,
        uint256 maxAvailableQty,
        uint256 auctionPrice,
        address tab,
        uint256 validTill
    );
    
    event SuccessfulBid(
        uint256 indexed auctionId, 
        address indexed bidder, 
        uint256 bidPrice, 
        uint256 bidQty,
        uint256 sentQty
    );

    error ZeroAddress();
    error ZeroValue();
    error InvalidAuction();
    error ZeroStepPrice();
    error ExistedAuction();
    error InvalidContractAddress();
    
}
