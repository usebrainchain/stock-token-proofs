// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {UnitBase} from "./UnitBase.sol";
import {Stock} from "stock/Stock.sol";
import {AccessControlled} from "stock/AccessControlled.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {BeaconProxy} from "oz-proxy/proxy/beacon/BeaconProxy.sol";
import {
    DEFAULT_ADMIN_ROLE,
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

contract P5RolesTest is UnitBase {
    uint256 internal constant N = 10;

    function setUp() public override {
        super.setUp();
        _mint(alice, 1000);
    }

    function _tokenGates() internal view returns (bytes32[N] memory roles, address[N] memory holders, bytes[N] memory calls) {
        roles = [
            MINTER_ROLE,
            BURNER_ROLE,
            ADMIN_BURNER_ROLE,
            TOKEN_PAUSER_ROLE,
            TOKEN_PAUSER_ROLE,
            MULTIPLIER_UPDATER_ROLE,
            MULTIPLIER_UPDATER_ROLE,
            ORACLE_PAUSER_ROLE,
            ORACLE_PAUSER_ROLE,
            METADATA_UPDATER_ROLE
        ];
        holders = [
            MINTER,
            BURNER,
            ADMIN_BURNER,
            TOKEN_PAUSER,
            TOKEN_PAUSER,
            MULTIPLIER_UPDATER,
            MULTIPLIER_UPDATER,
            ORACLE_PAUSER,
            ORACLE_PAUSER,
            METADATA_UPDATER
        ];
        calls = [
            abi.encodeCall(Stock.mint, (alice, 1)),
            abi.encodeCall(Stock.burn, (alice, 1)),
            abi.encodeCall(Stock.adminBurn, (alice, 1)),
            abi.encodeCall(Stock.pause, ()),
            abi.encodeCall(Stock.unpause, ()),
            abi.encodeWithSignature("updateMultiplier(uint256)", 2e18),
            abi.encodeWithSignature("updateMultiplier(uint256,uint256)", 2e18, block.timestamp + 1),
            abi.encodeCall(Stock.pauseOracle, ()),
            abi.encodeCall(Stock.unpauseOracle, ()),
            abi.encodeCall(Stock.setMetadata, ("N", "S"))
        ];
    }

    function test_holdersCanCallTheirFunctions() public {
        (, address[N] memory holders, bytes[N] memory calls) = _tokenGates();
        for (uint256 i; i < N; ++i) {
            vm.prank(holders[i]);
            (bool ok,) = address(token).call(calls[i]);
            assertTrue(ok);
        }
    }

    function testFuzz_tokenFunctionsRevertWithoutTheRole(address caller) public {
        (bytes32[N] memory roles,, bytes[N] memory calls) = _tokenGates();
        for (uint256 i; i < N; ++i) {
            if (registry.hasRole(roles[i], caller)) continue;
            vm.prank(caller);
            (bool ok, bytes memory ret) = address(token).call(calls[i]);
            assertFalse(ok);
            assertEq(ret, abi.encodeWithSelector(AccessControlled.AccessControlUnauthorizedAccount.selector, caller, roles[i]));
        }
    }

    function test_otherRoleHoldersAreRefused() public {
        (bytes32[N] memory roles,, bytes[N] memory calls) = _tokenGates();
        address[11] memory everyone = _roleHolders();
        for (uint256 i; i < N; ++i) {
            for (uint256 j; j < everyone.length; ++j) {
                if (registry.hasRole(roles[i], everyone[j])) continue;
                vm.prank(everyone[j]);
                (bool ok,) = address(token).call(calls[i]);
                assertFalse(ok);
            }
        }
    }

    function test_updateMultiplierChecksPauseBeforeRole() public {
        _pauseToken();
        vm.expectRevert(Stock.IsPaused.selector);
        vm.prank(carol);
        token.updateMultiplier(2e18);
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.AccessControlUnauthorizedAccount.selector, carol, MINTER_ROLE));
        vm.prank(carol);
        token.mint(alice, 1);
    }

    function testFuzz_registryFunctionsRevertWithoutTheRole(address caller) public {
        address[] memory list = new address[](1);
        list[0] = alice;
        bytes32[6] memory roles =
            [PAUSER_ROLE, PAUSER_ROLE, BEACON_UPGRADER_ROLE, BLOCKER_ROLE, BLOCKER_ROLE, DEFAULT_ADMIN_ROLE];
        bytes[6] memory calls = [
            abi.encodeWithSignature("pause()"),
            abi.encodeWithSignature("unpause()"),
            abi.encodeWithSignature("upgradeTo(address)", address(impl)),
            abi.encodeWithSignature("blockAccounts(address[])", list),
            abi.encodeWithSignature("unblockAccounts(address[])", list),
            abi.encodeWithSignature("grantRole(bytes32,address)", MINTER_ROLE, caller)
        ];
        for (uint256 i; i < calls.length; ++i) {
            if (registry.hasRole(roles[i], caller)) continue;
            vm.prank(caller);
            (bool ok, bytes memory ret) = address(registry).call(calls[i]);
            assertFalse(ok);
            assertEq(ret, abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, roles[i]));
        }
        if (!registry.hasRole(DEFAULT_ADMIN_ROLE, caller)) {
            vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, DEFAULT_ADMIN_ROLE));
            vm.prank(caller);
            registry.revokeRole(MINTER_ROLE, MINTER);
        }
    }

    function test_renounceOnlyForSelf() public {
        vm.expectRevert(IAccessControl.AccessControlBadConfirmation.selector);
        vm.prank(carol);
        registry.renounceRole(MINTER_ROLE, MINTER);
        vm.prank(MINTER);
        registry.renounceRole(MINTER_ROLE, MINTER);
        assertFalse(registry.hasRole(MINTER_ROLE, MINTER));
    }

    function test_everyRoleIsAdministeredByDefaultAdmin() public view {
        bytes32[11] memory roles = [
            DEFAULT_ADMIN_ROLE,
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
        ];
        for (uint256 i; i < roles.length; ++i) {
            assertEq(registry.getRoleAdmin(roles[i]), DEFAULT_ADMIN_ROLE);
        }
    }

    function test_revocationIsImmediate() public {
        vm.prank(ADMIN);
        registry.revokeRole(MINTER_ROLE, MINTER);
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.AccessControlUnauthorizedAccount.selector, MINTER, MINTER_ROLE));
        vm.prank(MINTER);
        token.mint(alice, 1);
    }

    function test_aRoleCoversEveryTokenOnTheRegistry() public {
        Stock other = Stock(
            address(new BeaconProxy(address(registry), abi.encodeCall(Stock.initialize, (bytes32("AAPL"), "Apple", "AAPL"))))
        );
        vm.prank(MINTER);
        other.mint(alice, 5);
        vm.prank(ADMIN_BURNER);
        other.adminBurn(alice, 5);
        assertEq(other.totalSupply(), 0);
    }

    function test_beaconUpgraderSwapsTheImplementationOfEveryToken() public {
        Stock replacement = new Stock(address(registry));
        vm.prank(UPGRADER);
        registry.upgradeTo(address(replacement));
        assertEq(registry.implementation(), address(replacement));
        assertEq(token.balanceOf(alice), 1000);
        vm.expectRevert(abi.encodeWithSignature("BeaconInvalidImplementation(address)", carol));
        vm.prank(UPGRADER);
        registry.upgradeTo(carol);
    }
}
