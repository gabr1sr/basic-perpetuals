// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract DataFeed is Ownable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         VARIABLES                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Key-value data where key is the token address and value is a Chainlink Data Feed address.
    mapping(address tokenAddress => address dataFeedAddress) private _tokenPriceFeeds;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Token address cannot be zero address.
    error TokenAddressIsZero();

    /// @dev No Chainlink Data Feed is set for the token address.
    error NoDataFeedAddress();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CONSTRUCTOR                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor() {
        _initializeOwner(msg.sender);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         DATA FEED                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Get the latest price, from the Chainlink Data Feed, for the given token.
    /// @param tokenAddress Address of the token you want to get the latest price.
    /// @return latestPrice The latest price of the token as uint256.
    function getPrice(address tokenAddress) external view returns (uint256 latestPrice) {
        if (tokenAddress == address(0)) _revert(0xdc2e5e8d);

        address priceFeedAddress = _tokenPriceFeeds[tokenAddress];
        if (priceFeedAddress == address(0)) _revert(0x806cf45a);

        AggregatorV3Interface dataFeed = AggregatorV3Interface(priceFeedAddress);
        (, int256 answer,,,) = dataFeed.latestRoundData();
        latestPrice = uint256(answer);
    }

    /// @dev Set the Chainlink Data Feed address for the given token.
    /// @param tokenAddress Address of the token.
    /// @param priceFeedAddress Chainlink Data Feed address.
    function setTokenPriceFeed(address tokenAddress, address priceFeedAddress) external onlyOwner {
        _tokenPriceFeeds[tokenAddress] = priceFeedAddress;
    }

    /// @dev Get the Chainlink Data Feed address of the given token.
    /// @param tokenAddress Address of the token.
    /// @return priceFeedAddress Chainlink Data Feed address.
    function getTokenPriceFeed(address tokenAddress) external view returns (address priceFeedAddress) {
        priceFeedAddress = _tokenPriceFeeds[tokenAddress];
    }

    /// @dev Internal helper for reverting efficiently.
    function _revert(uint256 s) private pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, s)
            revert(0x1c, 0x04)
        }
    }
}
