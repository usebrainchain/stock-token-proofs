// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {UnitBase} from "./UnitBase.sol";
import {Stock} from "stock/Stock.sol";
import {BLOCKER_ROLE} from "stock/Roles.sol";
import {BeaconProxy} from "oz-proxy/proxy/beacon/BeaconProxy.sol";

contract P3PauseTest is UnitBase {
    uint8 internal constant TOKEN = 1;
    uint8 internal constant REGISTRY = 2;
    uint8 internal constant BOTH = 3;

    function setUp() public override {
        super.setUp();
        _mint(alice, 1000);
        vm.prank(alice);
        token.approve(bob, 500);
    }

    function _pause(uint8 mode) internal {
        if (mode & TOKEN != 0) _pauseToken();
        if (mode & REGISTRY != 0) _pauseRegistry();
        assertTrue(token.paused());
    }

    function _gatedCalls() internal view returns (address[8] memory callers, bytes[8] memory calls) {
        (uint8 v, bytes32 r, bytes32 s) = _sign(token, ALICE_PK, carol, 1, block.timestamp);
        callers = [alice, bob, alice, carol, MINTER, BURNER, MULTIPLIER_UPDATER, MULTIPLIER_UPDATER];
        calls = [
            abi.encodeCall(Stock.transfer, (bob, 1)),
            abi.encodeCall(Stock.transferFrom, (alice, bob, 1)),
            abi.encodeCall(Stock.approve, (carol, 1)),
            abi.encodeCall(Stock.permit, (alice, carol, 1, block.timestamp, v, r, s)),
            abi.encodeCall(Stock.mint, (alice, 1)),
            abi.encodeCall(Stock.burn, (alice, 1)),
            abi.encodeWithSignature("updateMultiplier(uint256)", 2e18),
            abi.encodeWithSignature("updateMultiplier(uint256,uint256)", 2e18, block.timestamp + 1)
        ];
    }

    function _assertAllGatedCallsRevert() internal {
        (address[8] memory callers, bytes[8] memory calls) = _gatedCalls();
        for (uint256 i; i < calls.length; ++i) {
            vm.prank(callers[i]);
            (bool ok, bytes memory ret) = address(token).call(calls[i]);
            assertFalse(ok, "gated call succeeded while paused");
            assertEq(bytes4(ret), Stock.IsPaused.selector);
        }
    }

    function test_gatedCallsSucceedWhenUnpaused() public {
        (address[8] memory callers, bytes[8] memory calls) = _gatedCalls();
        for (uint256 i; i < calls.length; ++i) {
            vm.prank(callers[i]);
            (bool ok,) = address(token).call(calls[i]);
            assertTrue(ok);
        }
    }

    function test_tokenPauseRevertsGatedCalls() public {
        _pause(TOKEN);
        _assertAllGatedCallsRevert();
    }

    function test_registryPauseRevertsGatedCalls() public {
        _pause(REGISTRY);
        assertFalse(token.tokenPaused());
        _assertAllGatedCallsRevert();
    }

    function test_bothPausedRevertsGatedCalls() public {
        _pause(BOTH);
        _assertAllGatedCallsRevert();
    }

    function testFuzz_adminBurnStaysAvailable(uint8 mode, uint256 amount) public {
        _pause(uint8(bound(mode, 1, 3)));
        amount = bound(amount, 0, 1000);
        vm.prank(ADMIN_BURNER);
        token.adminBurn(alice, amount);
        assertEq(token.balanceOf(alice), 1000 - amount);
        assertEq(token.totalSupply(), 1000 - amount);
    }

    function test_ungatedFunctionsWorkWhilePaused() public {
        _pause(BOTH);
        vm.prank(METADATA_UPDATER);
        token.setMetadata("N", "S");
        vm.prank(ORACLE_PAUSER);
        token.pauseOracle();
        vm.prank(ORACLE_PAUSER);
        token.unpauseOracle();
        vm.prank(TOKEN_PAUSER);
        token.pause();
        _block(carol);
        _unblock(carol);
        vm.prank(ADMIN);
        registry.grantRole(BLOCKER_ROLE, carol);
        assertEq(token.name(), "N");
    }

    function test_scheduledMultiplierMaturesWhilePaused() public {
        vm.prank(MULTIPLIER_UPDATER);
        token.updateMultiplier(4e18, block.timestamp + 1 hours);
        _pause(BOTH);
        assertEq(token.uiMultiplier(), 1e18);
        vm.warp(block.timestamp + 1 hours);
        assertEq(token.uiMultiplier(), 4e18);
        assertEq(token.balanceOfUI(alice), 4000);
    }

    function test_pausesAreIndependent() public {
        _pause(BOTH);
        vm.prank(TOKEN_PAUSER);
        token.unpause();
        assertTrue(token.paused());
        _assertAllGatedCallsRevert();
        _pauseToken();
        vm.prank(REGISTRY_PAUSER);
        registry.unpause();
        assertTrue(token.paused());
        _assertAllGatedCallsRevert();
        vm.prank(TOKEN_PAUSER);
        token.unpause();
        assertFalse(token.paused());
    }

    function test_registryPauseCoversEveryToken() public {
        Stock other = Stock(
            address(new BeaconProxy(address(registry), abi.encodeCall(Stock.initialize, (bytes32("TSLA"), "Tesla", "TSLA"))))
        );
        _pauseRegistry();
        assertTrue(other.paused());
        assertFalse(other.tokenPaused());
    }

    function test_oraclePauseGatesNothing() public {
        vm.prank(ORACLE_PAUSER);
        token.pauseOracle();
        assertTrue(token.oraclePaused());
        assertFalse(token.paused());
        test_gatedCallsSucceedWhenUnpaused();
    }
}
