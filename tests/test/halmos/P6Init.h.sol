// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {HalmosBase} from "./HalmosBase.sol";
import {Stock} from "stock/Stock.sol";

contract P6InitHalmos is HalmosBase {
    uint256 internal constant INIT_MASK = (1 << 72) - 1;

    function check_implementationNeverInitialises(address caller, bytes32 uid, string memory n, string memory s)
        public
    {
        vm.prank(caller);
        (bool ok,) = address(impl).call(abi.encodeCall(Stock.initialize, (uid, n, s)));
        assert(!ok);
    }

    function check_noCallReenablesInitialisationOfTheImplementation(address caller) public {
        svm.enableSymbolicStorage(address(impl));
        vm.store(address(impl), INITIALIZABLE_SLOT, bytes32(uint256(type(uint64).max)));
        vm.store(address(impl), bytes32(uint256(ERC20_SLOT) + 3), bytes32(0));
        vm.store(address(impl), bytes32(uint256(ERC20_SLOT) + 4), bytes32(0));
        bytes memory data = svm.createCalldata("Stock");
        vm.prank(caller);
        (bool ok,) = address(impl).call(data);
        assert(!ok || bytes4(data) != Stock.initialize.selector);
        assert(uint256(vm.load(address(impl), INITIALIZABLE_SLOT)) & INIT_MASK == type(uint64).max);
    }

    function check_proxyInitialisesAtMostOnce(address first, address second, bytes32 uid, bytes32 uid2) public {
        uint256 word = svm.createUint256("initializable");
        vm.store(address(token), INITIALIZABLE_SLOT, bytes32(word));
        vm.prank(first);
        (bool ok,) = address(token).call(abi.encodeCall(Stock.initialize, (uid, "Apple", "AAPL")));
        if (ok) {
            assert(word & INIT_MASK == 0);
            assert(uint256(vm.load(address(token), INITIALIZABLE_SLOT)) & INIT_MASK == 1);
            assert(token.uid() == uid);
        }
        vm.prank(second);
        (bool again,) = address(token).call(abi.encodeCall(Stock.initialize, (uid2, "Tesla", "TSLA")));
        assert(!(ok && again));
        if (word & INIT_MASK != 0) assert(!ok);
    }

    function check_noCallResetsTheProxyInitialisedFlag(address caller) public {
        bytes memory data = svm.createCalldata("Stock");
        _call(caller, data);
        assert(uint256(vm.load(address(token), INITIALIZABLE_SLOT)) & INIT_MASK == 1);
    }
}
