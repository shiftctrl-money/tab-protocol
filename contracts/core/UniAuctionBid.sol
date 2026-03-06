// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RevertOptions} from "@zetachain/protocol-contracts/contracts/Revert.sol";
import {IGatewayEVM} from "@zetachain/protocol-contracts/contracts/evm/interfaces/IGatewayEVM.sol";

import {UniTabOperation} from "./UniTabOperation.sol";
import {IUniAuctionBid} from "../interfaces/IUniAuctionBid.sol";
import {IUniTab} from "../interfaces/IUniTab.sol";
import {ITabERC20} from "../interfaces/ITabERC20.sol";

/** 
 * @dev ShiftCTRL Tab Protocol's payback Tab operation on ZetaChain.
 */
contract UniAuctionBid is 
    Initializable, 
    UUPSUpgradeable,
    UniTabOperation,
    IUniAuctionBid
{
    // ZRC-20 ZETA token address on ZetaChain used to indicate destination chain
    address public zetaToken;

    // AuctionManager contract address on ZetaChain
    address public auctionManager;

    constructor() {
        _disableInitializers();
    }

    /** 
     * @dev Initialization.
     * @param _admin Governance controller address.
     * @param _upgrader Proxy admin contract address.
     * @param _deployer Deployer address.
     * @param _gatewayAddress EVM gateway address.
     * @param _zrc20GasToken Current chain ZRC20 gas token address.
     */
    function initialize(
        address _admin, 
        address _upgrader,
        address _deployer,
        address _gatewayAddress,
        address _zrc20GasToken
    ) 
        public 
        initializer 
    {
        __UUPSUpgradeable_init();
        __UniTabOperation_init(_admin, _upgrader, _deployer, _gatewayAddress, _zrc20GasToken, 1 days);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function updateZetaToken(address _zetaToken) external onlyRole(DEPLOYER_ROLE) {
        if (_zetaToken == address(0)) revert InvalidAddress();
        emit UpdatedZetaToken(zetaToken, _zetaToken);
        zetaToken = _zetaToken;
    }

    function updateAuctionManager(address _auctionManager) external onlyRole(DEPLOYER_ROLE) {
        if (_auctionManager == address(0)) revert InvalidAddress();
        emit UpdatedAuctionManager(auctionManager, _auctionManager);
        auctionManager = _auctionManager;
    }

    /**
     * @dev User to bid on active auction with Tab token. 
     *      Bidded BTC.BTC token will be transferred to receiver in ZetaChain.
     * @param _auctionId Active auction ID.
     * @param _tabToken Tab address, used to bid on the auction
     * @param _tabAmt Tab amount to bid.
     * @param _receiver Address in ZetaChain to receive bidded BTC token.
     */
    function bidWithTab(
        uint256 _auctionId,
        address _tabToken,
        uint256 _tabAmt,
        address _receiver
    ) external nonReentrant whenNotPaused {
        if (_tabToken == address(0) || _tabAmt == 0)
            revert ZeroTab();

        ITabERC20(_tabToken).burnFrom(msg.sender, _tabAmt);

        bytes32 tabKey = ITabERC20(_tabToken).tabKey();

        bytes memory callData = abi.encodeWithSignature(
            "bidWithTab(uint256,address,uint256,address)",
            _auctionId,
            _tabToken,
            _tabAmt,
            _receiver
        );

        bytes memory message = abi.encode(
            _tabToken,      // tabAddress
            tabKey,         // bytes32: tabKey
            zetaToken,      // destination
            universal,      // receiver: ZUniTab on ZetaChain
            _tabAmt,        // tokenAmount
            msg.sender,     // sender
            auctionManager, // callToAddress: only applicable for ZetaChain destination
            callData,       // callData
            true            // perform ERC-20 approve call on callToAddress
        );

        IGatewayEVM(gateway).call(
            universal,          // receiver
            message,            // payload
            RevertOptions(
                uniTab,         // revertAddress
                false,          // callOnRevert
                universal,      // abortAddress
                abi.encode(_tabToken, msg.sender, _tabAmt, msg.sender), // revertMessage
                IUniTab(uniTab).revertGasLimit() // onRevertGasLimit
            )
        ); 
        
        emit BidWithTab(
            msg.sender,
            _receiver,
            _auctionId,
            _tabToken,
            _tabAmt
        );
    }

}