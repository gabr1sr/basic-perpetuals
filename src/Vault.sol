// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC4626} from "solady/src/tokens/ERC4626.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract Vault is ERC4626 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 internal constant _MAX_UTILIZATION_RATE = 80;

    address internal immutable _underlying;

    uint8 internal immutable _decimals;

    string internal _name;

    string internal _symbol;

    bool public immutable useVirtualShares;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CONSTRUCTOR                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(address underlying_, string memory name_, string memory symbol_, bool useVirtualShares_) {
        _underlying = underlying_;

        (bool success, uint8 result) = _tryGetAssetDecimals(underlying_);
        _decimals = success ? result : _DEFAULT_UNDERLYING_DECIMALS;

        _name = name_;
        _symbol = symbol_;

        useVirtualShares = useVirtualShares_;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ERC20 METADATA                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ERC4626 CONSTANTS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function asset() public view override returns (address) {
        return _underlying;
    }

    function _underlyingDecimals() internal view override returns (uint8) {
        return _decimals;
    }

    function _useVirtualShares() internal view override returns (bool) {
        return useVirtualShares;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         PERPETUALS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function maxUtilization() public view returns (uint256 assets) {
        assets = FixedPointMathLib.fullMulDiv(totalAssets(), _MAX_UTILIZATION_RATE, 100);
    }
}
