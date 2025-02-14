// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IConfig} from "./IConfig.sol";

interface IGovernanceAction {

    function setContractAddress(
        address _config,
        address _tabRegistry,
        address _reserveRegistry,
        address _priceOracleManagerAddress
    )
        external;

    function setDefBlockGenerationTimeInSecond(uint256 sec) external;

    function updateTabParams(
        bytes3[] calldata _tab,
        IConfig.TabParams[] calldata _tabParams
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

    function addReserve(address _token, address _reserveSafe) external;

    function disableReserve(address _token) external;

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

    event UpdatedConfig(address old, address _addr);
    event UpdatedTabRegistry(address old, address _addr);   
    event UpdatedReserveRegistry(address old, address _addr);
    event UpdatedPriceOracleManagerAddr(address old, address _addr);

    event UpdatedDefBlockGenerationTimeInSecond(uint256 _after);
    event UpdatedTabParams(uint256 tabLength);
    event UpdatedAuctionParams(
        uint256 auctionStartPriceDiscount,
        uint256 auctionStepPriceDiscount,
        uint256 auctionStepDurationInSec,
        address auctionManager
    );

    event PeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio);
    event NewTab(bytes3 _tab, address tabAddr);

    event AddedReserve(address _addr, address _safe);
    event RemovedReserve(address _token);

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
    event ConfigPriceOracleProvider(
        address indexed provider,
        address paymentTokenAddress,
        uint256 paymentAmtPerFeed,
        uint256 blockCountPerFeed,
        uint256 feedSize,
        bytes32 whitelistedIPAddr
    );
    event RemovedPriceOracleProvider(address indexed _provider, uint256 blockNum, uint256 timestamp);
    event PausedPriceOracleProvider(address indexed _provider);
    event UnpausedPriceOracleProvider(address indexed _provider);

    event CtrlAltDelTab(bytes3 indexed _tab, uint256 _btcTabRate);

}
