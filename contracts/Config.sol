// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";
import "./shared/interfaces/IVaultKeeper.sol";

/**
 * @title  Store and manage protocol-related configurations and parameters.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract Config is AccessControlDefaultAdminRules {

    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    struct ReserveParams {
        uint256 processFeeRate; // default 0, put 1 for 0.01%, e.g. withdraw reserve, add fee as tab OS
        uint256 minReserveRatio; // default 180
        uint256 liquidationRatio; // default 120
    }

    struct TabParams {
        uint256 riskPenaltyPerFrame; // default 150 for 1.5% for 1 frame = 24 hours, penalty_amt = delta *
            // riskPenaltyPerFrame
        uint256 processFeeRate; // default 0, put 1 for 0.01% to withdraw & mint more tab, add fee as tab OS
    }

    struct AuctionParams {
        uint256 auctionStartPriceDiscount;
        uint256 auctionStepPriceDiscount;
        uint256 auctionStepDurationInSec;
        address auctionManager;
    }

    address public treasury; // storing risk penalty charged on vaults
    address public vaultKeeper;
    address public tabRegistry;
    AuctionParams public auctionParams;
    mapping(bytes32 => ReserveParams) public reserveParams; // reserve key : ReserveParams
    mapping(bytes3 => TabParams) public tabParams; // tab : TabParams

    event UpdatedReserveParams(
        bytes32[] reserveKey, uint256[] processFeeRate, uint256[] minReserveRatio, uint256[] liquidationRatio
    );
    event UpdatedTabParams(bytes3[] tab, uint256[] riskPenaltyPerFrame, uint256[] processFeeRate);
    event UpdatedAuctionParams(
        uint256 auctionStartPriceDiscount,
        uint256 auctionStepPriceDiscount,
        uint256 auctionStepDurationInSec,
        address auctionManager
    );
    event DefaultTabParams(bytes3 tab, uint256 riskPenaltyPerFrame, uint256 processFeeRate);
    event UpdatedVaultKeeperAddress(address b4, address _after);

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
        _grantRole(MAINTAINER_ROLE, _tabRegistry);
        treasury = _treasury;
        tabRegistry = _tabRegistry;
        // Default settings
        reserveParams[0x00] = ReserveParams(0, 180, 120);
        tabParams[0x00] = TabParams(150, 0);
        // Auction params
        auctionParams.auctionStartPriceDiscount = 90; // 10% discount on market price when auction is started
        auctionParams.auctionStepPriceDiscount = 97; // 3% discount on offer price when dutch auction starts new round
        auctionParams.auctionStepDurationInSec = 60; // 60 seconds to pass before auction starts new round
        auctionParams.auctionManager = _auctionManager;
    }

    function setVaultKeeperAddress(address _vaultKeeper) external onlyRole(MAINTAINER_ROLE) {
        require(_vaultKeeper != address(0), "INVALID_ADDR");
        emit UpdatedVaultKeeperAddress(vaultKeeper, _vaultKeeper);
        vaultKeeper = _vaultKeeper;
    }

    function setReserveParams(
        bytes32[] calldata _reserveKey,
        uint256[] calldata _processFeeRate,
        uint256[] calldata _minReserveRatio,
        uint256[] calldata _liquidationRatio
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        require(
            _reserveKey.length == _processFeeRate.length && _reserveKey.length == _minReserveRatio.length
                && _reserveKey.length == _liquidationRatio.length,
            "INVALID_LENGTH"
        );
        for (uint256 i = 0; i < _reserveKey.length; i = unsafe_inc(i)) {
            require(_minReserveRatio[i] > 100, "INVALID_MIN_RESERVE_RATIO");
            require(_liquidationRatio[i] > 100, "INVALID_LIQUIDATION_RATIO");

            reserveParams[_reserveKey[i]].processFeeRate = _processFeeRate[i];
            reserveParams[_reserveKey[i]].minReserveRatio = _minReserveRatio[i];
            reserveParams[_reserveKey[i]].liquidationRatio = _liquidationRatio[i];
        }
        emit UpdatedReserveParams(_reserveKey, _processFeeRate, _minReserveRatio, _liquidationRatio);
        IVaultKeeper(vaultKeeper).setReserveParams(_reserveKey, _minReserveRatio, _liquidationRatio);
    }

    function setDefTabParams(bytes3 _tab) external onlyRole(MAINTAINER_ROLE) {
        require(tabParams[_tab].riskPenaltyPerFrame == 0 && tabParams[_tab].processFeeRate == 0, "EXISTED_TAB_PARAMS");
        tabParams[_tab] = TabParams(tabParams[0x00].riskPenaltyPerFrame, tabParams[0x00].processFeeRate);

        bytes3[] memory tabList = new bytes3[](1);
        tabList[0] = _tab;
        uint256[] memory riskPenaltyPerFrameList = new uint256[](1);
        riskPenaltyPerFrameList[0] = tabParams[0x00].riskPenaltyPerFrame;
        IVaultKeeper(vaultKeeper).setTabParams(tabList, riskPenaltyPerFrameList);

        emit DefaultTabParams(_tab, tabParams[0x00].riskPenaltyPerFrame, tabParams[0x00].processFeeRate);
    }

    function setTabParams(
        bytes3[] calldata _tab,
        uint256[] calldata _riskPenaltyPerFrame,
        uint256[] calldata _processFeeRate
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        require(_tab.length == _riskPenaltyPerFrame.length && _tab.length == _processFeeRate.length, "INVALID_LENGTH");
        for (uint256 i = 0; i < _tab.length; i = unsafe_inc(i)) {
            require(_riskPenaltyPerFrame[i] > 0, "INVALID_RP_PER_FRAME");

            tabParams[_tab[i]].riskPenaltyPerFrame = _riskPenaltyPerFrame[i];
            tabParams[_tab[i]].processFeeRate = _processFeeRate[i];
        }
        emit UpdatedTabParams(_tab, _riskPenaltyPerFrame, _processFeeRate);
        IVaultKeeper(vaultKeeper).setTabParams(_tab, _riskPenaltyPerFrame);
    }

    function setAuctionParams(
        uint256 _auctionStartPriceDiscount,
        uint256 _auctionStepPriceDiscount,
        uint256 _auctionStepDurationInSec,
        address _auctionManager
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        require(_auctionStartPriceDiscount > 0, "INVALID_STR_PRICE_DISCOUNT");
        require(_auctionStepPriceDiscount > 0, "INVALID_STP_PRICE_DISCOUNT");
        require(_auctionStepDurationInSec > 0, "INVALID_STP_DURATION");
        require(_auctionManager != address(0), "INVALID_AUCTION_ADDR");

        auctionParams.auctionStartPriceDiscount = _auctionStartPriceDiscount;
        auctionParams.auctionStepPriceDiscount = _auctionStepPriceDiscount;
        auctionParams.auctionStepDurationInSec = _auctionStepDurationInSec;
        auctionParams.auctionManager = _auctionManager;
        emit UpdatedAuctionParams(
            _auctionStartPriceDiscount, _auctionStepPriceDiscount, _auctionStepDurationInSec, _auctionManager
        );
    }

    function unsafe_inc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

}
