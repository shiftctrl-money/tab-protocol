// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPriceOracle} from "./IPriceOracle.sol";

interface IVaultManager {
    struct Vault {
        address reserveAddr; // locked reserve address
        uint256 reserveAmt; // BTC quantity in 18 decimals
        address tab; // minted tab currency
        uint256 tabAmt; // tab currency value (18 decimals)
        uint256 osTabAmt; // other O/S tab, e.g. risk penalty or fee amt
        uint256 pendingOsMint; // osTabAmt to be minted out
    }

    struct LiquidatedVault {
        address vaultOwner;
        address auctionAddr;
    }

    function ownerList(uint256) external view returns(address);
    function vaultOwners(address, uint256) external view returns(uint256);
    function getVaults(address, uint256) external view returns(Vault memory);
    function vaultId() external view returns(uint256);
    function getLiquidatedVault(uint256) external view returns(LiquidatedVault memory);

    function configContractAddress(
        address _config,
        address _reserveRegistry,
        address _tabRegistry,
        address _priceOracle,
        address _keeper
    )
        external;

    function getOwnerList() external view returns (address[] memory);

    function getAllVaultIDByOwner(address _owner) external view returns (uint256[] memory);

    function createVault(
        uint256 _reserveAmt, 
        uint256 _tabAmt, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) 
        external;

    function withdrawTab(
        uint256 _vaultId, 
        uint256 _tabAmt, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) 
        external;

    function paybackTab(
        address _vaultOwner,
        uint256 _vaultId, 
        uint256 _tabAmt
    ) 
        external;

    function withdrawReserve(
        uint256 _vaultId, 
        uint256 _reserveAmt, 
        IPriceOracle.UpdatePriceData calldata sigPrice
    ) 
        external;

    function depositReserve(
        address _vaultOwner,
        uint256 _vaultId, 
        uint256 _reserveAmt
    )
        external;

    function chargeRiskPenalty(
        address _vaultOwner, 
        uint256 _vaultId, 
        uint256 _amt
    ) 
        external;

    function liquidateVault(
        uint256 _vaultId,
        uint256 _osRiskPenalty,
        IPriceOracle.UpdatePriceData calldata sigPrice
    )
        external;

    function tabCodeToTabKey(bytes3 code) external pure returns(bytes32);

    event UpdatedContract(
        address _config, 
        address _reserveRegistry, 
        address _tabRegistry, 
        address _priceOracle, 
        address _keeper
    );
    event NewVault(
        address indexed vaultOwner,
        uint256 indexed id, 
        address reserveAddr, 
        uint256 reserveAmt, 
        address tab, 
        uint256 tabAmt
    );
    event TabWithdraw(
        address indexed vaultOwner, 
        uint256 indexed id, 
        uint256 withdrawAmt, 
        uint256 newAmt
    );
    event TabReturned(
        address indexed vaultOwner, 
        uint256 indexed id, 
        uint256 returnedAmt, 
        uint256 newAmt
    );
    event ReserveWithdraw(
        address indexed vaultOwner, 
        uint256 indexed id, 
        uint256 withdrawAmt, 
        uint256 newAmt
    );
    event ReserveAdded(
        address indexed vaultOwner, 
        uint256 indexed id, 
        uint256 addedAmt, 
        uint256 newAmt
    );
    event RiskPenaltyCharged(
        address indexed vaultOwner, 
        uint256 indexed id, 
        uint256 riskPenaltyAmt, 
        uint256 newAmt
    );
    event LiquidatedVaultAuction(
        uint256 vaultId, 
        address reserveAddr, 
        uint256 maxReserveQty, 
        address tabAddr, 
        uint256 startPrice
    );

    error ZeroAddress();
    error ZeroValue();
    error InvalidReserve(address invalidReserveToken);
    error DisabledTab(bytes3 tab);
    error ExceededWithdrawable(uint256 withdrawable);
    error InvalidLiquidatedVault(uint256 vaultId);
    error ExcessAmount();
    error InvalidVault(address vaultOwner, uint256 vaultId);

}
