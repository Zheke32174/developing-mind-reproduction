# zenc — the RYZ/AeSH compiler

`zenc` turns the Bun reference sources into **native single-file binaries**
(via the `bun build --compile` backend, using the real bun at `~/.bun/bin/bun`).

```bash
zenc build aesh   # -> ../dist/aesh   (the AeSH shell, ~90 MB native ELF)
zenc build ryz    # -> ../dist/ryz    (the RYZ interpreter)
zenc build all    # both
zenc run x.ryz    # run a ryz program through the interpreter
zenc version
```

It is the piece the original spec meant by *"zenc creates the aesh binary."* The native
binary embeds the Bun runtime, so it runs without a separate bun/node install.

## Roadmap
- A true codegen backend (emit C → compile with gcc, which is present) for smaller, fully
  standalone binaries independent of the bun runtime.
- `zenc build <ryz-project>` to AOT-compile ryz sources once the ryz→native lowering exists.
