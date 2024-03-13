// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { TswapPoolHandler } from "./TSwapPoolHandler.t.sol";

contract Invariant is StdInvariant, Test {
    ERC20Mock public poolToken;
    ERC20Mock public weth;
    PoolFactory public factory;
    TSwapPool public pool;
    TswapPoolHandler public handler;

    int256 constant STARTING_X = 100e18; // starting ERC20
    int256 constant STARTING_Y = 50e18; // starting WETH
    int256 constant MATH_PRECISION = 1e18;

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        factory = new PoolFactory(address(weth));
        pool = TSwapPool(factory.createPool(address(poolToken)));

        // Create the initial X & Y values of the pool
        poolToken.mint(address(this), uint256(STARTING_X));
        weth.mint(address(this), uint256(STARTING_Y));
        poolToken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);
        pool.deposit(uint256(STARTING_Y), uint256(STARTING_Y), uint256(STARTING_X), uint64(block.timestamp));

        handler = new TswapPoolHandler(pool);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.swapPoolTokensBasedOnOutputWeth.selector;
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        targetContract(address(handler));
    }

    function invariant_constantProductFormulaStaysTheSame() public {
        assertEq(handler.actualDeltaX(), handler.expectedDeltaX());
    }
}
