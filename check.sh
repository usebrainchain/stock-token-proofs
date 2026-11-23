#!/usr/bin/env bash
# Rebuilds the Lean proofs about the Stock token implementation from pinned sources and checks them.
#
# Needs git and curl, plus perl, xxd or python3 to turn hex into bytes. Everything else (elan, the
# Lean toolchain, Blanc, Jaune, the Mathlib cache) is fetched into $WORK (default ./work) and
# $ELAN_HOME (default ~/.elan). The only call to Robinhood Chain is a read: eth_chainId and
# eth_getCode.
#
# Environment: WORK, ELAN_HOME, RPC_URL, REPLAY_JOBS (default 4), SKIP_REPLAY=1.
set -euo pipefail

BLANC_URL=https://github.com/skbaek/blanc.git
BLANC_BASE=bdb298483ac6cf82e70732df378aa8b443f7ec1c
PROOF_HEAD=0dcf77d5d44497e6f866880b1d624c948dd015a1
CODE_SHA256=0ac99e9cc7a3738645af72f6d9e8fb8242660b63134d8fb0c44ba6fac39deec2
CODE_SIZE=11614
IMPLEMENTATION=0xb35490d6f9163DE4F80d88dc75c3516eb64C5aE2
CHAIN_ID=0x1237
RPC_URL=${RPC_URL:-https://rpc.mainnet.chain.robinhood.com}
ELAN_INIT=https://raw.githubusercontent.com/leanprover/elan/v4.4.0/elan-init.sh

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK=${WORK:-$ROOT/work}
SRC=$WORK/blanc
LOGS=$WORK/logs
export ELAN_HOME=${ELAN_HOME:-$HOME/.elan}
export PATH=$ELAN_HOME/bin:$PATH

MODULES=(
  Blanc.Lift.Stock.Cert Blanc.Lift.Stock.CheckTries Blanc.Lift.Stock.CheckPart0
  Blanc.Lift.Stock.CheckPart1 Blanc.Lift.Stock.CheckPart2 Blanc.Lift.Stock.CheckPart3
  Blanc.Lift.Stock.Check Blanc.Lift.Stock.Jumps
  Blanc.Lift.StockWs.Ann Blanc.Lift.StockWs.Check0 Blanc.Lift.StockWs.Check1
  Blanc.Lift.StockWs.Check2 Blanc.Lift.StockWs.Check3 Blanc.Lift.StockWs.Check
  Blanc.Lift.Stock.Pause Blanc.Lift.Stock.Roles Blanc.Lift.Stock.Query Blanc.Lift.Stock.Paused
  Blanc.Lift.Stock.NoCheck Blanc.Lift.Stock.Blocked Blanc.Lift.Stock.InRun
  Blanc.Lift.Stock.Registry.Cert Blanc.Lift.Stock.Registry.Check
  Blanc.Lift.WitnessStatic Blanc.Lift.Stock.Witness
  # Not imported by the modules above, but changed by the patches, so built and replayed as well.
  Blanc.Lift.FreePtrMem
)

START=$SECONDS
fail() { printf '\nFAIL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s\n' "$1"; T0=$SECONDS; }
took() { printf -- '-- %ds\n' $((SECONDS - T0)); }
in_src() { (cd "$SRC" && "$@"); }

sha256() {
  if command -v sha256sum >/dev/null; then sha256sum | cut -d' ' -f1; else shasum -a 256 | cut -d' ' -f1; fi
}

unhex() {
  if command -v perl >/dev/null; then perl -ne 'chomp; print pack("H*", $_)'
  elif command -v xxd >/dev/null; then xxd -r -p
  else python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.stdin.read().strip()))'
  fi
}

rpc() {
  curl -sS --fail --retry 3 -X POST -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":$2}" "$RPC_URL" |
    sed -n 's/.*"result":"\(0x[0-9a-fA-F]*\)".*/\1/p' | tr 'A-F' 'a-f'
}

section "host"
for tool in git curl tar; do command -v "$tool" >/dev/null || fail "$tool is required"; done
command -v perl >/dev/null || command -v xxd >/dev/null || command -v python3 >/dev/null ||
  fail "perl, xxd or python3 is required to turn hex into bytes"
mkdir -p "$WORK" "$LOGS"
cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo '?')
mem_gb=$(awk '/^MemTotal/ {printf "%d", $2 / 1048576}' /proc/meminfo 2>/dev/null || echo '?')
disk_gb=$(df -Pk "$WORK" | awk 'NR == 2 {printf "%d", $4 / 1048576}')
echo "cores $cores, memory ${mem_gb} GB, free disk ${disk_gb} GB under $WORK"
[[ $mem_gb == '?' || $mem_gb -ge 12 ]] || echo "warning: on 8 cores the check peaked at about 9 GB of memory in use"
[[ $disk_gb -ge 13 ]] || echo "warning: the check needs about 8 GB under $WORK, plus 3.5 GB for the toolchain and downloads"

section "sources: Blanc $BLANC_BASE plus lean/patches"
if [[ -d $SRC/.git ]] && [[ $(git -C "$SRC" rev-parse HEAD 2>/dev/null) == "$PROOF_HEAD" ]]; then
  echo "reusing $SRC"
else
  rm -rf "$SRC"
  git init -q "$SRC"
  git -C "$SRC" fetch -q --depth 1 "$BLANC_URL" "$BLANC_BASE"
  git -C "$SRC" checkout -q --detach FETCH_HEAD
  [[ $(git -C "$SRC" rev-parse HEAD) == "$BLANC_BASE" ]] || fail "fetched Blanc is not at $BLANC_BASE"
  patches=("$ROOT"/lean/patches/*.patch)
  # Committing as the patches' author, at their dates, rebuilds the original commits hash for hash.
  author=$(sed -n '2s/^From: //p' "${patches[0]}")
  GIT_COMMITTER_NAME=${author% <*} GIT_COMMITTER_EMAIL=$(sed 's/.*<\(.*\)>$/\1/' <<<"$author") \
    git -C "$SRC" -c user.name=check -c user.email=check@localhost \
    am -q --committer-date-is-author-date "${patches[@]}"
fi
head=$(git -C "$SRC" rev-parse HEAD)
[[ $head == "$PROOF_HEAD" ]] || fail "the patches produced $head, expected $PROOF_HEAD"
git -C "$SRC" diff --quiet HEAD || fail "$SRC has local changes; remove it to start over"
git -C "$SRC" diff --quiet "$BLANC_BASE" HEAD -- lean-toolchain lakefile.lean lake-manifest.json ||
  fail "the patches change Blanc's toolchain or dependency pins"
git -C "$SRC" log --format='%h %s' "$BLANC_BASE..HEAD"
echo "HEAD $head; toolchain $(cat "$SRC/lean-toolchain"), dependency pins unchanged from Blanc"
took

section "lean toolchain"
if ! command -v elan >/dev/null; then
  echo "installing elan into $ELAN_HOME"
  curl -sSfL "$ELAN_INIT" | sh -s -- -y --default-toolchain none --no-modify-path
fi
elan --version
in_src lean --version
took

section "mathlib cache"
in_src lake exe cache get > "$LOGS/cache.log" 2>&1 || { tail -20 "$LOGS/cache.log"; fail "lake exe cache get"; }
tail -2 "$LOGS/cache.log"
took

section "build the Stock modules (about 5 minutes on 8 cores; log: $LOGS/build.log)"
in_src lake build "${MODULES[@]}" > "$LOGS/build.log" 2>&1 || { tail -40 "$LOGS/build.log"; fail "lake build"; }
tail -1 "$LOGS/build.log"
took

section "trust surface: no sorry, admit, native_decide, implemented_by, extern, axiom, opaque or unsafe"
changed=()
while IFS= read -r f; do changed+=("$f"); done < <(git -C "$SRC" diff --name-only "$BLANC_BASE" HEAD -- 'Blanc/*.lean')
[[ ${#changed[@]} -gt 0 ]] || fail "no changed modules found"
pattern='sorry|admit|native_decide|implemented_by|extern|axiom|opaque|unsafe'
hits=$(in_src grep -n -w -E "$pattern" "${changed[@]}" "$ROOT/lean/Claims.lean" "$ROOT/lean/CodeHex.lean" || true)
[[ -z $hits ]] || fail "forbidden tokens:"$'\n'"$hits"
echo "${#changed[@]} Lean modules added or changed by the patches, plus lean/Claims.lean: clean"
took

section "the certified bytes are the deployed implementation"
hex=$(in_src lake env lean "$ROOT/lean/CodeHex.lean") || fail "lean/CodeHex.lean"
[[ $hex =~ ^0x[0-9a-f]+$ ]] || fail "unexpected output from lean/CodeHex.lean"
size=$(( (${#hex} - 2) / 2 ))
sha=$(printf '%s' "${hex#0x}" | unhex | sha256)
echo "Blanc.Lift.Stock.code: $size bytes, sha256 $sha"
[[ $size == "$CODE_SIZE" && $sha == "$CODE_SHA256" ]] || fail "expected $CODE_SIZE bytes, sha256 $CODE_SHA256"
repo_hex=$(tr -d ' \n' < "$ROOT/onchain/Stock/runtime-bytecode.hex" | tr 'A-F' 'a-f')
[[ ${repo_hex#0x} == "${hex#0x}" ]] || fail "onchain/Stock/runtime-bytecode.hex differs from the certified bytes"
echo "onchain/Stock/runtime-bytecode.hex (the bytes tests/ rebuilds from source): identical"
chain=$(rpc eth_chainId '[]') || fail "no answer from $RPC_URL"
[[ $chain == "$CHAIN_ID" ]] || fail "$RPC_URL reports chain ${chain:-nothing}, expected $CHAIN_ID (4663)"
deployed=$(rpc eth_getCode "[\"$IMPLEMENTATION\",\"latest\"]") || fail "eth_getCode failed"
[[ -n $deployed ]] || fail "eth_getCode returned nothing"
echo "eth_getCode($IMPLEMENTATION) on chain 4663: $(( (${#deployed} - 2) / 2 )) bytes"
[[ $deployed == "$hex" ]] || fail "the code on chain differs from the certified bytes"
echo "identical to the certified bytes"
took

section "exact statements (lean/Claims.lean)"
in_src lake env lean -DwarningAsError=true "$ROOT/lean/Claims.lean" || fail "a pinned statement no longer matches"
echo "$(grep -c '^-- Stock:' "$ROOT/lean/Claims.lean") pinned statements match the theorems"
took

section "axioms (lean/Axioms.lean)"
axioms=$(in_src lake env lean -DwarningAsError=true "$ROOT/lean/Axioms.lean") || fail "lean/Axioms.lean"
printf '%s\n' "$axioms"
expected=$(grep -c '^#print axioms' "$ROOT/lean/Axioms.lean")
flat=$(tr '\n' ' ' <<<"$axioms")
lists=$(grep -o 'depends on axioms: \[[^]]*\]' <<<"$flat" || true)
none=$( (grep -o 'does not depend on any axioms' <<<"$flat" || true) | wc -l | tr -d ' ')
reported=$(( $(grep -c . <<<"$lists" || true) + none ))
[[ $reported == "$expected" ]] || fail "expected $expected axiom reports, read $reported"
extra=$(sed 's/.*\[\(.*\)\]/\1/' <<<"$lists" | tr ',' '\n' | tr -d ' ' | grep -v -x -E 'propext|Classical\.choice|Quot\.sound' | sort -u || true)
[[ -z $extra ]] || fail "axioms beyond propext, Classical.choice and Quot.sound: $(tr '\n' ' ' <<<"$extra")"
echo "$expected theorems, none beyond propext, Classical.choice and Quot.sound"
took

if [[ ${SKIP_REPLAY:-0} != 1 ]]; then
  section "kernel replay with leanchecker (${#changed[@]} modules, ${REPLAY_JOBS:-4} at a time)"
  results=$(for f in "${changed[@]}"; do m=${f%.lean}; echo "${m//\//.}"; done |
    xargs -P "${REPLAY_JOBS:-4}" -I{} sh -c \
      'cd "$1" && lake env leanchecker "$2" > "$3/replay-$2.log" 2>&1 && echo "ok   $2" || echo "FAIL $2"' \
      _ "$SRC" {} "$LOGS" | sort -k2)
  printf '%s\n' "$results"
  ! grep -q '^FAIL' <<<"$results" || fail "kernel replay (logs: $LOGS/replay-*.log)"
  took
fi

total=$((SECONDS - START))
printf '\nPASS: %d theorems about the Stock implementation at %s, on bytes identical to chain 4663, in %d min %d s\n' \
  "$expected" "$IMPLEMENTATION" $((total / 60)) $((total % 60))
