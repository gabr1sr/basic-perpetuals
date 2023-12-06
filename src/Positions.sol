// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {Vault} from "./Vault.sol";
import {DataFeed} from "./DataFeed.sol";

interface Token {
    function decimals() external view returns (uint8);
}

contract Positions is Ownable {
    mapping(address tokenAddress => uint8 decimals) private _decimals;

    mapping(address tokenAddress => address vaultAddress) private _tokenVaults;

    DataFeed private _dataFeed;

    struct Position {
        uint256 collateral;
        uint256 size;
        uint256 entryPrice;
        address collateralAddress;
        address sizeAddress;
        address priceAddress;
        bool long;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error ArraysLengthAreNotEqual();

    error ArrayLengthIsZero();

    error VaultAddressIsZero();

    error TokenAddressIsZero();

    error DataFeedAddressIsZero();

    error TokenOrFeedAddressIsZero();

    error NoTokenVaultAddress();

    error NoTokenDecimals();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CONSTRUCTOR                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(address usdc_, address[] memory tokens_, address[] memory vaults_, address dataFeed_) {
        _initializeOwner(msg.sender);

        if (dataFeed_ == address(0)) _revert(0x458d1d30); // revert DataFeedAddressIsZero();

        _dataFeed = DataFeed(dataFeed_);

        uint256 tokensLength = tokens_.length;
        uint256 vaultsLength = vaults_.length;

        if (tokensLength == 0 || vaultsLength == 0) _revert(0xea497c3c); // revert ArrayLengthIsZero();

        if (tokensLength != vaultsLength) _revert(0xe2952beb); // revert ArraysLengthAreNotEqual();

        for (uint256 i; i < tokensLength;) {
            _setTokenVault(tokens_[i], vaults_[i]);
            _setDecimals(tokens_[i]);

            unchecked {
                ++i;
            }
        }

        _setDecimals(usdc_);
        _decimals[dataFeed_] = uint8(8);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        PERPETUALS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // TODO: make leverage always have 2 decimals
    function calculateLeverage(uint256 collateral, uint256 size, address collateralAddress, address sizeAddress)
        public
        view
        returns (uint256 leverage)
    {
        (uint8 collateralPriceDecimals, uint256 collateralAsPrice) = _convertPrice(collateral, collateralAddress);
        (uint8 sizePriceDecimals, uint256 sizeAsPrice) = _convertPrice(size, sizeAddress);
        leverage = (sizeAsPrice / collateralAsPrice) / 10 ** (sizePriceDecimals - collateralPriceDecimals - 2);
    }

    function _convertPrice(uint256 amount, address tokenAddress)
        internal
        view
        returns (uint8 decimals, uint256 value)
    {
        uint256 latestPrice = _dataFeed.getPrice(tokenAddress);
        uint8 feedDecimals = getDecimals(address(_dataFeed));
        uint8 tokenDecimals = getDecimals(tokenAddress);
        decimals = feedDecimals + tokenDecimals;
        value = (amount * latestPrice);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        UTILITIES                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _setTokenVault(address tokenAddress, address vaultAddress) internal onlyOwner {
        if (tokenAddress == address(0)) _revert(0xdc2e5e8d); // revert TokenAddressIsZero();

        if (vaultAddress == address(0)) _revert(0xa371f56); // revert VaultAddressIsZero();

        _tokenVaults[tokenAddress] = vaultAddress;
    }

    function getTokenVault(address tokenAddress) public view returns (Vault vault) {
        if (tokenAddress == address(0)) _revert(0xdc2e5e8d); // revert TokenAddressIsZero();

        address vaultAddress = _tokenVaults[tokenAddress];
        if (vaultAddress == address(0)) _revert(0x231f8bbe); // revert NoTokenVaultAddress();

        vault = Vault(vaultAddress);
    }

    function _setDecimals(address tokenAddress) internal onlyOwner {
        if (tokenAddress == address(0)) _revert(0xaa385f98); // revert TokenOrFeedAddressIsZero();

        _decimals[tokenAddress] = Token(tokenAddress).decimals();
    }

    function getDecimals(address tokenOrFeedAddress) public view returns (uint8 decimals) {
        if (tokenOrFeedAddress == address(0)) _revert(0xaa385f98); // revert TokenOrFeedAddressIsZero();

        decimals = _decimals[tokenOrFeedAddress];
        if (decimals == 0) _revert(0x16f87766); // revert NoTokenDecimals();
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
