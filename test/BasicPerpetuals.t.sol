// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BasicPerpetuals} from "../src/BasicPerpetuals.sol";
import {ERC20DecimalsMock} from "./utils/ERC20DecimalsMock.sol";
import {DataConsumerV3Mock} from "./utils/DataConsumerV3Mock.sol";

contract BasicPerpetualsTest is Test {
    BasicPerpetuals public perpetuals;

    ERC20DecimalsMock public usdc;

    DataConsumerV3Mock public dataConsumer;

    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant BTC_DECIMALS = 8;
    uint256 public constant FEED_DECIMALS = 8;

    uint256 public constant ONE_USDC = 1e6;
    uint256 public constant ONE_BTC = 1e8;

    function setUp() public {
        // Craete a mainnet fork
        vm.createSelectFork("mainnet", 18635030);

        // BTC/USD Price Feed Address
        // address priceFeedAddress = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

        // Data Consumer for Price Feed Address
        dataConsumer = new DataConsumerV3Mock(int256(37_289 * (10 ** FEED_DECIMALS)));

        // USDC
        usdc = new ERC20DecimalsMock(uint8(USDC_DECIMALS));

        // Perpetuals
        perpetuals = new BasicPerpetuals(usdc, address(dataConsumer));
    }

    function _addLiquidity(address from, uint256 amount) private {
        // Impersonates `from` address
        vm.startPrank(from);

        // Approve Perpetuals to move USDC from the `from` address
        usdc.approve(address(perpetuals), amount);

        // Add liquidity
        perpetuals.addLiquidity(amount);

        // Stops impersonating
        vm.stopPrank();
    }

    function _removeLiquidity(address from, uint256 amount) private {
        // Impersonates `from` address
        vm.startPrank(from);

        // Remove Liquidity
        perpetuals.removeLiquidity(amount);

        // Stops impersonating
        vm.stopPrank();
    }

    function _createPosition(address to, uint256 collateral, uint256 size, bool long) private {
        // Impersonates `to` address
        vm.startPrank(to);

        // Approve Perpetuals to move USDC from the `to` address
        usdc.approve(address(perpetuals), collateral);

        // Create a new position
        perpetuals.createPosition(collateral, size, long);

        // Stops impersonating
        vm.stopPrank();
    }

    function testFuzz_AddLiquidity(uint256 amount) public {
        // Random Address
        address liquidityProvider = makeAddr("provider1");

        // Mint 250k USDC to the Random Address
        usdc.mint(liquidityProvider, 250_000 * (10 ** USDC_DECIMALS));

        // Retrieve Whale's USDC Balance
        uint256 whaleBalance = usdc.balanceOf(liquidityProvider);

        // Fuzzing - `amount` value cannot be higher than `whaleBalance`
        vm.assume(amount <= whaleBalance);

        // Protocol balance before
        uint256 balanceBefore = perpetuals.totalAssets();

        // Add Liquidity
        _addLiquidity(liquidityProvider, amount);

        // Whale balance after
        uint256 whaleBalanceAfter = usdc.balanceOf(liquidityProvider);

        // Protocol balance after
        uint256 balanceAfter = perpetuals.totalAssets();

        // Asserts Protocol balance
        assertGe(balanceAfter, balanceBefore);
        assertEq(balanceAfter, amount);

        // Asserts Whale balance
        assertGe(whaleBalance, whaleBalanceAfter);
    }

    function testFuzz_RemoveLiquidity(uint256 amount) public {
        // Random Address
        address liquidityProvider = makeAddr("provider1");

        // Mint 250k USDC to the Random Address
        usdc.mint(liquidityProvider, 250_000 * (10 ** USDC_DECIMALS));

        // Retrieve Whale's USDC Balance
        uint256 whaleBalance = usdc.balanceOf(liquidityProvider);

        // Fuzzing - `amount` value cannot be higher than `whaleBalance`
        vm.assume(amount <= whaleBalance);

        // Protocol balance before
        uint256 balanceBefore = perpetuals.totalAssets();

        // Add Liquidity
        _addLiquidity(liquidityProvider, amount);

        // Remove Liquidity
        _removeLiquidity(liquidityProvider, amount);

        // Whale balance after
        uint256 whaleBalanceAfter = usdc.balanceOf(liquidityProvider);

        // Protocol balance after
        uint256 balanceAfter = perpetuals.totalAssets();

        // Asserts Protocol balance
        assertEq(balanceBefore, balanceAfter);

        // Asserts Whale balance
        assertEq(whaleBalanceAfter, whaleBalance);
    }

    function test_CreateLongPosition() public {
        // Random Address
        address liquidityProvider = makeAddr("provider1");

        // Amount
        uint256 amount = 250_000 * (10 ** USDC_DECIMALS);

        // Mint 250k USDC to the Random Address
        usdc.mint(liquidityProvider, amount);

        // Add Liquidity
        _addLiquidity(liquidityProvider, amount);

        // Alice Address
        address alice = makeAddr("alice");

        // Collateral
        uint256 collateral = 10_000 * (10 ** USDC_DECIMALS);

        // Size
        uint256 size = 1 * (10 ** BTC_DECIMALS);

        // Mint 10k USDC to Alice
        usdc.mint(alice, collateral);

        // Create Long Position
        _createPosition(alice, collateral, size, true);

        // Asserts
        assertLe(perpetuals.calculateLeverage(collateral, size), perpetuals.MAX_LEVERAGE());
        assertEq(perpetuals.longDeposits(), collateral);
        assertEq(perpetuals.longOpenInterestInTokens(), size);
        assertEq(perpetuals.collateralOf(alice), collateral);
        assertEq(usdc.balanceOf(alice), 0);
    }

    function test_IncreaseCollateral() public {
        // Random Address
        address liquidityProvider = makeAddr("provider1");

        // Amount
        uint256 amount = 250_000 * (10 ** USDC_DECIMALS);

        // Mint 250k USDC to the Random Address
        usdc.mint(liquidityProvider, amount);

        // Add Liquidity
        _addLiquidity(liquidityProvider, amount);

        // Alice Address
        address alice = makeAddr("alice");

        // Collateral
        uint256 collateral = 10_000 * (10 ** USDC_DECIMALS);

        // Size
        uint256 size = 1 * (10 ** BTC_DECIMALS);

        // Mint 10k USDC to Alice
        usdc.mint(alice, collateral);

        // Create Long Position
        _createPosition(alice, collateral, size, true);

        // Amount to increase
        uint256 increaseAmount = 5_000 * (10 ** USDC_DECIMALS);

        // Mint 5k USDC to Alice
        usdc.mint(alice, increaseAmount);

        // Impersonates Alice
        vm.startPrank(alice);

        // Allow protocol to transfer 5k USDC from Alice
        usdc.approve(address(perpetuals), increaseAmount);

        // Increase 5k USDC of collateral
        perpetuals.increaseCollateral(increaseAmount);

        // Stops impersonating
        vm.stopPrank();

        // Total collateral
        uint256 totalCollateral = collateral + increaseAmount;

        // Asserts
        assertLe(perpetuals.calculateLeverage(totalCollateral, size), perpetuals.MAX_LEVERAGE());
        assertEq(perpetuals.longDeposits(), totalCollateral);
        assertEq(perpetuals.longOpenInterestInTokens(), size);
        assertEq(perpetuals.collateralOf(alice), totalCollateral);
        assertEq(usdc.balanceOf(alice), 0);
    }

    function test_DecreaseCollateral() public {
        // Random Address
        address liquidityProvider = makeAddr("provider1");

        // Amount
        uint256 amount = 250_000 * (10 ** USDC_DECIMALS);

        // Mint 250k USDC to the Random Address
        usdc.mint(liquidityProvider, amount);

        // Add Liquidity
        _addLiquidity(liquidityProvider, amount);

        // Alice Address
        address alice = makeAddr("alice");

        // Collateral
        uint256 collateral = 10_000 * (10 ** USDC_DECIMALS);

        // Size
        uint256 size = 1 * (10 ** BTC_DECIMALS);

        // Mint 10k USDC to Alice
        usdc.mint(alice, collateral);

        // Create Long Position
        _createPosition(alice, collateral, size, true);

        // Amount to decrease
        uint256 decreaseAmount = 2_500 * (10 ** USDC_DECIMALS);

        // Impersonates Alice
        vm.startPrank(alice);

        // Increase 5k USDC of collateral
        perpetuals.decreaseCollateral(decreaseAmount);

        // Stops impersonating
        vm.stopPrank();

        // Total collateral
        uint256 totalCollateral = collateral - decreaseAmount;

        // Asserts
        assertLe(perpetuals.calculateLeverage(totalCollateral, size), perpetuals.MAX_LEVERAGE());
        assertEq(perpetuals.longDeposits(), totalCollateral);
        assertEq(perpetuals.longOpenInterestInTokens(), size);
        assertEq(perpetuals.collateralOf(alice), totalCollateral);
        assertEq(usdc.balanceOf(alice), decreaseAmount);
    }

    function testFuzz_CalculateLongPnL(uint256 sizeInTokens) public {
        // Cap `sizeInTokens` limit to the first counterexample overflow
        vm.assume(sizeInTokens < 176904378841589733741797831619250);

        // Long Position Entry Price
        uint256 entryPrice = 37_000 * (10 ** FEED_DECIMALS);

        // Long Position Size
        uint256 size = sizeInTokens * (10 ** BTC_DECIMALS);

        // Long Position PnL
        (, uint256 pnl) = perpetuals.calculateLongPnL(size, entryPrice);

        // Assertions
        assertGe(pnl, 0);
    }

    function testFuzz_CalculateShortPnL(uint256 sizeInTokens) public {
        // Cap `sizeInTokens` limit to the first counterexample overflow
        vm.assume(sizeInTokens < 176904378841589733741797831619250);

        // Short Position Entry Price
        uint256 entryPrice = 37_000 * (10 ** FEED_DECIMALS);

        // Short Position Size
        uint256 size = sizeInTokens * (10 ** BTC_DECIMALS);

        // Short Position PnL
        (, uint256 pnl) = perpetuals.calculateShortPnL(size, entryPrice);

        // Assertions
        assertGe(pnl, 0);
    }

    function test_CloseLongPosition() public {
        // Random Address
        address liquidityProvider = makeAddr("provider1");

        // Amount
        uint256 amount = 250_000 * (10 ** USDC_DECIMALS);

        // Mint 250k USDC to the Random Address
        usdc.mint(liquidityProvider, amount);

        // Add Liquidity
        _addLiquidity(liquidityProvider, amount);

        // Alice Address
        address alice = makeAddr("alice");

        // Collateral
        uint256 collateral = 10_000 * (10 ** USDC_DECIMALS);

        // Size
        uint256 size = 1 * (10 ** BTC_DECIMALS);

        // Mint 10k USDC to Alice
        usdc.mint(alice, collateral);

        // Create Long Position
        _createPosition(alice, collateral, size, true);

        // Change block to a lower ETH price
        dataConsumer.changeAnswer(int256(33700 * (10 ** FEED_DECIMALS)));

        // Impersonates Alice
        vm.startPrank(alice);

        // Get My PnL
        (bool positive, uint256 pnlValue) = perpetuals.calculateMyPnL();

        console.log("Alice's PNL is positive:", positive);
        console.log("Alice's PNL:", pnlValue);

        // PnL in USDC
        uint256 pnl = pnlValue / (10 ** (FEED_DECIMALS - USDC_DECIMALS));

        // New Collateral
        uint256 newCollateral = positive ? collateral + pnl : collateral - pnl;

        // Protocol Balance
        uint256 protocolBalance = usdc.balanceOf(address(perpetuals));

        // New Protocol Balance
        uint256 newProtocolBalance = protocolBalance - newCollateral;

        // Close Position
        perpetuals.closePosition();

        // Stops impersonating
        vm.stopPrank();

        // Asserts
        assertLe(perpetuals.calculateLeverage(newCollateral, size), perpetuals.MAX_LEVERAGE());
        assertEq(perpetuals.longDeposits(), 0);
        assertEq(perpetuals.longOpenInterestInTokens(), 0);
        assertEq(usdc.balanceOf(alice), newCollateral);
        assertEq(usdc.balanceOf(address(perpetuals)), newProtocolBalance);
    }

    function test_IncreaseSize() public {
        // Random Address
        address liquidityProvider = makeAddr("provider1");

        // Amount
        uint256 amount = 250_000 * (10 ** USDC_DECIMALS);

        // Mint 250k USDC to the Random Address
        usdc.mint(liquidityProvider, amount);

        // Add Liquidity
        _addLiquidity(liquidityProvider, amount);

        // Alice Address
        address alice = makeAddr("alice");

        // Collateral
        uint256 collateral = 10_000 * (10 ** USDC_DECIMALS);

        // Size
        uint256 size = 1 * (10 ** BTC_DECIMALS);

        // Mint 10k USDC to Alice
        usdc.mint(alice, collateral);

        // Create Long Position
        _createPosition(alice, collateral, size, true);

        // Amount to increase
        uint256 increaseAmount = size;

        // Impersonates Alice
        vm.startPrank(alice);

        // Increase 1 BTC of Size
        perpetuals.increaseSize(increaseAmount);

        // Stops impersonating
        vm.stopPrank();

        // Total collateral
        uint256 totalSize = size + increaseAmount;

        // Asserts
        assertLe(perpetuals.calculateLeverage(collateral, totalSize), perpetuals.MAX_LEVERAGE());
        assertEq(perpetuals.longOpenInterestInTokens(), totalSize);
    }

    function test_DecreaseSize() public {
        // Random Address
        address liquidityProvider = makeAddr("provider1");

        // Amount
        uint256 amount = 2_500_000 * (10 ** USDC_DECIMALS);

        // Mint 250k USDC to the Random Address
        usdc.mint(liquidityProvider, amount);

        // Add Liquidity
        _addLiquidity(liquidityProvider, amount);

        // Alice Address
        address alice = makeAddr("alice");

        // Collateral
        uint256 collateral = 100_000 * (10 ** USDC_DECIMALS);

        // Size
        uint256 size = 10 * (10 ** BTC_DECIMALS);

        // Mint 10k USDC to Alice
        usdc.mint(alice, collateral);

        // Create Long Position
        _createPosition(alice, collateral, size, true);

        // Amount to decrease
        uint256 decreaseAmount = 1 * (10 ** BTC_DECIMALS);

        // Impersonates Alice
        vm.startPrank(alice);

        // Decrease 1 BTC of Size
        perpetuals.decreaseSize(decreaseAmount);

        // Stops impersonating
        vm.stopPrank();

        // Total collateral
        uint256 totalSize = size - decreaseAmount;

        // Asserts
        assertLe(perpetuals.calculateLeverage(collateral, totalSize), perpetuals.MAX_LEVERAGE());
        assertEq(perpetuals.longOpenInterestInTokens(), totalSize);
    }
}
