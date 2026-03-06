// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniAuctionBid {
    function updateZetaToken(address _zetaToken) external;

    function updateAuctionManager(address _auctionManager) external;

    function bidWithTab(
        uint256 _auctionId,
        address _tabToken,
        uint256 _tabAmt,
        address _receiver
    ) external;

    event UpdatedZetaToken(
        address indexed oldZetaToken,
        address indexed newZetaToken
    );

    event UpdatedAuctionManager(
        address indexed oldAuctionManager,
        address indexed newAuctionManager
    );

    event BidWithTab(
        address indexed bidder,
        address indexed receiver, 
        uint256 auctionId, 
        address tabToken,
        uint256 tabAmt
    );

    error ZeroTab();
}
