#!/usr/bin/env bash
# RYZ Linux coreutils A/B: each ryz-native tool must match the system tool AND the interpreter.
set -uo pipefail
BUN="${BUN:-$HOME/.bun/bin/bun}"
RL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R="$(cd "$RL/.." && pwd)"
ZENC="$BUN $R/ryz/zenc/zenc.ts"; RYZ="$BUN $R/ryz/bun/src/ryz.ts"
DIST="$R/ryz/dist"; BIN="$RL/bin"; mkdir -p "$BIN"
pass=0; fail=0
ck(){ if [ "$2" == "$3" ]; then echo "  ok  $1"; pass=$((pass+1)); else echo "FAIL  $1"; echo "   want: $(printf %q "$2")"; echo "   got : $(printf %q "$3")"; fail=$((fail+1)); fi; }
build(){ $ZENC native "$RL/src/$1.ryz" >/dev/null 2>&1 && cp "$DIST/$1" "$BIN/$1"; }

# echo
build echo
ck "echo: native vs system"     "$(/bin/echo hello ryz world)"          "$("$BIN/echo" hello ryz world)"
ck "echo: native vs interpreter" "$($RYZ run "$RL/src/echo.ryz" a b c)"  "$("$BIN/echo" a b c)"
ck "echo: empty"                "$(/bin/echo)"                          "$("$BIN/echo")"

# seq
build seq
ck "seq 5: native vs system"     "$(seq 5)"        "$("$BIN/seq" 5)"
ck "seq 1: native vs system"     "$(seq 1)"        "$("$BIN/seq" 1)"
ck "seq 0: native vs system"     "$(seq 0 2>/dev/null || true)" "$("$BIN/seq" 0)"

# cat
build cat
SAMPLE="$(mktemp)"; printf '%s\n' "line one" "line two" "  spaced  " "end" > "$SAMPLE"
ck "cat: native vs system"      "$(/bin/cat "$SAMPLE")"   "$("$BIN/cat" "$SAMPLE")"
ck "cat: native vs interpreter" "$($RYZ run "$RL/src/cat.ryz" "$SAMPLE")" "$("$BIN/cat" "$SAMPLE")"
rm -f "$SAMPLE"

echo; echo "coreutils A/B: $pass passed, $fail failed"
exit $((fail==0?0:1))
