# Tests

Foundry tests on the verified Solidity source of the Stock token and its access registry: unit tests, invariant fuzzing, Halmos symbolic checks and 25 planted mutants, across seven properties. They include the supply accounting that the Lean proofs leave out. Everything runs in a local EVM; no chain is called.

```sh
./run.sh                   # everything, about 28 minutes
SKIP_MUTANTS=1 ./run.sh    # everything except the mutants, about 2.5 minutes
```

Requirements: forge 1.8.1 (it fetches solc 0.8.33), Halmos 0.3.3 and python3.

## The code under test

The tests import the sources in `../onchain` directly. `scripts/check_bytecode.py` builds them with the deployed compiler settings (solc 0.8.33, optimizer 200 runs, cancun) and compares the runtime code with the bytes on chain. Stock's 11,614 bytes match once its 17 immutable spans are masked, and the registry's 2,332 bytes match as they are. Only the trailing CBOR metadata is excluded, because it hashes source paths.

`test/Fixture.sol` deploys the production topology: one `AccessControlsRegistry` that is both the beacon and the role, blocklist and pause authority, one `Stock` implementation built against it, and the token as an OpenZeppelin `BeaconProxy` initialised in its constructor. Each role sits with its own address.

## Properties

| | Property | Statement |
|---|---|---|
| P1 | Supply | Only `mint`, `burn` and `adminBurn` change `totalSupply`, each by exactly its amount and only for its one account. Balances always sum to `totalSupply`. |
| P2 | Blocklist | Each function checks a fixed set of parties against the registry and reverts if any is blocked: the caller and `to` for `transfer`; the caller, `from` and `to` for `transferFrom`; the caller and `spender` for `approve`; the relayer, `owner` and `spender` for `permit`; the caller and the account for `mint` and `burn`. `adminBurn` consults no blocklist. A blocked account's balance changes only through `adminBurn`. |
| P3 | Pause | The token is paused when its own flag or the registry's flag is set. While paused, `transfer`, `transferFrom`, `approve`, `permit`, `mint`, `burn` and both `updateMultiplier` forms revert, and no balance, allowance, nonce or `totalSupply` changes except through `adminBurn`. |
| P4 | Multiplier | An update never changes a raw balance, an allowance, a nonce or `totalSupply`. The multiplier is never zero. A scheduled value applies from its time, inclusive. |
| P5 | Roles | Every privileged function of the token and the registry reverts for a caller without its role. |
| P6 | Initialisation | The implementation can never be initialised. A deployed proxy initialises once. |
| P7 | Transfers | A successful transfer moves exactly `value` and touches no third account. `transferFrom` lowers a finite allowance by exactly `value`; an allowance of 2^256 - 1 is left as it is. `approve` and `permit` set exactly `value`, and `permit` increments the owner's nonce. |

## Layers

- **Unit tests** (`test/unit`, 85 tests, 18 of them fuzzed at 1,000 runs).
- **Invariant fuzzing** (`test/invariant`): one campaign of 256 runs at depth 500 checks eight invariants after every call. The handler drives 14 actions, including permits with real signatures, blocks, both pauses, multiplier schedules, time warps and privileged calls by callers without the role, and keeps an independent model of what each call must do.
- **Halmos** (`test/halmos`, 49 checks): the token's and the registry's storage are fully symbolic, so every balance, role, blocklist entry, flag and multiplier slot is unconstrained. String arguments are 0, 31 or 65 bytes long and loops unroll twice. Checks on balance deltas assume the two touched balances do not exceed `totalSupply`, which follows from the P1 invariant. `ecrecover` is uninterpreted, so the permit checks cover every outcome of the signature check. Two liveness checks on `adminBurn` bound the amount below 2^192 with the default multiplier.
- **Mutants** (`mutants/`): 25 copies of the source, each with one planted defect listed in `MUTANTS.tsv`. `mutants/run.py` builds each from scratch and runs every layer against it; each mutant is caught by at least one unit test, one invariant and one Halmos check of the property it breaks. Results are in `mutants/results.json`.
- **A bytecode control** (`controls/pause-norole`): the deployed runtime and a copy with `pause()`'s role check cut out. A caller without the role cannot pause the first and can pause the second, so the conclusion of the Lean theorem `pause_requires_role` is false for the mutant bytes.

## Run time

Measured on a 12-core laptop.

| Stage | Time |
|---|---|
| Build, bytecode identity and unit tests | about 5 s |
| Invariant campaign | about 80 s |
| Halmos | about 60 s |
| Mutants (25, 47 to 72 s each) | about 25 minutes |
