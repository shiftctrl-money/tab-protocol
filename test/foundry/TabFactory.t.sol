// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TabRegistry } from "../../contracts/TabRegistry.sol";
import { TabFactory } from "../../contracts/TabFactory.sol";
import { RateSimulator } from "./helper/RateSimulator.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

/// @dev reference https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment
/// https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment/blob/main/scripts/keyless-deploy-functions.js
contract TabFactoryTest is Test {

    address owner;
    TabRegistry tabRegistry;
    TabFactory tabFactory;
    RateSimulator rs;

    function setUp() public {
        owner = address(this);
        rs = new RateSimulator();
        tabRegistry = new TabRegistry(owner, owner, owner, owner, owner, owner);
        tabFactory = new TabFactory(owner, address(tabRegistry));
        console.log("Deployed TabRegistry: ", address(tabRegistry));
        console.log("Deployed TabFactory: ", address(tabFactory));
    }

    function testCreateTab() public {
        bytes3[] memory _tabs;
        uint256[] memory _prices;
        (_tabs, _prices) = rs.retrieveX(168, 100);

        for (uint256 i = 0; i < _tabs.length; i++) {
            address t = tabFactory.createTab(_tabs[i]);
            console.log(toTabCode(_tabs[i]), ": ", t);
        }
    }

    /// Once TabFactory address is different, all tab contracts will have different addresses
    // function testCreateTab_diffImplContract() public {
    //     tabFactory = new TabFactory(owner, address(tabRegistry));
    //     console.log("Re-deployed TabFactory: ", address(tabFactory));

    //     bytes3[] memory _tabs;
    //     uint256[] memory _prices;
    //     (_tabs, _prices) = rs.retrieveX(168, 100);

    //     for(uint256 i=0; i< _tabs.length; i++) {
    //         address t = tabFactory.createTab(_tabs[i]);
    //         console.log(toTabCode(_tabs[i]), ": ", t);
    //     }
    // }

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

}
