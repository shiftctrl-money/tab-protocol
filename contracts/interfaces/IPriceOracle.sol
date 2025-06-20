// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPriceOracle {
    struct PricePair{
        uint256 price;
        uint256 timestamp;
    }
    struct UpdatePriceData {
        uint256 price;
        uint256 timestamp;
        address owner;   // signer
        address updater; // user (vault owner) address
        address reserve; // reserve contract address
        bytes3 tab;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    function nonces(address) external view returns (uint256);
    function pause() external;
    function unpause() external;
    function updateInactivePeriod(uint256 _inactivePeriod) external;
    function setReserveSymbol(address _reserveAddr, string calldata _symbol) external;
    function setPeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio) external;
    function setDirectPrice(string calldata reserve, bytes3 tabCode, uint256 price, uint256 timestamp) external;
    function updatePrice(UpdatePriceData calldata priceData) external returns (uint256);
    function getPrice(bytes32 pricePairKey) external view returns (uint256);
    function getOldPrice(bytes32 pricePairKey) external view returns (uint256);
    function getPricePairKeyByTab(string calldata _reserve, bytes3 _tab) external pure returns (bytes32);
    function getCalcPrice(string calldata _reserve, bytes3 _tab) external view returns (uint256);
    
    event UpdatedInactivePeriod(uint256 b4, uint256 _after);
    event UpdatedPrice(bytes32 pricePairKey, uint256 oldPrice, uint256 newPrice, uint256 timestamp);

    error ZeroValue();
    error ZeroPrice();
    error InvalidSymbol(address reserve);
    error OutdatedPrice(bytes32 pricePairKey, uint256 updatingTimestamp);
    error InvalidSignature();
    error InvalidSignerRole();
    error ExpiredRate(bytes32 pricePairKey, uint256 currentTimestamp, uint256 rateTimestamp, uint256 inactivePeriod);

}
