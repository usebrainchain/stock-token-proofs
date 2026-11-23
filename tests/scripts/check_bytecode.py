#!/usr/bin/env python3
"""Confirms the contracts under test are the deployed code.

Compares the runtime bytecode forge built from ../onchain with the chain bytecode in ../onchain/*/runtime-bytecode.hex,
ignoring only the trailing CBOR metadata (it hashes source paths, which differ here) and masking the immutable
spans (Stock's 17 copies of ACCESS_CONTROLLED_REGISTRY). Run `forge build` first.
"""

import json
import os
import sys

TESTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS = [
    ("Stock", "out/Stock.sol/Stock.json", "../onchain/Stock/runtime-bytecode.hex"),
    ("AccessControlsRegistry", "out/AccessControlsRegistry.sol/AccessControlsRegistry.json",
     "../onchain/Registry/runtime-bytecode.hex"),
]


def strip_metadata(code):
    return code[: -(int.from_bytes(code[-2:], "big") + 2)]


def main():
    ok = True
    for name, artifact, chain_hex in TARGETS:
        with open(os.path.join(TESTS, artifact)) as f:
            deployed = json.load(f)["deployedBytecode"]
        with open(os.path.join(TESTS, chain_hex)) as f:
            chain = bytes.fromhex(f.read().strip().removeprefix("0x"))
        built = bytes.fromhex(deployed["object"].removeprefix("0x"))
        a, b = bytearray(strip_metadata(built)), bytearray(strip_metadata(chain))
        spans = [(r["start"], r["length"]) for refs in deployed.get("immutableReferences", {}).values() for r in refs]
        for start, length in spans:
            a[start : start + length] = bytes(length)
            b[start : start + length] = bytes(length)
        same = len(built) == len(chain) and a == b
        ok &= same
        print(f"{name}: {len(built)} bytes built, {len(chain)} on chain, {len(spans)} immutable spans masked: "
              f"{'identical' if same else 'DIFFERENT'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
