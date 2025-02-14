// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IConfig {
    struct TabParams {
        // Default 150 for 1.5% for 1 frame = 24 hours, 
        //   penalty_amt = delta * riskPenaltyPerFrame
        uint256 riskPenaltyPerFrame; 
        // default 0, e.g. set 1 for 0.01% fee when withdrawal & mint tab.
        //   Fee is add into vault's outstanding tab
        uint256 processFeeRate; 
        // default 180
        uint256 minReserveRatio; 
        // default 120
        uint256 liquidationRatio; 
    }

    struct AuctionParams {
        uint256 auctionStartPriceDiscount;
        uint256 auctionStepPriceDiscount;
        uint256 auctionStepDurationInSec;
        address auctionManager;
    }

    function treasury() external view returns(address);

    function getTabParams(bytes3) external view returns (TabParams memory);

    function getAuctionParams() external view returns(AuctionParams memory);

    function setVaultKeeperAddress(address _vaultKeeper) external;

    function setTreasuryAddress(address _treasury) external;

    function setDefTabParams(bytes3 _tab) external;

    function setTabParams(
        bytes3[] calldata _tab,
        TabParams[] calldata _tabParams
    )
        external;

    function setAuctionParams(
        uint256 _auctionStartPriceDiscount,
        uint256 _auctionStepPriceDiscount,
        uint256 _auctionStepDurationInSec,
        address _auctionManager
    )
        external;

    function tabCodeToTabKey(bytes3 _tab) external pure returns(bytes32);

    event UpdatedVaultKeeperAddress(address b4, address _after);
    event UpdatedTreasuryAddress(address b4, address _after);
    event DefaultTabParams(
        bytes3 tab, 
        uint256 riskPenaltyPerFrame, 
        uint256 processFeeRate,
        uint256 minReserveRatio,
        uint256 liquidationRatio
    );
    event UpdatedTabParams(
        bytes3 tab, 
        uint256 riskPenaltyPerFrame, 
        uint256 processFeeRate,
        uint256 minReserveRatio,
        uint256 liquidationRatio
    );
    event UpdatedAuctionParams(
        uint256 auctionStartPriceDiscount,
        uint256 auctionStepPriceDiscount,
        uint256 auctionStepDurationInSec,
        address auctionManager
    );
    
    error ZeroAddress();
    error InvalidContractAddress();
    error InvalidArrayLength();
    error ZeroValue();
}
