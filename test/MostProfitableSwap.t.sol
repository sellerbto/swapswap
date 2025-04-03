// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MostProfitableSwap} from "../src/MostProfitableSwap.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Vm} from "forge-std/Vm.sol";

contract MostProfitableSwapTest is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant UNISWAP_V3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;

    address constant WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    MostProfitableSwap swapContract;
    
    struct SwapResult {
        uint amountIn;
        uint amountOut;
        string protocol;
    }
    
    event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, string protocol);
    
    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18_000_000); 
        
        swapContract = new MostProfitableSwap(
            UNISWAP_V2_FACTORY,
            UNISWAP_V2_ROUTER,
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_ROUTER,
            UNISWAP_V3_QUOTER
        );
        
        vm.label(WETH, "WETH");
        vm.label(USDC, "USDC");
        vm.label(DAI, "DAI");
        vm.label(UNISWAP_V2_FACTORY, "UNISWAP_V2_FACTORY");
        vm.label(UNISWAP_V2_ROUTER, "UNISWAP_V2_ROUTER");
        vm.label(UNISWAP_V3_FACTORY, "UNISWAP_V3_FACTORY");
        vm.label(UNISWAP_V3_ROUTER, "UNISWAP_V3_ROUTER");
        vm.label(UNISWAP_V3_QUOTER, "UNISWAP_V3_QUOTER");
        vm.label(address(swapContract), "MostProfitableSwap");
        vm.label(WHALE, "WHALE");
    }

    function test_Constructor() public view {
        assertEq(swapContract.uniswapV2Factory(), UNISWAP_V2_FACTORY, "V2 Factory not set correctly");
        assertEq(swapContract.uniswapV2Router(), UNISWAP_V2_ROUTER, "V2 Router not set correctly");
        assertEq(swapContract.uniswapV3Factory(), UNISWAP_V3_FACTORY, "V3 Factory not set correctly");
        assertEq(swapContract.uniswapV3Router(), UNISWAP_V3_ROUTER, "V3 Router not set correctly");
        assertEq(swapContract.uniswapV3Quoter(), UNISWAP_V3_QUOTER, "V3 Quoter not set correctly");
        
        assertEq(swapContract.feeTiers(0), 500, "Fee tier 0 not set correctly");
        assertEq(swapContract.feeTiers(1), 3000, "Fee tier 1 not set correctly");
        assertEq(swapContract.feeTiers(2), 10000, "Fee tier 2 not set correctly");
    }

    function test_WETH_to_USDC_Swap() public {
        uint amountIn = 1 ether; 
        
        deal(WETH, address(this), amountIn);
        
        IERC20(WETH).approve(address(swapContract), amountIn);
        
        uint usdcBefore = IERC20(USDC).balanceOf(address(this));
        
        uint amountOut = swapContract.swapExactInput(
            WETH,
            USDC,
            address(this),
            block.timestamp + 3600, 
            amountIn,
            0 
        );
        
        uint usdcAfter = IERC20(USDC).balanceOf(address(this));
        uint usdcReceived = usdcAfter - usdcBefore;
        
        console.log("WETH to USDC swap");
        console.log("Amount in (WETH):", amountIn);
        console.log("Amount out (USDC):", amountOut);
        console.log("USDC received:", usdcReceived);
        
        assertEq(amountOut, usdcReceived, "Amount out does not match received tokens");
        assertTrue(amountOut > 0, "Swap did not return tokens");
    }
    
    function test_DAI_to_USDC_Swap() public {
        uint amountIn = 10000 * 1e18;
        
        deal(DAI, address(this), amountIn);
        
        IERC20(DAI).approve(address(swapContract), amountIn);
        
        uint usdcBefore = IERC20(USDC).balanceOf(address(this));
        
        uint amountOut = swapContract.swapExactInput(
            DAI,
            USDC,
            address(this),
            block.timestamp + 3600, 
            amountIn,
            0 
        );
        
        uint usdcAfter = IERC20(USDC).balanceOf(address(this));
        uint usdcReceived = usdcAfter - usdcBefore;
        
        console.log("DAI to USDC swap");
        console.log("Amount in (DAI):", amountIn);
        console.log("Amount out (USDC):", amountOut);
        console.log("USDC received:", usdcReceived);
        
        assertEq(amountOut, usdcReceived, "Amount out does not match received tokens");
        assertTrue(amountOut > 0, "Swap did not return tokens");
    }
    
    receive() external payable {}
} 