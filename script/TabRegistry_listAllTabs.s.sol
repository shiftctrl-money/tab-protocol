// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/TabRegistry.sol";

contract TabRegistry_listAllTabs is Script {    
    address reader = 0x16601e7dBf2642bF7832053417eE0E17C9c49f93; // any address
   
    address tabRegistry = 0x5B2949601CDD3721FF11bF55419F427c9C118e2c;
    
    function run() external view {
        // vm.startBroadcast(reader);

        TabRegistry tr = TabRegistry(tabRegistry);

        uint256 activatedTabCount = tr.activatedTabCount();
        console.log("activatedTabCount: ", activatedTabCount);
        for(uint256 i=0; i < activatedTabCount; i++) {
            bytes3 tabCode = tr.tabList(i);
            string memory currCode = bytes3ToString(tabCode);
            address tabAddr = tr.tabs(tabCode);
            console.log(currCode, ",", tabAddr);
        }

        // vm.stopBroadcast();
    }

    function bytes3ToString(bytes3 _data) public pure returns (string memory) {
        bytes memory paddedData = abi.encodePacked(_data); // Pad with 16 zeros
        return string(paddedData);
    }

}