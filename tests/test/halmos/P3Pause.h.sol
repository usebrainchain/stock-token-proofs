// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {HalmosBase} from "./HalmosBase.sol";
import {Stock} from "stock/Stock.sol";
import {ADMIN_BURNER_ROLE, METADATA_UPDATER_ROLE, TOKEN_PAUSER_ROLE, ORACLE_PAUSER_ROLE} from "stock/Roles.sol";

/// For every token pause flag, registry pause flag and token state.
contract P3PauseHalmos is HalmosBase {
    function _tokenFlag() internal view returns (bool) {
        return uint256(vm.load(address(token), bytes32(uint256(STOCK_SLOT) + 1))) & 0xff != 0;
    }

    function _registryFlag() internal view returns (bool) {
        return (uint256(vm.load(address(registry), bytes32(uint256(1)))) >> 160) & 0xff != 0;
    }

    function check_pausedIsEitherFlag() public view {
        assert(token.paused() == (_tokenFlag() || _registryFlag()));
        assert(token.tokenPaused() == _tokenFlag());
    }

    function check_gatedCallsRevertWhilePaused(address caller) public {
        bytes memory data = svm.createCalldata("Stock");
        bytes4 selector = bytes4(data);
        vm.assume(
            selector == Stock.transfer.selector || selector == Stock.transferFrom.selector
                || selector == Stock.approve.selector || selector == Stock.permit.selector
                || selector == Stock.mint.selector || selector == Stock.burn.selector
                || selector == bytes4(keccak256("updateMultiplier(uint256)"))
                || selector == bytes4(keccak256("updateMultiplier(uint256,uint256)"))
        );
        vm.assume(token.paused());
        assert(!_call(caller, data));
    }

    function check_whilePausedOnlyAdminBurnMovesValue(address caller, address x, address y) public {
        bytes memory data = svm.createCalldata("Stock");
        vm.assume(bytes4(data) != Stock.adminBurn.selector);
        vm.assume(token.paused());
        uint256 supply = token.totalSupply();
        uint256 bx = token.balanceOf(x);
        uint256 axy = token.allowance(x, y);
        uint256 nx = token.nonces(x);
        _call(caller, data);
        assert(token.totalSupply() == supply);
        assert(token.balanceOf(x) == bx);
        assert(token.allowance(x, y) == axy);
        assert(token.nonces(x) == nx);
    }

    function check_adminBurn_availableWhilePaused(address caller, address from, uint256 amount) public {
        _defaultMultiplier();
        vm.assume(token.paused());
        vm.assume(registry.hasRole(ADMIN_BURNER_ROLE, caller));
        vm.assume(from != address(0));
        vm.assume(amount <= token.balanceOf(from) && token.balanceOf(from) <= token.totalSupply());
        vm.assume(amount < 1 << 192);
        assert(_call(caller, abi.encodeCall(Stock.adminBurn, (from, amount))));
    }

    function check_adminFunctionsAvailableWhilePaused(address caller, bool flag) public {
        vm.assume(token.paused());
        vm.assume(registry.hasRole(METADATA_UPDATER_ROLE, caller));
        vm.assume(registry.hasRole(TOKEN_PAUSER_ROLE, caller));
        vm.assume(registry.hasRole(ORACLE_PAUSER_ROLE, caller));
        assert(_call(caller, abi.encodeCall(Stock.setMetadata, ("Renamed", "RN"))));
        assert(_call(caller, flag ? abi.encodeCall(Stock.pause, ()) : abi.encodeCall(Stock.unpause, ())));
        assert(_call(caller, flag ? abi.encodeCall(Stock.pauseOracle, ()) : abi.encodeCall(Stock.unpauseOracle, ())));
    }

    function check_scheduledMultiplierMaturesWhilePaused(uint256 t) public {
        vm.assume(token.paused());
        uint256 scheduled = token.newUIMultiplier();
        vm.assume(uint256(vm.load(address(token), bytes32(uint256(SCALED_SLOT) + 1))) != 0);
        vm.assume(t >= token.effectiveAt() && t >= block.timestamp);
        vm.warp(t);
        assert(token.uiMultiplier() == scheduled);
    }
}
