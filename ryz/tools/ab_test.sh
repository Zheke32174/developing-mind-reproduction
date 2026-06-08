#!/usr/bin/env bash
# A/B test: original bash tool vs ryz port must produce identical output.
set -uo pipefail
BUN="${BUN:-/home/fixxia/.bun/bin/bun}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RYZ_CLI="$HERE/../bun/src/ryz.ts"

SAMPLE="$(mktemp /tmp/filestats_sample.XXXX)"
printf '%s\n' "alpha" "   " "beta gamma" "" "a slightly longer line here" "x" > "$SAMPLE"

orig="$(bash "$HERE/orig/filestats.sh" "$SAMPLE")"
port="$("$BUN" "$RYZ_CLI" run "$HERE/filestats.ryz" "$SAMPLE")"

echo "original (bash): $orig"
echo "ryz port:        $port"
rm -f "$SAMPLE"

if [ "$orig" == "$port" ]; then
  echo "A/B MATCH ✅ — ryz port is behavior-equivalent to the original"
  exit 0
else
  echo "A/B MISMATCH ❌"
  exit 1
fi
