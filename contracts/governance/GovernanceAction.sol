// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../shared/interfaces/IConfig.sol";
import "../shared/interfaces/ITabRegistry.sol";
import "../shared/interfaces/IReserveRegistry.sol";
import "../ReserveSafe.sol";
import "../oracle/interfaces/IPriceOracleManager.sol";

contract GovernanceAction is Initializable, AccessControlDefaultAdminRulesUpgradeable, UUPSUpgradeable {

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    address emergencyGovernanceController;
    address configAddress;
    address tabRegistryAddress;
    address reserveRegistryAddress;
    address priceOracleManagerAddress;

    struct OracleProvider {
        uint256 activatedSinceBlockNum;
        uint256 activatedTimestamp;
        uint256 disabledOnBlockId;
        uint256 disabledTimestamp;
    }

    mapping(address => OracleProvider) public providers;
    uint256 public defBlockGenerationTimeInSecond;

    // event: Config related
    event UpdatedDefBlockGenerationTimeInSecond(uint256 b4, uint256 _after);
    event UpdatedConfig(address old, address _addr);
    event UpdatedReserveParams(
        bytes32[] reserve, uint256[] processFeeRate, uint256[] minReserveRatio, uint256[] liquidationRatio
    );
    event UpdatedTabParams(bytes3[] tab, uint256[] riskPenaltyPerFrame, uint256[] processFeeRate);
    event UpdatedAuctionParams(
        uint256 auctionStartPriceDiscount,
        uint256 auctionStepPriceDiscount,
        uint256 auctionStepDurationInSec,
        address auctionManager
    );

    // event: Tab related
    event UpdatedTabRegistry(address old, address _addr);

    // event: Reserve related
    event UpdatedReserveRegistry(address old, address _addr);
    event AddedReserve(bytes32 reserveKey, address _addr, address _safe);
    event RemovedReserve(bytes32 reserveKey);

    // event: Price Oracle related
    event UpdatedPriceOracleManagerAddr(address old, address _addr);
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

    event PeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio);
    event NewTab(bytes3 _tab, address tabAddr);
    event CtrlAltDelTab(bytes3 indexed _tab, uint256 _btcTabRate);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _governance, address _emergencyGovernance, address _deployer) public initializer {
        __AccessControlDefaultAdminRules_init(1 days, _governance);
        __UUPSUpgradeable_init();
        _grantRole(MAINTAINER_ROLE, _governance);
        _grantRole(MAINTAINER_ROLE, _emergencyGovernance);
        _grantRole(MAINTAINER_ROLE, _deployer);
        emergencyGovernanceController = _emergencyGovernance;
        defBlockGenerationTimeInSecond = 12;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function setContractAddress(
        address _config,
        address _tabRegistry,
        address _reserveRegistry,
        address _priceOracleManagerAddress
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        if (_config != address(0)) {
            emit UpdatedConfig(configAddress, _config);
            configAddress = _config;
        }
        if (_tabRegistry != address(0)) {
            emit UpdatedTabRegistry(tabRegistryAddress, _tabRegistry);
            tabRegistryAddress = _tabRegistry;
        }
        if (_reserveRegistry != address(0)) {
            emit UpdatedReserveRegistry(reserveRegistryAddress, _reserveRegistry);
            reserveRegistryAddress = _reserveRegistry;
        }
        if (_priceOracleManagerAddress != address(0)) {
            emit UpdatedPriceOracleManagerAddr(priceOracleManagerAddress, _priceOracleManagerAddress);
            priceOracleManagerAddress = _priceOracleManagerAddress;
        }
    }

    function setDefBlockGenerationTimeInSecond(uint256 sec) external onlyRole(MAINTAINER_ROLE) {
        require(sec > 0, "ZERO_VALUE");
        IPriceOracleManager(priceOracleManagerAddress).setDefBlockGenerationTimeInSecond(sec);
        emit UpdatedDefBlockGenerationTimeInSecond(defBlockGenerationTimeInSecond, sec);
        defBlockGenerationTimeInSecond = sec;
    }

    // Config

    function updateReserveParams(
        bytes32[] calldata _reserveKey,
        uint256[] calldata _processFeeRate,
        uint256[] calldata _minReserveRatio,
        uint256[] calldata _liquidationRatio
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        emit UpdatedReserveParams(_reserveKey, _processFeeRate, _minReserveRatio, _liquidationRatio);
        IConfig(configAddress).setReserveParams(_reserveKey, _processFeeRate, _minReserveRatio, _liquidationRatio);
    }

    function updateTabParams(
        bytes3[] calldata _tab,
        uint256[] calldata _riskPenaltyPerFrame,
        uint256[] calldata _processFeeRate
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        emit UpdatedTabParams(_tab, _riskPenaltyPerFrame, _processFeeRate);
        IConfig(configAddress).setTabParams(_tab, _riskPenaltyPerFrame, _processFeeRate);
    }

    function updateAuctionParams(
        uint256 _auctionStartPriceDiscount,
        uint256 _auctionStepPriceDiscount,
        uint256 _auctionStepDurationInSec,
        address _auctionManager
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        emit UpdatedAuctionParams(
            _auctionStartPriceDiscount, _auctionStepPriceDiscount, _auctionStepDurationInSec, _auctionManager
        );
        IConfig(configAddress).setAuctionParams(
            _auctionStartPriceDiscount, _auctionStepPriceDiscount, _auctionStepDurationInSec, _auctionManager
        );
    }

    // Tab

    /**
     *
     * @param _tab Tab code to be disabled(freezed)
     * @dev When tab is paused, the following actions on paused tab will fail:
     * - VaultManager.createVault
     * - VaultManager.adjustTab
     * - VaultManager.adjustReserve
     * - Disabled risk penalty on vaults below minimum reserve ratio
     */
    function disableTab(bytes3 _tab) external onlyRole(MAINTAINER_ROLE) {
        ITabRegistry(tabRegistryAddress).disableTab(_tab);
    }

    function enableTab(bytes3 _tab) external onlyRole(MAINTAINER_ROLE) {
        ITabRegistry(tabRegistryAddress).enableTab(_tab);
    }

    function disableAllTabs() external onlyRole(MAINTAINER_ROLE) {
        ITabRegistry(tabRegistryAddress).disableAllTab();
    }

    function enableAllTabs() external onlyRole(MAINTAINER_ROLE) {
        ITabRegistry(tabRegistryAddress).enableAllTab();
    }

    /**
     * @dev Call `createNewTab` first on the pegging currency(_ptab), then followed by calling `setPeggedTab`.
     * @param _ptab Pegging tab currency, rate is based on existing tab.
     * @param _tab Existing Tab, Tab rate is based on oracle service.
     * @param _priceRatio BTC/PEGGING_TAB = (BTC/TAB * _priceRatio) / 100
     */
    function setPeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio) external onlyRole(MAINTAINER_ROLE) {
        ITabRegistry(tabRegistryAddress).setPeggedTab(_ptab, _tab, _priceRatio);
        emit PeggedTab(_ptab, _tab, _priceRatio);
    }

    function createNewTab(bytes3 _tab) external onlyRole(MAINTAINER_ROLE) returns (address) {
        require(ITabRegistry(tabRegistryAddress).tabs(_tab) == address(0), "EXISTED_TAB");
        require(ITabRegistry(tabRegistryAddress).peggedTabPriceRatio(_tab) == 0, "EXISTED_PEGGED_TAB");

        address tabAddr = ITabRegistry(tabRegistryAddress).createTab(_tab);
        emit NewTab(_tab, tabAddr);

        return tabAddr;
    }

    // Reserve

    function addReserve(
        bytes32 _reserveKey,
        address _token,
        address _vaultManager
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        ReserveSafe reserveSafe = new ReserveSafe(owner(), emergencyGovernanceController, _vaultManager, _token);
        IReserveRegistry(reserveRegistryAddress).addReserve(_reserveKey, _token, address(reserveSafe));
        emit AddedReserve(_reserveKey, _token, address(reserveSafe));
    }

    function disableReserve(bytes32 _reserveKey) external onlyRole(MAINTAINER_ROLE) {
        IReserveRegistry(reserveRegistryAddress).removeReserve(_reserveKey);
        emit RemovedReserve(_reserveKey);
    }

    // Price Oracle

    /**
     *
     * @param provider Wallet address of the new provider.
     * @param paymentTokenAddress Payment token address.
     * @param paymentAmtPerFeed Unit price of each feed.
     * @param blockCountPerFeed Assume 5-min feed interval, 60s / 12s * 5m = 25 blockCountPerFeed.
     * Within blockCountPerFeed range, expect incoming feed
     * @param feedSize Minimum number of currency pairs sent by provider.
     * @param whitelistedIPAddr Comma separated IP Address(es). Max 2 IP when IP is full length (15*2). Price feeds are
     * expected to send from these IP.
     */
    function addPriceOracleProvider(
        address provider,
        address paymentTokenAddress,
        uint256 paymentAmtPerFeed,
        uint256 blockCountPerFeed,
        uint256 feedSize,
        bytes32 whitelistedIPAddr
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        require(provider != address(0), "INVALID_PROVIDER");
        require(providers[provider].activatedSinceBlockNum == 0, "EXISTED_PROVIDER");
        require(paymentTokenAddress != address(0), "INVALID_PAYMENT_TOKEN_ADDR");
        require(paymentAmtPerFeed > 0, "ZERO_PAYMENT_AMT");
        require(blockCountPerFeed > 0, "ZERO_BLOCK_COUNT_PER_FEED");
        require(feedSize > 0, "ZERO_FEED_SIZE");

        providers[provider] = OracleProvider(block.number, block.timestamp, 0, 0);

        emit NewPriceOracleProvider(
            block.number,
            block.timestamp,
            provider,
            paymentTokenAddress,
            paymentAmtPerFeed,
            blockCountPerFeed,
            feedSize,
            whitelistedIPAddr
        );
        IPriceOracleManager(priceOracleManagerAddress).addProvider(
            block.number,
            block.timestamp,
            provider,
            paymentTokenAddress,
            paymentAmtPerFeed,
            blockCountPerFeed,
            feedSize,
            whitelistedIPAddr
        );
    }

    function configurePriceOracleProvider(
        address provider,
        address paymentTokenAddress,
        uint256 paymentAmtPerFeed,
        uint256 blockCountPerFeed,
        uint256 feedSize,
        bytes32 whitelistedIPAddr
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        require(
            providers[provider].activatedTimestamp > 0 && providers[provider].disabledOnBlockId == 0, "INVALID_PROVIDER"
        );
        require(paymentTokenAddress != address(0), "INVALID_PAYMENT_TOKEN_ADDR");
        require(blockCountPerFeed > 0, "ZERO_BLOCK_COUNT_PER_FEED");
        require(feedSize > 0, "ZERO_FEED_SIZE");

        IPriceOracleManager(priceOracleManagerAddress).configureProvider(
            provider, paymentTokenAddress, paymentAmtPerFeed, blockCountPerFeed, feedSize, whitelistedIPAddr
        );
        emit ConfigPriceOracleProvider(
            provider, paymentTokenAddress, paymentAmtPerFeed, blockCountPerFeed, feedSize, whitelistedIPAddr
        );
    }

    function removePriceOracleProvider(
        address _provider,
        uint256 _blockNumber,
        uint256 _timestamp
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        require(_provider != address(0), "INVALID_ADDR");
        require(_blockNumber > 0, "ZERO_BLOCK_NUMBER");
        require(_timestamp > 0, "ZERO_TIMESTAMP");
        require(providers[_provider].activatedSinceBlockNum > 0, "NOT_FOUND");

        providers[_provider].disabledOnBlockId = _blockNumber;
        providers[_provider].disabledTimestamp = _timestamp;

        IPriceOracleManager(priceOracleManagerAddress).disableProvider(_provider, _blockNumber, _timestamp);
        emit RemovedPriceOracleProvider(_provider, _blockNumber, _timestamp);
    }

    function pausePriceOracleProvider(address _provider) external onlyRole(MAINTAINER_ROLE) {
        IPriceOracleManager(priceOracleManagerAddress).pauseProvider(_provider);
        emit PausedPriceOracleProvider(_provider);
    }

    function unpausePriceOracleProvider(address _provider) external onlyRole(MAINTAINER_ROLE) {
        IPriceOracleManager(priceOracleManagerAddress).unpauseProvider(_provider);
        emit UnpausedPriceOracleProvider(_provider);
    }

    /// @dev ProtocolVault contract is expected to be deployed before calling this & granted MINTER_ROLE for the TAB
    /// contract. Revoked same role from VaultManager.
    function ctrlAltDel(bytes3 _tab, uint256 _btcTabRate) external onlyRole(MAINTAINER_ROLE) {
        ITabRegistry(tabRegistryAddress).ctrlAltDel(_tab, _btcTabRate);
        emit CtrlAltDelTab(_tab, _btcTabRate);
    }

}
