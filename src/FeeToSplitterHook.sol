// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {FeeSplitter} from "./FeeSplitter.sol";

contract FeeToSplitterHook is BaseHook {
    address public feeToken;
    FeeSplitter public splitter;

    constructor(
        IPoolManager _poolManager,
        address _feeToken,
        FeeSplitter _splitter
    ) BaseHook(_poolManager) {
        feeToken = _feeToken;
        splitter = _splitter;
    }

    function getDeployParameters()
        public
        pure
        returns (bytes32 salt, bytes memory deployData)
    {
        // The salt must be unique to this hook type.
        bytes32 arbitrarySalt = keccak256("MY_FEE_SPLITTER_HOOK_V1");

        // deployData should contain your constructor arguments, abi-encoded.
        // For simplicity in a single-salt deployment, using the salt as deployData sometimes works.
        // However, the correct way is to encode the constructor arguments:
        // This assumes your constructor arguments are (_poolManager, _feeToken, _splitter)
        bytes memory data = abi.encode(
            address(0xA7B8e01F655C72F2fCf7b0b8F9e0633D5c86B8Dc), // PoolManager address from script
            address(0x00000000000000000000000000000000000000AA), // Token address from script
            address(0xd8e751a10C54F16Df924c4f7211e8cA2973E7Fc5) // FeeSplitter address from trace
        );

        return (arbitrarySalt, data);
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
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
        PoolKey calldata,
        SwapParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        int128 amount0 = delta.amount0();

        if (amount0 > 0) {
            splitter.distribute(feeToken, uint256(int256(amount0)));
        }

        return (BaseHook.afterSwap.selector, 0);
    }
}
