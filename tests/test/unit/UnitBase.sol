// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Fixture} from "../Fixture.sol";
import {Stock} from "stock/Stock.sol";

abstract contract UnitBase is Fixture {
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 internal constant ALICE_PK = 0xA11CE;
    address internal alice;
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA201);

    function setUp() public virtual {
        _deploy();
        alice = vm.addr(ALICE_PK);
    }

    function _sign(Stock t, uint256 pk, address spender, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        address owner = vm.addr(pk);
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, t.nonces(owner), deadline));
        (v, r, s) = vm.sign(pk, keccak256(abi.encodePacked("\x19\x01", t.DOMAIN_SEPARATOR(), structHash)));
    }

    function _permit(address relayer, address spender, uint256 value) internal {
        (uint8 v, bytes32 r, bytes32 s) = _sign(token, ALICE_PK, spender, value, block.timestamp);
        vm.prank(relayer);
        token.permit(alice, spender, value, block.timestamp, v, r, s);
    }
}
