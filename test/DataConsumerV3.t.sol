// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, expect, forks, println} from "vulcan/test.sol";
import {DataConsumerV3} from "../src/DataConsumerV3.sol";

contract DataConsumerV3Test is Test {
    DataConsumerV3 public dataConsumer;

    function setUp() public {
	// Create a Sepolia testnet fork
        forks.select(forks.create("sepolia"));

	// BTC/USD Price Feed Address
	address priceFeedAddress = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
	// Create a Data Consumer using Price Feed Address
	dataConsumer = new DataConsumerV3(priceFeedAddress);
    }

    function testPriceFeed_GetLatestAnswer() public {
	// Retrieve the latest answer from the Chainlink Data Feed
	int256 answer = dataConsumer.getChainlinkDataFeedLatestAnswer();

	// Log the BTC/USD price
        println("BTC/USD price: {i}", abi.encode(answer));

	// Check if answer is greater than 0
	expect(answer).toBeGreaterThan(int256(0));
    }
}
