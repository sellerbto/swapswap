// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IDEXAdapter {
    function getDexName() external view returns (string memory);

    function getQuote(address tokenIn, address tokenOut, uint256 amountIn) 
        external 
        returns (uint256 amountOut, bytes memory extraData);

    function executeSwap(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes memory extraData
    ) external returns (uint256 amountOut);
} 