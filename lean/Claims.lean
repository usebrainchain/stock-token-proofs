import Blanc.Lift.Stock.Pause
import Blanc.Lift.Stock.NoCheck
import Blanc.Lift.Stock.Blocked
import Blanc.Lift.Stock.InRun
import Blanc.Lift.Stock.Witness

/-!
# The exact statements, pinned

Each `example` below restates one definition or theorem of the Stock family in full and is
discharged by that constant alone, so this file elaborates only if every statement is exactly as
written here (up to definitional unfolding). A theorem weakened in the source, or a definition its
statement unfolds to that changed, makes this file fail.

The pins are the Stock section of Blanc's `scripts/ClaimCheck.lean` at the pinned commit, which
Blanc's own claim gate checks; `check.sh` elaborates this copy against the freshly built modules.
-/

/-! Robinhood Chain Stock token (`Blanc.Lift.Stock`): the deployed runtime's certificate, the
role-guard theorems and the definitions their statements unfold to. -/

namespace Blanc.Lift.Stock
open Jaune Blanc Blanc.Lift

-- Stock: registry
example : registry = (0xe10b6f6b275de231345c20d14ab812db62151b00 : Adr) := rfl

-- Stock: hasRoleData
example (role : B256) (account : Adr) :
    hasRoleData role account = [0x91, 0xd1, 0x48, 0x54] ++ role.toBytes ++ account.toB256.toBytes :=
  rfl

-- Stock: pauseSelector
example : pauseSelector = (0x8456cb59 : B256) := rfl

-- Stock: tokenPauserRole
example : tokenPauserRole =
    (0xe95e22ec6dbf4c911d1fae59680a3e9cb71dd35b3a1c697d232e4b01a8ff30a2 : B256) := rfl

-- Stock: tokenPauserRole_eq_keccak
example : tokenPauserRole = Bytes.keccak "TOKEN_PAUSER_ROLE".toUTF8.toList := tokenPauserRole_eq_keccak

-- Stock: cert_check
example : Cert.check code cert = true := cert_check

-- Stock: jumps_ok
example : Cert.jumpsOk code cert = true := jumps_ok

-- Stock: pause_requires_role
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = pauseSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    ∃ out : Bytes,
      StaticAnswered F.sevm F.devm registry (hasRoleData tokenPauserRole F.sevm.caller) out ∧
      32 ≤ out.length ∧ Bytes.toB256 (out.take 32) = 1 :=
  pause_requires_role pc onCode stack memory selector success fork

end Blanc.Lift.Stock

/-! Stock: role guards, paused guards and the entry points that make neither check. -/

namespace Blanc.Lift.Stock
open Jaune Blanc Blanc.Lift

-- Stock: minterRole_eq_keccak
example : minterRole = Bytes.keccak "MINTER_ROLE".toUTF8.toList := minterRole_eq_keccak

-- Stock: burnerRole_eq_keccak
example : burnerRole = Bytes.keccak "BURNER_ROLE".toUTF8.toList := burnerRole_eq_keccak

-- Stock: adminBurnerRole_eq_keccak
example : adminBurnerRole = Bytes.keccak "ADMIN_BURNER_ROLE".toUTF8.toList := adminBurnerRole_eq_keccak

-- Stock: oraclePauserRole_eq_keccak
example : oraclePauserRole = Bytes.keccak "ORACLE_PAUSER_ROLE".toUTF8.toList := oraclePauserRole_eq_keccak

-- Stock: metadataUpdaterRole_eq_keccak
example : metadataUpdaterRole = Bytes.keccak "METADATA_UPDATER_ROLE".toUTF8.toList := metadataUpdaterRole_eq_keccak

-- Stock: multiplierUpdaterRole_eq_keccak
example : multiplierUpdaterRole = Bytes.keccak "MULTIPLIER_UPDATER_ROLE".toUTF8.toList := multiplierUpdaterRole_eq_keccak

-- Stock: unpauseSelector
example : unpauseSelector = (0x3f4ba83a : B256) := rfl

-- Stock: mintSelector
example : mintSelector = (0x40c10f19 : B256) := rfl

-- Stock: burnSelector
example : burnSelector = (0x9dc29fac : B256) := rfl

-- Stock: adminBurnSelector
example : adminBurnSelector = (0x06dd0419 : B256) := rfl

-- Stock: pauseOracleSelector
example : pauseOracleSelector = (0x253ea980 : B256) := rfl

-- Stock: unpauseOracleSelector
example : unpauseOracleSelector = (0x0fab6865 : B256) := rfl

-- Stock: setMetadataSelector
example : setMetadataSelector = (0x51335b50 : B256) := rfl

-- Stock: transferSelector
example : transferSelector = (0xa9059cbb : B256) := rfl

-- Stock: transferFromSelector
example : transferFromSelector = (0x23b872dd : B256) := rfl

-- Stock: approveSelector
example : approveSelector = (0x095ea7b3 : B256) := rfl

-- Stock: permitSelector
example : permitSelector = (0xd505accf : B256) := rfl

-- Stock: updateMultiplierSelector
example : updateMultiplierSelector = (0x5ffe6146 : B256) := rfl

-- Stock: updateMultiplierAtSelector
example : updateMultiplierAtSelector = (0xbad60f18 : B256) := rfl

-- Stock: pausedSlot
example : pausedSlot =
    (0x8d25ea8ee309999a79f0af498fbab0e424669497170669bd9e93b81a62babc01 : B256) := rfl

-- Stock: tokenFlag
example (sevm : Sevm) (b : Devm) :
    tokenFlag sevm b = Bytes.toB256 [0xff] &&& b.getStorVal sevm.currentTarget pausedSlot := rfl

-- Stock: pausedData
example : pausedData = [0x5c, 0x97, 0x5a, 0xbb] := rfl

-- Stock: RoleAnswered
example (F : Exec.Deriv) (role : B256) : RoleAnswered F role ↔
    ∃ out : Bytes, StaticAnswered F.sevm F.devm registry (hasRoleData role F.sevm.caller) out ∧
      32 ≤ out.length ∧ Bytes.toB256 (out.take 32) = 1 := Iff.rfl

-- Stock: RoleAnsweredAfter
example (F : Exec.Deriv) (role : B256) : RoleAnsweredAfter F role ↔
    ∃ (b' : Devm) (out : Bytes), QuietFrom F.sevm F.devm b' ∧
      StaticAnswered F.sevm b' registry (hasRoleData role F.sevm.caller) out ∧
      32 ≤ out.length ∧ Bytes.toB256 (out.take 32) = 1 := Iff.rfl

-- Stock: UnpausedAnswered
example (F : Exec.Deriv) : UnpausedAnswered F ↔
    tokenFlag F.sevm F.devm = 0 ∧ ∃ out : Bytes, StaticAnswered F.sevm F.devm registry pausedData out ∧
      32 ≤ out.length ∧ Bytes.toB256 (out.take 32) = 0 := Iff.rfl

-- Stock: UnpausedAnsweredAfter
example (F : Exec.Deriv) : UnpausedAnsweredAfter F ↔
    tokenFlag F.sevm F.devm = 0 ∧ ∃ (b' : Devm) (out : Bytes), QuietFrom F.sevm F.devm b' ∧
      StaticAnswered F.sevm b' registry pausedData out ∧
      32 ≤ out.length ∧ Bytes.toB256 (out.take 32) = 0 := Iff.rfl

-- Stock: OnlyRoleQuery
example (e : Nat) (S : List Nat) : OnlyRoleQuery e S ↔
    RefClosed cert.prog S = true ∧ e ∈ S ∧ 58 ∉ S ∧ staticEntries S = [119] := Iff.rfl

-- Stock: unpause_requires_role
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = unpauseSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleAnswered F tokenPauserRole :=
  unpause_requires_role pc onCode stack memory selector success fork

-- Stock: mint_requires_role
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = mintSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleAnswered F minterRole :=
  mint_requires_role pc onCode stack memory selector success fork

-- Stock: burn_requires_role
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = burnSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleAnswered F burnerRole :=
  burn_requires_role pc onCode stack memory selector success fork

-- Stock: adminBurn_requires_role
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = adminBurnSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleAnswered F adminBurnerRole :=
  adminBurn_requires_role pc onCode stack memory selector success fork

-- Stock: pauseOracle_requires_role
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = pauseOracleSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleAnswered F oraclePauserRole :=
  pauseOracle_requires_role pc onCode stack memory selector success fork

-- Stock: unpauseOracle_requires_role
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = unpauseOracleSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleAnswered F oraclePauserRole :=
  unpauseOracle_requires_role pc onCode stack memory selector success fork

-- Stock: setMetadata_requires_role
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = setMetadataSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleAnswered F metadataUpdaterRole :=
  setMetadata_requires_role pc onCode stack memory selector success fork

-- Stock: updateMultiplier_requires_role
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = updateMultiplierSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleAnsweredAfter F multiplierUpdaterRole :=
  updateMultiplier_requires_role pc onCode stack memory selector success fork

-- Stock: updateMultiplierAt_requires_role
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = updateMultiplierAtSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleAnsweredAfter F multiplierUpdaterRole :=
  updateMultiplierAt_requires_role pc onCode stack memory selector success fork

-- Stock: transfer_requires_unpaused
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = transferSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    UnpausedAnswered F :=
  transfer_requires_unpaused pc onCode stack memory selector success fork

-- Stock: transferFrom_requires_unpaused
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = transferFromSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    UnpausedAnswered F :=
  transferFrom_requires_unpaused pc onCode stack memory selector success fork

-- Stock: approve_requires_unpaused
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = approveSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    UnpausedAnswered F :=
  approve_requires_unpaused pc onCode stack memory selector success fork

-- Stock: permit_requires_unpaused
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = permitSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    UnpausedAnswered F :=
  permit_requires_unpaused pc onCode stack memory selector success fork

-- Stock: updateMultiplier_requires_unpaused
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = updateMultiplierSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    UnpausedAnswered F :=
  updateMultiplier_requires_unpaused pc onCode stack memory selector success fork

-- Stock: updateMultiplierAt_requires_unpaused
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = updateMultiplierAtSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    UnpausedAnswered F :=
  updateMultiplierAt_requires_unpaused pc onCode stack memory selector success fork

-- Stock: mint_requires_unpaused
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = mintSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    UnpausedAnsweredAfter F :=
  mint_requires_unpaused pc onCode stack memory selector success fork

-- Stock: burn_requires_unpaused
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = burnSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    UnpausedAnsweredAfter F :=
  burn_requires_unpaused pc onCode stack memory selector success fork

-- Stock: adminBurn_no_pause_no_blocklist
example : OnlyRoleQuery 178
    [4, 9, 17, 18, 19, 20, 39, 41, 73, 79, 82, 83, 88, 90, 91, 99, 119, 120, 121, 123, 124, 125,
      136, 143, 178] := adminBurn_no_pause_no_blocklist

-- Stock: pause_no_pause_check
example : OnlyRoleQuery 162
    [9, 18, 54, 83, 88, 119, 120, 162] := pause_no_pause_check

-- Stock: unpause_no_pause_check
example : OnlyRoleQuery 169
    [9, 18, 63, 83, 88, 119, 120, 169] := unpause_no_pause_check

-- Stock: setMetadata_no_pause_check
example : OnlyRoleQuery 164
    [5, 8, 9, 18, 22, 23, 24, 25, 26, 56, 57, 80, 83, 88, 97, 101, 104, 105, 119, 120, 126, 127,
      128, 164] := setMetadata_no_pause_check

-- Stock: pauseOracle_no_pause_check
example : OnlyRoleQuery 175
    [9, 18, 70, 83, 88, 113, 119, 120, 175] := pauseOracle_no_pause_check

-- Stock: unpauseOracle_no_pause_check
example : OnlyRoleQuery 172
    [9, 18, 66, 83, 88, 109, 119, 120, 172] := unpauseOracle_no_pause_check

end Blanc.Lift.Stock

/-! Stock: the blocklist guards (property 2). -/

namespace Blanc.Lift.Stock
open Jaune Blanc Blanc.Lift

-- Stock: isBlockedData
example (a : Adr) : isBlockedData a = [0xfb, 0xac, 0x39, 0x51] ++ a.toB256.toBytes := rfl

-- Stock: argAdr
example (sevm : Sevm) (k : Nat) :
    argAdr sevm k = (Sevm.dataWord sevm (Nat.toB256 (4 + 32 * k))).toAdr := rfl

-- Stock: BlockedClear
example (F : Exec.Deriv) (a : Adr) : BlockedClear F a ↔
    ∃ (b' : Devm) (out : Bytes), QuietFrom F.sevm F.devm b' ∧
      StaticAnswered F.sevm b' registry (isBlockedData a) out ∧
      32 ≤ out.length ∧ Bytes.toB256 (out.take 32) = 0 := Iff.rfl

-- Stock: gasMeasure_initDevm
example (msg : Msg) : (initDevm msg).gasMeasure = msg.gas := gasMeasure_initDevm msg

-- Stock: transfer_requires_unblocked
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = transferSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork)
    (gas : F.devm.gasMeasure < 2 ^ 256) :
    BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F F.sevm.caller :=
  transfer_requires_unblocked pc onCode stack memory selector success fork gas

-- Stock: transferFrom_requires_unblocked
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = transferFromSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork)
    (gas : F.devm.gasMeasure < 2 ^ 256) :
    BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F (argAdr F.sevm 1) ∧ BlockedClear F F.sevm.caller :=
  transferFrom_requires_unblocked pc onCode stack memory selector success fork gas

-- Stock: approve_requires_unblocked
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = approveSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork)
    (gas : F.devm.gasMeasure < 2 ^ 256) :
    BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F F.sevm.caller :=
  approve_requires_unblocked pc onCode stack memory selector success fork gas

-- Stock: permit_requires_unblocked
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = permitSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork)
    (gas : F.devm.gasMeasure < 2 ^ 256) :
    BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F (argAdr F.sevm 1) ∧ BlockedClear F F.sevm.caller :=
  permit_requires_unblocked pc onCode stack memory selector success fork gas

-- Stock: mint_requires_unblocked
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = mintSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork)
    (gas : F.devm.gasMeasure < 2 ^ 256) :
    BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F F.sevm.caller :=
  mint_requires_unblocked pc onCode stack memory selector success fork gas

-- Stock: burn_requires_unblocked
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = burnSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork)
    (gas : F.devm.gasMeasure < 2 ^ 256) :
    BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F F.sevm.caller :=
  burn_requires_unblocked pc onCode stack memory selector success fork gas

end Blanc.Lift.Stock

namespace Blanc.Lift.Stock
open Jaune Blanc Blanc.Lift

-- Stock: dispatch_targets
example : cert.prog[178]? = some t_023f_c178 ∧ cert.prog[162]? = some t_03ca_c162 ∧
    cert.prog[169]? = some t_02cc_c169 ∧ cert.prog[164]? = some t_0339_c164 ∧
    cert.prog[175]? = some t_02ad_c175 ∧ cert.prog[172]? = some t_027c_c172 :=
  dispatch_targets

end Blanc.Lift.Stock

/-! Stock: the role queries as calls the run itself made. -/

namespace Blanc.Lift.Stock
open Jaune Blanc Blanc.Lift

-- Stock: CalledInRun
example (F : Exec.Deriv) (t : Adr) (data out : Bytes) : CalledInRun F t data out ↔
    ∃ step : CallOccurrenceStep F .staticcall,
      ∃ (b : Devm) (gw tw ii is oi os : B256) (S : List B256) (M : Mem) (G : Nat),
        step.occurrence.node.devm = St b (gw :: tw :: ii :: is :: oi :: os :: S) M G ∧
        tw.toAdr = t ∧ (M.read ii.toNat is.toNat).1 = data ∧
        step.returned.devm.stack = 1 :: S ∧ step.returned.devm.returnData = out ∧
        StaticAnswered F.sevm b t data out := Iff.rfl

-- Stock: RoleCalled
example (F : Exec.Deriv) (role : B256) : RoleCalled F role ↔
    ∃ out : Bytes, CalledInRun F registry (hasRoleData role F.sevm.caller) out ∧
      32 ≤ out.length ∧ Bytes.toB256 (out.take 32) = 1 := Iff.rfl

-- Stock: pause_role_in_run
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = pauseSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleCalled F tokenPauserRole :=
  pause_role_in_run pc onCode stack memory selector success fork

-- Stock: unpause_role_in_run
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = unpauseSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleCalled F tokenPauserRole :=
  unpause_role_in_run pc onCode stack memory selector success fork

-- Stock: mint_role_in_run
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = mintSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleCalled F minterRole :=
  mint_role_in_run pc onCode stack memory selector success fork

-- Stock: burn_role_in_run
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = burnSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleCalled F burnerRole :=
  burn_role_in_run pc onCode stack memory selector success fork

-- Stock: adminBurn_role_in_run
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = adminBurnSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleCalled F adminBurnerRole :=
  adminBurn_role_in_run pc onCode stack memory selector success fork

-- Stock: pauseOracle_role_in_run
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = pauseOracleSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleCalled F oraclePauserRole :=
  pauseOracle_role_in_run pc onCode stack memory selector success fork

-- Stock: unpauseOracle_role_in_run
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = unpauseOracleSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleCalled F oraclePauserRole :=
  unpauseOracle_role_in_run pc onCode stack memory selector success fork

-- Stock: setMetadata_role_in_run
example {F : Exec.Deriv} {post : Devm}
    (pc : F.pc = 0) (onCode : F.sevm.code = code)
    (stack : F.devm.stack = []) (memory : F.devm.memory = Mem.empty)
    (selector : Sevm.selector F.sevm = setMetadataSelector)
    (success : F.exn = .ok post) (fork : CoveredFork F.sevm.benvStat.fork) :
    RoleCalled F metadataUpdaterRole :=
  setMetadata_role_in_run pc onCode stack memory selector success fork

end Blanc.Lift.Stock

/-! Stock: non-vacuity witnesses for the role, pause and blocklist theorems. -/

namespace Blanc.Lift.Stock.Witnesses
open Jaune Blanc Blanc.Lift Blanc.Lift.Stock

-- Stock: Witnesses.Premises
example (F : Exec.Deriv) (sel : B256) (post : Devm) : Premises F sel post ↔
  F.pc = 0 ∧ F.sevm.code = code ∧ F.devm.stack = [] ∧ F.devm.memory = Mem.empty ∧
      Sevm.selector F.sevm = sel ∧ F.exn = .ok post ∧ CoveredFork F.sevm.benvStat.fork := Iff.rfl

-- Stock: pause_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F pauseSelector post ∧ post.error = none ∧
      RoleCalled F tokenPauserRole ∧
      ∃ out : Bytes,
        StaticAnswered F.sevm F.devm registry (hasRoleData tokenPauserRole F.sevm.caller) out ∧
        32 ≤ out.length ∧ Bytes.toB256 (out.take 32) = 1 :=
  pause_witness

-- Stock: unpause_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F unpauseSelector post ∧ post.error = none ∧
      RoleCalled F tokenPauserRole ∧
      ∃ out : Bytes,
        StaticAnswered F.sevm F.devm registry (hasRoleData tokenPauserRole F.sevm.caller) out ∧
        32 ≤ out.length ∧ Bytes.toB256 (out.take 32) = 1 :=
  unpause_witness

-- Stock: mint_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F mintSelector post ∧ post.error = none ∧
      RoleAnswered F minterRole ∧ RoleCalled F minterRole ∧ UnpausedAnsweredAfter F ∧
      (BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F F.sevm.caller) :=
  mint_witness

-- Stock: burn_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F burnSelector post ∧ post.error = none ∧
      RoleAnswered F burnerRole ∧ RoleCalled F burnerRole ∧ UnpausedAnsweredAfter F ∧
      (BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F F.sevm.caller) :=
  burn_witness

-- Stock: adminBurn_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F adminBurnSelector post ∧ post.error = none ∧
      RoleAnswered F adminBurnerRole ∧ RoleCalled F adminBurnerRole :=
  adminBurn_witness

-- Stock: pauseOracle_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F pauseOracleSelector post ∧ post.error = none ∧
      RoleAnswered F oraclePauserRole ∧ RoleCalled F oraclePauserRole :=
  pauseOracle_witness

-- Stock: unpauseOracle_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F unpauseOracleSelector post ∧ post.error = none ∧
      RoleAnswered F oraclePauserRole ∧ RoleCalled F oraclePauserRole :=
  unpauseOracle_witness

-- Stock: setMetadata_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F setMetadataSelector post ∧ post.error = none ∧
      RoleAnswered F metadataUpdaterRole ∧ RoleCalled F metadataUpdaterRole :=
  setMetadata_witness

-- Stock: transfer_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F transferSelector post ∧ post.error = none ∧
      UnpausedAnswered F ∧ (BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F F.sevm.caller) :=
  transfer_witness

-- Stock: transferFrom_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F transferFromSelector post ∧ post.error = none ∧
      UnpausedAnswered F ∧ (BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F (argAdr F.sevm 1) ∧
        BlockedClear F F.sevm.caller) :=
  transferFrom_witness

-- Stock: approve_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F approveSelector post ∧ post.error = none ∧
      UnpausedAnswered F ∧ (BlockedClear F (argAdr F.sevm 0) ∧ BlockedClear F F.sevm.caller) :=
  approve_witness

-- Stock: updateMultiplier_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F updateMultiplierSelector post ∧
      post.error = none ∧ UnpausedAnswered F ∧ RoleAnsweredAfter F multiplierUpdaterRole :=
  updateMultiplier_witness

-- Stock: updateMultiplierAt_witness
example :
    ∃ (F : Exec.Deriv) (post : Devm), Premises F updateMultiplierAtSelector post ∧
      post.error = none ∧ UnpausedAnswered F ∧ RoleAnsweredAfter F multiplierUpdaterRole :=
  updateMultiplierAt_witness

end Blanc.Lift.Stock.Witnesses
