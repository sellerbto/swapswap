// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { IDEXAdapter } from "../interfaces/IDEXAdapter.sol";
import { SafeERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { IQuoter } from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract UniswapV3Adapter is IDEXAdapter {
    using SafeERC20 for IERC20;
    
    address public immutable factory;
    address public immutable router;
    address public immutable quoter;
    
    uint24[] public feeTiers;
    
    event QuoteFailed(address indexed tokenIn, address indexed tokenOut, uint24 feeTier, string reason);
    
    error SwapFailed();
    
    constructor(address _factory, address _router, address _quoter) {
        factory = _factory;
        router = _router;
        quoter = _quoter;
        
        feeTiers = [500, 3000, 10000];
    }
    
    function getDexName() external view override returns (string memory) {
        return "Uniswap V3";
    }
    
    function getQuote(address tokenIn, address tokenOut, uint256 amountIn) 
        external 
        override 
        returns (uint256 bestAmountOut, bytes memory extraData) 
    {
        bestAmountOut = 0;
        uint24 bestFeeTier = 0;
        
        for (uint i = 0; i < feeTiers.length; i++) {
            uint24 feeTier = feeTiers[i];
            address pool = IUniswapV3Factory(factory).getPool(tokenIn, tokenOut, feeTier);
            
            if (pool == address(0)) continue;
            
            try IQuoter(quoter).quoteExactInputSingle(
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
        
        if (bestAmountOut > 0) {
            extraData = abi.encode(bestFeeTier);
        }
        
        return (bestAmountOut, extraData);
    }
    
    function executeSwap(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes memory extraData
    ) external override returns (uint256 amountOut) {
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        uint24 fee = 3000;
        if (extraData.length > 0) {
            fee = abi.decode(extraData, (uint24));
        }
        
        SafeERC20.forceApprove(IERC20(tokenIn), router, amountIn);
        
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
        
        try ISwapRouter(router).exactInputSingle(params) returns (uint256 result) {
            amountOut = result;
            SafeERC20.forceApprove(IERC20(tokenIn), router, 0);
            return amountOut;
        } catch {
            SafeERC20.forceApprove(IERC20(tokenIn), router, 0);
            revert SwapFailed();
        }
    }
} 