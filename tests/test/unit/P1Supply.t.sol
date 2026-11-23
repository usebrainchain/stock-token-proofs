// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Fixture} from "../Fixture.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {stdError} from "forge-std/StdError.sol";

contract P1SupplyTest is Fixture {
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        _deploy();
    }

    function testFuzz_mintAddsExactly(uint256 seed, uint256 amount) public {
        seed = bound(seed, 0, type(uint256).max - 1);
        _mint(bob, seed);
        amount = bound(amount, 0, type(uint256).max - seed);
        _mint(alice, amount);
        assertEq(token.totalSupply(), seed + amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(bob), seed);
    }

    function testFuzz_burnRemovesExactly(uint256 minted, uint256 burned) public {
        minted = bound(minted, 0, type(uint256).max - 7);
        burned = bound(burned, 0, minted);
        _mint(alice, minted);
        _mint(bob, 7);
        vm.prank(BURNER);
        token.burn(alice, burned);
        assertEq(token.totalSupply(), minted - burned + 7);
        assertEq(token.balanceOf(alice), minted - burned);
        assertEq(token.balanceOf(bob), 7);
    }

    function testFuzz_adminBurnRemovesExactly(uint256 minted, uint256 burned) public {
        minted = bound(minted, 0, type(uint256).max - 7);
        burned = bound(burned, 0, minted);
        _mint(alice, minted);
        _mint(bob, 7);
        vm.prank(ADMIN_BURNER);
        token.adminBurn(alice, burned);
        assertEq(token.totalSupply(), minted - burned + 7);
        assertEq(token.balanceOf(alice), minted - burned);
        assertEq(token.balanceOf(bob), 7);
    }

    function test_burnNeedsNoAllowanceFromTheHolder() public {
        _mint(alice, 100);
        assertEq(token.allowance(alice, BURNER), 0);
        vm.prank(BURNER);
        token.burn(alice, 100);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_mintOverflowReverts() public {
        _mint(alice, type(uint256).max);
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(MINTER);
        token.mint(bob, 1);
    }

    function test_mintToZeroReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(MINTER);
        token.mint(address(0), 1);
    }

    function test_burnFromZeroReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        vm.prank(BURNER);
        token.burn(address(0), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        vm.prank(ADMIN_BURNER);
        token.adminBurn(address(0), 0);
    }

    function test_burnBeyondBalanceReverts() public {
        _mint(alice, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 10, 11));
        vm.prank(BURNER);
        token.burn(alice, 11);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 10, 11));
        vm.prank(ADMIN_BURNER);
        token.adminBurn(alice, 11);
    }

    function test_nonSupplyFunctionsLeaveSupplyAlone() public {
        _mint(alice, 1000);
        uint256 supply = token.totalSupply();
        vm.prank(alice);
        token.transfer(bob, 100);
        vm.prank(alice);
        token.approve(bob, 50);
        vm.prank(bob);
        token.transferFrom(alice, bob, 50);
        vm.prank(MULTIPLIER_UPDATER);
        token.updateMultiplier(3e18);
        vm.prank(MULTIPLIER_UPDATER);
        token.updateMultiplier(5e18, block.timestamp + 1 days);
        vm.warp(block.timestamp + 2 days);
        vm.prank(METADATA_UPDATER);
        token.setMetadata("X", "Y");
        _pauseToken();
        vm.prank(TOKEN_PAUSER);
        token.unpause();
        vm.prank(ORACLE_PAUSER);
        token.pauseOracle();
        _block(alice);
        assertEq(token.totalSupply(), supply);
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), supply);
    }
}
