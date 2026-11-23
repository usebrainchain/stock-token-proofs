# Stock token proofs

Lean proofs, checked by the Lean kernel against the deployed bytecode, that in the contract behind every Robinhood stock token on Robinhood Chain (implementation `0xb35490d6f9163DE4F80d88dc75c3516eb64C5aE2` behind beacon `0xe10b6f6b275de231345c20d14ab812db62151b00`) a role-gated, pause-gated or blocklist-gated call succeeds only if the access registry gives the answer that call requires, with the token's own pause flag clear wherever the call checks it.

The proofs are built on [Blanc](https://github.com/skbaek/blanc) by skbaek, which lifts deployed EVM bytecode into Lean and proves theorems about it, and on Blanc's EVM semantics, [Jaune](https://github.com/skbaek/jaune). Blanc is MIT licensed; its license is in `LICENSE-BLANC`. This repository holds our patches on top of Blanc commit `bdb2984`, a script that rebuilds and checks them from scratch, and the Foundry tests written alongside them.

```sh
./check.sh
```

## The contract

All 205 stock tokens in Robinhood's published asset list ([`api.robinhood.com/rhj/assets`](https://docs.robinhood.com/chain/stock-token-apis), read on 24 Nov 2026) are beacon proxies whose beacon, `0xe10b…1b00`, returns the implementation `0xb354…5aE2`. `scripts/stock-tokens.sh` reads the ERC-1967 beacon slot of every token in that list over the public Robinhood Chain RPC, and the beacon's `implementation()`, and confirms both. The beacon is also the access registry: it holds the roles, the blocklist and a global pause flag that every token consults. The implementation's runtime code is 11,614 bytes with sha256 `0ac99e9cc7a3738645af72f6d9e8fb8242660b63134d8fb0c44ba6fac39deec2`. Its Solidity source is verified on Sourcify (exact match, solc 0.8.33) and copied in `onchain/`.

Blanc's lifter turns those bytes into a certificate of 181 entries, which the kernel checks against the bytes (`cert_check`, `jumps_ok`). Every theorem is stated over Jaune's execution of the bytes themselves. The Solidity source plays no part in the proofs.

## Premises

Every theorem below is about one execution frame `F` running the implementation's code, and assumes:

1. `F` starts at pc 0 of the certified bytes (`F.sevm.code = code`) with an empty stack and empty memory. Every fresh call frame starts this way, including the frame a proxy enters with `DELEGATECALL`.
2. The first four bytes of calldata are the entry point's selector. The rest of the calldata is unconstrained.
3. The frame finishes normally (`F.exn = .ok post`). A frame that ends in `REVERT` or an exceptional halt has no such result.
4. The fork is one Blanc covers: Prague, Osaka, BPO1 or BPO2.
5. For the blocklist theorems only: the frame's gas is below 2^256.

Nothing is assumed about the caller, the call value, the token's storage, the rest of the world or the registry's code.

## Theorems

"The registry" is the address `0xe10b…1b00` fixed in the bytecode, "caller" is the frame's `CALLER`, and "returns w" means the reply is at least 32 bytes long and its first 32-byte word is w. The conclusions take three forms:

- **Over the starting state.** A static call to the registry with the stated calldata, made over the frame's starting state (accounts, code and storage), succeeds and returns the stated word. The statement fixes what the registry returns over that state and does not point at a call inside the run. The gas, transient storage and warm-access sets of that static call are left open.
- **Over a quiet state.** The same, over a state reached from the starting one by quiet instructions only: no storage write, no log, and external calls only by `STATICCALL`. This form appears where the query follows an earlier registry call in the same run.
- **In the run.** The run itself executed a `STATICCALL` to the registry with the stated calldata at one of its own steps, and that call succeeded and returned the stated word.

All names are in the namespace `Blanc.Lift.Stock`. `CLAIMS.md` gives the file and line of each statement.

| Property | Lean name | Entry point | If a run of the entry point succeeds, then |
|---|---|---|---|
| roles | `pause_requires_role` | `pause()` | a static call to the registry asking `hasRole(TOKEN_PAUSER_ROLE, caller)`, over the starting state, succeeds and returns 1 |
| roles | `unpause_requires_role` | `unpause()` | a static call to the registry asking `hasRole(TOKEN_PAUSER_ROLE, caller)`, over the starting state, succeeds and returns 1 |
| roles | `mint_requires_role` | `mint(address,uint256)` | a static call to the registry asking `hasRole(MINTER_ROLE, caller)`, over the starting state, succeeds and returns 1 |
| roles | `burn_requires_role` | `burn(address,uint256)` | a static call to the registry asking `hasRole(BURNER_ROLE, caller)`, over the starting state, succeeds and returns 1 |
| roles | `adminBurn_requires_role` | `adminBurn(address,uint256)` | a static call to the registry asking `hasRole(ADMIN_BURNER_ROLE, caller)`, over the starting state, succeeds and returns 1 |
| roles | `pauseOracle_requires_role` | `pauseOracle()` | a static call to the registry asking `hasRole(ORACLE_PAUSER_ROLE, caller)`, over the starting state, succeeds and returns 1 |
| roles | `unpauseOracle_requires_role` | `unpauseOracle()` | a static call to the registry asking `hasRole(ORACLE_PAUSER_ROLE, caller)`, over the starting state, succeeds and returns 1 |
| roles | `setMetadata_requires_role` | `setMetadata(string,string)` | a static call to the registry asking `hasRole(METADATA_UPDATER_ROLE, caller)`, over the starting state, succeeds and returns 1 |
| roles | `updateMultiplier_requires_role` | `updateMultiplier(uint256)` | a static call to the registry asking `hasRole(MULTIPLIER_UPDATER_ROLE, caller)`, over a quiet state (after the `paused()` query), succeeds and returns 1 |
| roles | `updateMultiplierAt_requires_role` | `updateMultiplier(uint256,uint256)` | a static call to the registry asking `hasRole(MULTIPLIER_UPDATER_ROLE, caller)`, over a quiet state (after the `paused()` query), succeeds and returns 1 |
| roles | `pause_role_in_run` | `pause()` | the run itself called the registry asking `hasRole(TOKEN_PAUSER_ROLE, caller)`, and that call succeeded and returned 1 |
| roles | `unpause_role_in_run` | `unpause()` | the run itself called the registry asking `hasRole(TOKEN_PAUSER_ROLE, caller)`, and that call succeeded and returned 1 |
| roles | `mint_role_in_run` | `mint(address,uint256)` | the run itself called the registry asking `hasRole(MINTER_ROLE, caller)`, and that call succeeded and returned 1 |
| roles | `burn_role_in_run` | `burn(address,uint256)` | the run itself called the registry asking `hasRole(BURNER_ROLE, caller)`, and that call succeeded and returned 1 |
| roles | `adminBurn_role_in_run` | `adminBurn(address,uint256)` | the run itself called the registry asking `hasRole(ADMIN_BURNER_ROLE, caller)`, and that call succeeded and returned 1 |
| roles | `pauseOracle_role_in_run` | `pauseOracle()` | the run itself called the registry asking `hasRole(ORACLE_PAUSER_ROLE, caller)`, and that call succeeded and returned 1 |
| roles | `unpauseOracle_role_in_run` | `unpauseOracle()` | the run itself called the registry asking `hasRole(ORACLE_PAUSER_ROLE, caller)`, and that call succeeded and returned 1 |
| roles | `setMetadata_role_in_run` | `setMetadata(string,string)` | the run itself called the registry asking `hasRole(METADATA_UPDATER_ROLE, caller)`, and that call succeeded and returned 1 |
| pause | `transfer_requires_unpaused` | `transfer(address,uint256)` | the token's own paused flag is 0 in the starting storage, and a static call to the registry asking `paused()`, over the starting state, succeeds and returns 0 |
| pause | `transferFrom_requires_unpaused` | `transferFrom(address,address,uint256)` | the token's own paused flag is 0 in the starting storage, and a static call to the registry asking `paused()`, over the starting state, succeeds and returns 0 |
| pause | `approve_requires_unpaused` | `approve(address,uint256)` | the token's own paused flag is 0 in the starting storage, and a static call to the registry asking `paused()`, over the starting state, succeeds and returns 0 |
| pause | `permit_requires_unpaused` | `permit(address,address,uint256,uint256,uint8,bytes32,bytes32)` | the token's own paused flag is 0 in the starting storage, and a static call to the registry asking `paused()`, over the starting state, succeeds and returns 0 |
| pause | `updateMultiplier_requires_unpaused` | `updateMultiplier(uint256)` | the token's own paused flag is 0 in the starting storage, and a static call to the registry asking `paused()`, over the starting state, succeeds and returns 0 |
| pause | `updateMultiplierAt_requires_unpaused` | `updateMultiplier(uint256,uint256)` | the token's own paused flag is 0 in the starting storage, and a static call to the registry asking `paused()`, over the starting state, succeeds and returns 0 |
| pause | `mint_requires_unpaused` | `mint(address,uint256)` | the token's own paused flag is 0 in the starting storage, and a static call to the registry asking `paused()`, over a quiet state (after the role query), succeeds and returns 0 |
| pause | `burn_requires_unpaused` | `burn(address,uint256)` | the token's own paused flag is 0 in the starting storage, and a static call to the registry asking `paused()`, over a quiet state (after the role query), succeeds and returns 0 |
| pause | `pause_no_pause_check` | `pause()` | certificate fact: no paused check, and no registry query other than `hasRole` |
| pause | `unpause_no_pause_check` | `unpause()` | certificate fact: no paused check, and no registry query other than `hasRole` |
| pause | `setMetadata_no_pause_check` | `setMetadata(string,string)` | certificate fact: no paused check, and no registry query other than `hasRole` |
| pause | `pauseOracle_no_pause_check` | `pauseOracle()` | certificate fact: no paused check, and no registry query other than `hasRole` |
| pause | `unpauseOracle_no_pause_check` | `unpauseOracle()` | certificate fact: no paused check, and no registry query other than `hasRole` |
| blocklist | `transfer_requires_unblocked` | `transfer(to, value)` | for a = `to` and a = caller, a static call to the registry asking `isBlocked(a)`, over a quiet state, succeeds and returns 0 |
| blocklist | `transferFrom_requires_unblocked` | `transferFrom(from, to, value)` | for a = `from`, `to` and caller, a static call to the registry asking `isBlocked(a)`, over a quiet state, succeeds and returns 0 |
| blocklist | `approve_requires_unblocked` | `approve(spender, value)` | for a = `spender` and a = caller, a static call to the registry asking `isBlocked(a)`, over a quiet state, succeeds and returns 0 |
| blocklist | `permit_requires_unblocked` | `permit(owner, spender, …)` | for a = `owner`, `spender` and caller (the relayer), a static call to the registry asking `isBlocked(a)`, over a quiet state, succeeds and returns 0 |
| blocklist | `mint_requires_unblocked` | `mint(to, amount)` | for a = `to` and a = caller, a static call to the registry asking `isBlocked(a)`, over a quiet state, succeeds and returns 0 |
| blocklist | `burn_requires_unblocked` | `burn(from, amount)` | for a = `from` and a = caller, a static call to the registry asking `isBlocked(a)`, over a quiet state, succeeds and returns 0 |
| blocklist | `adminBurn_no_pause_no_blocklist` | `adminBurn(address,uint256)` | certificate fact: no paused check, and no registry query other than `hasRole`, so no `isBlocked` query |
| certificate | `cert_check`, `jumps_ok` | all | the certificate checks against the 11,614 deployed bytes, jump destinations included |
| certificate | `tokenPauserRole_eq_keccak` and six more | all | each role constant in the statements equals the keccak256 of its name, computed by the kernel |

An address argument is read as the ABI decoder reads it: the low 20 bytes of calldata word `4 + 32k`.

The certificate facts are kernel decisions about the checked certificate. From the entry point, the set of certificate entries its code can reach is closed under jumps and internal calls, excludes the `paused()` routine, and contains exactly one external call site, the `hasRole` query. `cert_check` ties the certificate to the bytes, and every successful run of the bytes follows the certificate's trees; the step from these facts to runs is not itself a Lean theorem.

### Witnesses

A theorem whose premises can never hold together says nothing. For each entry point below there is a concrete run of the deployed bytes, computed and checked by the kernel, on which every premise holds, the run succeeds, and the theorems above are applied to give their conclusions. The world holds the implementation's runtime at `0x7070…7070` and, at the registry address, a 17-byte stand-in registry, itself lifted and certified, that answers `hasRole` with 1 and every other query with 0. The caller is `0xcafe…cafe`, the call carries no value and 1,000,000 gas, on Prague.

| Lean name (namespace `Blanc.Lift.Stock.Witnesses`) | Call | Theorems shown on the run |
|---|---|---|
| `pause_witness` | `pause()` | role, role in the run |
| `unpause_witness` | `unpause()`, token paused at the start | role, role in the run |
| `mint_witness` | `mint(0xbeef…beef, 1000)` | role, role in the run, unpaused, unblocked |
| `burn_witness` | `burn(0xbeef…beef, 0)` | role, role in the run, unpaused, unblocked |
| `adminBurn_witness` | `adminBurn(0xbeef…beef, 0)` | role, role in the run |
| `pauseOracle_witness` | `pauseOracle()` | role, role in the run |
| `unpauseOracle_witness` | `unpauseOracle()` | role, role in the run |
| `setMetadata_witness` | `setMetadata("A", "B")` | role, role in the run |
| `transfer_witness` | `transfer(0xbeef…beef, 0)` | unpaused, unblocked |
| `transferFrom_witness` | `transferFrom(0xcafe…cafe, 0xbeef…beef, 0)` | unpaused, unblocked |
| `approve_witness` | `approve(0xbeef…beef, 0)` | unpaused, unblocked |
| `updateMultiplier_witness` | `updateMultiplier(1e18)` | unpaused, role |
| `updateMultiplierAt_witness` | `updateMultiplier(1e18, 100)` | unpaused, role |

The pause witness also shows the token's paused slot going from 0 to 1, and the unpause witness from 1 to 0.

## What is not covered

- **The proxy.** The theorems hold for any frame that runs the implementation's bytes, which is how a beacon proxy runs them. `scripts/stock-tokens.sh` confirms each token's beacon slot and the beacon's answer at the time it runs. That the proxy code forwards every call to that implementation, and that the beacon keeps returning it, is not proved; the proxy code is not lifted.
- **The chain.** Robinhood Chain is an Arbitrum Nitro chain. Reading the theorems as statements about it assumes Nitro executes these opcodes as the modelled Ethereum forks do.
- **The registry's own code.** The theorems say what the token asks the registry and which answers it requires. Any code at the registry address that returns those words satisfies them; whether the deployed registry answers truthfully is outside the proofs.
- **Liveness.** No theorem says an authorised call succeeds. The witnesses show one concrete authorised call per entry point succeeding.
- **Supply accounting.** That balances sum to `totalSupply` and only mint and the two burns change it is tested in `tests/`, not proved.
- **A witness for permit.** The two `permit` theorems have no kernel-checked witness: a successful `permit` needs the `ecrecover` precompile, which Blanc's witness interpreter does not run.
- **The gas premise.** A frame starts with the gas of the message that entered it (`gasMeasure_initDevm`, proved). That a message's gas fits under a transaction's gas limit, a 64-bit field, is argued in words, not proved in Lean.

## How it was checked

- **No `sorry` and no new axioms.** Blanc's trust-surface gate found no new `sorry`, axiom, `native_decide`, `extern` or `implemented_by` anywhere in the library, and its axiom walk over every module reached only `propext`, `Classical.choice` and `Quot.sound`. `check.sh` prints `#print axioms` for each of the 62 theorems in `lean/Axioms.lean`, fails on any other axiom, and scans every module the patches add or change for `sorry`, `admit`, `native_decide`, `implemented_by`, `extern`, `axiom`, `opaque` and `unsafe`.
- **Kernel replay.** Every module the patches add or change is replayed declaration by declaration with `leanchecker`. `check.sh` repeats the replay.
- **Exact statements.** Each statement is pinned in Blanc's claim gate, so a weakened statement fails the build. `lean/Claims.lean` holds the same pins and `check.sh` elaborates it against the fresh build.
- **Statement mutants.** Seventeen copies of the theorems, each with one change to the statement and the original proof, were elaborated: role swapped, caller replaced by the token's own address, the required answer flipped, the registry address moved by one, the selector swapped, an argument index moved. Every copy was rejected (`scripts/stock-controls/statement-mutants.py` in the patched tree).
- **A bytecode mutant.** A copy of the deployed bytes with `pause()`'s role check cut out still yields a checked certificate, and the proof of `pause_requires_role` fails on it in the role walk (`scripts/stock-controls/pause-norole.sh`). A Foundry run shows the statement is false for those bytes: a caller without the role can pause them (`tests/controls/pause-norole`).
- **Witnesses and a control.** Besides the witnesses above, a registry that denies every role keeps `pause()` and `mint()` from reaching a successful halt, while `transfer()`, which asks for no role, still succeeds (`scripts/stock-controls/witness-deny.sh`).
- **Blanc's gate catalogue.** At the final commit every correctness row of Blanc's 29-row catalogue passed. Rows whose inputs had not changed reused earlier results, and the elaboration-timing baseline was deferred.
- **Review of the statements.** A model from a different vendor than the one that wrote the proofs reviewed the statements against the Lean source. Its main point, that "the registry answered" overstated a theorem whose conclusion is about a static call over the same state, produced the wording above and the `*_role_in_run` theorems.

## Running the check

`./check.sh` needs a Linux machine with git, curl and one of perl, xxd or python3. It installs elan if `elan` is not on the path, fetches Blanc at `bdb2984` from its author's repository, applies `lean/patches`, confirms the result is commit `0dcf77d`, fetches the Mathlib cache, builds the Stock modules and runs the checks above. The only network call to Robinhood Chain is a read: `eth_chainId` and `eth_getCode` on `https://rpc.mainnet.chain.robinhood.com` (set `RPC_URL` to use another node).

Measured on 8 cores and 30 GB of memory, from an empty home directory: 9 minutes in total, of which the build takes 5 and the kernel replay 2. Memory in use peaked at 9 GB with no swap used; the largest single process reached 8.4 GB. Disk: 8.1 GB under `work/`, 3.0 GB for the toolchain and 0.5 GB of downloaded Mathlib cache. For comparison, building the whole Blanc library (`lake build` in `work/blanc`) takes about 32 minutes on the same machine, peaks near 24 GB and fills `.lake` with about 13 GB.

`scripts/stock-tokens.sh` runs on its own in about 15 seconds and needs only curl, awk and sed.

`SKIP_REPLAY=1` skips the kernel replay. `REPLAY_JOBS` sets how many modules are replayed at once (default 4, about 3 GB each). A second run reuses `work/`.

`tests/` holds the Foundry suite: unit tests, invariant fuzzing, Halmos checks and mutants for seven properties of the source, supply accounting among them. See `tests/README.md`.

## Layout

| Path | Contents |
|---|---|
| `check.sh` | the one-command check |
| `lean/patches/` | eleven commits on top of Blanc `bdb2984`, as `git format-patch` output |
| `lean/Claims.lean` | the exact statements, pinned |
| `lean/Axioms.lean` | `#print axioms` for every headline theorem |
| `lean/CodeHex.lean` | prints the certified bytes |
| `scripts/stock-tokens.sh` | confirms every listed stock token points to this implementation |
| `onchain/` | the verified sources, compiler settings and runtime code of the implementation and the registry |
| `tests/` | the Foundry tests |
| `CLAIMS.md` | each claim and the file and line of its Lean statement |
| `LICENSE`, `LICENSE-BLANC` | see Licenses |

## Licenses

| Files | License |
|---|---|
| Everything we wrote: `check.sh`, `scripts/`, `lean/` (the patches included), `tests/` outside `tests/lib`, and the documentation | MIT, `LICENSE` (Copyright (c) 2026 BrainChain) |
| Blanc, which `check.sh` fetches and the patches apply to | MIT, `LICENSE-BLANC` (Copyright (c) 2024 skbaek) |
| `onchain/` and the planted mutants in `tests/mutants/`, copies of the verified token and registry sources | MIT, per the SPDX header of each file |
| `tests/lib/forge-std` | MIT or Apache-2.0, `tests/lib/forge-std/LICENSE-MIT` |
| `tests/lib/oz-proxy` (OpenZeppelin proxy contracts) | MIT, `tests/lib/oz-proxy/LICENSE` |
| `tests/lib/halmos-cheatcodes/src/SVM.sol`, `SymTest.sol` | AGPL-3.0, `tests/lib/halmos-cheatcodes/LICENSE` |

## Why patches on Blanc

The Lean work is eleven commits on top of Blanc. Publishing them as patches keeps everything we wrote in one reviewable diff, and the check fetches Blanc itself from its author's repository by commit hash, so none of Blanc's code reaches you through us. Applying the patches with their recorded author and dates rebuilds commit `0dcf77d5d44497e6f866880b1d624c948dd015a1` hash for hash, and `check.sh` stops if it does not. The patch form and the fork history are therefore the same commit, and this repository stays small enough to hold the tests beside the proofs.
