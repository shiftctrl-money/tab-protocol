// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRules} 
    from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {IVaultKeeper} from "../interfaces/IVaultKeeper.sol";
import {IConfig} from "../interfaces/IConfig.sol";

/**
 * @title Manage protocol configurations and parameters.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract Config is IConfig, AccessControlDefaultAdminRules {
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant DEF_TAB_KEY = keccak256(abi.encodePacked(bytes3(0x0)));

    address public treasury; // storing risk penalty charged on vaults
    address public vaultKeeper;

    mapping(bytes32 => TabParams) public tabParams; // tab : TabParams
    AuctionParams public auctionParams;

    constructor(
        address _admin,
        address _admin2,
        address _governanceAction,
        address _deployer,
        address _treasury,
        address _tabRegistry,
        address _auctionManager
    )
        AccessControlDefaultAdminRules(1 days, _admin)
    {
        _grantRole(MAINTAINER_ROLE, _admin);
        _grantRole(MAINTAINER_ROLE, _admin2);
        _grantRole(MAINTAINER_ROLE, _governanceAction);
        _grantRole(MAINTAINER_ROLE, _deployer);
        // set default config when creating new Tab
        _grantRole(MAINTAINER_ROLE, _tabRegistry); 

        // Default settings
        tabParams[DEF_TAB_KEY] = TabParams(150, 0, 180, 120);
        
        // Auction params
        // 10% discount on market price when auction is started
        auctionParams.auctionStartPriceDiscount = 90;
        // 3% discount on offer price when dutch auction starts new round 
        auctionParams.auctionStepPriceDiscount = 97; 
        // 60 seconds to pass before auction starts new round
        auctionParams.auctionStepDurationInSec = 60; 
        auctionParams.auctionManager = _auctionManager;

        treasury = _treasury;
    }

    /**
     * @dev `VaultKeeper` contract address is maintained here to sync. configuration
     * values into vault keeper.
     * @param _vaultKeeper Vault keeper contract address.
     */
    function setVaultKeeperAddress(address _vaultKeeper) external onlyRole(MAINTAINER_ROLE) {
        if (_vaultKeeper == address(0))
            revert ZeroAddress();
        if (_vaultKeeper.code.length == 0)
            revert InvalidContractAddress();
        emit UpdatedVaultKeeperAddress(vaultKeeper, _vaultKeeper);
        vaultKeeper = _vaultKeeper;
    }

    /**
     * @dev Protocol owned address used to store protocol's funds.
     * @param _treasury Smart contract or EOA, governed by governance controller.
     */
    function setTreasuryAddress(address _treasury) external onlyRole(MAINTAINER_ROLE) {
        if (_treasury == address(0))
            revert ZeroAddress();
        emit UpdatedTreasuryAddress(treasury, _treasury);
        treasury = _treasury;
    }

    /**
     * @dev Triggered by `TabRegistry` contract when creating new Tab.
     * Propagate values to `VaultKeeper`.
     * @param _tab New tab code to set default configuration values.
     */
    function setDefTabParams(bytes3 _tab) external onlyRole(MAINTAINER_ROLE) {
        // save tab prams locally
        tabParams[tabCodeToTabKey(_tab)] = TabParams(
            tabParams[DEF_TAB_KEY].riskPenaltyPerFrame, 
            tabParams[DEF_TAB_KEY].processFeeRate,
            tabParams[DEF_TAB_KEY].minReserveRatio,
            tabParams[DEF_TAB_KEY].liquidationRatio
        );
        
        // set same set of default values into VaultKeeper
        bytes3[] memory tabList = new bytes3[](1);
        tabList[0] = _tab;
        TabParams[] memory tabParamList = new TabParams[](1);
        tabParamList[0].riskPenaltyPerFrame  = tabParams[DEF_TAB_KEY].riskPenaltyPerFrame;
        tabParamList[0].processFeeRate  = tabParams[DEF_TAB_KEY].processFeeRate;
        tabParamList[0].minReserveRatio  = tabParams[DEF_TAB_KEY].minReserveRatio;
        tabParamList[0].liquidationRatio  = tabParams[DEF_TAB_KEY].liquidationRatio;
        IVaultKeeper(vaultKeeper).setTabParams(tabList, tabParamList);
        
        emit DefaultTabParams(
            _tab, 
            tabParams[DEF_TAB_KEY].riskPenaltyPerFrame, 
            tabParams[DEF_TAB_KEY].processFeeRate,
            tabParams[DEF_TAB_KEY].minReserveRatio,
            tabParams[DEF_TAB_KEY].liquidationRatio
        );
    }

    function getTabParams(bytes3 _tab) external view returns(TabParams memory) {
        return tabParams[tabCodeToTabKey(_tab)];
    }

    function getAuctionParams() external view returns(AuctionParams memory) {
        return auctionParams;
    }

    /**
     * @dev Tab is set to default values unless overwritten by calling this.
     * @param _tab Tab code in bytes3 form.
     * @param _tabParams Configuration values assigned to specified Tab.
     */
    function setTabParams(
        bytes3[] calldata _tab,
        TabParams[] calldata _tabParams
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        if (_tab.length != _tabParams.length)
            revert InvalidArrayLength();
        
        bytes32 tabKey;
        for (uint256 i; i < _tab.length; i++) {
            tabKey = tabCodeToTabKey(_tab[i]);
            tabParams[tabKey].riskPenaltyPerFrame = _tabParams[i].riskPenaltyPerFrame;
            tabParams[tabKey].processFeeRate = _tabParams[i].processFeeRate;
            tabParams[tabKey].minReserveRatio = _tabParams[i].minReserveRatio;
            tabParams[tabKey].liquidationRatio = _tabParams[i].liquidationRatio;
            emit UpdatedTabParams(
                _tab[i], 
                _tabParams[i].riskPenaltyPerFrame, 
                _tabParams[i].processFeeRate,
                _tabParams[i].minReserveRatio,
                _tabParams[i].liquidationRatio
            );
        }
        IVaultKeeper(vaultKeeper).setTabParams(_tab, _tabParams);
    }

    /**
     * @dev Specify auction-related configurations.
     * @param _auctionStartPriceDiscount Discount applied to market price.
     * @param _auctionStepPriceDiscount Discount applied on each auction step.
     * @param _auctionStepDurationInSec Duration in second of each auction step.
     * @param _auctionManager Protocol auction manager contract.
     */
    function setAuctionParams(
        uint256 _auctionStartPriceDiscount,
        uint256 _auctionStepPriceDiscount,
        uint256 _auctionStepDurationInSec,
        address _auctionManager
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        if (_auctionStartPriceDiscount == 0 ||
            _auctionStepPriceDiscount == 0 ||
            _auctionStepDurationInSec == 0
        ) {
            revert ZeroValue();
        }
        if (_auctionManager == address(0))
            revert ZeroAddress();
        if (_auctionManager.code.length == 0)
            revert InvalidContractAddress();

        auctionParams.auctionStartPriceDiscount = _auctionStartPriceDiscount;
        auctionParams.auctionStepPriceDiscount = _auctionStepPriceDiscount;
        auctionParams.auctionStepDurationInSec = _auctionStepDurationInSec;
        auctionParams.auctionManager = _auctionManager;
        emit UpdatedAuctionParams(
            _auctionStartPriceDiscount, 
            _auctionStepPriceDiscount, 
            _auctionStepDurationInSec, 
            _auctionManager
        );
    }

    function tabCodeToTabKey(bytes3 code) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(code));
    }
}
