// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { TabRegistry } from "../../contracts/TabRegistry.sol";
import { TabFactory } from "../../contracts/TabFactory.sol";
import { TabProxyAdmin } from "../../contracts/TabProxyAdmin.sol";
import { RateSimulator } from "./helper/RateSimulator.sol";
import { TabERC20 } from "../../contracts/token/TabERC20.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

/// @dev reference https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment
/// https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment/blob/main/scripts/keyless-deploy-functions.js
contract TabFactoryTest is Test {

    address owner;
    TabRegistry tabRegistry;
    TabFactory tabFactory;
    TabProxyAdmin tabProxyAdmin;
    RateSimulator rs;

    function setUp() public {
        owner = address(this);
        rs = new RateSimulator();
        tabRegistry = new TabRegistry(owner, owner, owner, owner, owner, owner, owner);
        tabFactory = new TabFactory(owner, address(tabRegistry));
        tabProxyAdmin = new TabProxyAdmin(owner);
        console.log("Deployed TabRegistry: ", address(tabRegistry));
        console.log("Deployed TabFactory: ", address(tabFactory));
    }

    function testCreateTab() public {
        bytes3[] memory _tabs;
        uint256[] memory _prices;
        (_tabs, _prices) = rs.retrieveX(168, 100);

        string memory tabcode;
        for (uint256 i = 0; i < _tabs.length; i++) {
            tabcode = toTabCode(_tabs[i]);
            address t = tabFactory.createTab(
                _tabs[i],
                string(abi.encodePacked("Sound ", _tabs[i])),
                tabcode,
                owner,
                address(1),
                address(tabProxyAdmin)
            );

            console.log(tabcode, ": ", t);
            TabERC20 tab = TabERC20(t);
            assert(tab.tabCode() == _tabs[i]);
            assertEq(tab.name(), string(abi.encodePacked("Sound ", _tabs[i])));
            assertEq(tab.symbol(), tabcode);
            assertEq(tab.decimals(), 18);
            assertEq(tab.totalSupply(), 0);
            assertEq(tab.balanceOf(owner), 0);
        }
    }

    function testChangeTabERC20Addr() public {
        vm.expectRevert("INVALID_ADDR");
        tabFactory.changeTabERC20Addr(address(0));

        tabFactory.changeTabERC20Addr(address(1));
    }

    function toTabCode(bytes3 _tab) internal pure returns (string memory) {
        bytes memory b = new bytes(4);
        b[0] = hex"73"; // prefix s
        require(_tab[0] != 0x0, "INVALID_FIRST_TAB_CHAR");
        b[1] = _tab[0];
        require(_tab[1] != 0x0, "INVALID_SEC_TAB_CHAR");
        b[2] = _tab[1];
        require(_tab[2] != 0x0, "INVALID_3RD_TAB_CHAR");
        b[3] = _tab[2];
        return string(b);
    }

    function testGrantRole() public {
        tabFactory.revokeRole(keccak256("USER_ROLE"), address(tabRegistry));
        tabFactory.grantRole(keccak256("USER_ROLE"), address(1));

        tabFactory.beginDefaultAdminTransfer(address(2));
        vm.warp(block.timestamp + 1 days + 1);
        vm.startPrank(address(2));
        tabFactory.acceptDefaultAdminTransfer();
        assertEq(tabFactory.owner(), address(2));
        vm.stopPrank();
    }

}
