// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Fixture} from "../Fixture.sol";
import {Stock} from "stock/Stock.sol";

/// Starts from the production topology, then replaces the token's and the registry's storage with fully
/// symbolic storage: every balance, allowance, nonce, role, blocklist entry, pause flag and multiplier slot is
/// an unconstrained value. Pinned concretely: the proxy's beacon slot and the registry's implementation
/// pointer (so calls reach the real code), the proxy's initialised flag (1, not initialising) and its name and
/// symbol. The registry pause bit, packed beside the implementation pointer, stays symbolic.
abstract contract HalmosBase is SymTest, Fixture {
    function setUp() public virtual {
        _deploy();
        svm.enableSymbolicStorage(address(token));
        svm.enableSymbolicStorage(address(registry));
        vm.store(address(token), BEACON_SLOT, bytes32(uint256(uint160(address(registry)))));
        vm.store(address(token), INITIALIZABLE_SLOT, bytes32(uint256(1)));
        vm.store(address(token), bytes32(uint256(ERC20_SLOT) + 3), _short("NVIDIA"));
        vm.store(address(token), bytes32(uint256(ERC20_SLOT) + 4), _short("NVDA"));
        uint256 registryPaused = svm.createUint(1, "registryPaused");
        vm.store(
            address(registry), bytes32(uint256(1)), bytes32(uint256(uint160(address(impl))) | (registryPaused << 160))
        );
    }

    function _short(string memory s) internal pure returns (bytes32 word) {
        bytes memory b = bytes(s);
        word = bytes32(b);
        word |= bytes32(b.length * 2);
    }

    function _call(address caller, bytes memory data) internal returns (bool ok) {
        vm.prank(caller);
        (ok,) = address(token).call(data);
    }

    function _defaultMultiplier() internal {
        vm.store(address(token), SCALED_SLOT, bytes32(0));
        vm.store(address(token), bytes32(uint256(SCALED_SLOT) + 1), bytes32(0));
    }

    function _symbolicPermit()
        internal
        pure
        returns (address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    {
        owner = svm.createAddress("owner");
        spender = svm.createAddress("spender");
        value = svm.createUint256("value");
        deadline = svm.createUint256("deadline");
        v = uint8(svm.createUint(8, "v"));
        r = svm.createBytes32("r");
        s = svm.createBytes32("s");
    }
}
