// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BasicPerpetuals} from "../src/BasicPerpetuals.sol";
import {DataConsumerV3} from "../src/DataConsumerV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BasicPerpetualsTest is Test {
    BasicPerpetuals public perpetuals;
    IERC20 public usdc;

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
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

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
        // Random USDC Whale Address
        address usdcWhale = 0xDa9CE944a37d218c3302F6B82a094844C6ECEb17;

        // Retrieve Whale's USDC Balance
        uint256 whaleBalance = usdc.balanceOf(usdcWhale);

        // Fuzzing - `amount` value cannot be higher than `whaleBalance`
        vm.assume(amount <= whaleBalance);

        // Protocol balance before
        uint256 balanceBefore = perpetuals.totalAssets();

        // Add Liquidity
        _addLiquidity(usdcWhale, amount);

        // Whale balance after
        uint256 whaleBalanceAfter = usdc.balanceOf(usdcWhale);

        // Protocol balance after
        uint256 balanceAfter = perpetuals.totalAssets();

        // Asserts Protocol balance
        assertGe(balanceAfter, balanceBefore);
        assertEq(balanceAfter, amount);

        // Asserts Whale balance
        assertGe(whaleBalance, whaleBalanceAfter);
    }

    function testFuzz_RemoveLiquidity(uint256 amount) public {
        // Random USDC Whale Address
        address usdcWhale = 0xDa9CE944a37d218c3302F6B82a094844C6ECEb17;

        // Retrieve Whale's USDC Balance
        uint256 whaleBalance = usdc.balanceOf(usdcWhale);

        // Fuzzing - `amount` value cannot be higher than `whaleBalance`
        vm.assume(amount <= whaleBalance);

        // Protocol balance before
        uint256 balanceBefore = perpetuals.totalAssets();

        // Add Liquidity
        _addLiquidity(usdcWhale, amount);

        // Remove Liquidity
        _removeLiquidity(usdcWhale, amount);

        // Whale balance after
        uint256 whaleBalanceAfter = usdc.balanceOf(usdcWhale);

        // Protocol balance after
        uint256 balanceAfter = perpetuals.totalAssets();

        // Asserts Protocol balance
        assertEq(balanceBefore, balanceAfter);

        // Asserts Whale balance
        assertEq(whaleBalanceAfter, whaleBalance);
    }
}
