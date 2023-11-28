// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract DataConsumerV3Mock {
    int256 private _currentAnswer;

    constructor(int256 initialAnswer) {
        _currentAnswer = initialAnswer;
    }

    function getChainlinkDataFeedLatestAnswer() public view returns (int256) {
        return _currentAnswer;
    }

    function changeAnswer(int256 newAnswer) public {
        _currentAnswer = newAnswer;
    }
}
