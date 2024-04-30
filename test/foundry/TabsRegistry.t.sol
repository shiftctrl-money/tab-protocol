// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";
import { Config } from "../../contracts/Config.sol";
import { TabProxyAdmin } from "../../contracts/TabProxyAdmin.sol";
import { TabRegistry } from "../../contracts/TabRegistry.sol";
import { TabFactory } from "../../contracts/TabFactory.sol";
import { VaultKeeper } from "../../contracts/VaultKeeper.sol";
import { GovernanceAction } from "../../contracts/governance/GovernanceAction.sol";
import { PriceOracle } from "../../contracts/oracle/PriceOracle.sol";
import { PriceOracleManager } from "../../contracts/oracle/PriceOracleManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TabRegistryTest is Test {

    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    TabRegistry public tabRegistry;
    TabFactory public tabFactory;
    Config public config;
    TabProxyAdmin public tabProxyAdmin;
    PriceOracleManager public priceOracleManager;
    GovernanceAction public governanceAction;
    PriceOracle priceOracle;
    address public dummyVaultManager = address(1);
    address public dummyDefaultTabContract = address(2);
    address public dummyTabProxyAdmin = address(3);
    address public dummyAuctionManager = address(4);

    bytes3[] addedTabs; // Keep track of tabs added during tests

    event PeggedTab(bytes3 _ptab, bytes3 _tab, uint256 _priceRatio);
    event NewTab(bytes3 _tab, address tabAddr);

    function setUp() public {
        tabRegistry = new TabRegistry(
            address(this),
            address(this),
            address(this),
            address(this),
            address(this),
            dummyVaultManager,
            dummyTabProxyAdmin
        );
        tabFactory = new TabFactory(address(this), address(tabRegistry));
        tabRegistry.setTabFactory(address(tabFactory));

        config = new Config(
            address(this),
            address(this),
            address(this),
            address(this),
            address(this),
            address(tabRegistry),
            dummyAuctionManager
        );

        tabProxyAdmin = new TabProxyAdmin(address(this));
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)",
            address(this),
            address(this),
            address(this),
            address(this),
            address(1),
            address(tabRegistry)
        );
        priceOracleManager = new PriceOracleManager(); // implementation
        address priceOracleManagerProxy =
            address(new TransparentUpgradeableProxy(address(priceOracleManager), address(tabProxyAdmin), initData));

        priceOracle = new PriceOracle(
            address(this), address(this), dummyVaultManager, priceOracleManagerProxy, address(tabRegistry)
        );
        PriceOracleManager(priceOracleManagerProxy).setPriceOracle(address(priceOracle));

        tabRegistry.setConfigAddress(address(config));
        tabRegistry.setPriceOracleManagerAddress(priceOracleManagerProxy);

        bytes memory vaultKeeperInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)",
            address(this),
            address(this),
            address(this),
            address(this),
            dummyVaultManager,
            address(config)
        );
        VaultKeeper vaultKeeperImpl = new VaultKeeper(); // implementation
        address vaultKeeperAddr = address(
            new TransparentUpgradeableProxy(address(vaultKeeperImpl), address(tabProxyAdmin), vaultKeeperInitData)
        );
        config.setVaultKeeperAddress(vaultKeeperAddr);

        bytes memory governanceActionInitData =
            abi.encodeWithSignature("initialize(address,address,address)", address(this), address(this), address(this));
        GovernanceAction governanceActionImpl = new GovernanceAction(); // implementation
        governanceAction = GovernanceAction(
            address(
                new TransparentUpgradeableProxy(
                    address(governanceActionImpl), address(tabProxyAdmin), governanceActionInitData
                )
            )
        );

        tabRegistry.setGovernanceAction(address(governanceAction));

        // dummy addr for _reserveRegistry
        governanceAction.setContractAddress(
            address(config), address(tabRegistry), address(this), priceOracleManagerProxy
        );
    }

    function testCreateTab() public {
        bytes3 tab = "USD";
        vm.startPrank(dummyVaultManager); // Assuming the vaultManager has the USER_ROLE
        address createdAddr = tabRegistry.createTab(tab);
        require(createdAddr != address(0), "Tab address should not be zero");
        require(tabRegistry.tabs(tab) == createdAddr, "Tab address should match the created address");
        assertEq(keccak256(abi.encodePacked(ERC20(createdAddr).name())), keccak256("Sound USD"));
        vm.stopPrank();
    }

    function createTabForTesting() public returns (address) {
        bytes3 tab = "USD";
        address createdAddr = tabRegistry.createTab(tab);
        return createdAddr;
    }

    function testCreateTabTwice() public {
        bytes3 tab = "USD";
        vm.startPrank(address(1));
        address createdAddr1 = tabRegistry.createTab(tab);
        address createdAddr2 = tabRegistry.createTab(tab);
        // console2.log(createdAddr1);
        // console2.log(createdAddr2);
        assert(createdAddr1 == createdAddr2);
        vm.stopPrank();
    }

    function testAddToTablist() public {
        bytes3 tab = "JPY";
        vm.startPrank(dummyVaultManager);
        tabRegistry.createTab(tab);
        addedTabs.push(tab);
        bool found = false;
        for (uint256 i = 0; i < addedTabs.length; i++) {
            if (tabRegistry.tabList(i) == addedTabs[i]) {
                found = true;
                break;
            }
        }
        require(found, "Tab should be added to the tabList");
        vm.stopPrank();
    }

    function testShouldNotAddDuplicateTablists() public {
        bytes3 tab = "GBP";
        vm.startPrank(dummyVaultManager);
        tabRegistry.createTab(tab);
        addedTabs.push(tab);
        tabRegistry.createTab(tab); // Create the same tab again
        uint256 count = 0;
        for (uint256 i = 0; i < addedTabs.length; i++) {
            if (tabRegistry.tabList(i) == addedTabs[i]) {
                count++;
            }
        }
        require(count == 1, "Tab should not be duplicated in the tabList");
        vm.stopPrank();
    }

    function testRoleChecks() public {
        vm.startPrank(dummyTabProxyAdmin);
        bytes3 tab = "EUR";
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000000000003 is missing role 0x14823911f2da1b49f045a0929a60b8c1f2a7fc8c06c7284ca3e8ab4e193a08c8"
        );
        tabRegistry.createTab(tab); // This should fail since the dummy account doesn't have USER_ROLE
    }

    function testRoleAssignment() public view {
        assert(tabRegistry.hasRole(USER_ROLE, dummyVaultManager));
    }

    function toTabCode(bytes3 _tab) public pure returns (string memory) {
        bytes memory b = new bytes(4);
        b[0] = hex"73"; // prefix s
        b[1] = _tab[0];
        b[2] = _tab[1];
        b[3] = _tab[2];
        return string(b);
    }

    function testTabNaming() public pure {
        bytes3 tab = "AUD";
        string memory expectedName = "sAUD";
        string memory actualName = toTabCode(tab);
        assertEq(expectedName, actualName);
    }

    function testCreateTabWithInvalidCode() public {
        bytes3 invalidTab = "US"; // Less than 3 characters
        vm.expectRevert("INVALID_3RD_TAB_CHAR");
        tabRegistry.createTab(invalidTab);
    }

    function testCreateTabWithoutUserRole() public {
        vm.startPrank(dummyTabProxyAdmin);
        bytes3 tab = "CAD";
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000000000003 is missing role 0x14823911f2da1b49f045a0929a60b8c1f2a7fc8c06c7284ca3e8ab4e193a08c8"
        );
        tabRegistry.createTab(tab);
    }

    function testTabRetrieval() public {
        bytes3 tab = "NZD";
        vm.startPrank(dummyVaultManager);
        address createdAddr = tabRegistry.createTab(tab);
        assertEq(tabRegistry.tabs(tab), createdAddr);
        vm.stopPrank();
    }

    function testCreateTabWithInvalidAddress() public {
        vm.expectRevert();
        new TabRegistry(
            address(0), address(0), address(0), address(0), address(0), dummyVaultManager, dummyTabProxyAdmin
        );
    }

    function testTabListOrder() public {
        bytes3 tab1 = "CHF";
        bytes3 tab2 = "INR";
        vm.startPrank(dummyVaultManager);
        tabRegistry.createTab(tab1);
        tabRegistry.createTab(tab2);
        assertEq(tabRegistry.tabList(0), tab1);
        assertEq(tabRegistry.tabList(1), tab2);
        vm.stopPrank();
    }

    function testTabLimit() public {
        vm.startPrank(dummyVaultManager);
        for (uint256 i = 200; i < 390; i++) {
            bytes3 tab = bytes3(keccak256(abi.encodePacked(i)));
            tabRegistry.createTab(tab);
            assertEq(tabRegistry.activatedTabCount(), i - 200 + 1);
        }
        vm.stopPrank();
    }

    function testMultipleUsers() public {
        bytes3 tab1 = "PHP";
        bytes3 tab2 = "IDR";

        vm.startPrank(dummyVaultManager);
        tabRegistry.createTab(tab1);
        assertEq(tabRegistry.tabs(tab1) != address(0), true);
        vm.stopPrank();

        address anotherUser = address(4);
        tabRegistry.grantRole(USER_ROLE, anotherUser);
        vm.startPrank(anotherUser);
        tabRegistry.createTab(tab2);
        assertEq(tabRegistry.tabs(tab2) != address(0), true);
        vm.stopPrank();
    }

    function testQueryNonExistentTab() public view {
        bytes3 tab = "MYR";
        assert(tabRegistry.tabs(tab) == address(0));
    }

    function testPeggedTab() public {
        vm.expectRevert("INVALID_SAME_TAB");
        tabRegistry.setPeggedTab(0x555657, 0x555657, 100);

        vm.expectRevert("INACTIVE_TAB");
        tabRegistry.setPeggedTab(0x555657, 0x555601, 100); // 0x555601 not existed

        bytes3 tab = 0x555657;
        vm.startPrank(dummyVaultManager);
        tabRegistry.createTab(tab);
        vm.stopPrank();

        vm.expectRevert("INVALID_PRICE_RATIO");
        tabRegistry.setPeggedTab(0x555601, tab, 0);

        vm.expectRevert("INVALID_PRICE_RATIO");
        tabRegistry.setPeggedTab(0x555601, tab, 100); // tab has no price

        priceOracle.setDirectPrice(tab, 1e18, block.timestamp);
        vm.expectEmit();
        emit PeggedTab(0x555601, tab, 100);
        tabRegistry.setPeggedTab(0x555601, tab, 100);
        assertEq(tabRegistry.peggedTabCount(), 1);

        tabRegistry.setPeggedTab(0x555602, tab, 200);
        assertEq(tabRegistry.peggedTabCount(), 2);

        bytes3 peggedTab1 = 0x555601;
        bytes3 peggedTab2 = 0x555602;
        assertEq(keccak256(abi.encodePacked(tabRegistry.peggedTabList(0))), keccak256(abi.encodePacked(peggedTab1)));
        assertEq(keccak256(abi.encodePacked(tabRegistry.peggedTabList(1))), keccak256(abi.encodePacked(peggedTab2)));

        assertEq(keccak256(abi.encodePacked(tabRegistry.peggedTabMap(peggedTab1))), keccak256(abi.encodePacked(tab)));
        assertEq(keccak256(abi.encodePacked(tabRegistry.peggedTabMap(peggedTab2))), keccak256(abi.encodePacked(tab)));

        assertEq(tabRegistry.peggedTabPriceRatio(peggedTab1), 100);
        assertEq(tabRegistry.peggedTabPriceRatio(peggedTab2), 200);

        // once pegged tab is registed, create the tab as usual
        vm.startPrank(dummyVaultManager);
        tabRegistry.createTab(peggedTab1);
        tabRegistry.createTab(peggedTab2);
        vm.stopPrank();
    }

    function testNewTab() public {
        // create a dummy tab
        bytes3 tab = 0x555657;
        vm.startPrank(dummyVaultManager);
        tabRegistry.createTab(tab); // activatedTabCount = 1
        vm.stopPrank();

        // create dummy pegged tab
        bytes3 peggedTab = 0x555601;
        vm.expectRevert("INVALID_PRICE_RATIO"); // the dummy tab price is not set hence hitting error
        governanceAction.setPeggedTab(peggedTab, tab, 100);

        priceOracle.setDirectPrice(tab, 1e18, block.timestamp);
        vm.expectEmit();
        emit PeggedTab(peggedTab, tab, 100);
        governanceAction.setPeggedTab(peggedTab, tab, 100);

        vm.expectRevert("EXISTED_TAB");
        governanceAction.createNewTab(tab);

        vm.expectRevert("EXISTED_PEGGED_TAB");
        governanceAction.createNewTab(peggedTab);

        bytes3 newTab = 0x555602;
        vm.expectEmit(false, false, false, false);
        emit NewTab(newTab, address(0));
        address newTabAddr = governanceAction.createNewTab(newTab); // activatedTabCount = 2
        assertEq(tabRegistry.tabs(newTab), newTabAddr);
        assertEq(tabRegistry.activatedTabCount(), 2);
    }

}
