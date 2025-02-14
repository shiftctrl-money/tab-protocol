// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPriceOracle {
    struct UpdatePriceData {
        address owner;      // signer
        address updater;    // user (vault owner) address
        bytes3 tab;
        uint256 price;
        uint256 timestamp;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    function nonces(address) external view returns (uint256);
    function pause() external;
    function unpause() external;
    function updateInactivePeriod(uint256 _inactivePeriod) external;
    function setPeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio) external;
    function ctrlAltDel(bytes3 _tab, uint256 fixedPrice) external;
    function setDirectPrice(bytes3 tabCode, uint256 price, uint256 _lastUpdated) external;
    function updatePrice(UpdatePriceData calldata priceData) external returns (uint256);
    function getPrice(bytes3) external view returns (uint256);
    function getOldPrice(bytes3 _tab) external view returns (uint256);
    
    event UpdatedInactivePeriod(uint256 b4, uint256 _after);
    event UpdatedPrice(bytes3 indexed _tab, uint256 _oldPrice, uint256 _newPrice, uint256 _timestamp);

    error ZeroValue();
    error ZeroPrice();
    error OutdatedPrice(bytes3 _tab, uint256 updating);
    error InvalidSignature();
    error InvalidSignerRole();
    error ExpiredRate(uint256 currentTimestamp, uint256 rateTimestamp, uint256 inactivePeriod);
    error PostCtrlAltDelFixedPrice();

}
