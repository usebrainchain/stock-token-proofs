// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {UnitBase} from "./UnitBase.sol";
import {Stock} from "stock/Stock.sol";

contract P4MultiplierTest is UnitBase {
    uint256 internal t0;

    function setUp() public override {
        super.setUp();
        vm.warp(1_750_000_000);
        t0 = block.timestamp;
        _mint(alice, 1000e18);
        _mint(bob, 1);
    }

    function _now(uint256 m) internal {
        vm.prank(MULTIPLIER_UPDATER);
        token.updateMultiplier(m);
    }

    function _at(uint256 m, uint256 at) internal {
        vm.prank(MULTIPLIER_UPDATER);
        token.updateMultiplier(m, at);
    }

    function test_defaults() public view {
        assertEq(token.uiMultiplier(), 1e18);
        assertEq(token.newUIMultiplier(), 1e18);
        assertEq(token.effectiveAt(), 0);
        assertEq(token.balanceOfUI(alice), 1000e18);
    }

    function test_zeroMultiplierReverts() public {
        vm.expectRevert(bytes("New multiplier must be greater than 0"));
        _now(0);
        vm.expectRevert(bytes("New multiplier must be greater than 0"));
        _at(0, t0 + 1);
    }

    function test_pastEffectiveTimeReverts() public {
        vm.expectRevert(bytes("Effective time must not be in the past"));
        _at(2e18, t0 - 1);
    }

    function test_immediateFormTakesEffectInTheSameBlock() public {
        _now(3e18);
        assertEq(token.uiMultiplier(), 3e18);
        assertEq(token.effectiveAt(), t0);
        assertEq(token.balanceOfUI(alice), 3000e18);
    }

    function testFuzz_scheduledAppliesExactlyFromItsTime(uint256 m, uint256 delay) public {
        m = bound(m, 1, type(uint128).max);
        delay = bound(delay, 1, 365 days);
        _at(m, t0 + delay);
        assertEq(token.uiMultiplier(), 1e18);
        vm.warp(t0 + delay - 1);
        assertEq(token.uiMultiplier(), 1e18);
        vm.warp(t0 + delay);
        assertEq(token.uiMultiplier(), m);
        vm.warp(t0 + delay + 10 * 365 days);
        assertEq(token.uiMultiplier(), m);
    }

    function test_reschedulingBeforeMaturityCancelsThePendingValue() public {
        _at(2e18, t0 + 100);
        vm.warp(t0 + 50);
        _at(5e18, t0 + 200);
        assertEq(token.uiMultiplier(), 1e18);
        vm.warp(t0 + 100);
        assertEq(token.uiMultiplier(), 1e18);
        vm.warp(t0 + 200);
        assertEq(token.uiMultiplier(), 5e18);
    }

    function test_reschedulingAfterMaturityKeepsTheMaturedValueUntilTheNextTime() public {
        _at(2e18, t0 + 100);
        vm.warp(t0 + 150);
        _at(7e18, t0 + 300);
        assertEq(token.uiMultiplier(), 2e18);
        vm.warp(t0 + 299);
        assertEq(token.uiMultiplier(), 2e18);
        vm.warp(t0 + 300);
        assertEq(token.uiMultiplier(), 7e18);
    }

    function test_newUIMultiplierKeepsReportingTheLastScheduledValue() public {
        _at(2e18, t0 + 10);
        assertEq(token.newUIMultiplier(), 2e18);
        vm.warp(t0 + 10);
        assertEq(token.newUIMultiplier(), 2e18);
        assertEq(token.effectiveAt(), t0 + 10);
    }

    function test_scheduleAtMaxTimeNeverApplies() public {
        _at(9e18, type(uint256).max);
        vm.warp(type(uint64).max);
        assertEq(token.uiMultiplier(), 1e18);
    }

    function testFuzz_updateLeavesRawAccountingAlone(uint256 m, uint256 delay) public {
        m = bound(m, 1, type(uint128).max);
        delay = bound(delay, 0, 365 days);
        vm.prank(alice);
        token.approve(bob, 77);
        uint256 a = token.balanceOf(alice);
        uint256 b = token.balanceOf(bob);
        uint256 s = token.totalSupply();
        _at(m, t0 + delay);
        vm.warp(t0 + delay);
        _now(m + 1);
        assertEq(token.balanceOf(alice), a);
        assertEq(token.balanceOf(bob), b);
        assertEq(token.totalSupply(), s);
        assertEq(token.allowance(alice, bob), 77);
        assertEq(token.balanceOfUI(alice), a * (m + 1) / 1e18);
    }

    function testFuzz_uiMultiplierIsNeverZeroInAnyStorageState(uint256 cur, uint256 next, uint256 at, uint256 t)
        public
    {
        vm.store(address(token), SCALED_SLOT, bytes32(cur));
        vm.store(address(token), bytes32(uint256(SCALED_SLOT) + 1), bytes32(next));
        vm.store(address(token), bytes32(uint256(SCALED_SLOT) + 2), bytes32(at));
        vm.warp(t);
        assertGt(token.uiMultiplier(), 0);
        assertGt(token.newUIMultiplier(), 0);
    }

    function test_transferEventCarriesTheScaledValue() public {
        _now(25e17);
        vm.expectEmit(address(token));
        emit TransferWithScaledUI(alice, bob, 2e18, 5e18);
        vm.prank(alice);
        token.transfer(bob, 2e18);
    }

    event TransferWithScaledUI(address indexed from, address indexed to, uint256 value, uint256 uiValue);
}
