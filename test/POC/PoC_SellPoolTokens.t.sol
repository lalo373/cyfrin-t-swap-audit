// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract PoC_SellPoolTokens is Test {
    TSwapPool pool;
    ERC20Mock weth;
    ERC20Mock poolToken;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        weth = new ERC20Mock();
        poolToken = new ERC20Mock();
        pool = new TSwapPool(address(poolToken), address(weth), "LP Token", "LP");

        weth.mint(liquidityProvider, 100e18);
        poolToken.mint(liquidityProvider, 100e18);
        poolToken.mint(user, 1000e18); // extra balance so the buggy path doesn't revert on balance

        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();
    }

    function test_SellPoolTokensMismatchesInputAndOutput() public {
        uint256 sellAmount = 10e18;

        // What the user should receive for selling 10 pool tokens into a 100/100 pool
        uint256 expectedWeth = pool.getOutputAmountBasedOnInput(sellAmount, 100e18, 100e18);

        uint256 poolTokenBefore = poolToken.balanceOf(user);
        uint256 wethBefore = weth.balanceOf(user);

        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        pool.sellPoolTokens(sellAmount);
        vm.stopPrank();

        uint256 poolTokensSpent = poolTokenBefore - poolToken.balanceOf(user);
        uint256 wethReceived = weth.balanceOf(user) - wethBefore;

        emit log_named_uint("Expected WETH (wei)", expectedWeth);
        emit log_named_uint("Actual WETH (wei)", wethReceived);
        emit log_named_uint("Pool tokens spent (wei)", poolTokensSpent);

        assertEq(poolTokensSpent, sellAmount, "spent a different amount of pool tokens than requested");
        assertApproxEqAbs(wethReceived, expectedWeth, 1e15, "received wrong WETH amount");
    }
}
