# RYZ Linux — the self-hosted userland

**The repeating goal:** once ryz is *truly complete*, use **aesh** (the first complete native
binary) to convert the entire WSL userland — **in order from simplest to most complex** — into
standalone **ryz** natives and shared **LIBS** (`.so`), until the system is a self-hosted *RYZ
Linux*: all MIT-licensed projects and libraries reimplemented in ryz, depending on nothing but
the kernel.

## Principles
- **Native, no runtime.** Every converted tool is a real ELF via `zenc native` (ryz→C→gcc).
  Shared code becomes ryz `.so` libraries via `zenc lib` (C-ABI symbols). **LIBS.**
- **Simplest → most complex.** Convert in dependency/complexity order so each tier stands on the
  tier below. Exit-code utils → argv utils → file utils → text utils → libraries → applications.
- **A/B always.** Each ryz native must match the behavior of the tool it replaces; the original
  stays for testing. Never destroy the reference.
- **aesh drives it.** The conversion harness is an aesh script (`convert.aesh`) — the shell we
  built converts the system around it. Bootstrapping in the truest sense.
- **MIT/permissive only.** Reimplementations stay open; we convert what we may freely convert.

## Layout
```
ryz-linux/
├── src/            ryz sources for each converted tool
├── bin/            staged native ELF binaries (the RYZ Linux userland)   [gitignored]
├── lib/            staged ryz shared libraries (.so)                      [gitignored]
├── convert.aesh    the aesh-driven conversion harness
└── CONVERSIONS.md  the ordered ledger (what's converted, what's next)
```

## Status
- Userland natives (A/B-verified, built by aesh via zenc): **true, false, echo, seq, cat**.
- **LIBS:** ryz programs link ryz `.so`s (`extern fn` + `zenc native --lib`); `usemath` runs on
  `libmathlib.so`. Cross-language: Python calls ryz via the `.so` (DIRECTIONALITY.md).
- **aesh-as-init demonstrated:** `init.aesh` runs a session with `PATH=ryz-linux/bin` only — every
  external command resolves to a ryz-built native. A RYZ-userland session, driven by aesh.
- Next tiers (CONVERSIONS.md): `wc/head/tail` need string-length/char codegen; then more LIBS
  factoring and a fuller rootfs. The campaign continues, simplest → most complex.
