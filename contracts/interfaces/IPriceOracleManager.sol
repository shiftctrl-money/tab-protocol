// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPriceOracleManager {
    struct Tracker {
        uint256 lastUpdatedTimestamp;
        uint256 lastUpdatedBlockId;
        uint256 lastPaymentBlockId;
        uint256 osPayment; // accumulated payment
        uint256 feedMissCount; // value increased whenever provider missed configured feed count
    }

    struct Info {
        address paymentTokenAddress;
        uint256 paymentAmtPerFeed;
        uint256 blockCountPerFeed;
        uint256 feedSize;
        bytes32 whitelistedIPAddr;
    }

    struct OracleProvider {
        uint256 index;
        uint256 activatedSinceBlockNum;
        uint256 activatedTimestamp;
        uint256 disabledOnBlockId;
        uint256 disabledTimestamp;
        bool paused;
    }

    function priceOracle() external view returns(address);

    function setPriceOracle(address _priceOracle) external;

    function setDefBlockGenerationTimeInSecond(uint256 _secondPerBlock) external;

    function updateConfig(uint256 _movementDelta, uint256 _inactivePeriod) external;

    function getProvider(address providerKey) external view returns(OracleProvider memory);

    function getProviderTracker(address providerKey) external view returns(Tracker memory);

    function getProviderInfo(address providerKey) external view returns(Info memory);

    function getConfig() external view returns (uint256, uint256, uint256);

    function providerCount() external view returns (uint256);

    function activeProvider(address _addr) external view returns (bool);

    function activeProviderCount() external view returns (uint256 x);
    
    function addProvider(
        uint256 blockNum,
        uint256 timestamp,
        address provider,
        address paymentTokenAddress,
        uint256 paymentAmtPerFeed,
        uint256 blockCountPerFeed,
        uint256 feedSize,
        bytes32 whitelistedIPAddr
    )
        external;

    function configureProvider(
        address provider,
        address paymentTokenAddress,
        uint256 paymentAmtPerFeed,
        uint256 blockCountPerFeed,
        uint256 feedSize,
        bytes32 whitelistedIPAddr
    )
        external;

    function resetProviderTracker(address _provider) external;

    function pauseProvider(address _provider) external;

    function unpauseProvider(address _provider) external;

    function disableProvider(address _provider, uint256 _blockNum, uint256 _timestamp) external;

    function withdrawPayment(address _payToAddr) external;

    function submitProviderFeedCount(
        address[10] calldata _providerList,
        uint256[10] calldata _feedCount,
        uint256 _timestamp
    )
        external;


    event UpdatedPriceOracleAddress(address _old, address _new);
    event AdjustedSecondPerBlock(uint256 old_value, uint256 new_value);
    event PriceConfigUpdated(
        uint256 movementDelta_b4, 
        uint256 movementDelta_after, 
        uint256 inactivePeriod_b4, 
        uint256 inactivePeriod_after
    );
    event NewPriceOracleProvider(
        uint256 blockNum,
        uint256 timestamp,
        address indexed provider,
        address paymentTokenAddress,
        uint256 paymentAmtPerFeed,
        uint256 blockCountPerFeed,
        uint256 feedSize,
        bytes32 whitelistedIPAddr
    );
    event ConfigProvider(
        address indexed _provider,
        address paymentTokenAddress,
        uint256 paymentAmtPerFeed,
        uint256 blockCountPerFeed,
        uint256 feedSize,
        bytes32 whitelistedIPAddr
    );
    event ResetTracker(
        address indexed provider,
        uint256 lastUpdatedTimestamp,
        uint256 lastUpdatedBlockId,
        uint256 lastPaymentBlockId,
        uint256 osPayment,
        uint256 feedMissCount
    );
    event PausedProvider(address indexed _provider);
    event UnpausedProvider(address indexed _provider);
    event DisabledProvider(address indexed _provider, uint256 _blockNum, uint256 timestamp);
    event GiveUpPayment(address indexed provider, uint256 amt);
    event WithdrewPayment(address indexed provider, uint256 amt);
    event MissedFeed(address indexed provider, uint256 missedCount, uint256 totalMissedCount);
    event PaymentReady(address indexed provider, uint256 added, uint256 totalOS);
    
    error ZeroAddress();
    error ZeroValue();
    error ExistedProvider(address _existedAddr);
    error InvalidProvider(address _invalidProvider);
    error ZeroOutstandingAmount();
    error InsufficientBalance(uint256 requiredAmt);
    
}
