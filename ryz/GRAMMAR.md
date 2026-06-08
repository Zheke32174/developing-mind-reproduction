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
