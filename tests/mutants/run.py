#!/usr/bin/env python3
"""Runs every test layer against each mutant and writes the mutation matrix.

For mutant M of property P: the unit suites, the invariant campaign restricted to P's invariants, and all
seven Halmos contracts run against a source tree equal to the verified source with M's file swapped in.
A mutant is killed for P when at least one of P's own tests fails; kills by other properties' tests are
recorded too. Usage: python3 mutants/run.py [M01 M02 ...]
"""

import csv
import json
import os
import shutil
import subprocess
import sys
import time

TESTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(TESTS, "..", "onchain", "Stock", "sources", "src")
WORK = os.path.join(TESTS, "mutants", ".work")
RESULTS = os.path.join(TESTS, "mutants", "results.json")
PROPS = ["P1", "P2", "P3", "P4", "P5", "P6", "P7"]


def run(cmd, profile="mutant"):
    env = dict(os.environ, FOUNDRY_PROFILE=profile)
    return subprocess.run(cmd, cwd=TESTS, env=env, capture_output=True, text=True)


def stage(mutant, file):
    # Wipe the build: forge's incremental cache recompiles only the edited file, leaving test contracts that
    # embed Stock's creation code (through `new Stock`) with the previous mutant inside.
    for d in ("src", "out", "cache", "fuzz-failures", "invariant-failures"):
        shutil.rmtree(os.path.join(WORK, d), ignore_errors=True)
    src = os.path.join(WORK, "src")
    shutil.copytree(SRC, src)
    shutil.copy(os.path.join(TESTS, "mutants", mutant, file), os.path.join(src, file))
    if run(["forge", "build"]).returncode:
        raise RuntimeError(f"{mutant} does not compile")


def stock_code(out):
    """Creation and runtime code without the CBOR metadata, which hashes source paths."""
    with open(os.path.join(TESTS, out, "Stock.sol", "Stock.json")) as f:
        artifact = json.load(f)
    runtime = bytes.fromhex(artifact["deployedBytecode"]["object"].removeprefix("0x"))
    creation = bytes.fromhex(artifact["bytecode"]["object"].removeprefix("0x"))
    meta = runtime[-(int.from_bytes(runtime[-2:], "big") + 2):]
    return creation.replace(meta, b""), runtime[: -len(meta)]


def forge_failures(args):
    out = run(["forge", "test", "--json", *args]).stdout
    start = out.find("{")
    if start < 0:
        raise RuntimeError("forge produced no JSON: build failed?")
    failed = []
    for suite, body in json.loads(out[start:]).items():
        contract = suite.split(":")[-1]
        for name, result in body["test_results"].items():
            for inv in result.get("invariant_predicate_results") or []:
                if inv["status"] != "Success":
                    failed.append(inv["name"])
            if result["status"] != "Success" and not result.get("invariant_predicate_results"):
                failed.append(f"{contract}.{name.split('(')[0]}")
    return failed


def halmos_failures():
    report = os.path.join(WORK, "halmos.json")
    if os.path.exists(report):
        os.remove(report)
    run(["halmos", "--match-contract", "P[1-7].*Halmos", "--forge-build-out", "mutants/.work/out",
         "--early-exit", "--json-output", report])
    failed = []
    with open(report) as f:
        data = json.load(f)
    for contract, results in data["test_results"].items():
        for r in results:
            if r["exitcode"] != 0:
                failed.append(f"{contract.split(':')[-1]}.{r['name'].split('(')[0]}")
    return failed


def save(row):
    rows = []
    if os.path.exists(RESULTS):
        with open(RESULTS) as f:
            rows = [r for r in json.load(f) if r["id"] != row["id"]]
    rows.append(row)
    with open(RESULTS, "w") as f:
        json.dump(sorted(rows, key=lambda r: r["id"]), f, indent=1)


def owner(test):
    for p in PROPS:
        if test.startswith(p) or test.startswith(f"invariant_{p}"):
            return p
    return "other"


def main():
    with open(os.path.join(TESTS, "mutants", "MUTANTS.tsv")) as f:
        mutants = list(csv.DictReader(f, delimiter="\t"))
    wanted = set(sys.argv[1:])
    if run(["forge", "build"], profile="default").returncode:
        raise RuntimeError("the verified source does not build")
    original = stock_code("out")
    for m in mutants:
        if wanted and m["id"] not in wanted:
            continue
        t0 = time.time()
        stage(m["id"], m["file"])
        if stock_code("mutants/.work/out") == original:
            raise RuntimeError(f"{m['id']} builds to the original code")
        unit = forge_failures(["--match-path", "test/unit/*"])
        inv = forge_failures(["--match-contract", "StockInvariants", "--match-test", f"invariant_{m['property']}_"])
        sym = halmos_failures()
        own = m["property"]
        row = {
            "id": m["id"],
            "property": own,
            "change": m["change"],
            "unit": sorted(t for t in unit if owner(t) == own),
            "invariant": sorted(inv),
            "halmos": sorted(t for t in sym if owner(t) == own),
            "cross": sorted({owner(t) for t in unit + sym if owner(t) not in (own, "other")}),
            "seconds": round(time.time() - t0),
        }
        row["killed"] = bool(row["unit"] or row["invariant"] or row["halmos"])
        print(json.dumps(row), flush=True)
        save(row)
    with open(RESULTS) as f:
        rows = json.load(f)
    survivors = [r["id"] for r in rows if not r["killed"]]
    print("survivors:", survivors or "none")
    return 1 if survivors else 0


if __name__ == "__main__":
    sys.exit(main())
