// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ICREATE3Factory} from "../contracts/interfaces/ICREATE3Factory.sol";
import {TabFactory} from "../contracts/token/TabFactory.sol";
import {TabERC20} from "../contracts/token/TabERC20.sol";

/**
 * @dev Expected TabFactory deployed to 0x83F19d560935F5299E7DE4296e7cb7adA0417525 
 */
contract DeployTabFactory is Script {
    // refer https://github.com/ZeframLou/create3-factory
    address create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
    
    address deployer = 0xF9D253eB19B5c929fcF8B28a9B34Aaba61dB3F56;

    TabFactory tabFactory;
    TabERC20 tabERC20;

    /**
     * Execution console logs:
        TabERC20 deployed at: 0xE914B685a2912C2F5016EF5b29C7cD7Ec7904815
        TabFactory deployed at: 0x83F19d560935F5299E7DE4296e7cb7adA0417525
        TabFactory implementation: 0xE914B685a2912C2F5016EF5b29C7cD7Ec7904815
     */
    function run() external {
        vm.startBroadcast(deployer);

        tabERC20 = new TabERC20(); // implementation contract
        console.log("TabERC20 deployed at:", address(tabERC20));

        // args[0] = _implementation
        // args[1] = _initialOwner, deployer
        // transfer to governance controller once deployment is done.
        tabFactory = TabFactory(ICREATE3Factory(create3Factory).deploy(
            keccak256(abi.encodePacked("ShiftCTRL_v1.00.000: TabFactory")), 
            abi.encodePacked(type(TabFactory).creationCode, abi.encode(address(tabERC20), deployer))
        ));
        console.log("TabFactory deployed at:", address(tabFactory));
        console.log("TabFactory implementation:", tabFactory.implementation());

        vm.stopBroadcast();
    }
}