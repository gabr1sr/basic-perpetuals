// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {Positions} from "../src/Positions.sol";
import {DataFeed} from "../src/DataFeed.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";

contract PositionsTest is Test {
    ERC20Mock public usdcToken;
    ERC20Mock public wbtcToken;
    ERC20Mock public wethToken;

    PriceFeedMock public wbtcUsdcFeed;
    PriceFeedMock public wethUsdcFeed;
    PriceFeedMock public usdcUsdFeed;

    Vault public usdcWbtcVault;
    Vault public usdcWethVault;

    DataFeed public dataFeed;

    Positions public positions;

    function setUp() public {
        // Tokens
        usdcToken = new ERC20Mock("USDC Mock", "USDC", uint8(6));
        wbtcToken = new ERC20Mock("wBTC Mock", "wBTC", uint8(8));
        wethToken = new ERC20Mock("wETH Mock", "wETH", uint8(18));

        address[] memory tokens = new address[](2);
        tokens[0] = address(wbtcToken);
        tokens[1] = address(wethToken);

        // Vaults
        usdcWbtcVault = new Vault(address(usdcToken), "USDC/wBTC LP", "lpUSDCwBTC", false);
        usdcWethVault = new Vault(address(usdcToken), "USDC/wETH LP", "lpUSDCwETH", false);

        address[] memory vaults = new address[](2);
        vaults[0] = address(usdcWbtcVault);
        vaults[1] = address(usdcWethVault);

        // Price Feeds
        wbtcUsdcFeed = new PriceFeedMock(int256(4_376_071_000_000));
        wethUsdcFeed = new PriceFeedMock(int256(225_209_238_000));
        usdcUsdFeed = new PriceFeedMock(int256(100_000_000));

        // Data Feed
        dataFeed = new DataFeed();
        dataFeed.setTokenPriceFeed(address(wbtcToken), address(wbtcUsdcFeed));
        dataFeed.setTokenPriceFeed(address(wethToken), address(wethUsdcFeed));
        dataFeed.setTokenPriceFeed(address(usdcToken), address(usdcUsdFeed));

        // Positions
        positions = new Positions(address(usdcToken), tokens, vaults, address(dataFeed));
    }

    function test_CalculateLeverage_wBTC() public {
        // Tokens decimals
        uint256 collateralDecimals = uint256(positions.getDecimals(address(usdcToken)));
        uint256 sizeDecimals = uint256(positions.getDecimals(address(wbtcToken)));

        // Tokens amount
        uint256 collateral = 10_000 * (10 ** collateralDecimals);
        uint256 size = 1 * (10 ** sizeDecimals);

        // Tokens price
        uint256 collateralPrice = dataFeed.getPrice(address(usdcToken));
        uint256 sizePrice = dataFeed.getPrice(address(wbtcToken));

        // Tokens price amount
        uint256 collateralAsPrice = (collateral * collateralPrice);
        uint256 sizeAsPrice = (size * sizePrice);

        console.log("Collateral:", collateral); // 6 decimals
        console.log("Collateral Price:", collateralPrice); // 8 decimals
        console.log("Collateral * Collateral Price:", collateralAsPrice); // 14 decimals (6 + 8)

        console.log("Size:", size); // 8 decimals
        console.log("Size Price:", sizePrice); // 8 decimals
        console.log("Size * Size Price:", sizeAsPrice); // 16 decimals (8 + 8)

        // Leverage
        uint256 expectedLeverage = (sizeAsPrice / collateralAsPrice);
        uint256 leverage = positions.calculateLeverage(collateral, size, address(usdcToken), address(wbtcToken));

        console.log("Expected Leverage:", expectedLeverage);
        console.log("Leverage:", leverage);

        // Assertion
        assertEq(leverage, expectedLeverage); // 437 (4.37x)
    }
}
