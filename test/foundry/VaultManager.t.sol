// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { VaultManager } from "../../contracts/VaultManager.sol";
import { TabProxyAdmin } from "../../contracts/TabProxyAdmin.sol";
import { ReserveRegistry } from "../../contracts/ReserveRegistry.sol";
import "./helper/MockERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VaultManagerTest is Test {

    address public dummyAdmin = address(1);
    address public dummyDeployer = address(2);
    address public dummyKeeper = address(3);
    address public dummyUI = address(4);
    address public owner = address(10); // Reserving this to mimic owner

    uint256 INITIAL_BALANCE = 10 ether;

    MockERC20 public mockReserve;
    VaultManager public vaultManager;
    ReserveRegistry public reserveRegistry;

    function setUp() public {
        vm.startPrank(owner);

        mockReserve = new MockERC20();
        mockReserve.mint(owner, INITIAL_BALANCE);

        reserveRegistry = new ReserveRegistry(owner, owner, owner, owner);
        bytes32 dummyReserveKey = bytes32(0x1200000000000000000000000000000000000000000000000000000000000001);
        reserveRegistry.addReserve(dummyReserveKey, address(mockReserve), address(0)); // Assuming no safe is

        TabProxyAdmin tabProxyAdmin = new TabProxyAdmin(address(this));

        bytes memory vaultManagerInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address)", dummyAdmin, dummyAdmin, dummyDeployer, dummyUI
        );
        VaultManager vaultManagerImpl = new VaultManager(); // implementation
        address vaultManagerAddr = address(
            new TransparentUpgradeableProxy(address(vaultManagerImpl), address(tabProxyAdmin), vaultManagerInitData)
        );
        vaultManager = VaultManager(vaultManagerAddr);

        mockReserve.approve(address(vaultManager), INITIAL_BALANCE);

        vm.stopPrank();
    }

}
