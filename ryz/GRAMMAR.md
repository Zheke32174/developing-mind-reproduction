# RYZ Language Grammar (v0.1.0)
# Arxiv Anchor: 2511.10621 (Foundation Algorithms)

## Core Principles
1. **Memory Safety:** Rust-style ownership by default.
2. **Low-Level Control:** Zig-style manual memory blocks.
3. **Concurrency:** Go-style CSP (Communicating Sequential Processes).
4. **Ergonomics:** TypeScript/Lua-inspired scriptability.

## Keywords
- `let`, `mut`, `fn`, `spawn`, `chan`, `select`, `defer`, `import`, `export`.

## Type System
- Integers: `i8`, `u8`, `i32`, `u32`, `i64`, `u64`, `f32`, `f64`.
- Strings: `string`.
- Boolean: `bool`.
- Channels: `chan<T>`.

## Example Syntax
```ryz
import "std/fmt";

fn main() -> i32 {
    let message: string = "Hello from RYZ";
    fmt.println(message);
    return 0;
}
```

## v0.3.0 — implemented in the Bun reference (`bun/`, runnable via `bin/ryz`)
Beyond the v0.1 grammar, the working interpreter adds:
- **Control flow:** `if`/`else if`/`else`, `while`, `for x in <array|string>`, `defer` (LIFO).
- **Collections:** array literals `[1,2,3]`, indexing `a[i]` (negative ok), index-assignment;
  **map literals** `{"k": v}` with `m[k]` get/set, `map()`, `keys`/`values`/`has`/`del`, `sort`.
- **Structs:** `struct Point { x: i32, y: i32 }`; construct `Point(3,4)`; `p.x` get/set.
- **Mutability:** `let` is immutable; `let mut` / `mut` are reassignable (enforced at runtime).
- **Operators:** `+ - * / %  < > <= >= == !=  && || !`, Pratt precedence, string `+`.
- **Builtins (global):** `len`, `push`, `range`, `int`, `float`, `string`/`str`, `sort`,
  `map`/`keys`/`values`/`has`/`del`, and CSP `channel`/`send`/`recv`/`recv_any`/`len_chan`.
- **Stdlib modules:** `std/fmt` (println/print/sprintf), `std/math` (sqrt/abs/min/max/floor),
  `std/str` (upper/lower/trim/split/join/contains/replace/len), `std/fs` (read/write/exists/lines),
  `std/os` (args/getenv).

```ryz
import "std/fmt"; import "std/str";
fn main() -> i32 {
    let xs = [3, 1, 2];
    let mut total: i32 = 0;
    for x in xs { total = total + x; }
    fmt.println("sum=" + string(total), str.upper("done"));
    return 0;
}
```

## Concurrency (Go-style CSP, implemented — cooperative scheduler)
```ryz
fn worker(c, n) { send(c, n * 2); }
fn main() -> i32 {
    let c = channel();
    spawn worker(c, 21);          // queued; runs when main blocks on recv or at exit
    fmt.println(recv(c));          // 42
    return 0;
}
```
- `spawn f(args)` — capture args now, queue the call.
- `channel()` — buffered channel; `send(c, v)`, `recv(c)` (drains the scheduler when empty),
  `len_chan(c)`, `recv_any([c1, c2, ...])` → `[index, value]` fan-in.
- Semantics: **cooperative, run-to-completion** tasks (no preemption). True yielding coroutines
  and `select {}` block sugar are roadmap. `chan<T>` is accepted as a type annotation.

## Shared libraries & FFI (LIBS) — implemented in the native backend
```ryz
// declare a symbol provided by a ryz .so (or any C-ABI library)
extern fn add(a: i64, b: i64) -> i64;
fn main() -> i32 { fmt.println(add(20, 22)); return 0; }
```
- `export fn` → exported C-ABI symbol when built with `zenc lib x.ryz` (→ `libx.so`).
- `extern fn name(...) -> T;` → a prototype for a symbol linked from a `.so`.
- `zenc native prog.ryz --lib mathlib` links `libmathlib.so`. ryz programs thus build on ryz libs.
- **Directionality** (see `DIRECTIONALITY.md`): the `.so` is consumable by *any* language
  (bi-directional out); `.ryz` source still requires the ryz toolchain (mono-directional in).

## Roadmap (not yet implemented)
- Preemptive/yielding coroutines; `select {}` block syntax (fan-in builtin `recv_any` exists today).
- Pattern matching, generics, traits/methods; native AOT lowering via `zenc` (bytecode VM).
- (Done: arrays, maps, **structs**, CSP concurrency, shell command substitution + globbing.)
