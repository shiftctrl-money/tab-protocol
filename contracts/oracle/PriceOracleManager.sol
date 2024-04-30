// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";
import "./../shared/interfaces/IERC20.sol";
import "./interfaces/IPriceOracle.sol";

contract PriceOracleManager is Initializable, AccessControlDefaultAdminRulesUpgradeable, UUPSUpgradeable {

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant PAYMENT_ROLE = keccak256("PAYMENT_ROLE");

    mapping(bytes3 => bool) public tabs;
    bytes3[] public tabList; // list of all activated tab currrencies

    address public priceOracle;
    mapping(bytes3 => uint256) public prices;
    mapping(bytes3 => uint256) public lastUpdated;

    uint256 public movementDelta; // e.g delta 0.5%, update price when movement exceeded delta value
    uint256 public inactivePeriod; // force update price upon reaching inactivePeriod (inactivity due to small delta
        // movement in prices, hence skipped update)
    uint256 public defBlockGenerationTimeInSecond;

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

    mapping(address => OracleProvider) public providers;
    mapping(address => Tracker) public providerTracker;
    mapping(address => Info) public providerInfo;
    address[] public providerList;

    uint256 public ORACLE_PRICE_SIZE;

    struct TabPool {
        bytes3 tab;
        uint256 timestamp;
        uint256 listSize;
        uint256[9] mediumList;
    }

    struct CID {
        bytes32 ipfsCID_1;
        bytes32 ipfsCID_2;
    }

    event NewTab(bytes3 _tab, uint256 activatedCount);
    event AdjustedSecondPerBlock(uint256 old_value, uint256 new_value);
    event UpdatedPriceOracleAddress(address _old, address _new);
    event PriceConfigUpdated(
        uint256 movementDelta_b4, uint256 movementDelta_after, uint256 inactivePeriod_b4, uint256 inactivePeriod_after
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
    event ResetTracker(
        address indexed provider,
        uint256 lastUpdatedTimestamp,
        uint256 lastUpdatedBlockId,
        uint256 lastPaymentBlockId,
        uint256 osPayment,
        uint256 feedMissCount
    );
    event DisabledProvider(address indexed _provider, uint256 _blockNum, uint256 timestamp);
    event ConfigProvider(
        address indexed _provider,
        address paymentTokenAddress,
        uint256 paymentAmtPerFeed,
        uint256 blockCountPerFeed,
        uint256 feedSize,
        bytes32 whitelistedIPAddr
    );
    event PausedProvider(address indexed _provider);
    event UnpausedProvider(address indexed _provider);

    event UpdatedPrice(uint256 _tabCount, uint256 _timestamp, bytes _cid);
    event IgnoredPrice(
        bytes3 indexed tab, uint256 indexed timestamp, uint256 droppedMedianPrice, uint256 existingPrice
    );
    event MissedFeed(address indexed provider, uint256 missedCount, uint256 totalMissedCount);
    event PaymentReady(address indexed provider, uint256 added, uint256 totalOS);
    event WithdrewPayment(address indexed provider, uint256 amt);
    event GiveUpPayment(address indexed provider, uint256 amt);

    error InsufficientBalance(uint256 requiredAmt);
    error InvalidMediumValue(bytes3 _tab, uint256 _timestamp);
    error EmptyCID(bytes32 cidPart);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        address _admin2,
        address _governanceAction,
        address _deployer,
        address _authorizedCaller,
        address _tabRegistry
    )
        public
        initializer
    {
        __AccessControlDefaultAdminRules_init(1 days, _admin);
        __UUPSUpgradeable_init();

        _grantRole(MAINTAINER_ROLE, _admin);
        _grantRole(MAINTAINER_ROLE, _admin2);
        _grantRole(MAINTAINER_ROLE, _governanceAction);
        _grantRole(MAINTAINER_ROLE, _deployer);
        _grantRole(MAINTAINER_ROLE, _authorizedCaller);
        _grantRole(CONFIG_ROLE, _admin);
        _grantRole(CONFIG_ROLE, _admin2);
        _grantRole(CONFIG_ROLE, _governanceAction);
        _grantRole(CONFIG_ROLE, _tabRegistry);
        _setRoleAdmin(PAYMENT_ROLE, MAINTAINER_ROLE);

        ORACLE_PRICE_SIZE = 10;
        defBlockGenerationTimeInSecond = 12;
        movementDelta = 500; // update price whenever > +/- 0.5% delta, 0.5 * 1000 = 500
        inactivePeriod = 1 hours; // 3600
    }

    // Refer UUPSUpgradeable:
    // The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function addNewTab(bytes3 _tab) external onlyRole(CONFIG_ROLE) {
        tabList.push(_tab);
        tabs[_tab] = true;
        emit NewTab(_tab, tabList.length);
    }

    function setDefBlockGenerationTimeInSecond(uint256 _secondPerBlock) external onlyRole(MAINTAINER_ROLE) {
        require(_secondPerBlock > 0, "setSecondPerBlock/INVALID_SEC_PER_BLOCK");
        emit AdjustedSecondPerBlock(defBlockGenerationTimeInSecond, _secondPerBlock);
        defBlockGenerationTimeInSecond = _secondPerBlock;
    }

    function providerCount() external view returns (uint256) {
        return providerList.length;
    }

    function activeProvider(address _addr) external view returns (bool) {
        OracleProvider memory prv = providers[_addr];
        return prv.disabledOnBlockId == 0 && prv.disabledTimestamp == 0 && prv.paused == false
            && block.number >= prv.activatedSinceBlockNum && block.timestamp >= prv.activatedTimestamp;
    }

    function activeProviderCount() public view returns (uint256 x) {
        for (uint256 i = 0; i < providerList.length; i = unsafe_inc(i)) {
            OracleProvider memory prv = providers[providerList[i]];
            if (
                prv.disabledOnBlockId == 0 && prv.disabledTimestamp == 0 && prv.paused == false
                    && block.number >= prv.activatedSinceBlockNum && block.timestamp >= prv.activatedTimestamp
            ) {
                x++;
            }
        }
    }

    function activeTabCount() external view returns (uint256) {
        return tabList.length;
    }

    function setPriceOracle(address _priceOracle) external onlyRole(MAINTAINER_ROLE) {
        require(_priceOracle != address(0), "setPriceOracle/INVALID_ADDR");
        emit UpdatedPriceOracleAddress(priceOracle, _priceOracle);
        priceOracle = _priceOracle;
    }

    function updateConfig(uint256 _movementDelta, uint256 _inactivePeriod) external onlyRole(MAINTAINER_ROLE) {
        require(_movementDelta > 0, "updateConfig/ZERO_DELTA");
        require(_inactivePeriod > 0, "updateConfig/INVALID_INACTIVE_PERIOD");

        emit PriceConfigUpdated(movementDelta, _movementDelta, inactivePeriod, _inactivePeriod);

        IPriceOracle(priceOracle).updateInactivePeriod(_inactivePeriod);

        movementDelta = _movementDelta;
        inactivePeriod = _inactivePeriod;
    }

    /**
     *
     * @param blockNum Block number on activation
     * @param timestamp Timestamp on activation
     * @param provider Provider wallet address
     * @param paymentTokenAddress Payment token address
     * @param paymentAmtPerFeed Unit price of each feed
     * @param blockCountPerFeed Assume 5-min feed interval, 60s / 12s * 5m = 25 blockCountPerFeed.
     * Within blockCountPerFeed range, expect incoming feed
     * @param feedSize Minimum currency pairs provided
     * @param whitelistedIPAddr Comma separated IP Address(es). Provider needs to send feeds from these IP Addresses.
     */
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
        external
        onlyRole(MAINTAINER_ROLE)
    {
        providers[provider] = OracleProvider(providerList.length, blockNum, timestamp, 0, 0, false);
        providerInfo[provider] =
            Info(paymentTokenAddress, paymentAmtPerFeed, blockCountPerFeed, feedSize, whitelistedIPAddr);
        providerTracker[provider] = Tracker(timestamp, block.number, block.number, 0, 0);
        providerList.push(provider);
        _grantRole(PAYMENT_ROLE, provider);

        emit NewPriceOracleProvider(
            blockNum,
            timestamp,
            provider,
            paymentTokenAddress,
            paymentAmtPerFeed,
            blockCountPerFeed,
            feedSize,
            whitelistedIPAddr
        );
    }

    function configureProvider(
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
            providers[provider].activatedTimestamp > 0 && providers[provider].disabledOnBlockId == 0
                && providers[provider].disabledTimestamp == 0,
            "configureProvider/DISABLED_PROVIDER"
        );
        providerInfo[provider].paymentTokenAddress = paymentTokenAddress;
        providerInfo[provider].paymentAmtPerFeed = paymentAmtPerFeed;
        providerInfo[provider].blockCountPerFeed = blockCountPerFeed;
        providerInfo[provider].feedSize = feedSize;
        providerInfo[provider].whitelistedIPAddr = whitelistedIPAddr;
        emit ConfigProvider(
            provider, paymentTokenAddress, paymentAmtPerFeed, blockCountPerFeed, feedSize, whitelistedIPAddr
        );
    }

    /// @dev Upon unpause operation, the unpaused provider's tracker is reset.
    /// Take note osPayment amount is not cleared during reset.
    function resetProviderTracker(address _provider) public onlyRole(MAINTAINER_ROLE) {
        OracleProvider storage prv = providers[_provider];
        require(
            prv.activatedTimestamp > 0 && prv.disabledOnBlockId == 0 && prv.paused == false,
            "resetProviderTracker/DISABLED_PROVIDER"
        );
        emit ResetTracker(
            _provider,
            providerTracker[_provider].lastUpdatedTimestamp,
            providerTracker[_provider].lastUpdatedBlockId,
            providerTracker[_provider].lastPaymentBlockId,
            providerTracker[_provider].osPayment,
            providerTracker[_provider].feedMissCount
        );
        providerTracker[_provider].lastUpdatedTimestamp = block.timestamp;
        providerTracker[_provider].lastUpdatedBlockId = block.number;
        providerTracker[_provider].lastPaymentBlockId = block.number;

        // osPayment is not reset
        providerTracker[_provider].feedMissCount = 0;
    }

    /**
     * @dev System rejects feed from paused provider. Can withdraw payment when paused.
     * @param _provider Provider address.
     */
    function pauseProvider(address _provider) external onlyRole(MAINTAINER_ROLE) {
        require(
            providers[_provider].paused == false && providers[_provider].activatedTimestamp > 0,
            "pauseProvider/INVALID_PROVIDER"
        );
        providers[_provider].paused = true;
        emit PausedProvider(_provider);
    }

    function unpauseProvider(address _provider) external onlyRole(MAINTAINER_ROLE) {
        require(
            providers[_provider].paused == true && providers[_provider].activatedTimestamp > 0,
            "pauseProvider/INVALID_PROVIDER"
        );
        providers[_provider].paused = false;
        resetProviderTracker(_provider);
        emit UnpausedProvider(_provider);
    }

    /**
     *
     * @param _provider Provider address.
     * @param _blockNum Governance supplied block number to deactivate the provider.
     * @param _timestamp Governance supplied block timestamp to deactivate the provider.
     */
    function disableProvider(
        address _provider,
        uint256 _blockNum,
        uint256 _timestamp
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        require(
            providers[_provider].disabledOnBlockId == 0 && providers[_provider].disabledTimestamp == 0
                && providerList.length > 0,
            "disableProvider/ALREADY_DISABLED"
        );

        providers[_provider].disabledOnBlockId = _blockNum;
        providers[_provider].disabledTimestamp = _timestamp;

        emit DisabledProvider(_provider, _blockNum, _timestamp);
    }

    function withdrawPayment(address _withdrawToAddr) external onlyRole(PAYMENT_ROLE) {
        address _provider = msg.sender;
        OracleProvider memory prv = providers[_provider];

        require(
            block.timestamp > prv.activatedTimestamp && prv.disabledOnBlockId == 0 && prv.disabledTimestamp == 0,
            "withdrawPayment/DISABLED_PROVIDER"
        );

        require(
            block.timestamp > providerTracker[_provider].lastUpdatedTimestamp
                && block.number > providerTracker[_provider].lastUpdatedBlockId,
            "withdrawPayment/INVALID_LAST_TIMESTAMP"
        );
        require(providerTracker[_provider].osPayment > 0, "withdrawPayment/NO_OS_AMT");

        // provider can give up payment
        if (_withdrawToAddr == address(0)) {
            emit GiveUpPayment(_provider, providerTracker[_provider].osPayment);
            providerTracker[_provider].osPayment = 0;
            providerTracker[_provider].lastPaymentBlockId = block.number;
            return;
        }

        if (
            IERC20(providerInfo[_provider].paymentTokenAddress).balanceOf(address(this))
                >= providerTracker[_provider].osPayment
        ) {
            uint256 withdrawalAmt = providerTracker[_provider].osPayment;
            emit WithdrewPayment(_provider, withdrawalAmt);
            providerTracker[_provider].osPayment = 0;
            providerTracker[_provider].lastPaymentBlockId = block.number;
            SafeERC20.safeTransfer(IERC20(providerInfo[_provider].paymentTokenAddress), _withdrawToAddr, withdrawalAmt);
        } else {
            revert InsufficientBalance(providerTracker[_provider].osPayment);
        }
    }

    /// @dev scheduler execution - submit accumulated feed count each 24H (or more frequent, e.g. every hour)
    function submitProviderFeedCount(
        address[10] calldata _providerList,
        uint256[10] calldata _feedCount,
        uint256 _timestamp
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        OracleProvider memory prv;
        Info memory info;
        Tracker storage tracker;

        uint256 amtToPay = 0;
        uint256 timeSpanSinceLastUpdated = 0;
        for (uint256 i = 0; i < 10; i = unsafe_inc(i)) {
            if (_providerList[i] != address(0)) {
                prv = providers[_providerList[i]];
                if (_timestamp > prv.activatedTimestamp && prv.disabledOnBlockId == 0 && prv.paused == false) {
                    info = providerInfo[_providerList[i]];
                    tracker = providerTracker[_providerList[i]];

                    amtToPay = 0;
                    timeSpanSinceLastUpdated = FixedPointMathLib.zeroFloorSub(_timestamp, tracker.lastUpdatedTimestamp);
                    if (timeSpanSinceLastUpdated > 0) {
                        // estimated block count in tracking session / number of blocks of each feed
                        // = expect feed count in tracking session
                        uint256 sessionFeedCount =
                            timeSpanSinceLastUpdated / defBlockGenerationTimeInSecond / info.blockCountPerFeed;
                        if (_feedCount[i] < sessionFeedCount) {
                            uint256 numberOfMissedFeed = sessionFeedCount - _feedCount[i];
                            tracker.feedMissCount += numberOfMissedFeed; // no action, accumulated for alert only
                            emit MissedFeed(_providerList[i], numberOfMissedFeed, tracker.feedMissCount);

                            if (_feedCount[i] > 0) {
                                amtToPay = _feedCount[i] * info.paymentAmtPerFeed;
                            }
                        } else {
                            amtToPay = sessionFeedCount * info.paymentAmtPerFeed;
                        }

                        if (amtToPay > 0) {
                            tracker.osPayment += amtToPay;
                            emit PaymentReady(_providerList[i], amtToPay, tracker.osPayment);
                        }
                    }

                    tracker.lastUpdatedTimestamp = _timestamp;
                    tracker.lastUpdatedBlockId = block.number;
                }
            }
        }
    }

    function updatePrice(TabPool[10] calldata _tabPool, CID calldata _cid) external onlyRole(MAINTAINER_ROLE) {
        bytes memory cid = constructCIDv1(_cid.ipfsCID_1, _cid.ipfsCID_2);
        uint256 tabCount = 0;
        bytes3 _tab;
        uint256 _timestamp;

        // Required to call PriceOracle.setPrice
        bytes3[] memory _tabs = new bytes3[](ORACLE_PRICE_SIZE);
        uint256[] memory _prices = new uint256[](ORACLE_PRICE_SIZE);
        uint256[] memory _lastUpdated = new uint256[](ORACLE_PRICE_SIZE);

        for (uint256 i = 0; i < _tabPool.length; i = unsafe_inc(i)) {
            _timestamp = _tabPool[i].timestamp;
            if (_timestamp > 0) {
                // ignore if timestamp == 0, which is placehoolder to fill up TabPool fixed array of 10 items
                _tab = _tabPool[i].tab;

                // get medium value from sorted list
                uint256 mediumValue = 0;
                uint256[] memory actualMediumList = new uint256[](_tabPool[i].listSize);
                for (uint256 n = 0; n < _tabPool[i].listSize; n++) {
                    actualMediumList[n] = _tabPool[i].mediumList[n];
                }
                mediumValue = getMedianPrice(actualMediumList);

                if (mediumValue == 0) {
                    revert InvalidMediumValue(_tab, _timestamp);
                }

                // update price if:
                // (1) price changes exceeded configured threshold
                // (2) price last changed timestamp exceeded configured inactivePeriod
                if (
                    calcDiffPercentage(prices[_tab], mediumValue) > movementDelta
                        || _timestamp >= lastUpdated[_tab] + inactivePeriod
                ) {
                    _tabs[tabCount] = _tab;
                    _prices[tabCount] = mediumValue;
                    _lastUpdated[tabCount] = _timestamp;

                    prices[_tab] = mediumValue;
                    lastUpdated[_tab] = _timestamp;

                    tabCount = unsafe_inc(tabCount);
                } else {
                    emit IgnoredPrice(_tab, _timestamp, mediumValue, prices[_tab]);
                }
            }
        }

        IPriceOracle(priceOracle).setPrice(_tabs, _prices, _lastUpdated);

        emit UpdatedPrice(tabCount, _tabPool[0].timestamp, cid);
    }

    // ------------------------- internal functions ----------------------------------------------

    function getMedianPrice(uint256[] memory _prices) internal pure returns (uint256 median) {
        uint256 priceLength = _prices.length;
        uint256 mid = FixedPointMathLib.rawDiv(priceLength, 2);
        if (priceLength == 1) {
            median = _prices[0];
        } else {
            if (FixedPointMathLib.rawMod(priceLength, 2) == 0) {
                // even length
                median = FixedPointMathLib.rawDiv(
                    FixedPointMathLib.rawAdd(_prices[FixedPointMathLib.rawSub(mid, 1)], _prices[mid]), 2
                ); // (mid_left + mid_right) / 2
            } else {
                median = _prices[mid];
            } // middle value in sorted list
        }
    }

    function calcDiffPercentage(uint256 oldPrice, uint256 newPrice) internal pure returns (uint256) {
        if (oldPrice == 0) {
            return 100000;
        }
        uint256 difference = newPrice > oldPrice
            ? FixedPointMathLib.rawSub(newPrice, oldPrice)
            : FixedPointMathLib.rawSub(oldPrice, newPrice);
        return FixedPointMathLib.mulDiv(difference, 100000, oldPrice);
    }

    function constructCIDv1(bytes32 part1, bytes32 part2) private pure returns (bytes memory) {
        bytes memory cid = new bytes(59);
        uint256 i = 0;
        for (; i < 31; i = unsafe_inc(i)) {
            if (part1[i] == 0x00) {
                revert EmptyCID(part1);
            }
            cid[i] = part1[i];
        }
        for (uint256 j = 0; j < 28; j = unsafe_inc(j)) {
            if (part2[j] == 0x00) {
                revert EmptyCID(part2);
            }
            cid[i] = part2[j];
            i = unsafe_inc(i);
        }
        return cid;
    }

    function unsafe_inc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

}
