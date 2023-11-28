// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DataConsumerV3} from "./DataConsumerV3.sol";
import {console} from "forge-std/console.sol";

contract BasicPerpetuals is ERC4626 {
    using SafeERC20 for IERC20;

    struct Position {
        uint256 collateral;
        uint256 size;
        uint256 entryPrice;
        bool long;
    }

    IERC20 private immutable _asset;

    DataConsumerV3 private immutable _dataConsumer;

    uint256 public constant MAX_LEVERAGE = 15;
    uint256 public constant MAX_UTILIZATION = 80;

    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant BTC_DECIMALS = 8;
    uint256 public constant FEED_DECIMALS = 8;

    uint256 public longOpenInterestInTokens; // BTC
    uint256 public shortOpenInterestInTokens; // BTC

    uint256 public longDeposits; // USDC
    uint256 public shortDeposits; // USDC

    mapping(address trader => Position position) public positions;

    constructor(IERC20 _assetInstance, address _dataConsumerAddress)
        ERC4626(_assetInstance)
        ERC20("Basic: USDC to BTC", "bUSDCBTC")
    {
        _asset = _assetInstance;
        _dataConsumer = DataConsumerV3(_dataConsumerAddress);
    }

    // Liquidity Providers

    function addLiquidity(uint256 amount) public {
        deposit(amount, msg.sender);
    }

    function removeLiquidity(uint256 amount) public {
        withdraw(amount, msg.sender, msg.sender);
    }

    // Liquidity Reserves

    function totalDeposits() public view returns (uint256) {
        return longDeposits + shortDeposits;
    }

    function maxUtilization() public view returns (uint256) {
        return (totalAssets() * MAX_UTILIZATION) / 100;
    }

    // Open Interests

    function totalOpenInterest() public view returns (uint256) {
        return shortOpenInterest() + longOpenInterest();
    }

    function shortOpenInterest() public view returns (uint256) {
        uint256 price = uint256(_dataConsumer.getChainlinkDataFeedLatestAnswer()) / (10 ** FEED_DECIMALS);
        uint256 shortOpenInterestPrice = (shortOpenInterestInTokens * price) / (10 ** BTC_DECIMALS);
        return shortOpenInterestPrice;
    }

    function longOpenInterest() public view returns (uint256) {
        uint256 price = uint256(_dataConsumer.getChainlinkDataFeedLatestAnswer()) / (10 ** FEED_DECIMALS);
        uint256 longOpenInterestPrice = (longOpenInterestInTokens * price) / (10 ** BTC_DECIMALS);
        return longOpenInterestPrice;
    }

    function calculateLeverage(uint256 collateral, uint256 size) public view returns (uint256) {
        uint256 price = uint256(_dataConsumer.getChainlinkDataFeedLatestAnswer()) / (10 ** FEED_DECIMALS);
        uint256 sizePrice = price * (size / (10 ** BTC_DECIMALS));
        return sizePrice / (collateral / (10 ** USDC_DECIMALS));
    }

    function _calculateLeverageWithPrice(uint256 collateral, uint256 sizePrice) internal pure returns (uint256) {
        return sizePrice / (collateral / (10 ** USDC_DECIMALS));
    }

    // PnL

    function calculateLongPnL(uint256 size, uint256 entryPrice) public view returns (bool, uint256) {
        uint256 currentPrice = uint256(_dataConsumer.getChainlinkDataFeedLatestAnswer()) / (10 ** FEED_DECIMALS);
        uint256 sizePrice = (entryPrice / (10 ** FEED_DECIMALS)) * (size / (10 ** BTC_DECIMALS));
        bool isPositive = currentPrice > sizePrice;

        if (isPositive) {
            return (isPositive, (currentPrice - sizePrice) * size);
        }

        return (isPositive, (sizePrice - currentPrice) * size);
    }

    function calculateShortPnL(uint256 size, uint256 entryPrice) public view returns (bool, uint256) {
        uint256 currentPrice = uint256(_dataConsumer.getChainlinkDataFeedLatestAnswer()) / (10 ** FEED_DECIMALS);
        uint256 sizePrice = (entryPrice / (10 ** FEED_DECIMALS)) * (size / (10 ** BTC_DECIMALS));
        bool isPositive = currentPrice < sizePrice;

        if (isPositive) {
            return (isPositive, (sizePrice - currentPrice) * size);
        }

        return (isPositive, (currentPrice - sizePrice) * size);
    }

    function calculateMyPnL() public view returns (bool, uint256) {
        Position memory position = positions[msg.sender];
        return position.long
            ? calculateLongPnL(position.size, position.entryPrice)
            : calculateShortPnL(position.size, position.entryPrice);
    }

    // Positions

    function createPosition(uint256 collateral, uint256 size, bool long) external {
        require(collateral > 0, "Collateral must be greater than 0");
        require(size > 0, "Size must be greater than 0");
        require(_asset.balanceOf(msg.sender) >= collateral, "Insufficient asset balance");

        uint256 entryPrice = uint256(_dataConsumer.getChainlinkDataFeedLatestAnswer());
        uint256 sizePrice = (entryPrice / (10 ** FEED_DECIMALS)) * (size / (10 ** BTC_DECIMALS));
        uint256 leverage = _calculateLeverageWithPrice(collateral, sizePrice);
        require(leverage <= MAX_LEVERAGE, "Leverage cannot exceed 15x");

        uint256 futureTotalOpenInterest = totalOpenInterest() + sizePrice;
        require(futureTotalOpenInterest < maxUtilization(), "Open interests cannot exceed max utilization");

        Position memory position = Position({collateral: collateral, size: size, entryPrice: entryPrice, long: long});

        if (long) {
            longDeposits += collateral;
            longOpenInterestInTokens += size;
        } else {
            shortDeposits += collateral;
            shortOpenInterestInTokens += size;
        }

        positions[msg.sender] = position;
        _asset.safeTransferFrom(msg.sender, address(this), collateral);
    }

    function closePosition() external {
        Position storage position = positions[msg.sender];
        (bool positive, uint256 pnlValue) = position.long
            ? calculateLongPnL(position.size, position.entryPrice)
            : calculateShortPnL(position.size, position.entryPrice);

        uint256 pnl = pnlValue / (10 ** (FEED_DECIMALS - USDC_DECIMALS));

        if (positive) {
            uint256 pendingValue = position.collateral + pnl;
            require(maxUtilization() >= pendingValue, "After-withdraw liquidity cannot exceed max utilization");

            if (position.long) {
                longDeposits -= position.collateral;
                longOpenInterestInTokens -= position.size;
            } else {
                shortDeposits -= position.collateral;
                shortOpenInterestInTokens -= position.size;
            }

            delete positions[msg.sender];
            _asset.safeTransfer(msg.sender, pendingValue);
        } else {
            if (pnl >= position.collateral) {
                _liquidatePosition(msg.sender);
            } else {
                uint256 newCollateral = position.collateral - pnl;
                uint256 newLeverage = calculateLeverage(newCollateral, position.size);

                if (newLeverage <= MAX_LEVERAGE) {
                    require(maxUtilization() >= newCollateral, "After-withdraw liquidity cannot exceed max utilization");

                    if (position.long) {
                        longDeposits -= position.collateral;
                        longOpenInterestInTokens -= position.size;
                    } else {
                        shortDeposits -= position.collateral;
                        shortOpenInterestInTokens -= position.size;
                    }

                    delete positions[msg.sender];
                    _asset.safeTransfer(msg.sender, newCollateral);
                } else {
                    _liquidatePosition(msg.sender);
                }
            }
        }
    }

    function _liquidatePosition(address trader) internal {
        Position storage position = positions[trader];

        if (position.long) {
            longDeposits -= position.collateral;
            longOpenInterestInTokens -= position.size;
        } else {
            shortDeposits -= position.collateral;
            shortOpenInterestInTokens -= position.size;
        }

        delete positions[msg.sender];
    }

    // Collateral

    function increaseCollateral(uint256 valueToIncrease) external {
        require(_asset.balanceOf(msg.sender) >= valueToIncrease, "Insufficient asset balance");

        Position storage position = positions[msg.sender];
        position.collateral += valueToIncrease;

        uint256 newLeverage = calculateLeverage(position.collateral, position.size);
        require(newLeverage <= MAX_LEVERAGE, "Leverage cannot exceed 15x");

        if (position.long) {
            longDeposits += valueToIncrease;
        } else {
            shortDeposits += valueToIncrease;
        }

        _asset.safeTransferFrom(msg.sender, address(this), valueToIncrease);
    }

    function decreaseCollateral(uint256 value) external {
        require(totalAssets() >= value, "Insufficient liquidity");

        Position storage position = positions[msg.sender];
        require(value <= position.collateral, "Cannot decrease more than collateral");

        position.collateral -= value;
        uint256 newLeverage = calculateLeverage(position.collateral, position.size);
        require(newLeverage <= MAX_LEVERAGE, "Leverage cannot exceed 15x");

        if (position.long) {
            longDeposits -= value;
        } else {
            shortDeposits -= value;
        }

        _asset.safeTransfer(msg.sender, value);
    }

    function collateralOf(address target) external view returns (uint256) {
        Position memory position = positions[target];
        return position.collateral;
    }

    // Size

    function increaseSize(uint256 increaseAmount) public {
	Position storage position = positions[msg.sender];
	position.size += increaseAmount;

	uint256 entryPrice = uint256(_dataConsumer.getChainlinkDataFeedLatestAnswer());
        uint256 sizePrice = (entryPrice / (10 ** FEED_DECIMALS)) * (position.size / (10 ** BTC_DECIMALS));
	uint256 newLeverage = _calculateLeverageWithPrice(position.collateral, sizePrice);
	require(newLeverage <= MAX_LEVERAGE, "Leverage cannot exceed 15x");

	if (position.long) {
	    longOpenInterestInTokens += increaseAmount;
	} else {
	    shortOpenInterestInTokens += increaseAmount;
	}
    }

    function decreaseSize(uint256 decreaseAmount) public {
	Position storage position = positions[msg.sender];
	require(decreaseAmount < position.size, "Cannot decrease more than position size");
	position.size -= decreaseAmount;

	uint256 entryPrice = uint256(_dataConsumer.getChainlinkDataFeedLatestAnswer());
        uint256 sizePrice = (entryPrice / (10 ** FEED_DECIMALS)) * (position.size / (10 ** BTC_DECIMALS));
	uint256 newLeverage = _calculateLeverageWithPrice(position.collateral, sizePrice);
	require(newLeverage <= MAX_LEVERAGE, "Leverage cannot exceed 15x");

	if (position.long) {
	    longOpenInterestInTokens -= decreaseAmount;
	} else {
	    shortOpenInterestInTokens -= decreaseAmount;
	}
    }
}
