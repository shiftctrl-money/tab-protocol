// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRules} 
    from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

/**
 * @title Contract to store BTC to Tab rates.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract PriceOracle is IPriceOracle, Pausable, EIP712, AccessControlDefaultAdminRules {
    bytes32 public constant FEEDER_ROLE = keccak256("FEEDER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant TAB_REGISTRY_ROLE = keccak256("TAB_REGISTRY_ROLE");
    bytes32 public constant PRICE_ORACLE_MANAGER_ROLE = keccak256("PRICE_ORACLE_MANAGER_ROLE");

    mapping(bytes3 => uint256) private prices; // 18-decimals, tab code : price (base currency BTC, quote currency TAB)
    mapping(bytes3 => uint256) public lastUpdated;

    // EIP712
    mapping(address => uint256) public nonces;
    bytes32 private constant _DATA_TYPEHASH = keccak256("UpdatePriceData(address owner,address updater,bytes3 tab,uint256 price,uint256 timestamp,uint256 nonce)");

    // Maintain in PriceOracleManager
    uint256 public inactivePeriod; // allowed lastUpdated inactive for X seconds

    // Maintain in TabRegistry
    uint256 public peggedTabCount;
    bytes3[] public peggedTabList;
    mapping(bytes3 => bytes3) public peggedTabMap; // e.g. XXX pegged to USD
    mapping(bytes3 => uint256) public peggedTabPriceRatio;
    // ctrl-alt-del
    mapping(bytes3 => uint256) public ctrlAltDelTab; // >0 when the tab(key) is now set to fixed price

    /**
     * 
     * @param _admin Governance controller.
     * @param _admin2 Emergency governance controller.
     * @param _vaultManager Vault Manager contract.
     * @param _priceOracleManager Price Oracle Manager contract.
     * @param _tabRegistry Tab Registry contract.
     * @param _priceSigner Authorized oracle to sign tab rate.
     */
    constructor(
        address _admin,
        address _admin2,
        address _vaultManager,
        address _priceOracleManager,
        address _tabRegistry,
        address _priceSigner
    )
        EIP712("PriceOracle", "1") 
        AccessControlDefaultAdminRules(1 days, _admin)
    {
        _grantRole(FEEDER_ROLE, _admin);
        _grantRole(FEEDER_ROLE, _admin2);
        _grantRole(FEEDER_ROLE, _vaultManager);

        _grantRole(SIGNER_ROLE, _priceSigner);

        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin2);
        
        _grantRole(PRICE_ORACLE_MANAGER_ROLE, _admin);
        _grantRole(PRICE_ORACLE_MANAGER_ROLE, _admin2);
        _grantRole(PRICE_ORACLE_MANAGER_ROLE, _priceOracleManager);

        _grantRole(TAB_REGISTRY_ROLE, _admin);
        _grantRole(TAB_REGISTRY_ROLE, _admin2);
        _grantRole(TAB_REGISTRY_ROLE, _tabRegistry);
    
        inactivePeriod = 1 hours;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function updateInactivePeriod(
        uint256 _inactivePeriod
    )
        external 
        onlyRole(PRICE_ORACLE_MANAGER_ROLE) 
    {
        if (_inactivePeriod == 0) 
            revert ZeroValue();
        emit UpdatedInactivePeriod(inactivePeriod, _inactivePeriod);
        inactivePeriod = _inactivePeriod;
    }

    /**
     * @dev Triggered by `TabRegistry`. Propagate to call this when creating new pegged tab.
     * @param _ptab Pegged Tab code.
     * @param _tab Pegged to existing Tab.
     * @param _priceRatio Value 100 represents 100% value of the pegged price. 
     * E.g store 50 if ABC is 50% value of USD
     */
    function setPeggedTab(
        bytes3 _ptab, 
        bytes3 _tab, 
        uint256 _priceRatio
    ) 
        external 
        onlyRole(TAB_REGISTRY_ROLE) 
    {
        if (_priceRatio == 0)
            revert ZeroValue();
        uint256 peggedPrice = Math.mulDiv(prices[_tab], _priceRatio, 100);
        if (peggedPrice == 0)
            revert ZeroValue();

        // new pegged tab
        if (peggedTabMap[_ptab] == 0x0) {
            peggedTabCount = peggedTabCount + 1;
            peggedTabList.push(_ptab);
        }
        peggedTabMap[_ptab] = _tab;
        peggedTabPriceRatio[_ptab] = _priceRatio;
    }

    /**
     * @dev Triggered by `TabRegistry`. Propagate to call this to perform Ctrl-Alt-Del.
     * @param _tab Tab code to perform Ctrl-Alt-Del operation.
     * @param fixedPrice BTC to Tab rate to be fixed.
     */
    function ctrlAltDel(
        bytes3 _tab, 
        uint256 fixedPrice
    ) 
        external 
        onlyRole(TAB_REGISTRY_ROLE) 
    {
        emit UpdatedPrice(_tab, prices[_tab], fixedPrice, block.timestamp);
        prices[_tab] = fixedPrice;
        lastUpdated[_tab] = block.timestamp;
        ctrlAltDelTab[_tab] = fixedPrice; // price is fixed at this point
    }

    /**
     * @dev Governance set price directly (only on emergency scenario).
     * @param tabCode Tab Code.
     * @param price BTC/TAB Rate.
     * @param _lastUpdated Timestamp of rate update.
     */
    function setDirectPrice(
        bytes3 tabCode, 
        uint256 price, 
        uint256 _lastUpdated
    ) 
        external 
        onlyRole(FEEDER_ROLE) 
    {
        _requireNotPaused();

        if (price == 0)
            revert ZeroPrice();

        if (_lastUpdated <= lastUpdated[tabCode])
            revert OutdatedPrice(tabCode, _lastUpdated);

        if (ctrlAltDelTab[tabCode] > 0)
            revert PostCtrlAltDelFixedPrice();

        emit UpdatedPrice(tabCode, prices[tabCode], price, _lastUpdated);
        prices[tabCode] = price;
        lastUpdated[tabCode] = _lastUpdated;
    }

    /**
     * @dev On-demand (passive) tab rate update.
     * When user performs vault operation, the transaction will include 
     * latest rate signed by authorized oracle service.
     * @param priceData Signed Tab rate by authorized oracle service.
     */
    function updatePrice(
        UpdatePriceData calldata priceData
    ) 
        external 
        onlyRole(FEEDER_ROLE) 
        returns (uint256) 
    {
        _requireNotPaused();

        // not applicable on ctrl-alt-del tab, returns its fixed rate
        if (ctrlAltDelTab[priceData.tab] > 0)
            return _getPrice(priceData.tab);
        
        if (priceData.timestamp > lastUpdated[priceData.tab]) { 
            if (priceData.price == 0)
                revert ZeroPrice();
            bytes32 structHash = keccak256(abi.encode(
                _DATA_TYPEHASH, 
                priceData.owner,
                priceData.updater,
                priceData.tab,
                priceData.price,
                priceData.timestamp,
                nonces[priceData.updater]
            ));
        
            address signer = ECDSA.recover(
                _hashTypedDataV4(structHash), 
                priceData.v, 
                priceData.r, 
                priceData.s
            );
            if (signer != priceData.owner)
                revert InvalidSignature();
        
            if (!hasRole(SIGNER_ROLE, signer))
                revert InvalidSignerRole();

            if (block.timestamp > (priceData.timestamp + inactivePeriod))
                revert ExpiredRate(block.timestamp, priceData.timestamp, inactivePeriod);
            
            nonces[priceData.updater] += 1;

            // Regular (non-pegged) tab
            if (peggedTabMap[priceData.tab] == 0x0) {
                if (priceData.price == prices[priceData.tab]) {
                    lastUpdated[priceData.tab] = priceData.timestamp;
                    return priceData.price;
                } else {
                    emit UpdatedPrice(
                        priceData.tab, 
                        prices[priceData.tab], 
                        priceData.price, 
                        priceData.timestamp
                    );
                    prices[priceData.tab] = priceData.price;
                    lastUpdated[priceData.tab] = priceData.timestamp;
                    
                    return priceData.price;
                }
            } else { // Pegged tab existed, 
                // i.e. when PEG pegged to USD, calc. & update USD rate based on supplied PEG
                bytes3 peggedTab = peggedTabMap[priceData.tab];
                uint256 peggedTabRate = Math.mulDiv(
                    priceData.price, 
                    100, 
                    peggedTabPriceRatio[priceData.tab]
                );
                if (peggedTabRate == prices[peggedTab])
                    return priceData.price;
                else {
                    emit UpdatedPrice(
                        peggedTab, 
                        prices[peggedTab], 
                        peggedTabRate, 
                        priceData.timestamp
                    );
                    prices[peggedTab] = peggedTabRate;
                    lastUpdated[peggedTab] = priceData.timestamp;
                    
                    return priceData.price;
                }
            }
        } else {
            return _getPrice(priceData.tab);
        }
    }

    /**
     * 
     * @dev Get tab rate. If the rate's lastUpdated + inactivePeriod is 
     * less than block.timestamp, 
     */
    function getPrice(bytes3 _tab) external view returns (uint256) {
        return _getPrice(_tab);
    }

    /**
     * @dev Get tab rate, ignore lastUpdated check.
     */
    function getOldPrice(bytes3 _tab) external view returns (uint256) {
        if (peggedTabMap[_tab] == 0x0) {
            return prices[_tab];
        } else {
            return Math.mulDiv(prices[peggedTabMap[_tab]], peggedTabPriceRatio[_tab], 100);
        }
    }

    function _getPrice(bytes3 _tab) internal view returns(uint256) {
        if (peggedTabMap[_tab] == 0x0) {
            if (block.timestamp > (lastUpdated[_tab] + inactivePeriod))
                revert ExpiredRate(block.timestamp, lastUpdated[_tab], inactivePeriod);
            return prices[_tab];
        } else {
            if (block.timestamp > (lastUpdated[peggedTabMap[_tab]] + inactivePeriod))
                revert ExpiredRate(block.timestamp, lastUpdated[peggedTabMap[_tab]], inactivePeriod);
            return Math.mulDiv(prices[peggedTabMap[_tab]], peggedTabPriceRatio[_tab], 100);
        }
    }

}
