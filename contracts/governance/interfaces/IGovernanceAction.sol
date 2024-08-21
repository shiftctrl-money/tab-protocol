// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IGovernanceAction {

    function providers(address) external view returns (uint256, uint256, uint256, uint256);

    function setContractAddress(
        address _config,
        address _tabRegistry,
        address _reserveRegistry,
        address _priceOracleManagerAddress
    )
        external;

    function setDefBlockGenerationTimeInSecond(uint256 sec) external;

    function updateReserveParams(
        bytes32[] calldata _reserveKey,
        uint256[] calldata _processFeeRate,
        uint256[] calldata _minReserveRatio,
        uint256[] calldata _liquidationRatio
    )
        external;

    function updateTabParams(
        bytes3[] calldata _tab,
        uint256[] calldata _riskPenaltyPerFrame,
        uint256[] calldata _processFeeRate
    )
        external;

    function updateAuctionParams(
        uint256 _auctionStartPriceDiscount,
        uint256 _auctionStepPriceDiscount,
        uint256 _auctionStepDurationInSec,
        address _auctionManager
    )
        external;

    function disableTab(bytes3 _tab) external;

    function enableTab(bytes3 _tab) external;

    function disableAllTabs() external;

    function enableAllTabs() external;

    function setPeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio) external;

    function createNewTab(bytes3 _tab) external returns (address);

    function addReserve(bytes32 _reserveKey, address _token, address _vaultManager) external;

    function disableReserve(bytes32 _reserveKey) external;

    function addPriceOracleProvider(
        address provider,
        address paymentTokenAddress,
        uint256 paymentAmtPerFeed,
        uint256 blockCountPerFeed,
        uint256 feedSize,
        bytes32 whitelistedIPAddr
    )
        external;

    function configurePriceOracleProvider(
        address provider,
        address paymentTokenAddress,
        uint256 paymentAmtPerFeed,
        uint256 blockCountPerFeed,
        uint256 feedSize,
        bytes32 whitelistedIPAddr
    )
        external;

    function removePriceOracleProvider(address _provider, uint256 _blockNumber, uint256 _timestamp) external;

    function pausePriceOracleProvider(address _provider) external;

    function unpausePriceOracleProvider(address _provider) external;

    function ctrlAltDel(bytes3 _tab, uint256 _btcTabRate) external;

}
