# RYZ — Bun reference implementation

A **working** interpreter for the RYZ "Frankenstein" language defined in `../GRAMMAR.md`.
This is the first executable implementation; the `../src/*.zig` / `*.rs` / `*.go` files are
preserved design scaffolding (mocks) kept for reference and future native backends.

## Why Bun/TypeScript for the frontend
RYZ's design ingredients are conceptual: **Rust** (ownership/mutability), **Zig** (explicit
blocks), **Go** (CSP channels), **TypeScript+Bun** (ergonomics/host), **Lua** (scriptable
plugins), **Java** (later JVM-tool ports). The *compiler/interpreter* is written in the tooling
that actually exists in this environment (Bun 1.3.14). Zig/Rust are not installed here, which is
why the original scaffolding could never run.

## Run
```bash
# via the launcher (always uses the real bun, never the /usr/local/bin/bun->node shim)
../bin/ryz run examples/hello.ryz
../bin/ryz run examples/fib.ryz
../bin/ryz version

# or directly with real bun
~/.bun/bin/bun src/ryz.ts run examples/hello.ryz
~/.bun/bin/bun test/run_tests.ts      # 11/11 passing
```

## What works today (v0.2.0)
- Lexer: ints/floats/strings (with escapes), bools, idents, keywords, `//` `#` `/* */` comments,
  all operators incl. `-> == != <= >= && ||`.
- Parser: `import`, `fn`/`export fn`, params + type annotations, `chan<T>`/`[]` type syntax,
  `let`/`mut`/`let mut`, `return`, `if`/`else if`/`else`, `while`, `defer`, Pratt expressions
  with correct precedence, calls, member access, assignment.
- Interpreter: lexical scopes, **immutability enforcement** (`let` vs `mut`), recursion,
  `defer` (LIFO at block exit), `std/fmt` (`println`/`print`/`sprintf`) and `std/math`,
  `main()` return value → process exit code.

## Roadmap (tracked)
- Channels (`chan`/`spawn`/`select`) — Go-CSP runtime (skeleton types exist in interpreter).
- `zenc`: compile/bundle ryz+aesh → native `aesh` binary (`bun build --compile` / gcc backend).
- Member assignment, structs, arrays/maps, pattern matching.

## Environment notes (stabilization findings)
- `/usr/local/bin/bun` is a root-owned shim that execs `node` — it shadows the **real** Bun at
  `~/.bun/bin/bun`. The launcher sidesteps it. Repointing the system shim needs operator sign-off.
