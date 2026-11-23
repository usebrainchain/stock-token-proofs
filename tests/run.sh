#!/usr/bin/env bash
# Rebuilds and re-runs every test layer. Local simulation only: no RPC, no fork, no transactions.
set -euo pipefail
cd "$(dirname "$0")"

stage() {
  local name=$1
  shift
  local t0=$SECONDS
  echo "== $name"
  "$@"
  echo "== $name: $((SECONDS - t0))s"
}

start=$SECONDS
rm -rf cache/fuzz cache/invariant
stage build forge build
stage bytecode python3 scripts/check_bytecode.py
stage unit forge test --match-path 'test/unit/*'
stage invariant forge test --match-contract StockInvariants
stage halmos halmos --match-contract 'P[1-7].*Halmos'
stage control bash -c 'cd controls/pause-norole && forge test'
if [[ "${SKIP_MUTANTS:-0}" != 1 ]]; then
  stage mutants python3 mutants/run.py
fi
echo "== total: $((SECONDS - start))s"
