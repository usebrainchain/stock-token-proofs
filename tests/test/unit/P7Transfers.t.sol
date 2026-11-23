// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {UnitBase} from "./UnitBase.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

contract P7TransfersTest is UnitBase {
    function setUp() public override {
        super.setUp();
        _mint(alice, 1000);
        _mint(bob, 1000);
        _mint(carol, 1000);
        vm.prank(carol);
        token.approve(bob, 333);
    }

    function _snapshot() internal view returns (uint256[3] memory b, uint256 s, uint256 carolBob) {
        b = [token.balanceOf(alice), token.balanceOf(bob), token.balanceOf(carol)];
        s = token.totalSupply();
        carolBob = token.allowance(carol, bob);
    }

    function testFuzz_transferMovesExactlyValue(uint256 value) public {
        value = bound(value, 0, 1000);
        (uint256[3] memory b, uint256 s, uint256 cb) = _snapshot();
        vm.prank(alice);
        assertTrue(token.transfer(bob, value));
        assertEq(token.balanceOf(alice), b[0] - value);
        assertEq(token.balanceOf(bob), b[1] + value);
        assertEq(token.balanceOf(carol), b[2]);
        assertEq(token.totalSupply(), s);
        assertEq(token.allowance(carol, bob), cb);
    }

    function testFuzz_selfTransferChangesNothing(uint256 value) public {
        value = bound(value, 0, 1000);
        vm.prank(alice);
        token.transfer(alice, value);
        assertEq(token.balanceOf(alice), 1000);
    }

    function test_transferBeyondBalanceReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1000, 1001));
        vm.prank(alice);
        token.transfer(bob, 1001);
    }

    function test_transferToZeroReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(alice);
        token.transfer(address(0), 1);
    }

    function testFuzz_transferFromSpendsExactlyValue(uint256 allowance, uint256 value) public {
        allowance = bound(allowance, 0, type(uint256).max - 1);
        value = bound(value, 0, allowance < 1000 ? allowance : 1000);
        vm.prank(alice);
        token.approve(bob, allowance);
        (uint256[3] memory b, uint256 s, uint256 cb) = _snapshot();
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, carol, value));
        assertEq(token.allowance(alice, bob), allowance - value);
        assertEq(token.balanceOf(alice), b[0] - value);
        assertEq(token.balanceOf(carol), b[2] + value);
        assertEq(token.balanceOf(bob), b[1]);
        assertEq(token.totalSupply(), s);
        assertEq(token.allowance(carol, bob), cb);
    }

    function testFuzz_infiniteAllowanceIsNotSpent(uint256 value) public {
        value = bound(value, 0, 1000);
        vm.prank(alice);
        token.approve(bob, type(uint256).max);
        vm.prank(bob);
        token.transferFrom(alice, carol, value);
        assertEq(token.allowance(alice, bob), type(uint256).max);
        assertEq(token.balanceOf(carol), 1000 + value);
    }

    function test_ownerMovingOwnTokensThroughTransferFromNeedsAllowance() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transferFrom(alice, bob, 1);
        vm.prank(alice);
        token.approve(alice, 5);
        vm.prank(alice);
        token.transferFrom(alice, bob, 5);
        assertEq(token.allowance(alice, alice), 0);
    }

    function test_transferFromBeyondAllowanceReverts() public {
        vm.prank(alice);
        token.approve(bob, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 10, 11));
        vm.prank(bob);
        token.transferFrom(alice, carol, 11);
    }

    function test_transferFromBeyondBalanceReverts() public {
        vm.prank(alice);
        token.approve(bob, 5000);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1000, 1001));
        vm.prank(bob);
        token.transferFrom(alice, carol, 1001);
    }

    function testFuzz_approveSetsExactly(uint256 first, uint256 second) public {
        vm.prank(alice);
        token.approve(bob, first);
        vm.prank(alice);
        token.approve(bob, second);
        assertEq(token.allowance(alice, bob), second);
        assertEq(token.allowance(carol, bob), 333);
        assertEq(token.balanceOf(alice), 1000);
    }

    function test_approveZeroSpenderReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(alice);
        token.approve(address(0), 1);
    }

    function testFuzz_permitSetsAllowanceAndBumpsNonce(uint256 value) public {
        _permit(carol, bob, value);
        assertEq(token.allowance(alice, bob), value);
        assertEq(token.nonces(alice), 1);
        assertEq(token.balanceOf(alice), 1000);
    }

    function test_permitReplayFails() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(token, ALICE_PK, bob, 10, block.timestamp);
        token.permit(alice, bob, 10, block.timestamp, v, r, s);
        vm.expectPartialRevert(ERC20PermitUpgradeable.ERC2612InvalidSigner.selector);
        token.permit(alice, bob, 10, block.timestamp, v, r, s);
    }

    function test_permitExpiredFails() public {
        vm.warp(1000);
        (uint8 v, bytes32 r, bytes32 s) = _sign(token, ALICE_PK, bob, 10, 999);
        vm.expectRevert(abi.encodeWithSelector(ERC20PermitUpgradeable.ERC2612ExpiredSignature.selector, 999));
        token.permit(alice, bob, 10, 999, v, r, s);
    }
}
