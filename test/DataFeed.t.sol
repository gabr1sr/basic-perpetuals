// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {DataFeed} from "../src/DataFeed.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract DataFeedTest is Test {
    DataFeed public dataFeed;
    ERC20Mock public token;
    PriceFeedMock public priceFeed;

    address public alice = makeAddr("alice");

    function setUp() public {
        token = new ERC20Mock("USDC Mock", "USDC", 8);
        priceFeed = new PriceFeedMock(int256(37_000 * (10 ** 8)));
        dataFeed = new DataFeed();
    }

    function _setTokenPriceFeed(address caller, address tokenAddress, address priceFeedAddress) internal {
        // Impersonates `caller` address
        vm.startPrank(caller);

        // Set the price feed address for the token address
        dataFeed.setTokenPriceFeed(tokenAddress, priceFeedAddress);

        // Stops impersonating
        vm.stopPrank();
    }

    function test_SetTokenPriceFeed_AsOwner() public {
        // Owner address
        address owner = dataFeed.owner();

        // Set token price feed
        _setTokenPriceFeed(owner, address(token), address(priceFeed));

        // Get token price feed address
        address priceFeedAddress = dataFeed.getTokenPriceFeed(address(token));

        // Assert price feed address
        assertEq(priceFeedAddress, address(priceFeed));
    }

    function test_SetTokenPriceFeed_AsNonOwner() public {
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));

        // Reverts when trying to set token price feed
        _setTokenPriceFeed(alice, address(token), address(priceFeed));
    }

    function test_GetTokenPrice() public {
        // Set token price feed
        _setTokenPriceFeed(dataFeed.owner(), address(token), address(priceFeed));

        // Get the latest token price
        uint256 tokenPrice = dataFeed.getPrice(address(token));

        // Assert the token price
        assertGt(tokenPrice, 0);
    }

    function test_GetTokenPrice_AfterUpdate() public {
        // Set token price feed
        _setTokenPriceFeed(dataFeed.owner(), address(token), address(priceFeed));

        // Get the latest token price before update
        uint256 tokenPriceBefore = dataFeed.getPrice(address(token));

        // Change the token price
        priceFeed.setLatestAnswer(int256(38_000 * (10 ** 8)));

        // Get the latest token price after update
        uint256 tokenPriceAfter = dataFeed.getPrice(address(token));

        // Assert the token price
        assertGt(tokenPriceAfter, tokenPriceBefore);
    }

    function test_GetTokenPrice_TokenAddressIsZero() public {
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(DataFeed.TokenAddressIsZero.selector));

        // Reverts when trying to get the latest token price
        dataFeed.getPrice(address(0));
    }

    function test_GetTokenPrice_NoDataFeedAddress() public {
        // Set token price feed
        _setTokenPriceFeed(dataFeed.owner(), address(token), address(0));

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(DataFeed.NoDataFeedAddress.selector));

        // Reverts when trying to get the latest token price
        dataFeed.getPrice(address(token));
    }
}
