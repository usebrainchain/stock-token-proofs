// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {HalmosBase} from "./HalmosBase.sol";
import {Stock} from "stock/Stock.sol";
import {
    MINTER_ROLE,
    BURNER_ROLE,
    PAUSER_ROLE,
    BEACON_UPGRADER_ROLE,
    MULTIPLIER_UPDATER_ROLE,
    METADATA_UPDATER_ROLE,
    BLOCKER_ROLE,
    ADMIN_BURNER_ROLE,
    TOKEN_PAUSER_ROLE,
    ORACLE_PAUSER_ROLE
} from "stock/Roles.sol";

/// For every registry role assignment and every token state: a caller the registry does not list for a
/// function's role is refused.
contract P5RolesHalmos is HalmosBase {
    function _refused(bytes32 role, address caller, address target, bytes memory data) internal {
        vm.assume(!registry.hasRole(role, caller));
        vm.prank(caller);
        (bool ok,) = target.call(data);
        assert(!ok);
    }

    function check_mint(address caller, address to, uint256 amount) public {
        _refused(MINTER_ROLE, caller, address(token), abi.encodeCall(Stock.mint, (to, amount)));
    }

    function check_burn(address caller, address from, uint256 amount) public {
        _refused(BURNER_ROLE, caller, address(token), abi.encodeCall(Stock.burn, (from, amount)));
    }

    function check_adminBurn(address caller, address from, uint256 amount) public {
        _refused(ADMIN_BURNER_ROLE, caller, address(token), abi.encodeCall(Stock.adminBurn, (from, amount)));
    }

    function check_pause(address caller) public {
        _refused(TOKEN_PAUSER_ROLE, caller, address(token), abi.encodeCall(Stock.pause, ()));
    }

    function check_unpause(address caller) public {
        _refused(TOKEN_PAUSER_ROLE, caller, address(token), abi.encodeCall(Stock.unpause, ()));
    }

    function check_updateMultiplier(address caller, uint256 m) public {
        _refused(
            MULTIPLIER_UPDATER_ROLE, caller, address(token), abi.encodeWithSignature("updateMultiplier(uint256)", m)
        );
    }

    function check_updateMultiplierAt(address caller, uint256 m, uint256 at) public {
        _refused(
            MULTIPLIER_UPDATER_ROLE,
            caller,
            address(token),
            abi.encodeWithSignature("updateMultiplier(uint256,uint256)", m, at)
        );
    }

    function check_pauseOracle(address caller) public {
        _refused(ORACLE_PAUSER_ROLE, caller, address(token), abi.encodeCall(Stock.pauseOracle, ()));
    }

    function check_unpauseOracle(address caller) public {
        _refused(ORACLE_PAUSER_ROLE, caller, address(token), abi.encodeCall(Stock.unpauseOracle, ()));
    }

    function check_setMetadata(address caller, string memory n, string memory s) public {
        _refused(METADATA_UPDATER_ROLE, caller, address(token), abi.encodeCall(Stock.setMetadata, (n, s)));
    }

    function check_registryPause(address caller, bool on) public {
        _refused(PAUSER_ROLE, caller, address(registry), abi.encodeWithSignature(on ? "pause()" : "unpause()"));
    }

    function check_registryUpgradeTo(address caller) public {
        _refused(
            BEACON_UPGRADER_ROLE, caller, address(registry), abi.encodeWithSignature("upgradeTo(address)", address(impl))
        );
    }

    function check_registryBlocklist(address caller, address account, bool on) public {
        address[] memory list = new address[](1);
        list[0] = account;
        _refused(
            BLOCKER_ROLE,
            caller,
            address(registry),
            abi.encodeWithSignature(on ? "blockAccounts(address[])" : "unblockAccounts(address[])", list)
        );
    }

    function check_registryRoleAdmin(address caller, bytes32 role, address account, bool grant) public {
        _refused(
            registry.getRoleAdmin(role),
            caller,
            address(registry),
            abi.encodeWithSignature(grant ? "grantRole(bytes32,address)" : "revokeRole(bytes32,address)", role, account)
        );
    }

    function check_registryRenounceOnlySelf(address caller, bytes32 role, address account) public {
        vm.assume(caller != account);
        vm.prank(caller);
        (bool ok,) = address(registry).call(abi.encodeWithSignature("renounceRole(bytes32,address)", role, account));
        assert(!ok);
    }

    function check_unprivilegedCallerCannotTouchAdminState(address caller) public {
        vm.assume(!registry.hasRole(MINTER_ROLE, caller));
        vm.assume(!registry.hasRole(BURNER_ROLE, caller));
        vm.assume(!registry.hasRole(ADMIN_BURNER_ROLE, caller));
        vm.assume(!registry.hasRole(TOKEN_PAUSER_ROLE, caller));
        vm.assume(!registry.hasRole(MULTIPLIER_UPDATER_ROLE, caller));
        vm.assume(!registry.hasRole(ORACLE_PAUSER_ROLE, caller));
        vm.assume(!registry.hasRole(METADATA_UPDATER_ROLE, caller));
        bytes memory data = svm.createCalldata("Stock");
        uint256 supply = token.totalSupply();
        bool paused = token.tokenPaused();
        bool oracle = token.oraclePaused();
        bytes32 nameHash = keccak256(bytes(token.name()));
        bytes32 symbolHash = keccak256(bytes(token.symbol()));
        bytes32 uid = token.uid();
        bytes32 s0 = vm.load(address(token), SCALED_SLOT);
        bytes32 s1 = vm.load(address(token), bytes32(uint256(SCALED_SLOT) + 1));
        bytes32 s2 = vm.load(address(token), bytes32(uint256(SCALED_SLOT) + 2));
        _call(caller, data);
        assert(token.totalSupply() == supply);
        assert(token.tokenPaused() == paused);
        assert(token.oraclePaused() == oracle);
        assert(keccak256(bytes(token.name())) == nameHash);
        assert(keccak256(bytes(token.symbol())) == symbolHash);
        assert(token.uid() == uid);
        assert(vm.load(address(token), SCALED_SLOT) == s0);
        assert(vm.load(address(token), bytes32(uint256(SCALED_SLOT) + 1)) == s1);
        assert(vm.load(address(token), bytes32(uint256(SCALED_SLOT) + 2)) == s2);
    }
}
