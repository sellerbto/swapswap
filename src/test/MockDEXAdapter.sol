// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { IDEXAdapter } from "../interfaces/IDEXAdapter.sol";
import { SafeERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockDEXAdapter is IDEXAdapter {
    using SafeERC20 for IERC20;
    
    string public dexName;
    
    mapping(address => mapping(address => uint256)) public mockRates;
    
    event SwapExecuted(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    
    constructor(string memory _dexName) {
        dexName = _dexName;
    }
    
    function setMockRate(address tokenIn, address tokenOut, uint256 rate) external {
        mockRates[tokenIn][tokenOut] = rate;
    }
    
    function getDexName() external view override returns (string memory) {
        return dexName;
    }
    
    function getQuote(address tokenIn, address tokenOut, uint256 amountIn) 
        external 
        view 
        override 
        returns (uint256 amountOut, bytes memory extraData) 
    {
        uint256 rate = mockRates[tokenIn][tokenOut];
        if (rate == 0) {
            return (0, "");
        }
        
        amountOut = (amountIn * rate) / 1e18;
        return (amountOut, "");
    }
    
    function executeSwap(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes memory
    ) external override returns (uint256 amountOut) {
        uint256 rate = mockRates[tokenIn][tokenOut];
        require(rate > 0, "No mock rate set for this pair");
        
        amountOut = (amountIn * rate) / 1e18;
        require(amountOut >= minAmountOut, "Insufficient output amount");
        
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        IERC20(tokenOut).transfer(recipient, amountOut);
        
        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut);
        
        return amountOut;
    }
} 