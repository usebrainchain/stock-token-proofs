# Claims and where they are stated

Paths are in the patched Blanc tree at commit `0dcf77d` (`work/blanc` after `./check.sh`). The last column is the line in `lean/Claims.lean` where the exact statement is pinned. Names are in `Blanc.Lift.Stock` unless shown otherwise. The premises every theorem carries are listed in the README.

## Roles

| Claim, for a successful run of the entry point | Lean name | Statement | Pin |
|---|---|---|---|
| `pause()`: registry asked `hasRole(TOKEN_PAUSER_ROLE, caller)` over the starting state returns 1 | `pause_requires_role` | `Blanc/Lift/Stock/Pause.lean:848` | 50 |
| `unpause()`: the same, `TOKEN_PAUSER_ROLE` | `unpause_requires_role` | `Blanc/Lift/Stock/Roles.lean:226` | 162 |
| `mint`: the same, `MINTER_ROLE` | `mint_requires_role` | `Blanc/Lift/Stock/Roles.lean:249` | 171 |
| `burn`: the same, `BURNER_ROLE` | `burn_requires_role` | `Blanc/Lift/Stock/Roles.lean:273` | 180 |
| `adminBurn`: the same, `ADMIN_BURNER_ROLE` | `adminBurn_requires_role` | `Blanc/Lift/Stock/Roles.lean:294` | 189 |
| `pauseOracle()`: the same, `ORACLE_PAUSER_ROLE` | `pauseOracle_requires_role` | `Blanc/Lift/Stock/Roles.lean:318` | 198 |
| `unpauseOracle()`: the same, `ORACLE_PAUSER_ROLE` | `unpauseOracle_requires_role` | `Blanc/Lift/Stock/Roles.lean:343` | 207 |
| `setMetadata`: the same, `METADATA_UPDATER_ROLE` | `setMetadata_requires_role` | `Blanc/Lift/Stock/Roles.lean:365` | 216 |
| `updateMultiplier(uint256)`: `hasRole(MULTIPLIER_UPDATER_ROLE, caller)` returns 1 over a quiet state | `updateMultiplier_requires_role` | `Blanc/Lift/Stock/Paused.lean:274` | 225 |
| `updateMultiplier(uint256,uint256)`: the same | `updateMultiplierAt_requires_role` | `Blanc/Lift/Stock/Paused.lean:299` | 234 |
| `pause()`: the run itself asked `hasRole(TOKEN_PAUSER_ROLE, caller)` and got 1 | `pause_role_in_run` | `Blanc/Lift/Stock/InRun.lean:195` | 456 |
| `unpause()`: the same | `unpause_role_in_run` | `Blanc/Lift/Stock/InRun.lean:220` | 465 |
| `mint`: the same, `MINTER_ROLE` | `mint_role_in_run` | `Blanc/Lift/Stock/InRun.lean:243` | 474 |
| `burn`: the same, `BURNER_ROLE` | `burn_role_in_run` | `Blanc/Lift/Stock/InRun.lean:267` | 483 |
| `adminBurn`: the same, `ADMIN_BURNER_ROLE` | `adminBurn_role_in_run` | `Blanc/Lift/Stock/InRun.lean:288` | 492 |
| `pauseOracle()`: the same, `ORACLE_PAUSER_ROLE` | `pauseOracle_role_in_run` | `Blanc/Lift/Stock/InRun.lean:312` | 501 |
| `unpauseOracle()`: the same, `ORACLE_PAUSER_ROLE` | `unpauseOracle_role_in_run` | `Blanc/Lift/Stock/InRun.lean:337` | 510 |
| `setMetadata`: the same, `METADATA_UPDATER_ROLE` | `setMetadata_role_in_run` | `Blanc/Lift/Stock/InRun.lean:359` | 519 |

## Pause

| Claim, for a successful run of the entry point | Lean name | Statement | Pin |
|---|---|---|---|
| `transfer`: token flag 0 in the starting storage; registry asked `paused()` over the starting state returns 0 | `transfer_requires_unpaused` | `Blanc/Lift/Stock/Paused.lean:105` | 243 |
| `transferFrom`: the same | `transferFrom_requires_unpaused` | `Blanc/Lift/Stock/Paused.lean:126` | 252 |
| `approve`: the same | `approve_requires_unpaused` | `Blanc/Lift/Stock/Paused.lean:148` | 261 |
| `permit`: the same | `permit_requires_unpaused` | `Blanc/Lift/Stock/Paused.lean:172` | 270 |
| `updateMultiplier(uint256)`: the same | `updateMultiplier_requires_unpaused` | `Blanc/Lift/Stock/Paused.lean:191` | 279 |
| `updateMultiplier(uint256,uint256)`: the same | `updateMultiplierAt_requires_unpaused` | `Blanc/Lift/Stock/Paused.lean:213` | 288 |
| `mint`: token flag 0 in the starting storage; `paused()` returns 0 over a quiet state | `mint_requires_unpaused` | `Blanc/Lift/Stock/Paused.lean:473` | 297 |
| `burn`: the same | `burn_requires_unpaused` | `Blanc/Lift/Stock/Paused.lean:495` | 306 |
| `pause()` makes no paused check and no registry query other than `hasRole` (certificate fact) | `pause_no_pause_check` | `Blanc/Lift/Stock/NoCheck.lean:55` | 320 |
| `unpause()`: the same | `unpause_no_pause_check` | `Blanc/Lift/Stock/NoCheck.lean:59` | 324 |
| `setMetadata`: the same | `setMetadata_no_pause_check` | `Blanc/Lift/Stock/NoCheck.lean:63` | 328 |
| `pauseOracle()`: the same | `pauseOracle_no_pause_check` | `Blanc/Lift/Stock/NoCheck.lean:69` | 333 |
| `unpauseOracle()`: the same | `unpauseOracle_no_pause_check` | `Blanc/Lift/Stock/NoCheck.lean:73` | 337 |
| The certificate entries the five facts above and `adminBurn`'s start from are the ones the dispatcher sends those selectors to | `dispatch_targets` | `Blanc/Lift/Stock/NoCheck.lean:79` | 429 |

## Blocklist

| Claim, for a successful run of the entry point | Lean name | Statement | Pin |
|---|---|---|---|
| `transfer`: `isBlocked(to)` and `isBlocked(caller)` return 0 over quiet states | `transfer_requires_unblocked` | `Blanc/Lift/Stock/Blocked.lean:402` | 364 |
| `transferFrom`: the same for `from`, `to`, caller | `transferFrom_requires_unblocked` | `Blanc/Lift/Stock/Blocked.lean:445` | 374 |
| `approve`: the same for `spender`, caller | `approve_requires_unblocked` | `Blanc/Lift/Stock/Blocked.lean:498` | 384 |
| `permit`: the same for `owner`, `spender`, caller | `permit_requires_unblocked` | `Blanc/Lift/Stock/Blocked.lean:545` | 394 |
| `mint`: the same for `to`, caller | `mint_requires_unblocked` | `Blanc/Lift/Stock/Blocked.lean:595` | 404 |
| `burn`: the same for `from`, caller | `burn_requires_unblocked` | `Blanc/Lift/Stock/Blocked.lean:640` | 414 |
| `adminBurn` makes no paused check and no registry query other than `hasRole` (certificate fact) | `adminBurn_no_pause_no_blocklist` | `Blanc/Lift/Stock/NoCheck.lean:49` | 315 |
| A frame entered by a message starts with exactly the message's gas (supports the gas premise) | `gasMeasure_initDevm` | `Blanc/Lift/Stock/Blocked.lean:82` | 361 |

## Certificate and constants

| Claim | Lean name | Statement | Pin |
|---|---|---|---|
| The certificate checks against the deployed bytes | `cert_check` | `Blanc/Lift/Stock/Check.lean:33` | 44 |
| Its jump destinations check against the deployed bytes | `jumps_ok` | `Blanc/Lift/Stock/Jumps.lean:10` | 47 |
| `TOKEN_PAUSER_ROLE` is keccak256 of its name | `tokenPauserRole_eq_keccak` | `Blanc/Lift/Stock/Pause.lean:40` | 41 |
| `MINTER_ROLE` | `minterRole_eq_keccak` | `Blanc/Lift/Stock/Roles.lean:50` | 68 |
| `BURNER_ROLE` | `burnerRole_eq_keccak` | `Blanc/Lift/Stock/Roles.lean:52` | 71 |
| `ADMIN_BURNER_ROLE` | `adminBurnerRole_eq_keccak` | `Blanc/Lift/Stock/Roles.lean:54` | 74 |
| `ORACLE_PAUSER_ROLE` | `oraclePauserRole_eq_keccak` | `Blanc/Lift/Stock/Roles.lean:57` | 77 |
| `METADATA_UPDATER_ROLE` | `metadataUpdaterRole_eq_keccak` | `Blanc/Lift/Stock/Roles.lean:60` | 80 |
| `MULTIPLIER_UPDATER_ROLE` | `multiplierUpdaterRole_eq_keccak` | `Blanc/Lift/Stock/Roles.lean:63` | 83 |

## Witnesses (namespace `Blanc.Lift.Stock.Witnesses`)

| Claim | Lean name | Statement | Pin |
|---|---|---|---|
| The premises hold together on a successful `pause()`, with both role theorems applied | `pause_witness` | `Blanc/Lift/Stock/Witness.lean:195` | 540 |
| `unpause()` | `unpause_witness` | `Blanc/Lift/Stock/Witness.lean:238` | 549 |
| `mint` | `mint_witness` | `Blanc/Lift/Stock/Witness.lean:260` | 558 |
| `burn` | `burn_witness` | `Blanc/Lift/Stock/Witness.lean:280` | 565 |
| `adminBurn` | `adminBurn_witness` | `Blanc/Lift/Stock/Witness.lean:300` | 572 |
| `pauseOracle()` | `pauseOracle_witness` | `Blanc/Lift/Stock/Witness.lean:317` | 578 |
| `unpauseOracle()` | `unpauseOracle_witness` | `Blanc/Lift/Stock/Witness.lean:333` | 584 |
| `setMetadata` | `setMetadata_witness` | `Blanc/Lift/Stock/Witness.lean:352` | 590 |
| `transfer` | `transfer_witness` | `Blanc/Lift/Stock/Witness.lean:371` | 596 |
| `transferFrom` | `transferFrom_witness` | `Blanc/Lift/Stock/Witness.lean:390` | 602 |
| `approve` | `approve_witness` | `Blanc/Lift/Stock/Witness.lean:408` | 609 |
| `updateMultiplier(uint256)` | `updateMultiplier_witness` | `Blanc/Lift/Stock/Witness.lean:428` | 615 |
| `updateMultiplier(uint256,uint256)` | `updateMultiplierAt_witness` | `Blanc/Lift/Stock/Witness.lean:446` | 621 |

## Definitions the statements unfold to

| Name | Meaning | Definition | Pin |
|---|---|---|---|
| `code` | the 11,614 certified bytes | `Blanc/Lift/Stock/Cert.lean:746` | |
| `registry` | `0xe10b6f6b275de231345c20d14ab812db62151b00` | `Blanc/Lift/Stock/Pause.lean:33` | 26 |
| `hasRoleData` | calldata of `hasRole(bytes32,address)` | `Blanc/Lift/Stock/Pause.lean:45` | 29 |
| `isBlockedData` | calldata of `isBlocked(address)` | `Blanc/Lift/Stock/Blocked.lean:93` | 348 |
| `pausedData` | calldata of `paused()` | `Blanc/Lift/Stock/Query.lean:530` | 133 |
| `pausedSlot`, `tokenFlag` | the token's paused flag: low byte of its ERC-7201 slot | `Blanc/Lift/Stock/Query.lean:523`, `:526` | 125, 129 |
| `argAdr` | address argument `k`, as the ABI decoder reads it | `Blanc/Lift/Stock/Blocked.lean:382` | 351 |
| `StaticAnswered` | a successful static call with this calldata over this state, and its reply | `Blanc/Lift/StaticCall.lean:34` | |
| `QuietFrom` | a state reached by quiet instructions | `Blanc/Lift/Stock/Query.lean:25` | |
| `CalledInRun` | a `STATICCALL` the run itself executed, with its reply | `Blanc/Lift/Stock/InRun.lean:27` | 442 |
| `RoleAnswered`, `RoleAnsweredAfter`, `RoleCalled` | the three role conclusions | `Roles.lean:220`, `Paused.lean:238`, `InRun.lean:190` | 136, 141, 451 |
| `UnpausedAnswered`, `UnpausedAnsweredAfter` | the two pause conclusions | `Paused.lean:34`, `Paused.lean:421` | 147, 152 |
| `BlockedClear` | the blocklist conclusion | `Blanc/Lift/Stock/Blocked.lean:375` | 355 |
| `OnlyRoleQuery` | the certificate fact | `Blanc/Lift/Stock/NoCheck.lean:46` | 158 |
| `Witnesses.Premises` | the premises, bundled for the witnesses | `Blanc/Lift/Stock/Witness.lean:133` | 535 |
| `CoveredFork` | Prague, Osaka, BPO1 or BPO2 | `Blanc/Semantics.lean:167` | |
