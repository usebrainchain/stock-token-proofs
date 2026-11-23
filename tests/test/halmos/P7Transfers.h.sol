// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {HalmosBase} from "./HalmosBase.sol";
import {Stock} from "stock/Stock.sol";

/// Exact effects of the holder-facing calls, from every storage state in which the two touched balances
/// together do not exceed totalSupply (a consequence of the sum invariant). `other`, `o1` and `o2` range over
/// every address outside the call.
contract P7TransfersHalmos is HalmosBase {
    struct Snap {
        uint256 from;
        uint256 to;
        uint256 other;
        uint256 supply;
        uint256 pair;
        uint256 nonce;
    }

    function _snap(address from, address to, address other, address o1, address o2) internal view returns (Snap memory) {
        return Snap(
            token.balanceOf(from),
            token.balanceOf(to),
            token.balanceOf(other),
            token.totalSupply(),
            token.allowance(o1, o2),
            token.nonces(o1)
        );
    }

    function check_transfer_movesExactlyValue(address caller, address to, uint256 value, address other, address o1, address o2)
        public
    {
        vm.assume(other != caller && other != to);
        Snap memory b = _snap(caller, to, other, o1, o2);
        vm.assume(caller == to || b.from + b.to <= b.supply);
        if (_call(caller, abi.encodeCall(Stock.transfer, (to, value)))) {
            unchecked {
                if (caller != to) {
                    assert(token.balanceOf(caller) == b.from - value);
                    assert(token.balanceOf(to) == b.to + value);
                } else {
                    assert(token.balanceOf(caller) == b.from);
                }
            }
            assert(value <= b.from);
            assert(token.balanceOf(other) == b.other);
            assert(token.totalSupply() == b.supply);
            assert(token.allowance(o1, o2) == b.pair);
            assert(token.nonces(o1) == b.nonce);
        }
    }

    function check_transferFrom_movesAndSpendsExactly(
        address caller,
        address from,
        address to,
        uint256 value,
        address other,
        address o1,
        address o2
    ) public {
        vm.assume(other != from && other != to);
        vm.assume(o1 != from || o2 != caller);
        Snap memory b = _snap(from, to, other, o1, o2);
        uint256 allowance = token.allowance(from, caller);
        vm.assume(from == to || b.from + b.to <= b.supply);
        if (_call(caller, abi.encodeCall(Stock.transferFrom, (from, to, value)))) {
            unchecked {
                if (from != to) {
                    assert(token.balanceOf(from) == b.from - value);
                    assert(token.balanceOf(to) == b.to + value);
                } else {
                    assert(token.balanceOf(from) == b.from);
                }
                if (allowance == type(uint256).max) assert(token.allowance(from, caller) == allowance);
                else assert(token.allowance(from, caller) == allowance - value);
            }
            assert(value <= b.from && value <= allowance);
            assert(token.balanceOf(other) == b.other);
            assert(token.totalSupply() == b.supply);
            assert(token.allowance(o1, o2) == b.pair);
            assert(token.nonces(o1) == b.nonce);
        }
    }

    function check_approve_setsExactly(address caller, address spender, uint256 value, address x, address o1, address o2)
        public
    {
        vm.assume(o1 != caller || o2 != spender);
        Snap memory b = _snap(x, x, x, o1, o2);
        if (_call(caller, abi.encodeCall(Stock.approve, (spender, value)))) {
            assert(token.allowance(caller, spender) == value);
            assert(token.allowance(o1, o2) == b.pair);
            assert(token.balanceOf(x) == b.from);
            assert(token.totalSupply() == b.supply);
            assert(token.nonces(o1) == b.nonce);
        }
    }

    function check_permit_setsExactly(address caller, address x, address o1, address o2) public {
        (address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            _symbolicPermit();
        vm.assume(o1 != owner || o2 != spender);
        vm.assume(x != owner);
        Snap memory b = _snap(x, x, x, o1, o2);
        uint256 nonceX = token.nonces(x);
        uint256 nonce = token.nonces(owner);
        if (_call(caller, abi.encodeCall(Stock.permit, (owner, spender, value, deadline, v, r, s)))) {
            assert(token.allowance(owner, spender) == value);
            unchecked {
                assert(token.nonces(owner) == nonce + 1);
            }
            assert(block.timestamp <= deadline);
            assert(token.allowance(o1, o2) == b.pair);
            assert(token.balanceOf(x) == b.from);
            assert(token.totalSupply() == b.supply);
            assert(token.nonces(x) == nonceX);
        }
    }
}
