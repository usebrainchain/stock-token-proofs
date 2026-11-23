// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {Stock} from "stock/Stock.sol";
import {Handler} from "./Handler.sol";

contract StockInvariants is Test {
    bytes32 internal constant INITIALIZABLE_SLOT = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    Handler internal handler;
    Stock internal token;
    Stock internal impl;

    function setUp() public {
        handler = new Handler();
        (token, impl,) = handler.system();
        targetContract(address(handler));
    }

    function _users() internal view returns (address[5] memory u) {
        for (uint256 i; i < 5; ++i) {
            u[i] = handler.users(i);
        }
    }

    function invariant_P1_balancesSumToTotalSupply() public view {
        address[5] memory u = _users();
        uint256 sum;
        for (uint256 i; i < u.length; ++i) {
            sum += token.balanceOf(u[i]);
        }
        assertEq(sum, token.totalSupply());
        assertEq(handler.violations(1), 0, "P1 outcome");
    }

    function invariant_P1_supplyIsMintedLessBurned() public view {
        assertEq(token.totalSupply(), handler.minted() - handler.burned() - handler.adminBurned());
    }

    function invariant_P2_blockedBalancesOnlyFallByAdminBurn() public view {
        address[5] memory u = _users();
        for (uint256 i; i < u.length; ++i) {
            if (!handler.modelBlocked(u[i])) continue;
            assertEq(token.balanceOf(u[i]), handler.balanceAtBlock(u[i]) - handler.adminBurnedSinceBlock(u[i]));
        }
        assertEq(handler.violations(2), 0, "P2 outcome");
    }

    function invariant_P3_pauseGatesExactlyTheListedCalls() public view {
        assertEq(token.paused(), handler.modelPaused());
        assertEq(handler.violations(3), 0, "P3 outcome");
    }

    function invariant_P4_multiplierFollowsTheSchedule() public view {
        uint256 m = token.uiMultiplier();
        assertGt(m, 0);
        assertEq(m, handler.modelUiMultiplier());
        assertFalse(handler.multiplierMovedRawState());
        assertEq(handler.violations(4), 0, "P4 outcome");
    }

    function invariant_P5_rolesGateEveryPrivilegedCall() public view {
        assertEq(handler.violations(5), 0, "P5 outcome");
    }

    function invariant_P6_initialisedExactlyOnce() public view {
        assertEq(uint256(vm.load(address(token), INITIALIZABLE_SLOT)), 1);
        assertEq(uint256(vm.load(address(impl), INITIALIZABLE_SLOT)), type(uint64).max);
        assertEq(token.uid(), keccak256("NVDA"));
        assertEq(handler.violations(6), 0, "P6 outcome");
    }

    function invariant_P7_balancesAllowancesAndNoncesMatchTheModel() public view {
        address[5] memory u = _users();
        for (uint256 i; i < u.length; ++i) {
            assertEq(token.balanceOf(u[i]), handler.modelBalance(u[i]));
            assertEq(token.nonces(u[i]), handler.modelNonce(u[i]));
            for (uint256 j; j < u.length; ++j) {
                assertEq(token.allowance(u[i], u[j]), handler.modelAllowance(u[i], u[j]));
            }
        }
        assertEq(handler.violations(7), 0, "P7 outcome");
    }

    function afterInvariant() external view {
        assertGt(handler.succeeded(), 0);
    }
}
