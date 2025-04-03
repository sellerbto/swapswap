// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { IMostProfitableSwap } from "./interfaces/IMostProfitableSwap.sol";
import { IDEXAdapter } from "./interfaces/IDEXAdapter.sol";
import { SafeERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract MostProfitableSwap is IMostProfitableSwap {
    using SafeERC20 for IERC20;
    
    IDEXAdapter[] public dexAdapters;
    mapping(address => bool) public registeredAdapters;
    
    event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, string protocol);
    event AdapterAdded(address indexed adapter, string name);
    event AdapterRemoved(address indexed adapter);
    
    error NoLiquidityAvailableOrNoSuchTradePair(address tokenIn, address tokenOut);
    error SwapFailed();
    error AdapterAlreadyRegistered(address adapter);
    error AdapterNotRegistered(address adapter);
    error NoAdaptersRegistered();

    constructor() {
        // No default adapters - they should be added after deployment
    }
    
    function addAdapter(IDEXAdapter adapter) external {
        if (registeredAdapters[address(adapter)]) {
            revert AdapterAlreadyRegistered(address(adapter));
        }
        
        dexAdapters.push(adapter);
        registeredAdapters[address(adapter)] = true;
        
        emit AdapterAdded(address(adapter), adapter.getDexName());
    }
    
    function removeAdapter(IDEXAdapter adapter) external {
        if (!registeredAdapters[address(adapter)]) {
            revert AdapterNotRegistered(address(adapter));
        }
        
        for (uint256 i = 0; i < dexAdapters.length; i++) {
            if (address(dexAdapters[i]) == address(adapter)) {
                // Replace with the last adapter and pop
                dexAdapters[i] = dexAdapters[dexAdapters.length - 1];
                dexAdapters.pop();
                break;
            }
        }
        
        registeredAdapters[address(adapter)] = false;
        emit AdapterRemoved(address(adapter));
    }
    
    function getAdapterCount() external view returns (uint256) {
        return dexAdapters.length;
    }

    function swapExactInput(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut) {
        if (dexAdapters.length == 0) {
            revert NoAdaptersRegistered();
        }
        
        // Find the most profitable DEX
        IDEXAdapter bestAdapter;
        uint256 bestAmountOut = 0;
        bytes memory bestExtraData;
        
        for (uint256 i = 0; i < dexAdapters.length; i++) {
            IDEXAdapter adapter = dexAdapters[i];
            (uint256 quote, bytes memory extraData) = adapter.getQuote(tokenIn, tokenOut, amountIn);
            
            if (quote > bestAmountOut) {
                bestAmountOut = quote;
                bestAdapter = adapter;
                bestExtraData = extraData;
            }
        }
        
        if (bestAmountOut == 0 || address(bestAdapter) == address(0)) {
            revert NoLiquidityAvailableOrNoSuchTradePair(tokenIn, tokenOut);
        }
        
        // First approve the adapter to spend our tokens
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(bestAdapter), amountIn);
        
        // Execute swap on the most profitable DEX
        amountOut = bestAdapter.executeSwap(
            tokenIn,
            tokenOut,
            recipient,
            deadline,
            amountIn,
            minAmountOut,
            bestExtraData
        );
        
        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut, bestAdapter.getDexName());
        
        return amountOut;
    }
}