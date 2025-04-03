// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

contract ForkTest is Test {
    uint256 mainnetFork;
    
    function setUp() public virtual {
        mainnetFork = vm.createFork(vm.envString("ETH_RPC_URL"));
    }
    
    function testOnFork() public {
        vm.selectFork(mainnetFork);
        // Now all calls are executed on the forked network
    }
} 