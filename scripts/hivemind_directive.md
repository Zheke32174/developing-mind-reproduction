# Hivemind Directive
**Synthesized:** 2026-06-08T13:10Z (operator /goal re-target)

**Overall Status:** Stabilization complete (WSL DNS fixed, system_doctor green). RYZ language and
AeSH shell are now *working* (19 + 11 tests, native binary via zenc) but not yet at the bar.

**North star:** ryz + aesh + ecosystem + cross-device OS to **acquisition-grade quality**
(Microsoft-caliber worth) while staying **Linux-first, open, and Unix-native** — better than the
walled garden *because* it is open. See `ryz/QUALITY_BAR.md` for the definition of done.

**Active schedule:** Task Master ids 43–48
(`/workspaces/gentoo/.taskmaster/tasks/tasks.json`).
- 43 (in-progress): finish RYZ concurrency — chan/spawn/select (CSP).
- 44: ryz structs + maps. 45: aesh globbing/cmd-subst/single-quote-literal.
- 46: convert ≥3 more tools to ryz (A/B). 47: cross-level automation wiring.
- 48 (GATED): factory hivemind self-orchestrated operator, human-in-the-loop.

**Next Priority Action:** Land task 43 (CSP concurrency) to acquisition-grade — runtime + tests,
all existing tests stay green, GRAMMAR.md updated — then proceed down the chain. Phase 6 (the
self-orchestrating operator) stays gated until QUALITY_BAR items 1–5 hold for ryz and aesh.

**Operating doctrine (unchanged):** bounded bricks, leave receipts, one reviewable commit per
brick, keep originals, no unapproved outward/destructive actions (human-in-the-loop).
