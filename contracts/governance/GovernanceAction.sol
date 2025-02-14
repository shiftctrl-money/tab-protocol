// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} 
    from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IGovernanceAction} from "../interfaces/IGovernanceAction.sol";
import {IConfig} from "../interfaces/IConfig.sol";
import {ITabRegistry} from "../interfaces/ITabRegistry.sol";
import {IReserveRegistry} from "../interfaces/IReserveRegistry.sol";
import {IPriceOracleManager} from "../interfaces/IPriceOracleManager.sol";

/// @dev Utility & entry-point contract to perform governance actions.
contract GovernanceAction is 
    Initializable, 
    AccessControlDefaultAdminRulesUpgradeable, 
    UUPSUpgradeable, 
    IGovernanceAction 
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    address public configAddress;
    address public tabRegistryAddress;
    address public reserveRegistryAddress;
    address public priceOracleManagerAddress;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _governance, 
        address _emergencyGovernance, 
        address _deployer,
        address _upgrader
    ) 
        public 
        initializer 
    {
        __AccessControlDefaultAdminRules_init(1 days, _governance);
        __UUPSUpgradeable_init();
        _grantRole(MAINTAINER_ROLE, _governance);
        _grantRole(MAINTAINER_ROLE, _emergencyGovernance);
        _grantRole(MAINTAINER_ROLE, _deployer);
        
        _grantRole(UPGRADER_ROLE, _upgrader);
    }

    function _authorizeUpgrade(address newImplementation) internal override virtual onlyRole(UPGRADER_ROLE) { }

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
        IPriceOracleManager(priceOracleManagerAddress).setDefBlockGenerationTimeInSecond(sec);
        emit UpdatedDefBlockGenerationTimeInSecond(sec);
    }

    function updateTabParams(
        bytes3[] calldata _tab,
        IConfig.TabParams[] calldata _tabParams
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        IConfig(configAddress).setTabParams(_tab, _tabParams);
        emit UpdatedTabParams(_tab.length);
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
        IConfig(configAddress).setAuctionParams(
            _auctionStartPriceDiscount, _auctionStepPriceDiscount, _auctionStepDurationInSec, _auctionManager
        );
        emit UpdatedAuctionParams(
            _auctionStartPriceDiscount, _auctionStepPriceDiscount, _auctionStepDurationInSec, _auctionManager
        );
    }

    /**
     *
     * @dev When tab is paused, `VaultManager` operations such as create vault,
     * withdraw tab, payback tab, and withdraw reserve will fail.
     * And the frozen tab's vaults will not be charged risk penalty (if any).
     * @param _tab Tab code to be disabled(freezed)
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
        address tabAddr = ITabRegistry(tabRegistryAddress).createTab(_tab);
        emit NewTab(_tab, tabAddr);
        return tabAddr;
    }

    function addReserve(
        address _token,
        address _reserveSafe
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        IReserveRegistry(reserveRegistryAddress).addReserve(_token, _reserveSafe);
        emit AddedReserve(_token, _reserveSafe);
    }

    function disableReserve(address _token) external onlyRole(MAINTAINER_ROLE) {
        IReserveRegistry(reserveRegistryAddress).removeReserve(_token);
        emit RemovedReserve(_token);
    }

    /**
     *
     * @param provider Wallet address of the new provider.
     * @param paymentTokenAddress Payment token address.
     * @param paymentAmtPerFeed Unit price of each feed.
     * @param blockCountPerFeed Assume 5-min feed interval and 2s block gen. time
     * Each feed is expected to arrive within 60/2 * 5 = 150 blocks.
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

    /**
     * @dev `ProtocolVault` contract must be deployed first. 
     * Grant MINTER_ROLE on the targeted tab to the created `ProtocolVault`.
     * Revoke MINTER_ROLE from `VaultManager`.
     * @param _tab Tab to be depegged.
     * @param _btcTabRate BTC to Tab rate
     */
    function ctrlAltDel(bytes3 _tab, uint256 _btcTabRate) external onlyRole(MAINTAINER_ROLE) {
        ITabRegistry(tabRegistryAddress).ctrlAltDel(_tab, _btcTabRate);
        emit CtrlAltDelTab(_tab, _btcTabRate);
    }

}
