// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IPriceOracleManager} from "../interfaces/IPriceOracleManager.sol";

/**
 * @title Manage and track performance of authorized oracle providers.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract PriceOracleManager is 
    Initializable, 
    AccessControlDefaultAdminRulesUpgradeable, 
    UUPSUpgradeable, 
    IPriceOracleManager 
{

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant PAYMENT_ROLE = keccak256("PAYMENT_ROLE");

    // e.g delta 0.5%, update price when movement exceeded delta value
    uint256 public movementDelta; 
    // force update price upon reaching inactivePeriod (inactivity due to small delta
    //   movement in prices, hence skipped update)
    uint256 public inactivePeriod; 
        
    uint256 public defBlockGenerationTimeInSecond;

    address public priceOracle;

    mapping(address => OracleProvider) public providers;
    mapping(address => Tracker) public providerTracker;
    mapping(address => Info) public providerInfo;
    address[] public providerList;

    constructor() {
        _disableInitializers();
    }

    /**
     * @param _admin Governance controller.
     * @param _admin2 Emergency governance controller.
     * @param _governanceAction Governance action contract.
     * @param _deployer Deployer.
     * @param _authorizedCaller Offline Tab-Oracle module that tracks oracle provider performance.
     * @param _tabRegistry Tab Registry address.
     */
    function initialize(
        address _admin,
        address _admin2,
        address _governanceAction,
        address _deployer,
        address _upgrader,
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
        _grantRole(UPGRADER_ROLE, _upgrader);
        _setRoleAdmin(PAYMENT_ROLE, MAINTAINER_ROLE);

        defBlockGenerationTimeInSecond = 2; // refer https://base.blockscout.com/stats
        movementDelta = 500; // update price whenever > +/- 0.5% delta, 0.5 * 1000 = 500
        inactivePeriod = 1 hours; // 3600
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
    
    function setPriceOracle(address _priceOracle) external onlyRole(MAINTAINER_ROLE) {
        if (_priceOracle == address(0))
            revert ZeroAddress();
        emit UpdatedPriceOracleAddress(priceOracle, _priceOracle);
        priceOracle = _priceOracle;
    }

    function setDefBlockGenerationTimeInSecond(uint256 _secondPerBlock) external onlyRole(MAINTAINER_ROLE) {
        if (_secondPerBlock == 0)
            revert ZeroValue();
        emit AdjustedSecondPerBlock(defBlockGenerationTimeInSecond, _secondPerBlock);
        defBlockGenerationTimeInSecond = _secondPerBlock;
    }

    function updateConfig(uint256 _movementDelta, uint256 _inactivePeriod) external onlyRole(MAINTAINER_ROLE) {
        if (_movementDelta == 0)
            revert ZeroValue();
        if (_inactivePeriod == 0)
            revert ZeroValue();

        IPriceOracle(priceOracle).updateInactivePeriod(_inactivePeriod);
        
        emit PriceConfigUpdated(movementDelta, _movementDelta, inactivePeriod, _inactivePeriod);
        movementDelta = _movementDelta;
        inactivePeriod = _inactivePeriod;
    }

    function getProvider(address providerKey) external view returns(OracleProvider memory) {
        return providers[providerKey];
    }

    function getProviderTracker(address providerKey) external view returns(Tracker memory) {
        return providerTracker[providerKey];
    }

    function getProviderInfo(address providerKey) external view returns(Info memory) {
        return providerInfo[providerKey];
    }

    function getConfig() external view returns(uint256 _defBlockGenerationTimeInSecond, uint256 _movementDelta, uint256 _inactivePeriod) {
        _defBlockGenerationTimeInSecond = defBlockGenerationTimeInSecond;
        _movementDelta = movementDelta;
        _inactivePeriod = inactivePeriod;
    }

    function providerCount() external view returns (uint256) {
        return providerList.length;
    }

    function activeProvider(address _addr) external view returns (bool) {
        OracleProvider memory prv = providers[_addr];
        return prv.disabledOnBlockId == 0 && prv.disabledTimestamp == 0 && !prv.paused
            && block.number >= prv.activatedSinceBlockNum && block.timestamp >= prv.activatedTimestamp;
    }

    function activeProviderCount() public view returns (uint256 x) {
        for (uint256 i; i < providerList.length; i++) {
            OracleProvider memory prv = providers[providerList[i]];
            if (
                prv.disabledOnBlockId == 0 && prv.disabledTimestamp == 0 && !prv.paused
                    && block.number >= prv.activatedSinceBlockNum && block.timestamp >= prv.activatedTimestamp
            ) {
                x++;
            }
        }
    }

    /**
     *
     * @param blockNum Block number on activation
     * @param timestamp Timestamp on activation
     * @param provider Provider wallet address
     * @param paymentTokenAddress Payment token address
     * @param paymentAmtPerFeed Unit price of each feed
     * @param blockCountPerFeed Assume 5-min feed interval and 2s block gen. time,
     * each feed is expected to arrive within 60/2 * 5 = 150 blocks.
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
        if (blockNum == 0)
            revert ZeroValue();
        if (timestamp == 0)
            revert ZeroValue();
        if (provider == address(0))
            revert ZeroAddress();
        if (providers[provider].activatedSinceBlockNum > 0)
            revert ExistedProvider(provider);
        if (paymentTokenAddress == address(0))
            revert ZeroAddress();
        if (paymentAmtPerFeed == 0)
            revert ZeroValue();
        if (blockCountPerFeed == 0)
            revert ZeroValue();
        if (feedSize == 0)
            revert ZeroValue();

        providers[provider] = OracleProvider(
            providerList.length, 
            blockNum, 
            timestamp, 
            0, 
            0, 
            false
        );
        providerInfo[provider] = Info(
            paymentTokenAddress, 
            paymentAmtPerFeed, 
            blockCountPerFeed, 
            feedSize, 
            whitelistedIPAddr
        );
        providerTracker[provider] = Tracker(
            timestamp, 
            block.number, 
            block.number, 
            0, 
            0
        );
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
        if (
            providers[provider].activatedTimestamp == 0 || 
            (providers[provider].disabledOnBlockId > 0 && 
            providers[provider].disabledTimestamp > 0)
        )
            revert InvalidProvider(provider);

        if (paymentTokenAddress == address(0))
            revert ZeroAddress();
        if (paymentAmtPerFeed == 0)
            revert ZeroValue();
        if (blockCountPerFeed == 0)
            revert ZeroValue();
        if (feedSize == 0)
            revert ZeroValue();

        providerInfo[provider].paymentTokenAddress = paymentTokenAddress;
        providerInfo[provider].paymentAmtPerFeed = paymentAmtPerFeed;
        providerInfo[provider].blockCountPerFeed = blockCountPerFeed;
        providerInfo[provider].feedSize = feedSize;
        providerInfo[provider].whitelistedIPAddr = whitelistedIPAddr;

        emit ConfigProvider(
            provider, 
            paymentTokenAddress, 
            paymentAmtPerFeed, 
            blockCountPerFeed, 
            feedSize, 
            whitelistedIPAddr
        );
    }

    /// @dev Upon unpause operation, the unpaused provider's tracker is reset.
    /// Take note osPayment amount is not cleared during reset.
    function resetProviderTracker(address _provider) public onlyRole(MAINTAINER_ROLE) {
        OracleProvider storage prv = providers[_provider];
        if (prv.activatedTimestamp == 0 || 
            prv.disabledOnBlockId > 0 || 
            prv.paused
        )
            revert InvalidProvider(_provider);

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
        if (providers[_provider].paused || 
            providers[_provider].activatedTimestamp == 0
        )
            revert InvalidProvider(_provider);
        
        providers[_provider].paused = true;
        emit PausedProvider(_provider);
    }

    function unpauseProvider(address _provider) external onlyRole(MAINTAINER_ROLE) {
        if (
            !providers[_provider].paused ||
            providers[_provider].activatedTimestamp == 0
        )
            revert InvalidProvider(_provider);

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
        if (_blockNum == 0)
            revert ZeroValue();
        if (_timestamp == 0)
            revert ZeroValue();
        if (providers[_provider].activatedTimestamp == 0 ||
            providers[_provider].disabledOnBlockId > 0 ||
            providers[_provider].disabledTimestamp > 0
        )
            revert InvalidProvider(_provider);

        providers[_provider].disabledOnBlockId = _blockNum;
        providers[_provider].disabledTimestamp = _timestamp;

        emit DisabledProvider(_provider, _blockNum, _timestamp);
    }

    function withdrawPayment(address _withdrawToAddr) external onlyRole(PAYMENT_ROLE) {
        address _provider = msg.sender;
        OracleProvider memory prv = providers[_provider];

        if (block.timestamp <= prv.activatedTimestamp ||
            prv.disabledOnBlockId > 0 ||
            prv.disabledTimestamp > 0
        )
            revert InvalidProvider(_provider);

        if (providerTracker[_provider].osPayment == 0)
            revert ZeroOutstandingAmount();

        // provider gives up payment
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
            emit WithdrewPayment(_provider, providerTracker[_provider].osPayment);
            uint256 osAmt = providerTracker[_provider].osPayment;
            providerTracker[_provider].osPayment = 0;
            providerTracker[_provider].lastPaymentBlockId = block.number;
            SafeERC20.safeTransfer(
                IERC20(providerInfo[_provider].paymentTokenAddress), 
                _withdrawToAddr, 
                osAmt
            );
        } else {
            revert InsufficientBalance(providerTracker[_provider].osPayment);
        }
    }

    /**
     * @dev scheduler execution - submit accumulated feed count each 24H (or more frequent, e.g. every hour)
     */ 
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

        uint256 amtToPay;
        uint256 timeSpanSinceLastUpdated;
        for (uint256 i; i < 10; i++) {
            if (_providerList[i] == address(0))
                break;

            prv = providers[_providerList[i]];
            if (_timestamp > prv.activatedTimestamp && prv.disabledOnBlockId == 0 && !prv.paused) {
                info = providerInfo[_providerList[i]];
                tracker = providerTracker[_providerList[i]];

                amtToPay = 0;
                (, timeSpanSinceLastUpdated) = Math.trySub(_timestamp, tracker.lastUpdatedTimestamp);
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
