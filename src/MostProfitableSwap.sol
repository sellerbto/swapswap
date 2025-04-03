// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { IMostProfitableSwap } from "./interfaces/IMostProfitableSwap.sol";
import { SafeERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { IQuoter } from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";


contract MostProfitableSwap is IMostProfitableSwap {
    using SafeERC20 for IERC20;
    
    address public immutable uniswapV2Factory;
    address public immutable uniswapV2Router;
    
    address public immutable uniswapV3Factory;
    address public immutable uniswapV3Router;
    address public immutable uniswapV3Quoter;
    
    uint24[] public feeTiers;

    event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, string protocol);
    event QuoteFailed(address indexed tokenIn, address indexed tokenOut, uint24 feeTier, string reason);
    
    error NoLiquidityAvailableOrNoSuchTradePair(address tokenIn, address tokenOut);
    error SwapFailed();

    constructor(
        address _uniswapV2Factory,
        address _uniswapV2Router,
        address _uniswapV3Factory,
        address _uniswapV3Router,
        address _uniswapV3Quoter
    ) {
        uniswapV2Factory = _uniswapV2Factory;
        uniswapV2Router = _uniswapV2Router;
        uniswapV3Factory = _uniswapV3Factory;
        uniswapV3Router = _uniswapV3Router;
        uniswapV3Quoter = _uniswapV3Quoter;
        
        feeTiers = [500, 3000, 10000];
    }

    function swapExactInput(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut) {
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        uint256 v2AmountOut = getUniswapV2Quote(tokenIn, tokenOut, amountIn);
        (uint256 v3AmountOut, uint24 bestFeeTier) = getBestUniswapV3Quote(tokenIn, tokenOut, amountIn);
        
        if (v2AmountOut == 0 && v3AmountOut == 0) {
            revert NoLiquidityAvailableOrNoSuchTradePair(tokenIn, tokenOut);
        }
        
        if (v2AmountOut > v3AmountOut && v2AmountOut > 0) {
            SafeERC20.forceApprove(IERC20(tokenIn), uniswapV2Router, amountIn);
            amountOut = _executeV2Swap(tokenIn, tokenOut, recipient, deadline, amountIn, minAmountOut);
            SafeERC20.forceApprove(IERC20(tokenIn), uniswapV2Router, 0);
        } else {
            SafeERC20.forceApprove(IERC20(tokenIn), uniswapV3Router, amountIn);
            amountOut = _executeV3Swap(tokenIn, tokenOut, recipient, deadline, amountIn, minAmountOut, bestFeeTier);
            SafeERC20.forceApprove(IERC20(tokenIn), uniswapV3Router, 0);
        }
        
        return amountOut;
    }
    
    function _executeV2Swap(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal returns (uint256 amountOut) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        try IUniswapV2Router02(uniswapV2Router).swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            recipient,
            deadline
        ) returns (uint[] memory amounts) {
            amountOut = amounts[amounts.length - 1];
            emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut, "Uniswap V2");
            return amountOut;
        } catch {
            revert SwapFailed();
        }
    }
    
    function _executeV3Swap(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 fee
    ) internal returns (uint256 amountOut) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: recipient,
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut,
            sqrtPriceLimitX96: 0
        });
        
        try ISwapRouter(uniswapV3Router).exactInputSingle(params) returns (uint256 result) {
            amountOut = result;
            emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut, "Uniswap V3");
            return amountOut;
        } catch {
            revert SwapFailed();
        }
    }
    
    function getUniswapV2Quote(address tokenIn, address tokenOut, uint256 amountIn) internal view returns (uint256) {
        address pair = IUniswapV2Factory(uniswapV2Factory).getPair(tokenIn, tokenOut);
        if (pair == address(0)) {
            return 0;
        }
        
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        try IUniswapV2Router02(uniswapV2Router).getAmountsOut(amountIn, path) returns (uint[] memory amounts) {
            return amounts[1];
        } catch {
            return 0;
        }
    }
    
    function getBestUniswapV3Quote(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256 bestAmountOut, uint24 bestFeeTier) {
        bestAmountOut = 0;
        bestFeeTier = 0;
        
        for (uint i = 0; i < feeTiers.length; i++) {
            uint24 feeTier = feeTiers[i];
            address pool = IUniswapV3Factory(uniswapV3Factory).getPool(tokenIn, tokenOut, feeTier);
            
            if (pool == address(0)) continue;
            
            try IQuoter(uniswapV3Quoter).quoteExactInputSingle(
                tokenIn,
                tokenOut,
                feeTier,
                amountIn,
                0
            ) returns (uint256 amountOut) {
                if (amountOut > bestAmountOut) {
                    bestAmountOut = amountOut;
                    bestFeeTier = feeTier;
                }
            } catch Error(string memory reason) {
                emit QuoteFailed(tokenIn, tokenOut, feeTier, reason);
            } catch {
                emit QuoteFailed(tokenIn, tokenOut, feeTier, "Unknown error");
            }
        }
        
        return (bestAmountOut, bestFeeTier);
    }
}