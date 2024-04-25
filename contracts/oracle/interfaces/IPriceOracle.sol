// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPriceOracle {

    function getPrice(bytes3) external view returns (uint256);

    function getOldPrice(bytes3 _tab) external view returns (uint256);

    function setPrice(bytes3[] calldata _tabs, uint256[] calldata _prices, uint256[] calldata _lastUpdated) external;

    function setDirectPrice(bytes3 tabCode, uint256 price, uint256 _lastUpdated) external;

    function updateInactivePeriod(uint256 _inactivePeriod) external;

    function setPeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio) external;

    function ctrlAltDel(bytes3 _tab, uint256 fixedPrice) external;

    event UpdatedPrice(bytes3 indexed _tab, uint256 _oldPrice, uint256 _newPrice, uint256 _timestamp);

    event UpdatedInactivePeriod(uint256 b4, uint256 _after);

    error OutdatedPrice(uint256 updating);

    error PostCtrlAltDelFixedPrice();

}
