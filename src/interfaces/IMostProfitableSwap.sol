// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IMostProfitableSwap {
    function swapExactInput(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut);
}