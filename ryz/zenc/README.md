# zenc — the RYZ/AeSH compiler

`zenc` turns the Bun reference sources into **native single-file binaries**
(via the `bun build --compile` backend, using the real bun at `~/.bun/bin/bun`).

```bash
zenc build aesh    # -> ../dist/aesh   (the AeSH shell, ~90 MB native ELF; bundles bun runtime)
zenc build ryz     # -> ../dist/ryz    (the RYZ interpreter)
zenc run x.ryz     # run a ryz program through the interpreter

# TRUE native backend (ryz -> C -> gcc): NO runtime, real ELF + shared libs
zenc native x.ryz  # -> ../dist/x        standalone ELF executable (no bun/node)
zenc lib   x.ryz   # -> ../dist/libx.so  shared library; `export fn` -> C-ABI symbols  (LIBS!)
zenc version
```

## The native backend (`ryzc.ts`)
Transpiles RYZ to C and compiles with gcc. This is what lets ryz **transcend its interpreter** and
build an OS: the output is real machine code with no JS runtime, and `export fn`s become real
shared-library symbols other programs (C or ryz) can link. Verified by `zenc/test/native_parity.sh`
(native output == interpreter output; ELF; runs on a bare PATH; .so links + calls).
Core subset today (Task #51); coverage grows in #52 (arrays/structs/strings/argv).

It is the piece the original spec meant by *"zenc creates the aesh binary."* The native
binary embeds the Bun runtime, so it runs without a separate bun/node install.

## Roadmap
- A true codegen backend (emit C → compile with gcc, which is present) for smaller, fully
  standalone binaries independent of the bun runtime.
- `zenc build <ryz-project>` to AOT-compile ryz sources once the ryz→native lowering exists.
