# RYZ directionality — bi-directional outward, mono-directional inward

A design law of ryz (operator directive):

> *Functionally bi-directional, but uniquely mono-directional.*

## Bi-directional (outward) — ryz exports capability
Anything ryz compiles is a first-class native artifact on the C ABI, so **any language can run
ryz code**:
- `zenc lib x.ryz` → `libx.so` whose `export fn`s are plain C symbols.
- Consumers need **no ryz toolchain** — just the `.so`. Proven both ways:
  - C links `libmathlib.so` and calls `add/mul/fib` (`zenc/test/native_parity.sh`).
  - Python loads it via `ctypes` and runs the same functions
    (`integration/bidirectional/use_ryz_lib.py`).
- This is the "easy to install with the shared-libs half" — ryz adopts into any ecosystem.

## Mono-directional (inward) — ryz keeps authority over ryz
The flow only goes one way at the *source* level:
- A `.ryz` program **requires ryz** to run or build. There is no foreign runtime that executes
  `.ryz` source; you need the interpreter (`bin/ryz`) or the compiler (`zenc native`/`zenc lib`).
- The exported `.so` is a **one-way capability**: it lets others *call* ryz, never *author* or
  *reconstruct* ryz. The language stays sovereign.
- Practically: shipping a `.so` does not ship ryz. Running `.ryz` is gated on the ryz toolchain.

## Why this shape
ryz trades goods freely (libs anyone can consume) while keeping its language sovereign — adoption
without surrender. It can pervade other systems via shared libs, yet ryz-the-language is only ever
served by ryz. Outward generosity, inward sovereignty.

## Invariants to preserve as the language grows
1. Every `export fn` stays C-ABI clean (no ryz-runtime dependency leaks into the `.so`).
2. No `.ryz` execution path exists outside the ryz toolchain (no transpile-and-forget that lets a
   foreign toolchain own `.ryz`). The generated C is an *output*, not a substitute for ryz.
3. Consuming a ryz `.so` never requires bun/node/ryz — verified by the cross-language demos.
