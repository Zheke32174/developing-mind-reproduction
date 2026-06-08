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
First batch landed: `true`, `false` (exit-code tier) — built native by aesh, A/B-verified vs
`/bin/true` and `/bin/false`. Next tiers blocked on ryz native-codegen coverage (Task #52:
argv/strings/loops → echo/yes/basename; then file IO → cat/wc/head/tail). See `CONVERSIONS.md`.
