# AI Module: Developing Mind Reproduction

## Role

`developing-mind-reproduction` is the ecosystem's memory-bearing governance and demonstration module. It holds the engram ledger, governance scripts, judge/check scripts, harnesses, and status files used to prove that the larger ecosystem can coordinate across agents and repos.

## Connector-only entry

An AI with only GitHub access should read these files first:

1. `PHASE_1_MANIFEST.md`
2. `ECOSYSTEM_MAP.md`
3. `TCOT_METHODOLOGY.md`
4. `scripts/devmind-env.sh`
5. `scripts/hivemind_governor.sh`
6. `scripts/daily_governance.py`
7. `tests/test_ecosystem.py`

## Capability whitelist

The following connector-only capabilities are granted by default:

```text
repo.read
repo.summarize
repo.static_audit
repo.docs_hotfix
repo.path_portability_hotfix
repo.add_module_contract
audit.report
```

The following are not granted by this module contract:

```text
runtime.execute_local
credential.manage
network.expose_service
evidence.rewrite
human_approval.override
```

## Allowed AI actions

- Read and summarize repository files.
- Identify stale docs, hardcoded local paths, and portability drift.
- Add or improve static audit docs.
- Parameterize hardcoded local paths through `scripts/devmind-env.sh`.
- Update tests so they use environment-aware paths.
- Report any live command that still needs operator execution.

## Forbidden AI actions

- Do not create, request, expose, or rotate credentials.
- Do not alter external service exposure.
- Do not bypass human approval gates.
- Do not rewrite ledger history to hide failures.
- Do not assume local shell access when operating through a GitHub connector.

## State paths

Preferred environment-aware paths:

```text
DEVMIND_REPRO_DIR
DEVMIND_LAMP_DIR
DEVMIND_LOG_DIR
DEVMIND_STATE_DIR
DEVMIND_LEDGER
DEVMIND_GEMINI_DIR
DEVMIND_RALPH_STATE
DEVMIND_RALPH_SETUP
```

Legacy Fixxia/WSL paths may remain as compatibility fallbacks only.

## Audit command

Live shell audit, when available:

```bash
python3 -m unittest tests/test_ecosystem.py
```

Connector-only fallback:

```text
Inspect scripts for hardcoded /mnt/c/Users/Fixxia and /home/fixxia paths.
Verify new scripts source scripts/devmind-env.sh or resolve paths via environment variables.
Report files that still need portability migration.
```

## Safe hotfix scope

Safe changes include:

- docs and module contracts
- tests
- path portability refactors
- read-mostly audit helpers
- state/log path parameterization

## Handoff outputs

Useful outputs for the next agent cycle:

```text
scripts/hivemind_directive.md
scripts/governance_state.json
scripts/evolution_state.json
PHASE_2_LEDGER.md
```

## Escalation triggers

Ask for operator confirmation before:

- running local commands that mutate host state
- changing auth or provider posture
- deleting or rewriting historical ledger entries
- touching private evidence archives
- enabling new network-facing services
