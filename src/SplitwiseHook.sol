// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ISplitwise {
    function autoRepay(address payer, address token, uint256 amount) external;
}

contract SplitwiseHook is BaseHook {
    using SafeERC20 for IERC20;

    ISplitwise public immutable splitwise;
    address public immutable payer; // Bill owner

    constructor(
        IPoolManager _poolManager,
        ISplitwise _splitwise,
        address _payer
    ) BaseHook(_poolManager) {
        splitwise = _splitwise;
        payer = _payer;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _afterSwap(
        address,
        PoolKey calldata poolKey,
        SwapParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {

        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);

        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();

        // ✅ TOKEN 0 FEE
        if (amount0 > 0) {
            uint256 amt0 = uint256(int256(amount0));

            // ✅ Pull fee from PoolManager to this hook
            poolManager.take(poolKey.currency0, address(this), amt0);

            // ✅ Forward to Splitwise
            IERC20(token0).safeTransfer(address(splitwise), amt0);

            // ✅ Apply auto repayment
            splitwise.autoRepay(payer, token0, amt0);
        }

        // ✅ TOKEN 1 FEE
        if (amount1 > 0) {
            uint256 amt1 = uint256(int256(amount1));

            poolManager.take(poolKey.currency1, address(this), amt1);
            IERC20(token1).safeTransfer(address(splitwise), amt1);
            splitwise.autoRepay(payer, token1, amt1);
        }

        return (BaseHook.afterSwap.selector, 0);
    }
}
