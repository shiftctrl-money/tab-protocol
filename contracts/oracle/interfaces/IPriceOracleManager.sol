// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPriceOracleManager {

    function priceOracle() external view returns (address);

    function tabs(bytes3) external view returns (bool);

    function tabList(uint256) external view returns (bytes3);

    function prices(bytes3 _tab) external view returns (uint256);

    function lastUpdated(bytes3 _tab) external view returns (uint256);

    function movementDelta() external view returns (uint256);

    function inactivePeriod() external view returns (uint256);

    function defBlockGenerationTimeInSecond() external view returns (uint256);

    function addNewTab(bytes3 _tab) external;

    function setDefBlockGenerationTimeInSecond(uint256 _secondPerBlock) external;

    function providers(address) external view returns (uint256, uint256, uint256, uint256, uint256, bool);

    function providerTracker(address) external view returns (uint256, uint256, uint256, uint256, uint256);

    function providerInfo(address) external view returns (address, uint256, uint256, uint256, bytes32);

    function providerList(uint256) external view returns (address);

    function providerCount() external view returns (uint256);

    function activeProvider(address _addr) external view returns (bool);

    function activeProviderCount() external view returns (uint256 x);

    function activeTabCount() external view returns (uint256);

    function setPriceOracle(address _priceOracle) external;

    function updateConfig(uint256 _movementDelta, uint256 _inactivePeriod) external;

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

    struct TabPool {
        bytes3 tab;
        uint256 timestamp;
        uint256 listSize;
        uint256[9] medianList;
    }

    struct CID {
        bytes32 ipfsCID_1;
        bytes32 ipfsCID_2;
    }

    function submitProviderFeedCount(
        address[10] calldata _providerList,
        uint256[10] calldata _feedCount,
        uint256 _timestamp
    )
        external;

    function updatePrice(TabPool[10] calldata _tabPool, CID calldata _cid) external;

}
