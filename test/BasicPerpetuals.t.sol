// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BasicPerpetuals} from "../src/BasicPerpetuals.sol";
import {DataConsumerV3} from "../src/DataConsumerV3.sol";
import {ERC20DecimalsMock} from "./utils/ERC20DecimalsMock.sol";

contract BasicPerpetualsTest is Test {
    BasicPerpetuals public perpetuals;

    ERC20DecimalsMock public usdc;

    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant BTC_DECIMALS = 8;

    uint256 public constant ONE_USDC = 1e6;
    uint256 public constant ONE_BTC = 1e8;

    function setUp() public {
        // Craete a mainnet fork
        vm.createSelectFork("mainnet", 18635030);

        // BTC/USD Price Feed Address
        address priceFeedAddress = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

        // Data Consumer for Price Feed Address
        DataConsumerV3 dataConsumer = new DataConsumerV3(priceFeedAddress);

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
}
