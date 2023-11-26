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

        // Alice USDC balance
        uint256 aliceBalance = usdc.balanceOf(alice);

        // Impersonates Alice
        vm.startPrank(alice);

        // Approve Protocol to transact Alice's USDC
        usdc.approve(address(perpetuals), aliceBalance);

        // Create Long Position
        perpetuals.createPosition(collateral, size, true);

        // Stops impersonating
        vm.stopPrank();

        // Console
        console.log("Total Deposits:", perpetuals.totalDeposits());
        console.log("Total Assets:", perpetuals.totalAssets());
        console.log("Max Utilization:", perpetuals.maxUtilization());
        console.log("Total Open Long Interest:", perpetuals.longOpenInterest());
    }
}
