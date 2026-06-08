# RYZ + AeSH

A Frankenstein systems language (**ryz**), a recombinant shell (**aesh**), and a native compiler
(**zenc**) — **Linux-first, open, Unix-native.** Built to an acquisition-grade bar (see
[`QUALITY_BAR.md`](QUALITY_BAR.md)) while staying free and better-than-the-walled-garden *because*
it's open.

```
ryz/
├── bun/      RYZ language — lexer/parser/interpreter (TypeScript on Bun)   27 tests
├── aesh/     AeSH shell — bash·zsh·fish·elvish recombination               11 tests
├── zenc/     compiler — emits native single-file binaries (bun-compile)
├── tools/    tools converted to ryz, with originals kept for A/B parity
├── bin/ryz   launcher (always uses real bun, never the node shim)
└── src/      original zig/rust/go design scaffolding (preserved)
```

## Quickstart (Linux / WSL / Termux)
```bash
# run a ryz program
bin/ryz run bun/examples/hello.ryz
bin/ryz run bun/examples/csp.ryz        # Go-style concurrency
~/.bun/bin/bun bun/test/run_tests.ts    # 27/27

# the shell, compiled to a native binary
~/.bun/bin/bun zenc/zenc.ts build aesh  # -> dist/aesh  (~90MB native ELF)
./dist/aesh -c 'echo hi | tr a-z A-Z && echo $((6*7))'
~/.bun/bin/bun aesh/test/run_tests.ts   # 11/11

# convert-tool parity
bash tools/ab_test.sh                    # filestats + wordfreq A/B-match bash
```

## RYZ language — what works
- Ownership-flavored **mutability** (`let` vs `mut`, enforced), `fn`, recursion.
- Control flow: `if/else if/else`, `while`, `for x in …`, `defer` (LIFO).
- Data: ints/floats/strings/bools, **arrays** (+neg index, index-assign), **maps** `{}`.
- **CSP concurrency:** `spawn`, `channel()`, `send`/`recv`/`recv_any` (cooperative scheduler).
- Stdlib: `std/fmt`, `std/math`, `std/str`, `std/fs`, `std/os`; globals `len/push/range/sort/…`.
- Frankenstein thesis: Rust safety · Zig control · Go CSP · TS/Bun ergonomics · Lua/Java influence.

## AeSH shell — what works
- bash: pipelines `|`, redirects `> >> <`, `&& || ;`, `$(( ))` arithmetic.
- zsh/fish: tab-completion, persistent history, prefix autosuggest.
- elvish: structured builtins. Native binary via zenc; `-c`, script, REPL, piped modes.

## Status & roadmap
Tracked in Task Master (`/workspaces/gentoo/.taskmaster`, ids 43+). Done: CSP (#43), maps+sort
(#44). Next: aesh globbing/cmd-subst/quoting (#45), more tool ports (#46), cross-level automation
(#47), structs (#49); then the gated factory operator (#48). See `QUALITY_BAR.md` for the gates.

## License / ethos
Open and free. No telemetry, no lock-in. Runs natively where Linux runs.
