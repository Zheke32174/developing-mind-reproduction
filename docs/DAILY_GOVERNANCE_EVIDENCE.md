# Daily governance evidence contract

`scripts/daily_governance.py` consumes one typed record for the previous day:

```text
$DEVMIND_LOG_DIR/daily-YYYYMMDD.json
```

The canonical contract is `schemas/daily-governance-v1.schema.json`; a passing fixture is provided at `examples/daily-governance.example.json`.

## What counts as evidence

Every planned action must identify its objective, whether it was attempted, its terminal outcome, verification status and receipts, rollback or refinement status, and provenance. The daily record must also enumerate unresolved failures instead of hiding them in prose.

A Markdown report may remain useful for humans, but its existence is not proof and it is not parsed by the governance gate.

## Outcome semantics

- `success` requires an attempted action and passed verification with at least one evidence reference.
- `recovered` additionally requires a succeeded rollback or refinement receipt.
- `failed`, `aborted`, and `timeout` remain blockers even if other actions passed.
- an unattempted action, missing verification, failed verification, or any unresolved failure forces `REFINEMENT`.

The analytic reliability score is derived from these actual action traces. It is an additional gate, not a way to average away a known failure.

## Publication boundary

A passing record permits the next bounded orchestration cycle to proceed. It does not merge code, deploy artifacts, grant capabilities, rewrite canon, or approve its own promotion. Those remain external governed transactions.

The resulting `governance_state.json` is atomically replaced with mode `PROGRESS` or `REFINEMENT`, the exact normalized record digest, plan identity, action count, reliability score, threshold, and blockers.
