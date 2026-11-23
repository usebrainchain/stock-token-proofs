#!/usr/bin/env bash
# Confirms that every stock token in Robinhood's published asset list is a beacon proxy whose beacon is
# 0xe10b…1b00 and that the beacon returns the implementation the proofs are about.
#
# The list is read from https://api.robinhood.com/rhj/assets (documented at
# https://docs.robinhood.com/chain/stock-token-apis). For each token on chain 4663 it reads the ERC-1967
# beacon slot with eth_getStorageAt; then it calls implementation() on the beacon once. Read-only RPC.
#
# Needs bash, curl, awk and sed. Environment: RPC_URL, ASSETS_URL, JOBS (default 4).
set -euo pipefail

ASSETS_URL=${ASSETS_URL:-https://api.robinhood.com/rhj/assets}
RPC_URL=${RPC_URL:-https://rpc.mainnet.chain.robinhood.com}
BEACON=e10b6f6b275de231345c20d14ab812db62151b00
IMPLEMENTATION=b35490d6f9163de4f80d88dc75c3516eb64c5ae2
# bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)
BEACON_SLOT=0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

rpc() {
  curl -sS --fail --retry 3 -X POST -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":$2}" "$RPC_URL" |
    sed -n 's/.*"result":"\(0x[0-9a-fA-F]*\)".*/\1/p' | tr 'A-F' 'a-f'
}
export -f rpc
export RPC_URL BEACON_SLOT

[[ $(rpc eth_chainId '[]') == 0x1237 ]] || fail "$RPC_URL is not Robinhood Chain (4663)"

# One "SYMBOL ADDRESS" line per deployment on chain 4663.
tokens=$(curl -sS --fail --retry 3 "$ASSETS_URL" |
  grep -o '"tokenSymbol":"[^"]*"\|"contractAddress":"0x[0-9a-fA-F]*","chainId":[0-9]*' |
  awk -F'"' '/tokenSymbol/ {sym = $4; next} {split($0, c, ":"); if (c[3] == 4663) print sym, $4}')
count=$(grep -c . <<<"$tokens" || true)
[[ $count -gt 0 ]] || fail "no tokens on chain 4663 in $ASSETS_URL"
echo "$count stock tokens on chain 4663 in $ASSETS_URL"

# Each output line: SYMBOL ADDRESS BEACON
results=$(xargs -P "${JOBS:-4}" -L 1 bash -c \
  'slot=$(rpc eth_getStorageAt "[\"$1\",\"$BEACON_SLOT\",\"latest\"]"); echo "$0 $1 ${slot: -40}"' <<<"$tokens")

others=$(awk -v b="$BEACON" '$3 != b' <<<"$results")
[[ -z $others ]] || fail "tokens whose beacon is not 0x$BEACON:"$'\n'"$others"
[[ $(grep -c . <<<"$results") == "$count" ]] || fail "read $(grep -c . <<<"$results") beacon slots for $count tokens"
echo "all $count have beacon 0x$BEACON in their ERC-1967 beacon slot"

impl=$(rpc eth_call "[{\"to\":\"0x$BEACON\",\"data\":\"0x5c60da1b\"},\"latest\"]")
[[ ${impl: -40} == "$IMPLEMENTATION" ]] || fail "the beacon returns 0x${impl: -40}, expected 0x$IMPLEMENTATION"
echo "the beacon's implementation() is 0x$IMPLEMENTATION"
echo "PASS: all $count stock tokens run implementation 0x$IMPLEMENTATION through beacon 0x$BEACON"
