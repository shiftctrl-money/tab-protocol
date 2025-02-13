// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ISkybitCreate3Factory} from "../contracts/interfaces/ISkybitCreate3Factory.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";

/**
 * @dev TabFactory must deploy to address 0x042903578B67B36AC5CCe2c3d75292D62C16C459 
 * to generate fixed address for TabERC20 contracts.
 */
contract DeployTabFactory is Script {
    // refer https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment
    address skybitFactory = 0xA8D5D2166B1FB90F70DF5Cc70EA7a1087bCF1750;
    
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;

    TabFactory tabFactory;
    TabERC20 tabERC20;

    /**
     * Execution console logs:
        TabFactory deployed at: 0x9F440e98dD11a44AeDC8CA88bb7cA3756fdfFED1
        TabERC20 deployed at: 0x2A6AEa496E296bb3A1b3Eb13Ef78D35CBf222083
        TabFactory implementation updated to: 0x2A6AEa496E296bb3A1b3Eb13Ef78D35CBf222083
     */
    function run() external {
        vm.startBroadcast(deployer);

        // args[0] = _implementation, putting `skybitFactory` as placeholder.
        // args[1] = _initialOwner, use deployer for now, 
        // transfer to governance controller once deployment is done.
        tabFactory = TabFactory(ISkybitCreate3Factory(skybitFactory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.00.000: TabFactory")), 
            abi.encodePacked(type(TabFactory).creationCode, abi.encode(skybitFactory, deployer))
        ));
        console.log("TabFactory deployed at:", address(tabFactory));

        // Next deployment steps:
        // 1. Deploy TabERC20 contract.
        tabERC20 = new TabERC20(); // implementation contract
        console.log("TabERC20 deployed at:", address(tabERC20));

        // 2. Update TabFactory implementation to TabERC20 contract by calling `upgradeTo` function.
        tabFactory.upgradeTo(address(tabERC20));
        console.log("TabFactory implementation updated to:", tabFactory.implementation());

        // 3. Update TabFactory address to protocol deployment script.

        vm.stopBroadcast();
    }
}