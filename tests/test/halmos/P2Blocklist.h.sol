// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {HalmosBase} from "./HalmosBase.sol";
import {Stock} from "stock/Stock.sol";
import {ADMIN_BURNER_ROLE} from "stock/Roles.sol";

/// For every registry blocklist and every token state.
contract P2BlocklistHalmos is HalmosBase {
    function _blocked(address a) internal view returns (bool) {
        return registry.isBlocked(a);
    }

    function check_transfer_refusesBlockedParties(address caller, address to, uint256 value) public {
        bool ok = _call(caller, abi.encodeCall(Stock.transfer, (to, value)));
        assert(!ok || !(_blocked(caller) || _blocked(to)));
    }

    function check_transferFrom_refusesBlockedParties(address caller, address from, address to, uint256 value)
        public
    {
        bool ok = _call(caller, abi.encodeCall(Stock.transferFrom, (from, to, value)));
        assert(!ok || !(_blocked(caller) || _blocked(from) || _blocked(to)));
    }

    function check_approve_refusesBlockedParties(address caller, address spender, uint256 value) public {
        bool ok = _call(caller, abi.encodeCall(Stock.approve, (spender, value)));
        assert(!ok || !(_blocked(caller) || _blocked(spender)));
    }

    function check_permit_refusesBlockedParties(address caller) public {
        (address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            _symbolicPermit();
        bool ok = _call(caller, abi.encodeCall(Stock.permit, (owner, spender, value, deadline, v, r, s)));
        assert(!ok || !(_blocked(caller) || _blocked(owner) || _blocked(spender)));
    }

    function check_mint_refusesBlockedParties(address caller, address to, uint256 amount) public {
        bool ok = _call(caller, abi.encodeCall(Stock.mint, (to, amount)));
        assert(!ok || !(_blocked(caller) || _blocked(to)));
    }

    function check_burn_refusesBlockedParties(address caller, address from, uint256 amount) public {
        bool ok = _call(caller, abi.encodeCall(Stock.burn, (from, amount)));
        assert(!ok || !(_blocked(caller) || _blocked(from)));
    }

    function check_adminBurn_ignoresTheBlocklist(address caller, address from, uint256 amount) public {
        _defaultMultiplier();
        vm.assume(registry.hasRole(ADMIN_BURNER_ROLE, caller));
        vm.assume(from != address(0));
        vm.assume(amount <= token.balanceOf(from) && token.balanceOf(from) <= token.totalSupply());
        vm.assume(amount < 1 << 192);
        assert(_call(caller, abi.encodeCall(Stock.adminBurn, (from, amount))));
    }

    function check_onlyAdminBurnTouchesABlockedAccount(address caller, address blocked, address other) public {
        bytes memory data = svm.createCalldata("Stock");
        vm.assume(bytes4(data) != Stock.adminBurn.selector);
        vm.assume(_blocked(blocked));
        uint256 balance = token.balanceOf(blocked);
        uint256 given = token.allowance(blocked, other);
        uint256 received = token.allowance(other, blocked);
        uint256 nonce = token.nonces(blocked);
        _call(caller, data);
        assert(token.balanceOf(blocked) == balance);
        assert(token.allowance(blocked, other) == given);
        assert(token.allowance(other, blocked) == received);
        assert(token.nonces(blocked) == nonce);
    }
}
