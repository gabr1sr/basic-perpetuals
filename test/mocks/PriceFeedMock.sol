// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract PriceFeedMock {
    int256 internal _latestAnswer;

    constructor(int256 initialAnswer) {
        _latestAnswer = initialAnswer;
    }

    function latestRoundData() external view returns (uint80, int256 answer, uint256, uint256, uint80) {
        answer = _latestAnswer;
    }

    function setLatestAnswer(int256 latestAnswer) external {
        _latestAnswer = latestAnswer;
    }
}
