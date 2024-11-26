// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControlDefaultAdminRules } from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { TabERC20 } from "./TabERC20.sol";

/**
 * @dev Dependency on https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment to create fixed TabFactory contract address.
 * @title  Factory to create new Tab contract.
 * @notice Refer https://www.shiftctrl.money for details.
 */
contract TabFactory is AccessControlDefaultAdminRules {
    bytes32 public constant DEPLOY_ROLE = keccak256("DEPLOY_ROLE");
    TabERC20 tabERC20;
    event UpdatedTabContractTemplate(address oldAddr, address newAddr);
    error ZeroAddress();

    /**
     * @param admin Super administrator.
     * @param minter Contract authorized to mint Tabs.
     */
    constructor(address admin, address minter) AccessControlDefaultAdminRules(1 days, admin) {
        _grantRole(DEPLOY_ROLE, admin);
        _grantRole(DEPLOY_ROLE, minter);
        tabERC20 = new TabERC20();
    }

    /**
     * @dev Update Tab implementation address.
     * @param newTabAddr Deployed tab implementation.
     */
    function changeTabERC20Addr(address newTabAddr) external onlyRole(DEPLOY_ROLE) {
        if (newTabAddr == address(0))
            revert ZeroAddress();
        emit UpdatedTabContractTemplate(address(tabERC20), newTabAddr);
        tabERC20 = TabERC20(newTabAddr);
    }

    /**
     * @dev Create a proxy from stored tab implementation.
     * @param name Tab name, e.g. Sound USD.
     * @param symbol Tab symbol, e.g. sXXX.
     * @param admin Admin user of the tab token.
     * @param minter User authorized to mint tabs.
     * @param tabProxyAdmin Proxy admin.
     */
    function createTab(
        string calldata name,
        string calldata symbol,
        address admin,
        address minter,
        address tabProxyAdmin
    )
        external
        onlyRole(DEPLOY_ROLE)
        returns (address)
    {
        bytes memory deployCode = type(TransparentUpgradeableProxy).creationCode;
        bytes memory initData = abi.encodeCall(TabERC20.initialize, (name, symbol, admin, tabProxyAdmin, minter));
        bytes memory params = abi.encode(address(tabERC20), tabProxyAdmin, initData);

        // deploy(uint256 amount, bytes32 salt, bytes memory bytecode)
        return Create2.deploy(
            0,
            keccak256(abi.encodePacked("shiftCTRL TAB_v1: ", symbol)),
            abi.encodePacked(deployCode, params)
        );
    }
}
