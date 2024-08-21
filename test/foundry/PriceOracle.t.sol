// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";

import "./Deployer.t.sol";
import "./helper/RateSimulator.sol";

contract PriceOracleTest is Test, Deployer {

    bytes3[] _tabs;
    uint256[] _prices;
    uint256[] _timestamps;

    event UpdatedPrice(bytes3 indexed _tab, uint256 _oldPrice, uint256 _newPrice, uint256 _timestamp);
    event UpdatedInactivePeriod(uint256 b4, uint256 _after);

    function setUp() public {
        test_deploy();

        RateSimulator rs = new RateSimulator();
        (_tabs, _prices) = rs.retrieveX(168, 100);

        _timestamps = new uint256[](168);
        uint256 currentLastUpdated = priceOracle.lastUpdated(bytes3(abi.encodePacked("USD")));
        for (uint256 i = 0; i < 168; i++) {
            _timestamps[i] = currentLastUpdated + 1 + i;
        }
    }

    function test_setPrice() public {
        priceOracle.pause();
        vm.expectRevert("Pausable: paused");
        priceOracle.setPrice(_tabs, _prices, _timestamps);

        priceOracle.unpause();

        vm.startPrank(eoa_accounts[9]);
        vm.expectRevert();
        priceOracle.setPrice(_tabs, _prices, _timestamps);
        vm.stopPrank();

        for (uint256 i = 0; i < _tabs.length; i++) {
            vm.expectEmit();
            if (_tabs[i] == bytes3(abi.encodePacked("USD"))) {
                emit UpdatedPrice(
                    _tabs[i],
                    0x0000000000000000000000000000000000000000000005815e55ed50a7120000,
                    _prices[i],
                    _timestamps[i]
                );
            } else if (_tabs[i] == bytes3(abi.encodePacked("MYR"))) {
                emit UpdatedPrice(
                    _tabs[i],
                    0x0000000000000000000000000000000000000000000019932eb5d23b0b67d000,
                    _prices[i],
                    _timestamps[i]
                );
            } else if (_tabs[i] == bytes3(abi.encodePacked("JPY"))) {
                emit UpdatedPrice(
                    _tabs[i],
                    0x0000000000000000000000000000000000000000000327528f703dab9edda000,
                    _prices[i],
                    _timestamps[i]
                );
            } else {
                emit UpdatedPrice(_tabs[i], 0, _prices[i], _timestamps[i]);
            }
        }
        priceOracle.setPrice(_tabs, _prices, _timestamps);

        assertEq(priceOracle.getPrice(_tabs[0]), _prices[0]);
        assertEq(priceOracle.getPrice(_tabs[_tabs.length - 1]), _prices[_prices.length - 1]);

        assertEq(priceOracle.getOldPrice(_tabs[0]), _prices[0]);
        assertEq(priceOracle.getOldPrice(_tabs[_tabs.length - 1]), _prices[_prices.length - 1]);

        assertEq(priceOracle.lastUpdated(_tabs[0]), _timestamps[0]);
        assertEq(priceOracle.lastUpdated(_tabs[_tabs.length - 1]), _timestamps[_timestamps.length - 1]);
    }

    function test_setDirectPrice(uint256 price, uint256 _lastUpdated) public {
        uint256 currentLastUpdated = priceOracle.lastUpdated(bytes3(abi.encodePacked("USD")));
        uint256 inactivePeriod = priceOracle.inactivePeriod();

        vm.assume(
            price > 0 && _lastUpdated > currentLastUpdated && _lastUpdated < type(uint256).max - inactivePeriod - 1
        );
        require(price > 0 && _lastUpdated > currentLastUpdated && _lastUpdated < type(uint256).max - inactivePeriod - 1);

        priceOracle.pause();
        vm.expectRevert("Pausable: paused");
        priceOracle.setDirectPrice(bytes3(abi.encodePacked("USD")), price, _lastUpdated + 1);
        priceOracle.unpause();

        vm.startPrank(eoa_accounts[9]);
        vm.expectRevert();
        priceOracle.setDirectPrice(bytes3(abi.encodePacked("USD")), price, _lastUpdated + 1);
        vm.stopPrank();

        vm.warp(_lastUpdated + 1);
        vm.expectEmit();
        emit UpdatedPrice(
            bytes3(abi.encodePacked("USD")),
            0x0000000000000000000000000000000000000000000005815e55ed50a7120000,
            price,
            _lastUpdated + 1
        );
        priceOracle.setDirectPrice(bytes3(abi.encodePacked("USD")), price, _lastUpdated + 1);
        _lastUpdated = priceOracle.lastUpdated(bytes3(abi.encodePacked("USD"))); // = lastUpdated + 1;

        vm.warp(_lastUpdated + priceOracle.inactivePeriod() - 1);
        assertEq(priceOracle.getPrice(bytes3(abi.encodePacked("USD"))), price); // within valid price window
        assertEq(priceOracle.getOldPrice(bytes3(abi.encodePacked("USD"))), price);

        vm.warp(_lastUpdated + priceOracle.inactivePeriod());
        vm.expectRevert("INACTIVE");
        priceOracle.getPrice(bytes3(abi.encodePacked("USD")));
    }

    function test_updateInactivePeriod(uint256 _period) public {
        vm.assume(_period > 0);
        require(_period > 0);
        vm.expectEmit();
        emit UpdatedInactivePeriod(priceOracle.inactivePeriod(), _period);
        priceOracle.updateInactivePeriod(_period);
    }

    function test_peggedTab(uint256 _priceRatio) public {
        vm.assume(_priceRatio > 0 && _priceRatio < 1e18);
        require(_priceRatio > 0 && _priceRatio < 1e18);

        bytes3 pegTab = bytes3(abi.encodePacked("XXX"));
        bytes3 usd = bytes3(abi.encodePacked("USD"));
        uint256 usdPrice = priceOracle.getPrice(usd);
        console.log("usdPrice: ", usdPrice);
        console.log("_priceRatio: ", _priceRatio);

        vm.startPrank(address(tabRegistry));
        priceOracle.setPeggedTab(pegTab, usd, _priceRatio);
        vm.stopPrank();

        assertEq(priceOracle.getPrice(pegTab), FixedPointMathLib.mulDiv(usdPrice, _priceRatio, 100));
    }

}
