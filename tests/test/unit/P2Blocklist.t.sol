// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {UnitBase} from "./UnitBase.sol";
import {Stock} from "stock/Stock.sol";
import {AccessControlled} from "stock/AccessControlled.sol";
import {BeaconProxy} from "oz-proxy/proxy/beacon/BeaconProxy.sol";

contract P2BlocklistTest is UnitBase {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1000);
        _mint(bob, 1000);
        vm.prank(alice);
        token.approve(bob, 500);
        vm.prank(bob);
        token.approve(alice, 500);
    }

    function _expectBlocked(address who) internal {
        vm.expectRevert(abi.encodeWithSelector(AccessControlled.Blocked.selector, who));
    }

    function test_transfer_blockedSender() public {
        _block(alice);
        _expectBlocked(alice);
        vm.prank(alice);
        token.transfer(bob, 1);
    }

    function test_transfer_blockedRecipient() public {
        _block(bob);
        _expectBlocked(bob);
        vm.prank(alice);
        token.transfer(bob, 1);
    }

    function test_transferFrom_blockedOwner() public {
        _block(alice);
        _expectBlocked(alice);
        vm.prank(bob);
        token.transferFrom(alice, carol, 1);
    }

    function test_transferFrom_blockedRecipient() public {
        _block(carol);
        _expectBlocked(carol);
        vm.prank(bob);
        token.transferFrom(alice, carol, 1);
    }

    function test_transferFrom_blockedSpender() public {
        _block(bob);
        _expectBlocked(bob);
        vm.prank(bob);
        token.transferFrom(alice, carol, 1);
    }

    function test_approve_blockedOwner() public {
        _block(alice);
        _expectBlocked(alice);
        vm.prank(alice);
        token.approve(carol, 1);
    }

    function test_approve_blockedSpender() public {
        _block(carol);
        _expectBlocked(carol);
        vm.prank(alice);
        token.approve(carol, 1);
    }

    function test_permit_blockedOwner() public {
        _block(alice);
        (uint8 v, bytes32 r, bytes32 s) = _sign(token, ALICE_PK, carol, 1, block.timestamp);
        _expectBlocked(alice);
        vm.prank(carol);
        token.permit(alice, carol, 1, block.timestamp, v, r, s);
        assertEq(token.nonces(alice), 0);
    }

    function test_permit_blockedSpender() public {
        _block(carol);
        (uint8 v, bytes32 r, bytes32 s) = _sign(token, ALICE_PK, carol, 1, block.timestamp);
        _expectBlocked(carol);
        vm.prank(bob);
        token.permit(alice, carol, 1, block.timestamp, v, r, s);
    }

    function test_permit_blockedRelayer() public {
        _block(bob);
        (uint8 v, bytes32 r, bytes32 s) = _sign(token, ALICE_PK, carol, 1, block.timestamp);
        _expectBlocked(bob);
        vm.prank(bob);
        token.permit(alice, carol, 1, block.timestamp, v, r, s);
        assertEq(token.nonces(alice), 0);
    }

    function test_mint_blockedRecipient() public {
        _block(carol);
        _expectBlocked(carol);
        vm.prank(MINTER);
        token.mint(carol, 1);
    }

    function test_mint_blockedMinter() public {
        _block(MINTER);
        _expectBlocked(MINTER);
        vm.prank(MINTER);
        token.mint(carol, 1);
    }

    function test_burn_blockedHolder() public {
        _block(alice);
        _expectBlocked(alice);
        vm.prank(BURNER);
        token.burn(alice, 1);
    }

    function test_burn_blockedBurner() public {
        _block(BURNER);
        _expectBlocked(BURNER);
        vm.prank(BURNER);
        token.burn(alice, 1);
    }

    function test_adminBurn_ignoresBlockedHolder() public {
        _block(alice);
        vm.prank(ADMIN_BURNER);
        token.adminBurn(alice, 400);
        assertEq(token.balanceOf(alice), 600);
    }

    function test_adminBurn_ignoresBlockedCaller() public {
        _block(ADMIN_BURNER);
        _block(alice);
        vm.prank(ADMIN_BURNER);
        token.adminBurn(alice, 1000);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_blockingMovesNothingAndAllowancesSurvive() public {
        _block(alice);
        _block(bob);
        assertEq(token.balanceOf(alice), 1000);
        assertEq(token.allowance(alice, bob), 500);
        _unblock(alice);
        _unblock(bob);
        vm.prank(bob);
        token.transferFrom(alice, bob, 500);
        assertEq(token.balanceOf(bob), 1500);
    }

    function test_blocklistIsSharedAcrossTokens() public {
        Stock other = Stock(
            address(new BeaconProxy(address(registry), abi.encodeCall(Stock.initialize, (bytes32("AAPL"), "Apple", "AAPL"))))
        );
        vm.prank(MINTER);
        other.mint(alice, 1);
        _block(alice);
        _expectBlocked(alice);
        vm.prank(alice);
        other.transfer(bob, 1);
    }

    function test_unprivilegedFunctionsIgnoreTheBlocklist() public {
        _block(MULTIPLIER_UPDATER);
        _block(METADATA_UPDATER);
        _block(TOKEN_PAUSER);
        _block(ORACLE_PAUSER);
        vm.prank(MULTIPLIER_UPDATER);
        token.updateMultiplier(2e18);
        vm.prank(METADATA_UPDATER);
        token.setMetadata("A", "B");
        vm.prank(ORACLE_PAUSER);
        token.pauseOracle();
        vm.prank(TOKEN_PAUSER);
        token.pause();
        assertTrue(token.paused());
    }

    function testFuzz_blockedBalanceOnlyFallsThroughAdminBurn(uint8 op, uint256 amount) public {
        _block(alice);
        amount = bound(amount, 1, 1000);
        uint256 before = token.balanceOf(alice);
        bytes memory call;
        address caller;
        op = op % 6;
        if (op == 0) (caller, call) = (alice, abi.encodeCall(Stock.transfer, (bob, amount)));
        if (op == 1) (caller, call) = (bob, abi.encodeCall(Stock.transfer, (alice, amount)));
        if (op == 2) (caller, call) = (bob, abi.encodeCall(Stock.transferFrom, (alice, bob, amount)));
        if (op == 3) (caller, call) = (alice, abi.encodeCall(Stock.transferFrom, (bob, alice, amount)));
        if (op == 4) (caller, call) = (MINTER, abi.encodeCall(Stock.mint, (alice, amount)));
        if (op == 5) (caller, call) = (BURNER, abi.encodeCall(Stock.burn, (alice, amount)));
        vm.prank(caller);
        (bool ok,) = address(token).call(call);
        assertFalse(ok);
        assertEq(token.balanceOf(alice), before);
    }
}
