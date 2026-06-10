#!/usr/bin/env bash
# Task #51 test: ryz native (zenc->C->gcc) output must match the interpreter,
# the artifacts must be real ELF, run without a JS runtime, and ship a working .so.
set -uo pipefail
BUN="${BUN:-$HOME/.bun/bin/bun}"
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZENC="$BUN $R/zenc/zenc.ts"
RYZ="$BUN $R/bun/src/ryz.ts"
EX="$R/bun/examples"; DIST="$R/dist"
pass=0; fail=0
ck(){ if [ "$2" == "$3" ]; then echo "  ok  $1"; pass=$((pass+1)); else echo "FAIL  $1"; echo "   interp: $2"; echo "   native: $3"; fail=$((fail+1)); fi; }

for prog in hello fib; do
  $ZENC native "$EX/$prog.ryz" >/dev/null 2>&1 || { echo "FAIL  $prog (build)"; fail=$((fail+1)); continue; }
  interp="$($RYZ run "$EX/$prog.ryz")"
  native="$("$DIST/$prog")"
  ck "native parity: $prog" "$interp" "$native"
done

# ELF check
file "$DIST/hello" | grep -q ELF && { echo "  ok  hello is ELF"; pass=$((pass+1)); } || { echo "FAIL  hello not ELF"; fail=$((fail+1)); }
# no-runtime check (bare PATH)
out="$(env -i PATH=/usr/bin:/bin HOME="$HOME" "$DIST/hello")"
ck "runs without bun/node (bare PATH)" "Hello from RYZ" "$out"

# shared library
$ZENC lib "$EX/mathlib.ryz" >/dev/null 2>&1
file "$DIST/libmathlib.so" | grep -q "shared object" && { echo "  ok  libmathlib.so is a shared object"; pass=$((pass+1)); } || { echo "FAIL  .so"; fail=$((fail+1)); }
for sym in add mul fib; do nm -D "$DIST/libmathlib.so" | grep -qE " T $sym$" && { echo "  ok  exports $sym"; pass=$((pass+1)); } || { echo "FAIL  missing export $sym"; fail=$((fail+1)); }; done
cat > /tmp/np.c <<'EOF'
long long add(long long,long long); int main(){return add(20,22)==42?0:1;}
EOF
gcc -O2 -o /tmp/np /tmp/np.c -L"$DIST" -lmathlib -Wl,-rpath,"$DIST" 2>/dev/null && /tmp/np && { echo "  ok  C links + calls ryz .so (add(20,22)==42)"; pass=$((pass+1)); } || { echo "FAIL  link/call .so"; fail=$((fail+1)); }
rm -f /tmp/np /tmp/np.c

echo; echo "native parity: $pass passed, $fail failed"
exit $((fail==0?0:1))
