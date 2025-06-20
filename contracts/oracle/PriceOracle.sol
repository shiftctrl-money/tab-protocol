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

    // key: keccak256("RESERVE/TAB"), e.g. keccak256("cbBTC/sTRY") or keccak256("BTC/sUSD") 
    mapping(bytes32 => PricePair) public pricePairs; 
    mapping(address => string) public reserveSymbols; // store reserve contract's ERC20.symbol() result

    // EIP712
    mapping(address => uint256) public nonces;
    bytes32 private constant _DATA_TYPEHASH = keccak256("UpdatePriceData(uint256 price,uint256 timestamp,address owner,address updater,address reserve,bytes3 tab,uint256 nonce)");

    // Maintained in PriceOracleManager, duplication for quick access
    uint256 public inactivePeriod; // allowed lastUpdated inactive for X seconds

    // Maintained in TabRegistry
    uint256 public peggedTabCount;
    bytes3[] public peggedTabList;
    mapping(bytes3 => bytes3) public peggedTabMap; // e.g. XXX pegged to USD
    mapping(bytes3 => uint256) public peggedTabPriceRatio;

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

    /// @dev Pause price update from function `updatePrice` and `setDirectPrice`.
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
     * @dev When reserve contract does not support ERC20.symbol(), set it here manually.
     * @param _reserveAddr Reserve contract address.
     * @param _symbol Reserve symbol.
     */
    function setReserveSymbol(
        address _reserveAddr, 
        string calldata _symbol
    ) 
        external 
        onlyRole(PRICE_ORACLE_MANAGER_ROLE) 
    {
        if (_reserveAddr == address(0))
            revert ZeroValue();
        if (bytes(_symbol).length == 0)
            revert InvalidSymbol(_reserveAddr);
        reserveSymbols[_reserveAddr] = _symbol;
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

        // new pegged tab
        if (peggedTabMap[_ptab] == 0x0) {
            peggedTabCount = peggedTabCount + 1;
            peggedTabList.push(_ptab);
        }
        peggedTabMap[_ptab] = _tab;
        peggedTabPriceRatio[_ptab] = _priceRatio;
    }

    /**
     * @dev Governance set price directly (only on emergency scenario).
     * @param reserve Reserve symbol, e.g. "cbBTC", "BTC"
     * @param tabCode Tab Code.
     * @param price Price rate.
     * @param timestamp Timestamp of rate update.
     */
    function setDirectPrice(
        string calldata reserve,
        bytes3 tabCode, 
        uint256 price, 
        uint256 timestamp
    ) 
        external 
        onlyRole(FEEDER_ROLE) 
    {
        _requireNotPaused();

        if (price == 0)
            revert ZeroPrice();
        
        bytes32 pricePairKey = getPricePairKeyByTab(reserve, tabCode);
        PricePair storage pricePair = pricePairs[pricePairKey];

        if (timestamp <= pricePair.timestamp)
            revert OutdatedPrice(pricePairKey, timestamp);

        emit UpdatedPrice(pricePairKey, pricePair.price, price, timestamp);
        pricePair.price = price;
        pricePair.timestamp = timestamp;
    }

    /**
     * @dev On-demand (passive) tab rate update.
     * When user performs vault operation, the transaction will include 
     * latest rate signed by authorized oracle service.
     * For pegged tab, `priceData.tab` is pegged tab code (e.g. XXX) and 
     * `priceData.price` is the pegged tab rate (BTC/XXX rate).
     * System calc. pegging tab rate and store it.
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
        
        string memory reserveSymbol = _getReserveSymbol(priceData.reserve);
        bytes32 pricePairKey = getPricePairKeyByTab(reserveSymbol, priceData.tab);
        PricePair storage pricePair = pricePairs[pricePairKey];
        
        if (priceData.timestamp > pricePair.timestamp) { 
            if (priceData.price == 0)
                revert ZeroPrice();
            bytes32 structHash = keccak256(abi.encode(
                _DATA_TYPEHASH, 
                priceData.price,
                priceData.timestamp,
                priceData.owner,
                priceData.updater,
                priceData.reserve,
                priceData.tab,
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
                revert ExpiredRate(pricePairKey, block.timestamp, priceData.timestamp, inactivePeriod);
            
            nonces[priceData.updater] += 1;

            // Regular Tab (Non-pegged)
            if (peggedTabMap[priceData.tab] == 0x0) {
                emit UpdatedPrice(
                    pricePairKey, 
                    pricePair.price, 
                    priceData.price, 
                    priceData.timestamp
                );
                if (priceData.price == pricePair.price) {
                    if (priceData.timestamp > pricePair.timestamp)
                        pricePair.timestamp = priceData.timestamp;
                } else {  
                    pricePair.price = priceData.price;
                    pricePair.timestamp = priceData.timestamp;
                }
                return priceData.price;
            } else { // Pegged tab existed, 
                // i.e. when PEG pegged to USD, calc. & update USD rate based on supplied PEG
                bytes3 peggedTab = peggedTabMap[priceData.tab]; // e.g. priceData.tab = XXX, peggedTab = USD
                uint256 peggedTabRate = Math.mulDiv(
                    priceData.price, 
                    100, 
                    peggedTabPriceRatio[priceData.tab]
                ); // e.g. calc. USD rate

                bytes32 peggedPricePairKey = getPricePairKeyByTab(reserveSymbol, peggedTab);
                PricePair storage peggedPricePair = pricePairs[peggedPricePairKey];

                // Pegged Tab, e.g. XXX 
                emit UpdatedPrice(
                    pricePairKey,
                    pricePair.price, 
                    priceData.price, 
                    priceData.timestamp
                );
                pricePair.price = priceData.price;
                pricePair.timestamp = priceData.timestamp;

                // Tab rate, e.g. USD
                emit UpdatedPrice(
                    peggedPricePairKey, 
                    peggedPricePair.price, 
                    peggedTabRate, 
                    priceData.timestamp
                );
                peggedPricePair.price = peggedTabRate;
                peggedPricePair.timestamp = priceData.timestamp;

                return priceData.price;
            }
        } else {
            return _getPrice(pricePairKey);
        }
    }

    /**
     * 
     * @dev Return Tab rate when the rate's last updated timestamp + inactivePeriod is 
     * less than block.timestamp, 
     */
    function getPrice(bytes32 pricePairKey) external view returns (uint256) {
        return _getPrice(pricePairKey);
    }

    /**
     * @dev Get tab rate, ignore last updated timestamp check.
     */
    function getOldPrice(bytes32 pricePairKey) public view returns (uint256) {
        return pricePairs[pricePairKey].price;
    }

    /**
     * @dev Mapping key used for pricePair.
     * @param _reserve Reserve symbol, e.g. "cbBTC", "BTC".
     * @param _tab Tab code.
     */
    function getPricePairKeyByTab(
        string memory _reserve,
        bytes3 _tab
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_reserve, "/s", _tab));  
    }

    /**
     * @dev Get rate without checking timestamp.
     * @param _reserve Reserve symbol, e.g. "cbBTC", "BTC".
     * @param _tab Tab code or pegged tab code.
     */
    function getCalcPrice(string calldata _reserve, bytes3 _tab) external view returns (uint256) {
        if (peggedTabMap[_tab] == 0x0) {
            return getOldPrice(getPricePairKeyByTab(_reserve, _tab));
        } else {
            PricePair memory pricePair = pricePairs[getPricePairKeyByTab(_reserve, _tab)];
            if (pricePair.timestamp > 0) {
                return pricePair.price;
            } else {
                PricePair memory peggedPricePair = pricePairs[getPricePairKeyByTab(_reserve, peggedTabMap[_tab])];
                if (peggedPricePair.price > 0)
                    return Math.mulDiv(peggedPricePair.price, peggedTabPriceRatio[_tab], 100);
                else
                    return 0; // no price available
            }
        }
    }

    /**
     * @dev Get price from pricePairs mapping. Check if the price is expired before returning.
     * @param _pricePairKey Price pair key, e.g. keccak256("cbBTC/sTRY") or keccak256("BTC/sUSD").
     */
    function _getPrice(bytes32 _pricePairKey) internal view returns(uint256) {
        PricePair memory pricePair = pricePairs[_pricePairKey];
        if (block.timestamp > (pricePair.timestamp + inactivePeriod))
            revert ExpiredRate(_pricePairKey, block.timestamp, pricePair.timestamp, inactivePeriod); 
        return pricePair.price;
    }

    /**
     * @dev Get reserve symbol from reserveSymbols mapping or call reserve contract's symbol() function.
     * @param _reserveAddr Reserve contract address.
     * @return symbol Reserve symbol.
     */
    function _getReserveSymbol(address _reserveAddr) internal returns(string memory symbol) {
        symbol = reserveSymbols[_reserveAddr];
        if (bytes(symbol).length > 0)
            return symbol;

        (bool success, bytes memory data) = _reserveAddr.staticcall(abi.encodeWithSignature("symbol()"));
        if (!success)
            revert InvalidSymbol(_reserveAddr);
        symbol = abi.decode(data, (string));
        if (bytes(symbol).length == 0)
            revert InvalidSymbol(_reserveAddr);

        reserveSymbols[_reserveAddr] = abi.decode(data, (string));
    }

}
