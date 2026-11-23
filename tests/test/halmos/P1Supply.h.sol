// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {HalmosBase} from "./HalmosBase.sol";
import {Stock} from "stock/Stock.sol";

/// Supply accounting per call, from every storage state in which the touched balance does not exceed
/// totalSupply (a consequence of the sum invariant, which the stateful suite checks).
contract P1SupplyHalmos is HalmosBase {
    function check_mint_addsExactlyAmount(address caller, address to, uint256 amount, address other) public {
        vm.assume(other != to);
        uint256 supply = token.totalSupply();
        uint256 toBefore = token.balanceOf(to);
        uint256 otherBefore = token.balanceOf(other);
        vm.assume(toBefore <= supply);
        if (_call(caller, abi.encodeCall(Stock.mint, (to, amount)))) {
            unchecked {
                assert(token.totalSupply() == supply + amount);
                assert(token.totalSupply() >= supply);
                assert(token.balanceOf(to) == toBefore + amount);
            }
            assert(token.balanceOf(other) == otherBefore);
        }
    }

    function check_burn_removesExactlyAmount(address caller, address from, uint256 amount, address other) public {
        _checkBurn(caller, from, amount, other, abi.encodeCall(Stock.burn, (from, amount)));
    }

    function check_adminBurn_removesExactlyAmount(address caller, address from, uint256 amount, address other) public {
        _checkBurn(caller, from, amount, other, abi.encodeCall(Stock.adminBurn, (from, amount)));
    }

    function _checkBurn(address caller, address from, uint256 amount, address other, bytes memory data) internal {
        vm.assume(other != from);
        uint256 supply = token.totalSupply();
        uint256 fromBefore = token.balanceOf(from);
        uint256 otherBefore = token.balanceOf(other);
        vm.assume(fromBefore <= supply);
        if (_call(caller, data)) {
            unchecked {
                assert(token.totalSupply() == supply - amount);
                assert(token.balanceOf(from) == fromBefore - amount);
            }
            assert(amount <= fromBefore);
            assert(token.balanceOf(other) == otherBefore);
        }
    }

    function check_mint_revertsOnSupplyOverflow(address to, uint256 amount) public {
        uint256 supply = token.totalSupply();
        unchecked {
            vm.assume(supply + amount < supply);
        }
        assert(!_call(MINTER, abi.encodeCall(Stock.mint, (to, amount))));
    }

    function check_onlyMintAndBurnsChangeSupply(address caller) public {
        bytes memory data = svm.createCalldata("Stock");
        bytes4 selector = bytes4(data);
        vm.assume(
            selector != Stock.mint.selector && selector != Stock.burn.selector && selector != Stock.adminBurn.selector
        );
        uint256 supply = token.totalSupply();
        _call(caller, data);
        assert(token.totalSupply() == supply);
    }
}
