// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Deployer} from "./Deployer.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IPriceOracle} from "../contracts/interfaces/IPriceOracle.sol";

contract PriceOracleTest is Deployer {

    bytes32 public constant FEEDER_ROLE = keccak256("FEEDER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant TAB_REGISTRY_ROLE = keccak256("TAB_REGISTRY_ROLE");
    bytes32 public constant PRICE_ORACLE_MANAGER_ROLE = keccak256("PRICE_ORACLE_MANAGER_ROLE");

    function setUp() public {
        deploy();
    }

    function test_permission() public {
        assertEq(priceOracle.defaultAdmin() , address(governanceTimelockController));
        assertEq(priceOracle.hasRole(FEEDER_ROLE, address(governanceTimelockController)), true);
        assertEq(priceOracle.hasRole(FEEDER_ROLE, address(emergencyTimelockController)), true);
        assertEq(priceOracle.hasRole(FEEDER_ROLE, address(vaultManager)), true);
        assertEq(priceOracle.hasRole(SIGNER_ROLE, signerAuthorizedAddr), true);
        assertEq(priceOracle.hasRole(PAUSER_ROLE, address(governanceTimelockController)), true);
        assertEq(priceOracle.hasRole(PAUSER_ROLE, address(emergencyTimelockController)), true);
        assertEq(priceOracle.hasRole(PRICE_ORACLE_MANAGER_ROLE, address(governanceTimelockController)), true);
        assertEq(priceOracle.hasRole(PRICE_ORACLE_MANAGER_ROLE, address(emergencyTimelockController)), true);
        assertEq(priceOracle.hasRole(PRICE_ORACLE_MANAGER_ROLE, address(priceOracleManager)), true);
        assertEq(priceOracle.hasRole(TAB_REGISTRY_ROLE, address(governanceTimelockController)), true);
        assertEq(priceOracle.hasRole(TAB_REGISTRY_ROLE, address(emergencyTimelockController)), true);
        assertEq(priceOracle.hasRole(TAB_REGISTRY_ROLE, address(tabRegistry)), true);
        assertEq(priceOracle.inactivePeriod(), 1 hours);

        vm.expectRevert();
        priceOracle.beginDefaultAdminTransfer(owner);

        vm.startPrank(address(governanceTimelockController));
        priceOracle.beginDefaultAdminTransfer(owner);
        nextBlock(1 days + 1);
        vm.stopPrank();

        vm.startPrank(owner);
        priceOracle.acceptDefaultAdminTransfer();
        vm.stopPrank();
        assertEq(priceOracle.defaultAdmin() , owner);
    }

    function test_updateInactivePeriod(uint256 _period) public {
        vm.assume(_period > 0);
        require(_period > 0);
        
        vm.expectRevert(); // unauthorized
        priceOracle.updateInactivePeriod(_period);
        
        vm.startPrank(address(priceOracleManager));

        vm.expectRevert(IPriceOracle.ZeroValue.selector);
        priceOracle.updateInactivePeriod(0);

        vm.expectEmit();
        emit IPriceOracle.UpdatedInactivePeriod(priceOracle.inactivePeriod(), _period);
        priceOracle.updateInactivePeriod(_period);
        assertEq(priceOracle.inactivePeriod(), _period);
        vm.stopPrank();
    }

    function test_setPeggedTab(uint256 _price, uint256 _priceRatio) public {
        _price = bound(_price, 1e18, 1000000e18);
        _priceRatio = bound(_priceRatio, 1, 1000);
        require(
            _price > 0 && 
            _price <= 1000000e18 && 
            _priceRatio > 0 && 
            _priceRatio < 1001
        );
        bytes3 usd = bytes3(abi.encodePacked("USD"));

        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(usd);
        vm.stopPrank();

        vm.startPrank(address(emergencyTimelockController));
        priceOracle.setDirectPrice(usd, _price, block.timestamp);
        vm.stopPrank();

        bytes3 pegTab = bytes3(abi.encodePacked("XXX"));
        vm.expectRevert(); // unauthorized
        priceOracle.setPeggedTab(pegTab, usd, _priceRatio);

        vm.startPrank(address(tabRegistry));
        priceOracle.setPeggedTab(pegTab, usd, _priceRatio);
        vm.stopPrank();
                
        uint256 usdPrice = priceOracle.getPrice(usd);
        uint256 pegPrice = priceOracle.getPrice(pegTab);
        assertEq(pegPrice, Math.mulDiv(usdPrice, _priceRatio, 100));
        assertEq(pegPrice, priceOracle.getOldPrice(pegTab));
        assertEq(priceOracle.peggedTabCount(), 1);
        assertEq(keccak256(abi.encode(priceOracle.peggedTabList(0))), keccak256(abi.encode(pegTab)));
        assertEq(keccak256(abi.encode(priceOracle.peggedTabMap(pegTab))), keccak256(abi.encode(usd)));
        assertEq(priceOracle.peggedTabPriceRatio(pegTab), _priceRatio);
    }

    function test_ctrlAltDel() public {
        bytes3 sUSD = bytes3(abi.encodePacked("USD"));
        vm.startPrank(address(governanceTimelockController));
        governanceAction.createNewTab(sUSD);
        vm.stopPrank();

        uint256[] memory deposits = new uint256[](10);
        deposits[0] = 1e17;
        deposits[1] = 2e17;
        deposits[2] = 3e17;
        deposits[3] = 44e16;
        deposits[4] = 55555e12;
        deposits[5] = 6e17;
        deposits[6] = 77e16;
        deposits[7] = 888e15;
        deposits[8] = 9e17;
        deposits[9] = 10e16;

        vm.startPrank(deployer);
        cbBTC.approve(address(vaultManager), 100e8);
        priceData = signer.getUpdatePriceSignature(sUSD, 100000e18, block.timestamp); 
        uint256 depositSum = 0;
        for(uint256 i; i < 10; i++) {
            vaultManager.createVault(address(cbBTC), deposits[i], 100e18, priceData);    
            depositSum += deposits[i];
        }
        address sUSDAddr = tabRegistry.getTabAddress(sUSD);
        assertEq(cbBTC.balanceOf(address(reserveSafe)), reserveSafe.getNativeTransferAmount(address(cbBTC), depositSum));
        assertEq(IERC20(sUSDAddr).balanceOf(deployer), 100e18 * 10);

        vm.startPrank(address(governanceTimelockController));
        
        governanceAction.ctrlAltDel(sUSD, 110000e18);
        assertEq(priceOracle.ctrlAltDelTab(sUSD), 110000e18);
        assertEq(priceOracle.getPrice(sUSD), 110000e18);
        assertEq(priceOracle.getOldPrice(sUSD), 110000e18);

        bytes3[] memory ctrlAltDelTabList = tabRegistry.getCtrlAltDelTabList();
        assertEq(keccak256(abi.encodePacked(ctrlAltDelTabList[0])), keccak256(abi.encodePacked(sUSD)));

        nextBlock(block.timestamp + 100);
        vm.expectRevert(IPriceOracle.PostCtrlAltDelFixedPrice.selector);
        priceOracle.setDirectPrice(sUSD, 1e18, block.timestamp);

        // Protocol Vault setup
        IAccessControl(sUSDAddr).grantRole(keccak256("MINTER_ROLE"), address(protocolVault));
        IAccessControl(sUSDAddr).revokeRole(keccak256("MINTER_ROLE"), address(vaultManager));

        vm.startPrank(deployer);
        cbBTC.transfer(eoa_accounts[1], 1e8);

        vm.startPrank(eoa_accounts[1]);
        cbBTC.approve(address(protocolVault), 1e8);
        protocolVault.buyTab(address(cbBTC), sUSDAddr, 1e18);
        assertEq(IERC20(sUSDAddr).balanceOf(eoa_accounts[1]), 110000e18);
        vm.stopPrank();

        vm.startPrank(deployer);
        IERC20(sUSDAddr).approve(address(protocolVault), 100e18);
        protocolVault.sellTab(address(cbBTC), sUSDAddr, 100e18);
        assertEq(IERC20(sUSDAddr).balanceOf(deployer), 100e18 * 9);
    }

    function test_setDirectPrice(uint256 price) public {
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        uint256 inactivePeriod = priceOracle.inactivePeriod();

        vm.assume(price > 0 && price < type(uint256).max);
        require(price > 0 && price < type(uint256).max);

        vm.startPrank(address(governanceTimelockController));
        priceOracle.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        priceOracle.setDirectPrice(usd, price, block.timestamp);
        priceOracle.unpause();
        vm.stopPrank();

        vm.expectRevert(); // unauthorized
        priceOracle.setDirectPrice(usd, price, block.timestamp);

        vm.startPrank(address(emergencyTimelockController));

        vm.expectRevert(IPriceOracle.ZeroPrice.selector);
        priceOracle.setDirectPrice(usd, 0, block.timestamp);

        vm.expectEmit();
        emit IPriceOracle.UpdatedPrice(
            usd,
            0x0,
            price,
            block.timestamp
        );
        priceOracle.setDirectPrice(usd, price, block.timestamp);
        assertEq(block.timestamp, priceOracle.lastUpdated(usd));

        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.OutdatedPrice.selector, usd, block.timestamp-1));
        priceOracle.setDirectPrice(usd, price, block.timestamp - 1);

        nextBlock(1000);
        assertEq(priceOracle.getPrice(usd), price); // within valid price window
        assertEq(priceOracle.getOldPrice(usd), price);

        nextBlock(inactivePeriod);
        vm.expectRevert(abi.encodeWithSelector(
            IPriceOracle.ExpiredRate.selector, 
            block.timestamp, 
            block.timestamp - inactivePeriod - 1000, 
            inactivePeriod
        ));
        priceOracle.getPrice(usd);
        vm.stopPrank();
    }

    function test_updatePrice(uint256 _price) public {
        vm.assume(_price > 0);
        require(_price > 0);

        bytes3 sUSD = bytes3(abi.encodePacked("USD"));
        priceData = signer.getUpdatePriceSignature(sUSD, 100000e18, block.timestamp); 

        vm.startPrank(address(governanceTimelockController));
        priceOracle.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        priceOracle.updatePrice(priceData);
        priceOracle.unpause();
        vm.stopPrank();

        vm.startPrank(signer.authorizedAddr());
        vm.expectRevert();
        priceOracle.updatePrice(priceData); // unauthorized
        vm.stopPrank();

        vm.startPrank(address(vaultManager));
        priceData = signer.getUpdatePriceSignature(sUSD, 100000e18, block.timestamp);
        vm.expectEmit();
        emit IPriceOracle.UpdatedPrice(sUSD, 0, 100000e18, block.timestamp);
        uint256 updatedPrice = priceOracle.updatePrice(priceData);
        uint256 lastUpdated = priceOracle.lastUpdated(sUSD);
        assertEq(updatedPrice, 100000e18);
        // no update, retrieve last updated value
        assertEq(priceOracle.updatePrice(priceData), 100000e18); 
        
        uint256 inactivePeriod = priceOracle.inactivePeriod();
        nextBlock(block.timestamp + inactivePeriod + 1);
        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.ExpiredRate.selector, block.timestamp, lastUpdated, inactivePeriod));
        priceOracle.updatePrice(priceData);

        priceData = signer.getUpdatePriceSignature(sUSD, 0, block.timestamp); 
        vm.expectRevert(IPriceOracle.ZeroPrice.selector);
        priceOracle.updatePrice(priceData);

        signer.updateSigner( // signer and private key not matched
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 
            0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356
        );
        priceData = signer.getUpdatePriceSignature(sUSD, 1, block.timestamp);
        vm.expectRevert(IPriceOracle.InvalidSignature.selector);
        priceOracle.updatePrice(priceData);
        
        signer.updateSigner(
            0x14dC79964da2C08b23698B3D3cc7Ca32193d9955, 
            0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356
        );
        priceData = signer.getUpdatePriceSignature(sUSD, 1, block.timestamp); 
        vm.expectRevert(IPriceOracle.InvalidSignerRole.selector);
        priceOracle.updatePrice(priceData);

        // restored default
        signer.updateSigner(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 
            0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        );
        priceData = signer.getUpdatePriceSignature(sUSD, 1, block.timestamp); 
        priceData.price = 99; // modified price
        vm.expectRevert(IPriceOracle.InvalidSignature.selector);
        priceOracle.updatePrice(priceData);

        priceData = signer.getUpdatePriceSignature(sUSD, 1, block.timestamp); 
        nextBlock(inactivePeriod + 1);
        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.ExpiredRate.selector, block.timestamp, priceData.timestamp, inactivePeriod));
        priceOracle.updatePrice(priceData);

        nextBlock(100);
        lastUpdated = block.timestamp;
        if (_price == 100000e18) {
            _price += 1; // fuzz value collides with last updated value
        }
        priceData = signer.getUpdatePriceSignature(sUSD, _price, block.timestamp); 
        vm.expectEmit();
        emit IPriceOracle.UpdatedPrice(sUSD, 100000e18, _price, lastUpdated);
        updatedPrice = priceOracle.updatePrice(priceData);
        assertEq(priceOracle.getPrice(sUSD), updatedPrice);
        assertEq(priceOracle.lastUpdated(sUSD), lastUpdated);

        nextBlock(1);
        priceData = signer.getUpdatePriceSignature(sUSD, _price, block.timestamp); 
        updatedPrice = priceOracle.updatePrice(priceData); // no price update
        assertEq(priceOracle.getPrice(sUSD), updatedPrice);
        assertEq(priceOracle.lastUpdated(sUSD), lastUpdated + 1);

        vm.stopPrank();
    }

}
