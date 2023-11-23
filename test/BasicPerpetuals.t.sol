// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BasicPerpetuals} from "../src/BasicPerpetuals.sol";
import {DataConsumerV3} from "../src/DataConsumerV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BasicPerpetualsTest is Test {
    BasicPerpetuals public perpetuals;
    IERC20 public usdc;
    
    function setUp() public {
	// Craete a Sepolia testnet fork
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

    function testLeverage_CalculateLeverage() public {
	uint256 collateral = 2000e6;
	uint256 size = 1e8;
	uint256 leverage = perpetuals.calculateLeverage(collateral, size);
	assert(leverage > 0);
    }

    function testLong_CalculatePnL() public {
	uint256 collateral = 2000e6;
	uint256 size = 1e8;
	int256 price = 37000e8;
	int256 pnl = perpetuals.calculateLongPnL(int256(size), price);
	assert(pnl > 0);
    }

    function testShort_CalculatePnL() public {
	uint256 collateral = 2000e6;
	uint256 size = 1e8;
	int256 price = 38000e8;
	int256 pnl = perpetuals.calculateShortPnL(int256(size), price);
	assert(pnl > 0);
    }

    function testLong_CalculateTotalPnL() public {
	uint256 amount = 10_000e6; // 10k USDC
	uint256 size = 1e8; // 1 BTC

	_transferUSDC(msg.sender, amount);

	_addLiquidity();

	_createPosition(msg.sender, amount, size, true);

	console.log("Total Open Interests:", perpetuals.totalOpenInterests());
	console.log("Total Open Interests In Size:", perpetuals.totalOpenInterestsInSize());
	
	int256 pnl = perpetuals.calculateTotalLongPnL();
    }

    function _transferUSDC(address trader, uint256 amount) internal {
	address usdcWhale = 0xDa9CE944a37d218c3302F6B82a094844C6ECEb17;
	
	vm.startPrank(usdcWhale);

        usdc.transfer(trader, amount);

	vm.stopPrank();
    }

    function _createPosition(address trader, uint256 amount, uint256 size, bool long) internal {
	vm.startPrank(trader);

	usdc.approve(address(perpetuals), amount);
	perpetuals.createPosition(amount, size, long);
	
	vm.stopPrank();
    }
    
    function _addLiquidity() internal {
	address usdcWhale = 0xDa9CE944a37d218c3302F6B82a094844C6ECEb17;
	uint256 amount = usdc.balanceOf(usdcWhale);
	
	vm.startPrank(usdcWhale);

	usdc.approve(address(perpetuals), amount);
	perpetuals.addLiquidity(amount);

	vm.stopPrank();
    }
}
