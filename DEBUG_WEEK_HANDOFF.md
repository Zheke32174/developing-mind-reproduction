# Debug Week Handoff for AI Agents

This repository is in **debug freeze**.

No expansion until the existing ecosystem stops hiding obvious walls.

This document is for any AI agent entering through GitHub connector access: Claude, Gemini, Codex, GPT, OpenCode, or future models. You do not need local shell access to start. Read, inspect, classify, and make only bounded debug improvements.

## Current operating mode

```text
Mode: DEBUG WEEK
Expansion: frozen
Primary goal: stabilize existing organs
Secondary goal: make the system legible to the next AI
Operator remains sovereign
```

Allowed work:

```text
repo.read
repo.summarize
repo.static_audit
repo.docs_hotfix
repo.path_portability_hotfix
repo.add_module_contract
audit.report
```

Not granted:

```text
runtime.execute_local
credential.manage
network.expose_service
evidence.rewrite
human_approval.override
zub.write
```

## Entry order

Read these first:

1. `AI_MODULE.md`
2. `ECOSYSTEM_MAP.md`
3. `TCOT_METHODOLOGY.md`
4. `scripts/devmind-env.sh`
5. `scripts/hivemind_governor.sh`
6. `scripts/daily_governance.py`
7. `tests/test_ecosystem.py`
8. this file

Then search for hardcoded local paths:

```text
/mnt/c/Users/Fixxia
/home/fixxia
/substrate/mind
```

Treat `scripts/devmind-env.sh` as the canonical compatibility shim. Legacy Fixxia/WSL paths may remain there as fallback only. Active governor, judge, worker, and harness scripts should source or mirror the resolver pattern rather than hardcoding local paths directly.

## Known current walls

The current high-priority walls are:

```text
scripts/hyperbolic_judge.sh
scripts/system_subgovernor.sh
scripts/subconscious-daemon.sh
scripts/secretary_worker.py
remaining harness scripts
backup .bak files polluting static search results
```

Expected fixes:

```text
1. Active scripts should source scripts/devmind-env.sh or resolve paths through environment variables.
2. Generated logs/state should route through DEVMIND_LOG_DIR, DEVMIND_STATE_DIR, or module-specific env overrides.
3. Backup .bak files should be ignored by static audits or moved into a clearly named archive path.
4. No script should assume a specific model vendor, CLI, WSL path, or host user unless that path is explicitly fallback-only.
```

## Debug session rule

Each AI debug session should leave one small clean brick:

```text
One target.
One hypothesis.
One bounded fix.
One reviewable commit.
One receipt.
No expansion.
```

End every session by reporting:

```text
What changed?
What stayed blocked?
What should the next AI check first?
Was any live operator check required?
```

## GGA / Guardian posture

The Gentleman Guardian Angel review layer is a truth gate, not a maze wall.

No change passes because an AI is confident. A change passes because the review can explain why it is safe, coherent, and inside the module contract.

## Definition of done for debug week

Debug week is complete when:

```text
1. A fresh AI with only GitHub access can understand the repo role.
2. Active governor/judge/worker scripts no longer hide platform-specific path assumptions.
3. Static audit can identify remaining hardcoded local paths without being polluted by backups.
4. Codex Judge, Subconscious Daemon, Council Nerve Center, and Hivemind Governor have clear env-resolved paths.
5. GGA or equivalent review can inspect diffs before they are accepted.
6. Operator can run the live checks with no critical/high failures or panics.
```

## Build freeze reminder

Do not add new organs, new agents, new architecture, or new myth layers during debug week unless the operator explicitly says to. Repair, clarify, audit, and stabilize what already exists.

The practical doctrine:

```text
Burn false structure.
Preserve truth.
Make truth queryable.
Leave receipts.
```
