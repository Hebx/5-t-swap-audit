// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TSwapPoolHandler is Test {
    TSwapPool public pool;
    ERC20Mock public poolToken;
    ERC20Mock public weth;

    address user = makeAddr("user");
    address liquidityProvider = makeAddr("liquidityProvider");

    // Ghost Variables
    int256 public expectedDeltaX;
    int256 public expectedDeltaY;
    int256 public actualDeltaX;
    int256 public actualDeltaY;

    int256 public startingY;
    int256 public startingX;
    int256 public endingY;
    int256 public endingX;
    // DeltaY == outputAmount (outputWeth)
    // DeltaX == inputAmount (poolTokenAmount)
    // x == inputReserve (poolToken balance)
    // y == outputReserves (weth balance)

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(address(pool.getWeth()));
        poolToken = ERC20Mock(address(pool.getPoolToken()));
    }

    function swapPoolTokensBasedOnOutputWeth(uint256 outputWeth) public {
        outputWeth = bound(outputWeth, 0, type(uint64).max);
        if (outputWeth >= weth.balanceOf(address(pool))) {
            return;
        }
        // Based on x * y = (x + ∆x) * (y − ∆y) => ∆x = (β/(1-β)) * x where β = (∆y / y)
        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
            outputWeth, poolToken.balanceOf(address(pool)), weth.balanceOf(address(pool))
        );

        if (poolTokenAmount >= type(uint64).max) {
            return;
        }
        startingY = int256(weth.balanceOf(address(this)));
        startingX = int256(poolToken.balanceOf(address(this)));
        expectedDeltaX = int256(pool.getPoolTokensToDepositBasedOnWeth(poolTokenAmount));
        expectedDeltaY = int256(outputWeth);

        if (poolToken.balanceOf(address(user)) < poolTokenAmount) {
            poolToken.mint(user, poolTokenAmount - poolToken.balanceOf(address(user)) + 1); // ????
        }
        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        vm.stopPrank();
        // Actual Invariants
        endingX = int256(poolToken.balanceOf(address(this)));
        endingY = int256(weth.balanceOf(address(this)));

        actualDeltaY = endingY - startingY;
        actualDeltaX = endingX - startingX;
    }

    function deposit(uint256 wethAmountToDeposit) public {
        startingY = int256(weth.balanceOf(address(this)));
        startingX = int256(poolToken.balanceOf(address(this)));
        wethAmountToDeposit = bound(wethAmountToDeposit, pool.getMinimumWethDepositAmount(), type(uint64).max);
        uint256 poolTokensAmountToDepositBasedOnWeth = pool.getPoolTokensToDepositBasedOnWeth(wethAmountToDeposit);
        expectedDeltaX = int256(poolTokensAmountToDepositBasedOnWeth);
        expectedDeltaY = int256(wethAmountToDeposit);
        // Deposit
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmountToDeposit);
        poolToken.mint(liquidityProvider, poolTokensAmountToDepositBasedOnWeth);
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        pool.deposit(wethAmountToDeposit, 0, poolTokensAmountToDepositBasedOnWeth, uint64(block.timestamp));
        vm.stopPrank();

        // Actual Invariants
        endingX = int256(poolToken.balanceOf(address(this)));
        endingY = int256(weth.balanceOf(address(this)));

        actualDeltaY = endingY - startingY;
        actualDeltaX = endingX - startingX;
    }
}
