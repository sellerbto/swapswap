// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { IDEXAdapter } from "../interfaces/IDEXAdapter.sol";
import { SafeERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract UniswapV2Adapter is IDEXAdapter {
    using SafeERC20 for IERC20;
    
    address public immutable factory;
    address public immutable router;
    
    error SwapFailed();
    
    constructor(address _factory, address _router) {
        factory = _factory;
        router = _router;
    }
    
    function getDexName() external view override returns (string memory) {
        return "Uniswap V2";
    }
    
    function getQuote(address tokenIn, address tokenOut, uint256 amountIn) 
        external 
        view 
        override 
        returns (uint256 amountOut, bytes memory extraData) 
    {
        address pair = IUniswapV2Factory(factory).getPair(tokenIn, tokenOut);
        if (pair == address(0)) {
            return (0, "");
        }
        
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        try IUniswapV2Router02(router).getAmountsOut(amountIn, path) returns (uint[] memory amounts) {
            return (amounts[1], "");
        } catch {
            return (0, "");
        }
    }
    
    function executeSwap(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes memory
    ) external override returns (uint256 amountOut) {
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        SafeERC20.forceApprove(IERC20(tokenIn), router, amountIn);
        
        try IUniswapV2Router02(router).swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            recipient,
            deadline
        ) returns (uint[] memory amounts) {
            amountOut = amounts[amounts.length - 1];
            SafeERC20.forceApprove(IERC20(tokenIn), router, 0);
            return amountOut;
        } catch {
            SafeERC20.forceApprove(IERC20(tokenIn), router, 0);
            revert SwapFailed();
        }
    }
} 