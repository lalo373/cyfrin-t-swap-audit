// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";

contract PoC_InputAmountFee is Test {
    TSwapPool pool;

    function setUp() public {
        // Pure pricing functions don't touch these addresses, so placeholders are fine.
        // Adjust the constructor arguments if your TSwapPool signature differs.
        pool = new TSwapPool(address(0x1), address(0x2), "LP Token", "LP");
    }

    function test_InputAmountIsTenTimesTooHigh() public view {
        uint256 inputReserves = 100e18;
        uint256 outputReserves = 100e18;
        uint256 outputAmount = 1e18;

        // What the pool currently returns
        uint256 actualInput = pool.getInputAmountBasedOnOutput(
            outputAmount,
            inputReserves,
            outputReserves
        );

        // Expected: the 0.3% fee means the multiplier should be 1000/997
        uint256 expectedInput = (inputReserves * outputAmount * 1_000)
            / ((outputReserves - outputAmount) * 997);

        console.log("Expected input (wei):", expectedInput);
        console.log("Actual input   (wei):", actualInput);

        // Sanity check: the buggy version is exactly 10x the correct one
        assertEq(actualInput, expectedInput * 10, "buggy input should be 10x expected");

        // The real assertion that fails on the vulnerable code
        assertApproxEqAbs(actualInput, expectedInput, 1e15, "input amount is too high");
    }

    function test_RoundTripShowsUserOverpays() public view {
        uint256 inputReserves = 100e18;
        uint256 outputReserves = 100e18;
        uint256 outputAmount = 1e18;

        uint256 actualInput = pool.getInputAmountBasedOnOutput(
            outputAmount,
            inputReserves,
            outputReserves
        );

        // Feed the quoted input back into the forward pricing function.
        // A correct quote should return roughly outputAmount.
        uint256 receivedOutput = pool.getOutputAmountBasedOnInput(
            actualInput,
            inputReserves,
            outputReserves
        );

        console.log("Output received from buggy quote (wei):", receivedOutput);

        // The user pays ~10x what's needed, so they receive far less than they asked for
        // in the sense of overpaying for the same output.
        assertGt(actualInput, expectedInputFor(inputReserves, outputReserves, outputAmount));
    }

    function expectedInputFor(
        uint256 inputReserves,
        uint256 outputReserves,
        uint256 outputAmount
    ) internal pure returns (uint256) {
        return (inputReserves * outputAmount * 1_000)
            / ((outputReserves - outputAmount) * 997);
    }
}
