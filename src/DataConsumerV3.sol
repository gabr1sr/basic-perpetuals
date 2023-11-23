// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DataConsumerV3 {
    AggregatorV3Interface public dataFeed;

    constructor(address priceFeedAddress) {
        dataFeed = AggregatorV3Interface(priceFeedAddress);
    }

    function getChainlinkDataFeedLatestAnswer() public view returns (int256) {
        (
            /* uint80 roundID */
            ,
            int256 answer,
            /* uint256 startedAt */
            ,
            /* uint256 updatedAt */
            ,
            /* uint80 answeredInRound */
        ) = dataFeed.latestRoundData();
        return answer;
    }
}
