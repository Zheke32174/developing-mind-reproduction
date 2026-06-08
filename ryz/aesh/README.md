# AeSH — Advanced embedded Shell

A working shell that recombines five shells, compiled to a **native binary** by `zenc`.

| Shell | Borrowed strength | Status in AeSH v0.1.0 |
| :--- | :--- | :--- |
| Bash | pipelines, redirects, `&&`/`\|\|`/`;`, `$(( ))` arithmetic | ✅ implemented |
| Zsh | tab-completion (commands + files), persistent history | ✅ implemented |
| Fish | history-prefix autosuggest (accept with → at line end) | ✅ implemented |
| Elvish | structured builtins (cd/export/set/history/type) | ✅ implemented |
| Bash (v0.2) | command substitution `$(...)`, globbing `* ? []`, single-quote literal | ✅ implemented |
| Nu | dataframe/structured pipes | 🔜 roadmap |

## Run
```bash
# source (real bun)
~/.bun/bin/bun aesh/src/aesh.ts -c 'echo hi | tr a-z A-Z && echo $((2*21))'
~/.bun/bin/bun aesh/test/run_tests.ts          # 11/11 passing

# native binary (built by zenc)
../zenc/... build aesh   # -> ../dist/aesh
./dist/aesh -c 'pwd && echo done'
./dist/aesh script.aesh   # run a script
./dist/aesh               # interactive REPL (TTY)
```

## Modes
- `aesh -c "<cmd>"` — run one command line (non-interactive, output captured through io).
- `aesh <file>` — run a script (lines, `#` comments).
- `aesh` (TTY) — interactive REPL: completion, history (`~/.aesh_history`), fish autosuggest.
- piped stdin — `echo 'pwd' | aesh`.

## Architecture
- `src/parser.ts` — tokenizer + AST (lists → pipelines → simple commands + redirects), honoring
  single/double quotes and escapes.
- `src/exec.ts` — variable/arith expansion, builtins, external pipelines via `Bun.spawn`
  (capture mode funnels child output through the io sink; REPL inherits the TTY).
- `src/aesh.ts` — entry/REPL (readline completer + history + keypress autosuggest).

## Known limitations / roadmap
- Single-quote literal, command substitution `$(...)`, and globbing `* ? []` are **done** (v0.2,
  17 tests). Remaining: job control `&`, structured (Nu) pipes, brace expansion, here-docs.
