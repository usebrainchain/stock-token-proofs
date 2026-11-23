// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";

/// A registry that grants no role, blocks nobody and is not paused.
contract DenyAll {
    function hasRole(bytes32, address) external pure returns (bool) { return false; }
    function isBlocked(address) external pure returns (bool) { return false; }
    function paused() external pure returns (bool) { return false; }
}

/// The deployed Stock runtime and a planted mutant of it, run at the address the immutables name
/// for the registry. In the mutant, pause()'s call into _checkRole at 0x10ac (`DUP2 PUSH2 0x1954
/// JUMP`) becomes `JUMP STOP STOP STOP STOP`, so the body jumps straight to the flag write at 0x10b1.
/// An account without the role cannot pause the deployed bytes and can pause the mutant, so the
/// conclusion of pause_requires_role is false on the mutant. scripts/stock-controls/pause-norole.sh
/// in the patched Blanc tree shows the Lean proof fails on the same mutant.
contract PauseNoRoleTest is Test {
    address constant REGISTRY = 0xe10b6f6B275de231345c20D14Ab812db62151b00;
    address constant DEPLOYED = address(0xD1);
    address constant MUTANT = address(0xD2);
    address constant STRANGER = address(0xBEEF);

    function setUp() public {
        vm.etch(REGISTRY, address(new DenyAll()).code);
        bytes memory code = vm.parseBytes(vm.trim(vm.readFile("../../../onchain/Stock/runtime-bytecode.hex")));
        assertEq(sha256(code), 0x0ac99e9cc7a3738645af72f6d9e8fb8242660b63134d8fb0c44ba6fac39deec2);
        vm.etch(DEPLOYED, code);
        bytes memory cut = hex"6110b181611954565b";
        for (uint256 i; i < cut.length; ++i) assertEq(code[0x10a9 + i], cut[i]);
        code[0x10ac] = 0x56;
        for (uint256 i = 0x10ad; i < 0x10b1; ++i) code[i] = 0x00;
        vm.etch(MUTANT, code);
    }

    function test_deployedRefusesStranger() public {
        vm.prank(STRANGER);
        (bool ok,) = DEPLOYED.call(abi.encodeWithSignature("pause()"));
        assertFalse(ok);
        (, bytes memory flag) = DEPLOYED.staticcall(abi.encodeWithSignature("tokenPaused()"));
        assertFalse(abi.decode(flag, (bool)));
    }

    function test_mutantLetsStrangerPause() public {
        vm.prank(STRANGER);
        (bool ok,) = MUTANT.call(abi.encodeWithSignature("pause()"));
        assertTrue(ok);
        (, bytes memory flag) = MUTANT.staticcall(abi.encodeWithSignature("tokenPaused()"));
        assertTrue(abi.decode(flag, (bool)));
    }
}
