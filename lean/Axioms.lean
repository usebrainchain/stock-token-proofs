import Blanc.Lift.Stock.Pause
import Blanc.Lift.Stock.NoCheck
import Blanc.Lift.Stock.Blocked
import Blanc.Lift.Stock.InRun
import Blanc.Lift.Stock.Witness

/-!
# Axioms behind every headline theorem

`check.sh` runs this file and fails unless every line printed below names only `propext`,
`Classical.choice` and `Quot.sound`. A `sorry` anywhere in a proof shows up here as `sorryAx`, and
`native_decide` as `Lean.ofReduceBool`.
-/

-- The certificate: the lifted program is checked against the deployed bytes.
#print axioms Blanc.Lift.Stock.cert_check
#print axioms Blanc.Lift.Stock.jumps_ok

-- Each role constant is the keccak256 of its name.
#print axioms Blanc.Lift.Stock.tokenPauserRole_eq_keccak
#print axioms Blanc.Lift.Stock.minterRole_eq_keccak
#print axioms Blanc.Lift.Stock.burnerRole_eq_keccak
#print axioms Blanc.Lift.Stock.adminBurnerRole_eq_keccak
#print axioms Blanc.Lift.Stock.oraclePauserRole_eq_keccak
#print axioms Blanc.Lift.Stock.metadataUpdaterRole_eq_keccak
#print axioms Blanc.Lift.Stock.multiplierUpdaterRole_eq_keccak

-- Roles.
#print axioms Blanc.Lift.Stock.pause_requires_role
#print axioms Blanc.Lift.Stock.unpause_requires_role
#print axioms Blanc.Lift.Stock.mint_requires_role
#print axioms Blanc.Lift.Stock.burn_requires_role
#print axioms Blanc.Lift.Stock.adminBurn_requires_role
#print axioms Blanc.Lift.Stock.pauseOracle_requires_role
#print axioms Blanc.Lift.Stock.unpauseOracle_requires_role
#print axioms Blanc.Lift.Stock.setMetadata_requires_role
#print axioms Blanc.Lift.Stock.updateMultiplier_requires_role
#print axioms Blanc.Lift.Stock.updateMultiplierAt_requires_role
#print axioms Blanc.Lift.Stock.pause_role_in_run
#print axioms Blanc.Lift.Stock.unpause_role_in_run
#print axioms Blanc.Lift.Stock.mint_role_in_run
#print axioms Blanc.Lift.Stock.burn_role_in_run
#print axioms Blanc.Lift.Stock.adminBurn_role_in_run
#print axioms Blanc.Lift.Stock.pauseOracle_role_in_run
#print axioms Blanc.Lift.Stock.unpauseOracle_role_in_run
#print axioms Blanc.Lift.Stock.setMetadata_role_in_run

-- Pause.
#print axioms Blanc.Lift.Stock.transfer_requires_unpaused
#print axioms Blanc.Lift.Stock.transferFrom_requires_unpaused
#print axioms Blanc.Lift.Stock.approve_requires_unpaused
#print axioms Blanc.Lift.Stock.permit_requires_unpaused
#print axioms Blanc.Lift.Stock.mint_requires_unpaused
#print axioms Blanc.Lift.Stock.burn_requires_unpaused
#print axioms Blanc.Lift.Stock.updateMultiplier_requires_unpaused
#print axioms Blanc.Lift.Stock.updateMultiplierAt_requires_unpaused
#print axioms Blanc.Lift.Stock.pause_no_pause_check
#print axioms Blanc.Lift.Stock.unpause_no_pause_check
#print axioms Blanc.Lift.Stock.setMetadata_no_pause_check
#print axioms Blanc.Lift.Stock.pauseOracle_no_pause_check
#print axioms Blanc.Lift.Stock.unpauseOracle_no_pause_check
#print axioms Blanc.Lift.Stock.dispatch_targets

-- Blocklist.
#print axioms Blanc.Lift.Stock.transfer_requires_unblocked
#print axioms Blanc.Lift.Stock.transferFrom_requires_unblocked
#print axioms Blanc.Lift.Stock.approve_requires_unblocked
#print axioms Blanc.Lift.Stock.permit_requires_unblocked
#print axioms Blanc.Lift.Stock.mint_requires_unblocked
#print axioms Blanc.Lift.Stock.burn_requires_unblocked
#print axioms Blanc.Lift.Stock.adminBurn_no_pause_no_blocklist
#print axioms Blanc.Lift.Stock.gasMeasure_initDevm

-- Witnesses: concrete successful runs on which the premises hold and the theorems apply.
#print axioms Blanc.Lift.Stock.Witnesses.pause_witness
#print axioms Blanc.Lift.Stock.Witnesses.unpause_witness
#print axioms Blanc.Lift.Stock.Witnesses.mint_witness
#print axioms Blanc.Lift.Stock.Witnesses.burn_witness
#print axioms Blanc.Lift.Stock.Witnesses.adminBurn_witness
#print axioms Blanc.Lift.Stock.Witnesses.pauseOracle_witness
#print axioms Blanc.Lift.Stock.Witnesses.unpauseOracle_witness
#print axioms Blanc.Lift.Stock.Witnesses.setMetadata_witness
#print axioms Blanc.Lift.Stock.Witnesses.transfer_witness
#print axioms Blanc.Lift.Stock.Witnesses.transferFrom_witness
#print axioms Blanc.Lift.Stock.Witnesses.approve_witness
#print axioms Blanc.Lift.Stock.Witnesses.updateMultiplier_witness
#print axioms Blanc.Lift.Stock.Witnesses.updateMultiplierAt_witness
