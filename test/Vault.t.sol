// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract VaultTest is Test {
    uint256 internal constant _MAX_UTILIZATION_RATE = 80;

    ERC20Mock public token;
    Vault public vault;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        // Underlying token
        token = new ERC20Mock("USDC Mock", "USDC", 8);

        // Vault
        vault = new Vault(address(token), "USDC/BTC Liquidity Pool", "lpUSDCBTC", false);
    }

    function _mintUnderlying(address to, uint256 amount) internal {
        // Mint `amount` of USDC for `to` address
        token.mint(to, amount);

        // Assert `to` address USDC balance
        assertEq(token.balanceOf(to), amount);
    }

    function _maxUtilizationFromAssets(uint256 assets) internal pure returns (uint256) {
        return FixedPointMathLib.fullMulDiv(assets, _MAX_UTILIZATION_RATE, 100);
    }

    function _deposit(uint256 amount, address to) internal {
        // Impersonates `to` address
        vm.startPrank(to);

        // Shares balance before depositing
        uint256 sharesBalanceBefore = vault.balanceOf(to);

        // Assets balance before depositing
        uint256 assetsBalanceBefore = token.balanceOf(to);

        // Expected amount of shares to be received
        uint256 expectedShares = vault.previewDeposit(amount);

        // Allow Vault to transfer `amount` of USDC from `to` address
        token.approve(address(vault), amount);

        // Add `amount` of USDC to the Vault
        vault.deposit(amount, to);

        // Assert expected amount of assets
        assertEq(token.balanceOf(to), assetsBalanceBefore - amount);

        // Assert expected amount of shares
        assertEq(vault.balanceOf(to), sharesBalanceBefore + expectedShares);

        // Stops impersonating
        vm.stopPrank();
    }

    function _withdraw(uint256 amount, address to) internal {
        // Impersonates `to` address
        vm.startPrank(to);

        // Shares balance before withdraw
        uint256 sharesBalanceBefore = vault.balanceOf(to);

        // Assets balance before withdraw
        uint256 assetsBalanceBefore = token.balanceOf(to);

        // Expected amount of shares to send
        uint256 expectedShares = vault.previewWithdraw(amount);

        // Withdraw assets from Vault
        vault.withdraw(amount, to, to);

        // Assert expected amount of assets
        assertEq(token.balanceOf(to), assetsBalanceBefore + amount);

        // Assert expected amount of shares
        assertEq(vault.balanceOf(to), sharesBalanceBefore - expectedShares);

        // Stops impersonating
        vm.stopPrank();
    }

    function testFuzz_SingleDepositWithdraw(uint256 amount) public {
        // Mint underlying token
        _mintUnderlying(alice, amount);

        // Vault total assets before deposit
        uint256 totalAssetsBefore = vault.totalAssets();

        // Add `amount` of USDC to the Vault
        _deposit(amount, alice);

        // Vault total USDC balance
        uint256 totalAssets = vault.totalAssets();

        // Assert Vault USDC balance
        assertEq(totalAssets, amount);

        // Assert Vault max utilization balance
        assertEq(vault.maxUtilization(), _maxUtilizationFromAssets(totalAssets));

        // Withdraw `amount` of USDC from the Vault
        _withdraw(amount, alice);

        // Assert Vault USDC balance
        assertEq(vault.totalAssets(), totalAssetsBefore);
    }

    function testFuzz_ThreeDepositWithdraw(uint256 amount) public {
        // Limit the `amount` value while fuzzing to not overflow
        vm.assume(amount <= type(uint256).max / 3);

        // Mint `amount` of USDC for Alice, Bob, and Charlie
        _mintUnderlying(alice, amount);
        _mintUnderlying(bob, amount);
        _mintUnderlying(charlie, amount);

        // Vault total assets before deposit
        uint256 totalAssetsBefore = vault.totalAssets();

        // Deposit `amount` of USDC to the Vault as Alice, Bob, and Charlie
        _deposit(amount, alice);
        _deposit(amount, bob);
        _deposit(amount, charlie);

        // Vault total USDC balance
        uint256 totalAssets = vault.totalAssets();

        // Assert Vault USDC balance
        assertEq(vault.totalAssets(), amount * 3);

        // Assert Vault max utilization balance
        assertEq(vault.maxUtilization(), _maxUtilizationFromAssets(totalAssets));

        // Withdraw `amount` of USDC from the Vault as Alice, Bob, and Charlie
        _withdraw(amount, alice);
        _withdraw(amount, bob);
        _withdraw(amount, charlie);

        // Assert Vault USDC balance
        assertEq(vault.totalAssets(), totalAssetsBefore);
    }
}
