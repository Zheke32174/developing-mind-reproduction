#!/usr/bin/env bash
# A/B test: original bash tool vs ryz port must produce identical output.
set -uo pipefail
BUN="${BUN:-/home/fixxia/.bun/bin/bun}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RYZ_CLI="$HERE/../bun/src/ryz.ts"

fail=0

# --- filestats ---
SAMPLE="$(mktemp /tmp/filestats_sample.XXXX)"
printf '%s\n' "alpha" "   " "beta gamma" "" "a slightly longer line here" "x" > "$SAMPLE"
orig="$(bash "$HERE/orig/filestats.sh" "$SAMPLE")"
port="$("$BUN" "$RYZ_CLI" run "$HERE/filestats.ryz" "$SAMPLE")"
echo "[filestats] original: $orig"
echo "[filestats] ryz port: $port"
[ "$orig" == "$port" ] && echo "  A/B MATCH ✅" || { echo "  A/B MISMATCH ❌"; fail=1; }
rm -f "$SAMPLE"

# --- wordfreq ---
WS="$(mktemp /tmp/wordfreq_sample.XXXX)"
printf '%s\n' "the cat sat on the mat" "the dog sat" "cat and dog" "the the the" > "$WS"
worig="$(bash "$HERE/orig/wordfreq.sh" "$WS")"
wport="$("$BUN" "$RYZ_CLI" run "$HERE/wordfreq.ryz" "$WS")"
if [ "$worig" == "$wport" ]; then echo "[wordfreq] A/B MATCH ✅"; else
  echo "[wordfreq] A/B MISMATCH ❌"; echo "--- bash ---"; echo "$worig"; echo "--- ryz ---"; echo "$wport"; fail=1
fi
rm -f "$WS"

[ "$fail" -eq 0 ] && echo "ALL TOOL PORTS A/B-MATCH ✅" || { echo "SOME PORTS DIVERGE ❌"; exit 1; }
