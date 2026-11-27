// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager, SwapParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Exact-input demo route for the seeded IRL/WETH pool on Robinhood Chain Testnet.
contract IRLTestnetSwapRouter is IUnlockCallback {
    using SafeERC20 for IERC20;

    IPoolManager public immutable manager;
    address public immutable weth;
    address public immutable irl;
    IHooks public immutable hook;

    constructor(IPoolManager manager_, address weth_, address irl_, IHooks hook_) {
        require(block.chainid == 46630, "Robinhood Testnet only");
        manager = manager_;
        weth = weth_;
        irl = irl_;
        hook = hook_;
    }

    function buy(uint128 amountIn, uint128 minIrlOut, uint160 limit, uint256 deadline) external returns (uint256) {
        require(block.timestamp <= deadline && amountIn != 0 && minIrlOut != 0, "Invalid order");
        return abi.decode(manager.unlock(abi.encode(msg.sender, amountIn, minIrlOut, limit)), (uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(manager), "Only PoolManager");
        (address buyer, uint128 amountIn, uint128 minIrlOut, uint160 limit) =
            abi.decode(data, (address, uint128, uint128, uint160));
        bool wethFirst = weth < irl;
        Currency input = Currency.wrap(weth);
        Currency output = Currency.wrap(irl);
        PoolKey memory key = PoolKey(wethFirst ? input : output, wethFirst ? output : input, 3000, 60, hook);

        // The hook collects its fee during the swap, so settle WETH before the callback.
        manager.sync(input);
        IERC20(weth).safeTransferFrom(buyer, address(manager), amountIn);
        require(manager.settle() == amountIn, "WETH settlement mismatch");

        BalanceDelta delta = manager.swap(key, SwapParams(wethFirst, -int256(uint256(amountIn)), limit), "");
        int128 paid = wethFirst ? delta.amount0() : delta.amount1();
        int128 received = wethFirst ? delta.amount1() : delta.amount0();
        require(int256(paid) == -int256(uint256(amountIn)), "Partial fill");
        require(received >= int256(uint256(minIrlOut)), "Insufficient IRL output");
        manager.take(output, buyer, uint256(int256(received)));
        return abi.encode(uint256(int256(received)));
    }
}
