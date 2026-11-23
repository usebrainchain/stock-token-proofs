// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {HalmosBase} from "./HalmosBase.sol";
import {Stock} from "stock/Stock.sol";

/// For every multiplier storage state, timestamp and token state.
contract P4MultiplierHalmos is HalmosBase {
    function check_uiMultiplierNeverZero(uint256 t) public {
        vm.warp(t);
        assert(token.uiMultiplier() > 0);
        assert(token.newUIMultiplier() > 0);
    }

    function check_updateRejectsZeroAndPast(address caller, uint256 m, uint256 at) public {
        vm.assume(m == 0 || at < block.timestamp);
        assert(!_call(caller, abi.encodeWithSignature("updateMultiplier(uint256,uint256)", m, at)));
        if (m == 0) assert(!_call(caller, abi.encodeWithSignature("updateMultiplier(uint256)", m)));
    }

    function check_updateLeavesRawStateAlone(address caller, uint256 m, uint256 at, bool immediate, address x, address y)
        public
    {
        uint256 supply = token.totalSupply();
        uint256 bx = token.balanceOf(x);
        uint256 axy = token.allowance(x, y);
        uint256 nx = token.nonces(x);
        bytes memory data = immediate
            ? abi.encodeWithSignature("updateMultiplier(uint256)", m)
            : abi.encodeWithSignature("updateMultiplier(uint256,uint256)", m, at);
        if (_call(caller, data)) {
            assert(token.totalSupply() == supply);
            assert(token.balanceOf(x) == bx);
            assert(token.allowance(x, y) == axy);
            assert(token.nonces(x) == nx);
        }
    }

    function check_scheduleAppliesExactlyFromItsTime(address caller, uint256 m, uint256 at, uint256 t) public {
        uint256 inForce = token.uiMultiplier();
        vm.assume(t >= block.timestamp);
        if (_call(caller, abi.encodeWithSignature("updateMultiplier(uint256,uint256)", m, at))) {
            assert(token.newUIMultiplier() == m);
            assert(token.effectiveAt() == at);
            vm.warp(t);
            assert(token.uiMultiplier() == (t >= at ? m : inForce));
        }
    }

    function check_immediateFormAppliesNow(address caller, uint256 m) public {
        if (_call(caller, abi.encodeWithSignature("updateMultiplier(uint256)", m))) {
            assert(token.uiMultiplier() == m);
            assert(token.effectiveAt() == block.timestamp);
        }
    }

    function check_onlyUpdateMultiplierWritesTheSchedule(address caller) public {
        bytes memory data = svm.createCalldata("Stock");
        bytes4 selector = bytes4(data);
        vm.assume(
            selector != bytes4(keccak256("updateMultiplier(uint256)"))
                && selector != bytes4(keccak256("updateMultiplier(uint256,uint256)"))
        );
        bytes32 a = vm.load(address(token), SCALED_SLOT);
        bytes32 b = vm.load(address(token), bytes32(uint256(SCALED_SLOT) + 1));
        bytes32 c = vm.load(address(token), bytes32(uint256(SCALED_SLOT) + 2));
        _call(caller, data);
        assert(vm.load(address(token), SCALED_SLOT) == a);
        assert(vm.load(address(token), bytes32(uint256(SCALED_SLOT) + 1)) == b);
        assert(vm.load(address(token), bytes32(uint256(SCALED_SLOT) + 2)) == c);
    }
}
