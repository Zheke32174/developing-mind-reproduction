# Daily governance evidence contract

`scripts/daily_governance.py` consumes one content-addressed execution record for the previous governed day:

```text
$DEVMIND_LOG_DIR/daily-YYYYMMDD.execution.json
```

The canonical contract is `developing-mind.daily-execution-evidence/v1`, published at `schemas/daily-governance-v1.schema.json`. A digest-valid passing fixture is provided at `examples/daily-governance.example.json`.

## What counts as evidence

Every action records whether it was attempted, its terminal outcome, verification status and receipts, rollback status and receipts, and a unique action identity. The daily record also binds:

- record and plan identity;
- the plan digest;
- collector and source provenance;
- unresolved failures;
- the canonical digest of the complete record with `record_digest` blanked during digest calculation.

A Markdown report may remain useful for humans, but its existence is not proof and it is not parsed by the governance gate.

## Outcome semantics

- `success` requires an attempted action, verified status, at least one verification receipt, and either no rollback requirement or a receipt-backed completed rollback.
- `rolled-back` requires an attempted action and receipt-backed completed rollback; it remains a blocker rather than being mislabeled as success.
- `failure` remains a blocker even if an analytic model assigns a high score.
- `skipped` is valid only for unattempted work with missing verification and no rollback requirement.
- every unresolved failure and every action not proven successful forces `REFINEMENT`.

## Reliability semantics

Transition traces are derived only from the validated execution record. The production fit uses no synthetic transition smoothing, and the evaluation horizon is derived from the longest actual trace. The default reliability threshold is `0.85`.

Reliability is an additional gate. It cannot average away a known failure, missing receipt, contradictory state, or unresolved failure.

## Publication boundary

A passing record permits the next bounded orchestration cycle to proceed. It does not merge code, deploy artifacts, grant capabilities, rewrite canon, or approve its own promotion. Those remain external governed transactions.

The resulting `governance_state.json` is atomically replaced at mode `0600` and binds the governed day, evidence digest, plan digest, trace digest, reliability score, threshold, decision digest, and exact blockers.
