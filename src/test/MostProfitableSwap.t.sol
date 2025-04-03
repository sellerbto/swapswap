// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../MostProfitableSwap.sol";
import "./MockDEXAdapter.sol";
import "./MockERC20.sol";

contract MostProfitableSwapTest is Test {
    MostProfitableSwap public swapper;
    MockDEXAdapter public dex1;
    MockDEXAdapter public dex2;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    
    address public alice = address(0x1);
    uint256 public constant INITIAL_BALANCE = 1000 * 1e18;
    
    function setUp() public {
        swapper = new MostProfitableSwap();
        
        dex1 = new MockDEXAdapter("MockDEX1");
        dex2 = new MockDEXAdapter("MockDEX2");
        
        tokenA = new MockERC20("Token A", "TKA", 18);
        tokenB = new MockERC20("Token B", "TKB", 18);
        
        dex1.setMockRate(address(tokenA), address(tokenB), 2 * 1e18);
        
        dex2.setMockRate(address(tokenA), address(tokenB), 15 * 1e17);
        
        swapper.addAdapter(dex1);
        swapper.addAdapter(dex2);
        
        tokenA.mint(alice, INITIAL_BALANCE);
        
        tokenB.mint(address(dex1), INITIAL_BALANCE * 10);
        tokenB.mint(address(dex2), INITIAL_BALANCE * 10);
        
        vm.startPrank(alice);
        tokenA.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
    }
    
    function testAddRemoveAdapter() public {
        assertEq(swapper.getAdapterCount(), 2);
        
        MockDEXAdapter dex3 = new MockDEXAdapter("MockDEX3");
        swapper.addAdapter(dex3);
        assertEq(swapper.getAdapterCount(), 3);
        
        swapper.removeAdapter(dex1);
        assertEq(swapper.getAdapterCount(), 2);
    }
    
    function testSwapChoosesMostProfitableDEX() public {
        uint256 amountIn = 100 * 1e18;
        uint256 minAmountOut = 150 * 1e18;
        uint256 deadline = block.timestamp + 3600;
        
        vm.startPrank(alice);
        
        uint256 amountOut = swapper.swapExactInput(
            address(tokenA),
            address(tokenB),
            alice,
            deadline,
            amountIn,
            minAmountOut
        );
        
        vm.stopPrank();
        
        assertEq(tokenA.balanceOf(alice), INITIAL_BALANCE - amountIn);
        assertEq(tokenB.balanceOf(alice), amountOut);
        assertEq(amountOut, 200 * 1e18);
    }
    
    function testSwapFailsWithNoAdapters() public {
        swapper.removeAdapter(dex1);
        swapper.removeAdapter(dex2);
        
        uint256 amountIn = 100 * 1e18;
        uint256 minAmountOut = 150 * 1e18;
        uint256 deadline = block.timestamp + 3600;
        
        vm.startPrank(alice);
        
        vm.expectRevert(abi.encodeWithSignature("NoAdaptersRegistered()"));
        swapper.swapExactInput(
            address(tokenA),
            address(tokenB),
            alice,
            deadline,
            amountIn,
            minAmountOut
        );
        
        vm.stopPrank();
    }
} 