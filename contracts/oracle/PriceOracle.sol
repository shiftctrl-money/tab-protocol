// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./interfaces/IPriceOracle.sol";
import "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";

/**
 * @title Contract to store BTC to Tab rates.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract PriceOracle is IPriceOracle, Pausable, EIP712, AccessControlDefaultAdminRules {

    bytes32 public constant FEEDER_ROLE = keccak256("FEEDER_ROLE");
    bytes32 public constant TAB_REGISTRY_ROLE = keccak256("TAB_REGISTRY_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(bytes3 => uint256) private prices; // 18-decimals, tab code : price (base currency BTC, quote currency TAB)
    mapping(bytes3 => uint256) public lastUpdated;

    // EIP712
    mapping(address => uint256) public nonces;
    bytes32 private constant _DATA_TYPEHASH = keccak256("UpdatePriceData(address owner,address updater,bytes3 tab,uint256 price,uint256 timestamp,uint256 nonce)");

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
        address _admin2,
        address _vaultManager,
        address _priceOracleManager,
        address _tabRegistry,
        address _authorizedCaller
    )
        EIP712("PriceOracle", "1") 
        AccessControlDefaultAdminRules(1 days, _admin)
    {
        _grantRole(FEEDER_ROLE, _admin);
        _grantRole(FEEDER_ROLE, _admin2);
        _grantRole(FEEDER_ROLE, _priceOracleManager);
        _grantRole(FEEDER_ROLE, _vaultManager);
        _grantRole(FEEDER_ROLE, _authorizedCaller);

        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin2);

        _grantRole(TAB_REGISTRY_ROLE, _tabRegistry);
        inactivePeriod = 1 hours;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Called by governance when external authorized oracle providers are down.
     * @param tabCode Tab Code.
     * @param price BTC/TAB Rate.
     * @param _lastUpdated timestamp of rate update.
     */
    function setDirectPrice(bytes3 tabCode, uint256 price, uint256 _lastUpdated) external onlyRole(FEEDER_ROLE) {
        _requireNotPaused();

        if (_lastUpdated <= lastUpdated[tabCode]) {
            revert OutdatedPrice(tabCode, _lastUpdated);
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
     * @dev Batch update of Tab rates from PriceOracleManager. 
     *      Obsolete and operation is replaced by `updatePrice` function.
     * @param _tabs List of tab codes.
     * @param _prices List of tab rates (BTC/TAB price).
     * @param _lastUpdated List of last updated timestamp value.
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

    /**
     * @dev Replace batch update of tab rate with on-demand tab rate update. 
     *      When user performs vault operation, the transaction will include 
     *      latest rate signed by authorized oracle service.
     * @param priceData Signed Tab rate by authorized oracle service.
     */
    function updatePrice(UpdatePriceData calldata priceData) external onlyRole(FEEDER_ROLE) returns (uint256) {
        _requireNotPaused();
        if (ctrlAltDelTab[priceData.tab] > 0) {
            return _getPrice(priceData.tab);
        }
        
        if (priceData.timestamp > lastUpdated[priceData.tab]) { 
            require(priceData.price > 0, "INVALID_PRICE");
            bytes32 structHash = keccak256(abi.encode(
                _DATA_TYPEHASH, 
                priceData.owner,
                priceData.updater,
                priceData.tab,
                priceData.price,
                priceData.timestamp,
                nonces[priceData.updater]
            ));            
            address signer = ECDSA.recover(_hashTypedDataV4(structHash), priceData.v, priceData.r, priceData.s);

            require(signer == priceData.owner, "INVALID_SIGNATURE"); // signed by authorized price provider
            require(hasRole(FEEDER_ROLE, signer), "INVALID_ROLE");
            require(block.timestamp <= (priceData.timestamp + inactivePeriod), "EXPIRED");
            
            nonces[priceData.updater] += 1;

            if (peggedTabMap[priceData.tab] == 0x0) {
                if (priceData.price == prices[priceData.tab])
                    return priceData.price;
                else {
                    emit UpdatedPrice(priceData.tab, prices[priceData.tab], priceData.price, priceData.timestamp);
                    prices[priceData.tab] = priceData.price;
                    lastUpdated[priceData.tab] = priceData.timestamp;
                    
                    return priceData.price;
                }
            } else { // update pegged price's tab based on oracle pegged rate
                bytes3 peggedTab = peggedTabMap[priceData.tab];
                uint256 peggedTabRate = FixedPointMathLib.mulDiv(priceData.price, 100, peggedTabPriceRatio[priceData.tab]);
                if (peggedTabRate == prices[peggedTab])
                    return priceData.price;
                else {
                    emit UpdatedPrice(peggedTab, prices[peggedTab], peggedTabRate, priceData.timestamp);
                    prices[peggedTab] = peggedTabRate;
                    lastUpdated[peggedTab] = priceData.timestamp;
                    
                    return priceData.price;
                }
            }
        } else {
            return _getPrice(priceData.tab);
        }
    }

    function _getPrice(bytes3 _tab) internal view returns(uint256) {
        if (peggedTabMap[_tab] == 0x0) {
            require(lastUpdated[_tab] + inactivePeriod > block.timestamp, "INACTIVE");
            return prices[_tab];
        } else {
            require(lastUpdated[peggedTabMap[_tab]] + inactivePeriod > block.timestamp, "INACTIVE");
            return FixedPointMathLib.mulDiv(prices[peggedTabMap[_tab]], peggedTabPriceRatio[_tab], 100);
        }
    }

    function getPrice(bytes3 _tab) external view returns (uint256) {
        return _getPrice(_tab);
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
