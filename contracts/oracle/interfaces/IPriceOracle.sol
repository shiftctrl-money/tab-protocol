// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IPriceOracle {
    struct UpdatePriceData {
        address owner;      // signer
        address updater;    // user address
        bytes3 tab;
        uint256 price;
        uint256 timestamp;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    function nonces(address) external view returns (uint256);

    function getPrice(bytes3) external view returns (uint256);

    function getOldPrice(bytes3 _tab) external view returns (uint256);

    function setPrice(bytes3[] calldata _tabs, uint256[] calldata _prices, uint256[] calldata _lastUpdated) external;

    function setDirectPrice(bytes3 tabCode, uint256 price, uint256 _lastUpdated) external;

    function updatePrice(UpdatePriceData calldata priceData) external returns (uint256);

    function updateInactivePeriod(uint256 _inactivePeriod) external;

    function setPeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio) external;

    function ctrlAltDel(bytes3 _tab, uint256 fixedPrice) external;

    event UpdatedPrice(bytes3 indexed _tab, uint256 _oldPrice, uint256 _newPrice, uint256 _timestamp);

    event UpdatedInactivePeriod(uint256 b4, uint256 _after);

    error OutdatedPrice(bytes3 _tab, uint256 updating);

    error PostCtrlAltDelFixedPrice();

}
