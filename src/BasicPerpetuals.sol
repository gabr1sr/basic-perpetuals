// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DataConsumerV3} from "./DataConsumerV3.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {console} from "forge-std/console.sol";

contract BasicPerpetuals is ERC4626 {
    using SafeERC20 for IERC20;

    uint256 constant public MAX_LEVERAGE = 15; // 15x
    uint256 constant public MAX_UTILIZATION_RATE = 80;

    IERC20 immutable private _asset;
    
    DataConsumerV3 immutable private _dataConsumer;

    mapping(address trader => Position position) public positions;

    uint256 public traderDeposits;
    uint256 public openLongInterests;
    uint256 public openShortInterests;
    uint256 public openLongInterestsInSize;
    uint256 public openShortInterestsInSize;
    
    // TODO: support for Long and Short Positions
    struct Position {
	uint256 collateral;
	uint256 size;
	int256 price;
	bool long;
    }

    constructor(IERC20 _assetInstance, address _dataConsumerAddress) ERC4626(_assetInstance) ERC20("Basic: USDC to BTC", "bUSDCBTC") {
	_asset = _assetInstance;
	_dataConsumer = DataConsumerV3(_dataConsumerAddress);
    }

    // ====================
    // Liquidity Providers
    // ====================
    
    function addLiquidity(uint256 amount) public {
	deposit(amount, msg.sender);
    }

    function _maxUtilization() internal view returns (uint256) {
	return (_asset.balanceOf(address(this)) * MAX_UTILIZATION_RATE) / 100;
    }

    function totalOpenInterests() public view returns (uint256) {
	return openLongInterests + openShortInterests;
    }

    function totalOpenInterestsInSize() public view returns (uint256) {
	return openLongInterestsInSize + openShortInterestsInSize;
    }
    
    // ====================
    // Traders
    // ====================
    
    function createPosition(uint256 collateral, uint256 size, bool long) external {
        require(collateral > 0, "Collateral must be greater than 0");
	require(size > 0, "Size must be greater than 0");
	require(_asset.balanceOf(msg.sender) >= collateral, "Insufficient collateral balance");
	
        uint256 leverage = _calculateLeverage(collateral, size);
	require(leverage < MAX_LEVERAGE, "Leverage exceed MAX_LEVERAGE");

	int256 price = _dataConsumer.getChainlinkDataFeedLatestAnswer();
	uint256 sizePrice = _calculateSizePrice(size, price);
	require(sizePrice < _maxUtilization(), "Size Price exceed MAX_UTILIZATION_RATE");
	
	Position memory position = Position({
	    collateral: collateral,
	    size: size,
	    price: price,
	    long: long
	});

	if (long) {
	    openLongInterestsInSize += size;
	    openLongInterests += sizePrice;
	} else {
	    openShortInterestsInSize += size;
	    openShortInterests += sizePrice;
	}
	
	traderDeposits += collateral;
	positions[msg.sender] = position;
	_asset.safeTransferFrom(msg.sender, address(this), collateral);
    }

    // ====================
    // Calculations
    // ====================

    function calculateLeverage(uint256 collateral, uint256 size) external view returns (uint256) {
	return _calculateLeverage(collateral, size);
    }

    function _calculateLeverage(uint256 collateral, uint256 size) internal view returns (uint256) {
	uint256 latestPrice = uint256(_dataConsumer.getChainlinkDataFeedLatestAnswer()) / 1e8;
	uint256 sizePrice = (size / 1e8) * latestPrice;
	return sizePrice / (collateral / 1e6);
    }
    
    function calculateLongPnL(int256 size, int256 price) external view returns (int256) {
	return _calculateLongPnL(size, price);
    }
    
    function _calculateLongPnL(int256 size, int256 price) internal view returns (int256) {
	int256 latestPrice = _dataConsumer.getChainlinkDataFeedLatestAnswer() / 1e8;
	int256 entryPrice = price / 1e8;
	int256 sizeCount = size / 1e8;
	return (latestPrice - entryPrice) * sizeCount;
    }

    function calculateShortPnL(int256 size, int256 price) external view returns (int256) {
	return _calculateShortPnL(size, price);
    }

    function _calculateShortPnL(int256 size, int256 price) internal view returns (int256) {
	int256 latestPrice = _dataConsumer.getChainlinkDataFeedLatestAnswer() / 1e8;
	int256 entryPrice = price / 1e8;
	int256 sizeCount = size / 1e8;
	return (entryPrice - latestPrice) * sizeCount;
    }

    function calculateSizePrice(uint256 size, int256 price) external view returns (uint256) {
	return _calculateSizePrice(size, price);
    }
    
    function _calculateSizePrice(uint256 size, int256 price) internal view returns (uint256) {
	return (size * uint256(price)) / 1e8;
    }

    function calculateTotalLongPnL() external view returns (int256) {
	return _calculateTotalLongPnL();
    }
    
    function _calculateTotalLongPnL() internal view returns (int256) {
	uint256 size = totalOpenInterestsInSize() / 1e8;
	int256 latestPrice = _dataConsumer.getChainlinkDataFeedLatestAnswer() / 1e8;
	int256 totalLatestPrice = int256(_calculateSizePrice(size, latestPrice)) / 1e8;
	int256 totalEntryPrice = int256(totalOpenInterests()) / 1e8;
	return int256(totalLatestPrice - totalEntryPrice) * int256(size);
    }
}
