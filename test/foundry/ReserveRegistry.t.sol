// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { ReserveRegistry } from "../../contracts/ReserveRegistry.sol";
import { MockERC20 } from "./helper/MockERC20.sol";

contract ReserveRegistryTest is Test {

    ReserveRegistry public registry;
    MockERC20 public mockToken;
    address public dummySafe = address(1);

    bytes32 public TEST_RESERVE_KEY = keccak256("TEST");

    event AddedReserve(bytes32 key, address _addr, address _safe);
    event RemovedReserve(bytes32 key);

    function setUp() public {
        registry = new ReserveRegistry(address(this), address(this), address(this), address(this));
        mockToken = new MockERC20();
    }

    function testInitialSetup() public view {
        assertEq(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), address(this)), true);
        assertEq(registry.hasRole(registry.MAINTAINER_ROLE(), address(this)), true);
    }

    function testAddReserve() public {
        vm.expectEmit();
        emit AddedReserve(TEST_RESERVE_KEY, address(mockToken), dummySafe);
        registry.addReserve(TEST_RESERVE_KEY, address(mockToken), dummySafe);
        assertEq(registry.reserveAddr(TEST_RESERVE_KEY), address(mockToken));
        assertEq(registry.reserveKey(address(mockToken)), TEST_RESERVE_KEY);
        assertEq(registry.reserveSafeAddr(TEST_RESERVE_KEY), dummySafe);
    }

    function testUnauthorizedReserveAddition() public {
        registry.revokeRole(registry.MAINTAINER_ROLE(), address(this));
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x339759585899103d2ace64958e37e18ccb0504652c81d4a1b8aa80fe2126ab95"
        );
        registry.addReserve(TEST_RESERVE_KEY, address(mockToken), dummySafe);
    }

    function testRoleChecks() public {
        registry.revokeRole(registry.MAINTAINER_ROLE(), address(this));
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x339759585899103d2ace64958e37e18ccb0504652c81d4a1b8aa80fe2126ab95"
        );
        registry.addReserve(TEST_RESERVE_KEY, address(mockToken), dummySafe);
    }

    function testRetrieveNonExistentReserve() public view {
        bytes32 nonExistentKey = keccak256("NON_EXISTENT");
        assertEq(registry.reserveAddr(nonExistentKey), address(0));
        assertEq(registry.reserveSafeAddr(nonExistentKey), address(0));
    }

    function testAddReserveWithExistingTokenAddress() public {
        bytes32 newKey = keccak256("NEW_TEST");
        registry.addReserve(newKey, address(mockToken), dummySafe);
        assertEq(registry.reserveAddr(newKey), address(mockToken));
        assertEq(registry.reserveKey(address(mockToken)), newKey); // The key should be updated
        assertEq(registry.reserveSafeAddr(newKey), dummySafe);
    }

    function testReAddReserveWithExistingKey() public {
        address newMockTokenAddress = address(2);
        address newDummySafe = address(3);
        registry.addReserve(TEST_RESERVE_KEY, newMockTokenAddress, newDummySafe);
        assertEq(registry.reserveAddr(TEST_RESERVE_KEY), newMockTokenAddress);
        assertEq(registry.reserveSafeAddr(TEST_RESERVE_KEY), newDummySafe);
    }

    function testRoleRevokingAndReGranting() public {
        registry.revokeRole(registry.MAINTAINER_ROLE(), address(this));
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x339759585899103d2ace64958e37e18ccb0504652c81d4a1b8aa80fe2126ab95"
        );
        registry.addReserve(TEST_RESERVE_KEY, address(mockToken), dummySafe);

        registry.grantRole(registry.MAINTAINER_ROLE(), address(this));
        registry.addReserve(TEST_RESERVE_KEY, address(mockToken), dummySafe); // Should not revert now
    }

    function testSafeAddressMapping() public {
        registry.addReserve(TEST_RESERVE_KEY, address(mockToken), dummySafe);
        assertEq(registry.reserveSafeAddr(TEST_RESERVE_KEY), dummySafe);
    }

    function testEnabledReserve() public {
        registry.addReserve(TEST_RESERVE_KEY, address(mockToken), dummySafe);
        assertEq(registry.enabledReserve(TEST_RESERVE_KEY), true);
        address reserveAddr = registry.reserveAddr(TEST_RESERVE_KEY);
        assertEq(registry.isEnabledReserve(reserveAddr), true);

        vm.expectEmit();
        emit RemovedReserve(TEST_RESERVE_KEY);
        registry.removeReserve(TEST_RESERVE_KEY);
        assertEq(registry.enabledReserve(TEST_RESERVE_KEY), false);
        assertEq(registry.isEnabledReserve(reserveAddr), false);
    }

}
