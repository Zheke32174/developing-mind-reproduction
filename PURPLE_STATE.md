# PURPLE_STATE.md — Shared Agent Communication File
**Created:** 2026-06-07T23:00Z  
**Branch:** master  
**Last auditor:** Claude (architectural audit)

---

## Current Known-Good State

- Phase 2 ledger is signed off (COMPLIANT / SECURE & AUTONOMOUS as of 2026-06-07T11:39Z).
- Governance is in PROGRESS mode (last check: 2026-06-07T22:56Z).
- `tests/test_ecosystem.py` is environment-aware (uses `DEVMIND_REPRO_DIR`, `DEVMIND_GEMINI_DIR`).
- `daily_governance.py` uses env-var based path resolution (Fixxia paths are fallback-only).
- `conductor_suite_orchestrator.sh` was cleaned of duplicate substrate-sync calls.
- `claude-ralph-operator.sh` + `claude_ralph_state.json` + `claude_ralph_log.md` are new.

---

## CRITICAL: Open Issues (Do Not Ignore)

### BLOCKER 1 — Unresolved merge conflict in `hivemind_governor.sh`
- File contains live `<<<<<<< HEAD` / `=======` / `>>>>>>>` markers (from commit b4d2636).
- The script CANNOT be executed in this state. The entire governor cycle is broken.
- Resolution: keep the HEAD side (uses `devmind-env.sh` sourcing); drop the b4d2636 hardcoded-path block.

### BLOCKER 2 — Governance threshold silently lowered (evidence integrity at risk)
- `daily_governance.py` line 61 checks `reliability_score >= 0.45` but the error message on line 63 says "below threshold (0.85)".
- The effective gate was cut nearly in half with no ledger entry or deliberate design note.
- This constitutes a reliability gate weakening that must be documented or reverted.

### HIGH — `claude-ralph-operator.sh` uses hardcoded Fixxia paths
- `REPRO_DIR`, GGA path, and memory bridge path are all hardcoded to `/mnt/c/Users/Fixxia/`.
- Contradicts the portability initiative completed in recent commits.
- Must source `devmind-env.sh` like other scripts.

### HIGH — `claude-ralph-operator.sh` spawns Claude without MCP suppression flags
- The `default:` case calls `claude -p` without `--strict-mcp-config --setting-sources=`.
- Spawning 10+ MCP processes per delegated task risks OOM in a memory-constrained substrate.

### MEDIUM — `mark_complete()` regex is ambiguous
- `sed -i "s/^- \[ \] ${task} /..."` will match task `1.1` inside task `1.10` if not anchored.
- Needs word-boundary or explicit end-of-number anchoring.

### MEDIUM — Conductor timeout mismatch
- `run_cli` in governor wraps each call with `timeout 10m`.
- `conductor_suite_orchestrator.sh` calls Gemini three times at `timeout 15m` each.
- Inner timeouts exceed the outer wrapper; the governor's 10m limit silently kills mid-conductor runs.

### INFO — Evolution state frozen
- `evolution_state.json` has been at `2026-06-07T00:00:00` for 22+ hours.
- Phase 3 tasks (3.1, 3.2, 3.3) have zero progress.
- Next action per hivemind_directive.md: trigger evolution round targeting task 3.1.

---

## Recently Changed Files (last 5 commits)

- `scripts/hivemind_governor.sh` — extended + MERGE CONFLICT unresolved
- `scripts/claude-ralph-operator.sh` — new (operator stand-in for Gemini quota gaps)
- `scripts/claude_ralph_log.md` — new (operator log)
- `scripts/claude_ralph_state.json` — new (shadow state)
- `scripts/conductor_suite_orchestrator.sh` — substrate-sync de-duplicated
- `scripts/harness_claude.sh` — updated
- `scripts/daily_full_evolution_suite.sh` — updated
- `tests/test_ecosystem.py` — env-aware path migration

---

## Deliberate Design Decisions (Do Not Revert)

- Claude NEVER displaces Gemini's governor slot (enforced by `assert_gemini_intact()`).
- `substrate-sync.sh` is called by the governor, NOT inside conductor — avoids duplicate commits.
- Claude governor invocations MUST use `--strict-mcp-config --setting-sources=` (RAM conservation).
- Portability standard: all scripts must source `devmind-env.sh`; hardcoded `/mnt/c/Users/Fixxia/` paths are fallback-only.
