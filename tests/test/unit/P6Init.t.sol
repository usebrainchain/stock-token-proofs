// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {UnitBase} from "./UnitBase.sol";
import {Stock} from "stock/Stock.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {BeaconProxy} from "oz-proxy/proxy/beacon/BeaconProxy.sol";
import {IBeacon} from "oz-proxy/proxy/beacon/IBeacon.sol";

/// Delegates `initialize` twice from inside its own constructor, which OpenZeppelin's `initializer`
/// permits while the caller has no code yet.
contract TwiceInConstructor {
    constructor(address beacon) {
        address implementation = IBeacon(beacon).implementation();
        (bool first,) = implementation.delegatecall(abi.encodeCall(Stock.initialize, (bytes32("A"), "First", "F")));
        (bool second,) = implementation.delegatecall(abi.encodeCall(Stock.initialize, (bytes32("B"), "Second", "S")));
        require(first && second);
    }
}

contract P6InitTest is UnitBase {
    function testFuzz_implementationCannotBeInitialised(address caller, bytes32 uid, string calldata n, string calldata s)
        public
    {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(caller);
        impl.initialize(uid, n, s);
    }

    function test_implementationInitializersAreDisabledForever() public view {
        assertEq(uint64(uint256(vm.load(address(impl), INITIALIZABLE_SLOT))), type(uint64).max);
    }

    function testFuzz_proxyInitialisesOnce(address caller, bytes32 uid, string calldata n, string calldata s) public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(caller);
        token.initialize(uid, n, s);
        assertEq(token.uid(), UID);
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(uint64(uint256(vm.load(address(token), INITIALIZABLE_SLOT))), 1);
    }

    function test_anUninitialisedProxyCanBeInitialisedByAnyoneOnce() public {
        Stock bare = Stock(address(new BeaconProxy(address(registry), "")));
        assertEq(bare.name(), "");
        vm.prank(carol);
        bare.initialize(bytes32("X"), "Squatted", "SQ");
        assertEq(bare.name(), "Squatted");
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(ADMIN);
        bare.initialize(UID, NAME, SYMBOL);
    }

    function test_constructorExemptionAllowsRepeatedInitialisationBeforeCodeExists() public {
        address twice = address(new TwiceInConstructor(address(registry)));
        assertEq(vm.load(twice, STOCK_SLOT), bytes32("B"));
    }

    function test_uidHasNoSetterButNameAndSymbolDo() public {
        vm.prank(METADATA_UPDATER);
        token.setMetadata("Renamed", "RN");
        assertEq(token.uid(), UID);
        assertEq(token.name(), "Renamed");
    }
}
