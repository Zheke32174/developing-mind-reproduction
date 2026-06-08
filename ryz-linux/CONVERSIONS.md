# RYZ Linux — conversion ledger (simplest → most complex)

Each row: a WSL userland component being reimplemented as a standalone ryz native (+ ryz `.so`
libs where shared). Status: ✅ done & A/B-verified · 🔨 in progress · ⏳ blocked on codegen · ⬜ queued.

## Tier 0 — exit-code utilities (no I/O)
| tool | status | notes |
|---|---|---|
| true  | ✅ | `fn main()->i32{return 0;}` → native ELF; matches /bin/true |
| false | ✅ | exit 1; matches /bin/false |

## Tier 1 — argv / string utilities  (Task #52 native codegen: argv + strings + int landed)
| tool | status | notes |
|---|---|---|
| echo | ✅ | argv join + newline; matches /bin/echo AND interpreter |
| seq  | ✅ | `seq N` 1..N via int(args[0])→atoll; matches /usr/bin/seq |
| yes | ⬜ | basename | ⬜ | dirname | ⬜ | (need string slicing) |

## Tier 2 — file utilities  (needs file-IO codegen)
| cat | ⬜ | wc | ⬜ | head | ⬜ | tail | ⬜ | nl | ⬜ | tac | ⬜ |

## Tier 3 — text processing
| sort | ⬜ | uniq | ⬜ | cut | ⬜ | tr | ⬜ | grep (basic) | ⬜ |

## Tier 4 — shared libraries (LIBS)
| libryzc (common runtime helpers) | ⬜ | libryzstr (string ops) | ⬜ | libryzfs (fs) | ⬜ |

## Tier 5+ — MIT-licensed projects (standalone ryz reimplementations)
| jq-lite | ⬜ | a static http server | ⬜ | … | ⬜ |

Process per item: write `src/<tool>.ryz` → `aesh convert.aesh` builds native via zenc →
A/B vs the system tool → stage to `bin/` (and `.so` to `lib/`) → tick this ledger.
