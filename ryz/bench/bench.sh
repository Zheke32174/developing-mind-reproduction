#!/usr/bin/env bash
# Simple perf harness for ryz/aesh (acquisition-grade: measure, don't assume).
set -uo pipefail
BUN="${BUN:-/home/fixxia/.bun/bin/bun}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RYZ="$HERE/../bun/src/ryz.ts"

# nanoseconds via GNU date; convert diffs to ms for reporting.
ns() { date +%s%N; }
ms_of() { echo $(( ($1 - $2) / 1000000 )); }

echo "== RYZ interpreter: fib(30) =="
t0=$(ns); out=$("$BUN" "$RYZ" run "$HERE/fib.ryz"); t1=$(ns)
echo "  result: $out   (fib(30)=832040 expected)"
echo "  time:   $(ms_of "$t1" "$t0") ms  (interpreted + bun startup)"

echo "== RYZ: tight loop 1e6 increments =="
LOOP="$(mktemp /tmp/ryz_loop.XXXX.ryz)"
printf '%s\n' 'import "std/fmt";' 'fn main()->i32{ let mut i:i64=0; let mut s:i64=0; while i<1000000 { s=s+i; i=i+1; } fmt.println(s); return 0;}' > "$LOOP"
t0=$(ns); out=$("$BUN" "$RYZ" run "$LOOP"); t1=$(ns)
echo "  result: $out   time: $(ms_of "$t1" "$t0") ms"
rm -f "$LOOP"

echo "== AeSH: 200 -c command dispatches =="
AESH="$HERE/../aesh/src/aesh.ts"
t0=$(ns); for i in $(seq 1 200); do "$BUN" "$AESH" -c 'true' >/dev/null; done; t1=$(ns)
total=$(ms_of "$t1" "$t0")
echo "  200 spawns in ${total} ms  (~$(( total / 200 )) ms each, bun startup-dominated)"

echo "NOTE: native zenc binary removes per-call bun startup; these are dev-mode (interpreted) numbers."
