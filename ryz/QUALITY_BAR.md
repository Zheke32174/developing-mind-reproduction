# RYZ / AeSH — Acquisition-Grade Quality Bar

**North star (operator directive, 2026-06-08):** ryz (language), aesh (shell), the resulting
ecosystem, and the cross-device OS must reach a quality an acquirer of Microsoft's caliber would
value. This is the *standard for all work*, not a single deliverable. Honest framing: we cannot
manufacture an acquisition; we can make the artifact genuinely worth one.

**Soul / ethos (operator directive):** *be Linux — because it's better than Microsoft.* The
quality bar is "acquisition-grade"; the values are open and Unix-native. Concretely:
- **Linux-first, native.** Runs first-class on Linux/WSL/Termux. No Windows lock-in; Windows is
  a guest, not the host. POSIX-friendly, terminal-native, composable.
- **Open & free.** Permissive/libre license, readable source, no telemetry, no walled garden.
- **Unix philosophy.** Small sharp tools, text/structured streams, do-one-thing-well, pipe-able.
  aesh and ryz extend that tradition rather than replacing it.
- The point of being "worth Microsoft money" is to prove open/Linux craft beats the walled
  garden on its own quality terms — then stay open.

## What "acquisition-grade" means here — the definition of done

1. **Correctness & rigor** — every feature has tests; no mocks masquerading as features; error
   paths handled; deterministic behavior. Target: broad unit + integration coverage, CI-runnable.
2. **Architecture** — clean separation (frontend/runtime/stdlib/tooling), documented invariants,
   no hidden global state, extensible without rewrites.
3. **Performance** — measured, not assumed. Benchmarks for the interpreter hot paths and shell
   command dispatch; native binaries via zenc with size/startup tracked.
4. **Robustness & safety** — fuzz the lexer/parser; graceful failure; resource bounds (the
   security_gate.go memory-gating concept wired in for plugins); no UB, no crashes on bad input.
5. **DX & docs** — a language spec, a shell manual, a getting-started, runnable examples, and a
   stable CLI. A new engineer is productive in under an hour.
6. **Distribution** — reproducible builds, versioning/semver, install story per platform
   (Windows/WSL/Termux), and a clear license.
7. **Differentiation** — the Frankenstein thesis (Rust safety + Zig control + Go CSP + TS/Bun
   ergonomics + Lua plug-ins + Java interop) realized in a way that is demonstrably more than the
   sum of parts; aesh as a structured, fast, scriptable shell.

## Gating
Phase 6 (factory hivemind self-orchestrated operator) does NOT start until items 1–5 above hold
for ryz and aesh, verified by the test suites + `scripts/system_doctor.sh` and reviewed.

## Current honest status (2026-06-08)
- ryz: working interpreter, 27 tests, arrays/maps/for/stdlib + CSP concurrency. **Gaps to bar:**
  structs (#49), error model, fuzzing, full spec. **Perf (#50 — DONE):** replaced exception-per-
  `return` with a flag + plain-object scopes → **fib(30) 18.9s → 0.94s (~20×)**, 27/27 still green.
  Current baseline (`bench/bench.sh`): fib(30) ≈ 0.94s, 1e6-iter loop ≈ 0.5s, aesh `-c` ≈ 79ms
  (bun-startup bound; native zenc binary removes that). Next perf frontier: bytecode VM (roadmap).
- aesh: working shell, 11 tests, native binary via zenc. **Gaps:** globbing, command
  substitution, single-quote literal, job control, structured (Nu) pipes, line-editor polish.
- ecosystem/OS: stabilization + system_doctor done; cross-device automation + the operator layer
  remain.

Progress is tracked in Task Master (`/workspaces/gentoo/.taskmaster/tasks/tasks.json`, ids 43+).
