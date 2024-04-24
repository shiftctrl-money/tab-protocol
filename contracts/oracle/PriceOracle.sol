// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IPriceOracle.sol";
import "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";

contract PriceOracle is IPriceOracle, Pausable, AccessControlDefaultAdminRules {

    bytes32 public constant FEEDER_ROLE = keccak256("FEEDER_ROLE");
    bytes32 public constant TAB_REGISTRY_ROLE = keccak256("TAB_REGISTRY_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    mapping(bytes3 => uint256) private prices; // 18-decimals, tab code : price (base currency BTC, quote currency TAB)
    mapping(bytes3 => uint256) public lastUpdated;

    // ctrl-alt-del
    mapping(bytes3 => uint256) public ctrlAltDelTab; // >0 when the tab(key) is now set to fixed price

    // set value in PriceOracleManager
    uint256 public inactivePeriod; // allowed lastUpdated inactive for X seconds

    // set value in TabRegistry
    uint256 public peggedTabCount;
    bytes3[] public peggedTabList;
    mapping(bytes3 => bytes3) public peggedTabMap; // e.g. XXX pegged to USD
    mapping(bytes3 => uint256) public peggedTabPriceRatio;

    constructor(
        address _admin,
        address _vaultManager,
        address _priceOracleManager,
        address _tabRegistry
    )
        AccessControlDefaultAdminRules(1 days, _admin)
    {
        _grantRole(FEEDER_ROLE, _admin); // governance may step in to update price if really needed
        _grantRole(FEEDER_ROLE, _priceOracleManager);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(USER_ROLE, _vaultManager);
        _grantRole(TAB_REGISTRY_ROLE, _tabRegistry);
        inactivePeriod = 1 hours;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setDirectPrice(bytes3 tabCode, uint256 price, uint256 _lastUpdated) external onlyRole(FEEDER_ROLE) {
        _requireNotPaused();

        if (_lastUpdated <= lastUpdated[tabCode]) {
            revert OutdatedPrice(_lastUpdated);
        }

        if (ctrlAltDelTab[tabCode] > 0) {
            revert PostCtrlAltDelFixedPrice();
        }

        emit UpdatedPrice(tabCode, prices[tabCode], price, _lastUpdated);
        prices[tabCode] = price;
        lastUpdated[tabCode] = _lastUpdated;
    }

    /**
     *
     * @param _tabs list of tab codes
     * @param _prices list of tab prices (BTC/TAB price)
     * @param _lastUpdated list of timestamp value
     */
    function setPrice(
        bytes3[] calldata _tabs,
        uint256[] calldata _prices,
        uint256[] calldata _lastUpdated
    )
        external
        onlyRole(FEEDER_ROLE)
    {
        _requireNotPaused();

        uint256 count = _tabs.length;
        bytes3 _tab;
        require(count == _prices.length && count == _lastUpdated.length, "UnmatchedLength");

        for (uint256 i = 0; i < count; i = unsafe_inc(i)) {
            _tab = _tabs[i];

            if (
                _tab == 0x0 // empty placeholder from the list
            ) {
                break;
            }

            if (ctrlAltDelTab[_tab] > 0) {
                revert PostCtrlAltDelFixedPrice();
            }

            emit UpdatedPrice(_tab, prices[_tab], _prices[i], _lastUpdated[i]);
            prices[_tab] = _prices[i];
            lastUpdated[_tab] = _lastUpdated[i];
        }
    }

    function getPrice(bytes3 _tab) external view onlyRole(USER_ROLE) returns (uint256) {
        if (peggedTabMap[_tab] == 0x0) {
            require(lastUpdated[_tab] + inactivePeriod > block.timestamp, "INACTIVE");
            return prices[_tab];
        } else {
            require(lastUpdated[peggedTabMap[_tab]] + inactivePeriod > block.timestamp, "INACTIVE");
            return FixedPointMathLib.mulDiv(prices[peggedTabMap[_tab]], peggedTabPriceRatio[_tab], 100);
        }
    }

    function getOldPrice(bytes3 _tab) external view returns (uint256) {
        if (peggedTabMap[_tab] == 0x0) {
            return prices[_tab];
        } else {
            return FixedPointMathLib.mulDiv(prices[peggedTabMap[_tab]], peggedTabPriceRatio[_tab], 100);
        }
    }

    function updateInactivePeriod(uint256 _inactivePeriod) external onlyRole(FEEDER_ROLE) {
        require(_inactivePeriod > 0, "INVALID_INACTIVE_PERIOD");
        emit UpdatedInactivePeriod(inactivePeriod, _inactivePeriod);
        inactivePeriod = _inactivePeriod;
    }

    function setPeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio) external onlyRole(TAB_REGISTRY_ROLE) {
        // validate _priceRatio
        uint256 peggedPrice = FixedPointMathLib.mulDiv(prices[_tab], _priceRatio, 100);
        require(peggedPrice > 0, "INVALID_PRICE_RATIO");

        if (peggedTabMap[_ptab] == 0x0) {
            // new pegged tab
            peggedTabCount = peggedTabCount + 1;
            peggedTabList.push(_ptab);
        }
        peggedTabMap[_ptab] = _tab;
        peggedTabPriceRatio[_ptab] = _priceRatio;
    }

    function ctrlAltDel(bytes3 _tab, uint256 fixedPrice) external onlyRole(TAB_REGISTRY_ROLE) {
        emit UpdatedPrice(_tab, prices[_tab], fixedPrice, block.timestamp);

        prices[_tab] = fixedPrice;
        lastUpdated[_tab] = block.timestamp;
        ctrlAltDelTab[_tab] = fixedPrice; // price is fixed at this point
    }

    function unsafe_inc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

}
