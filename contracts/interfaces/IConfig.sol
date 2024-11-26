// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IConfig {

    function treasury() external view returns (address);

    function vaultKeeper() external view returns (address);

    function tabRegistry() external view returns (address);

    function reserveParams(bytes32) external view returns (uint256, uint256, uint256);

    function tabParams(bytes3) external view returns (uint256, uint256);

    function auctionParams() external view returns (uint256, uint256, uint256, address);

    function setVaultKeeperAddress(address _vaultKeeper) external;

    function setReserveParams(
        bytes32[] calldata _reserveKey,
        uint256[] calldata _processFeeRate,
        uint256[] calldata _minReserveRatio,
        uint256[] calldata _liquidationRatio
    )
        external;

    function setDefTabParams(bytes3 _tab) external;

    function setTabParams(
        bytes3[] calldata _tab,
        uint256[] calldata _riskPenaltyPerFrame,
        uint256[] calldata _processFeeRate
    )
        external;

    function setAuctionParams(
        uint256 _auctionStartPriceDiscount,
        uint256 _auctionStepPriceDiscount,
        uint256 _auctionStepDurationInSec,
        address auctionManager
    )
        external;

}
