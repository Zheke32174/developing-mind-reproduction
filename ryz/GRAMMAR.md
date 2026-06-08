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
- **Collections:** array literals `[1,2,3]`, indexing `a[i]` (negative ok), index-assignment.
- **Mutability:** `let` is immutable; `let mut` / `mut` are reassignable (enforced at runtime).
- **Operators:** `+ - * / %  < > <= >= == !=  && || !`, Pratt precedence, string `+`.
- **Builtins (global):** `len`, `push`, `range`, `int`, `float`, `string`/`str`.
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

## Roadmap (not yet implemented)
- Concurrency: `spawn` / `chan<T>` / `select` (Go-CSP) — keywords reserved, runtime pending.
- Structs/maps, pattern matching, command substitution at shell layer, native AOT via `zenc`.
