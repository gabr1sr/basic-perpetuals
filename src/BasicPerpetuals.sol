// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DataConsumerV3} from "./DataConsumerV3.sol";

contract BasicPerpetuals is ERC4626 {
    using SafeERC20 for IERC20;

    IERC20 private immutable _asset;

    DataConsumerV3 private immutable _dataConsumer;

    constructor(IERC20 _assetInstance, address _dataConsumerAddress)
        ERC4626(_assetInstance)
        ERC20("Basic: USDC to BTC", "bUSDCBTC")
    {
        _asset = _assetInstance;
        _dataConsumer = DataConsumerV3(_dataConsumerAddress);
    }

    function addLiquidity(uint256 amount) public {
        deposit(amount, msg.sender);
    }

    function removeLiquidity(uint256 amount) public {
        withdraw(amount, msg.sender, msg.sender);
    }
}
