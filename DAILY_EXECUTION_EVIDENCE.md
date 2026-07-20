# Daily execution evidence contract

`scripts/daily_governance.py` accepts exactly one evidence file for the governed day:

```text
$DEVMIND_LOG_DIR/daily-YYYYMMDD.execution.json
```

A Markdown report may remain useful to people, but its existence is never governance proof.

## Record shape

```json
{
  "schema": "developing-mind.daily-execution-evidence/v1",
  "date": "20260718",
  "record_id": "daily-execution-20260718",
  "plan_id": "plan-20260718",
  "plan_digest": "sha256:<64 lowercase hex characters>",
  "created_at": "2026-07-19T06:59:00Z",
  "provenance": {
    "collector": "lamp-governance-recorder/v1",
    "source_refs": ["artifact:verification/example.json"]
  },
  "actions": [
    {
      "action_id": "compile",
      "attempted": true,
      "outcome": "success",
      "verification": {
        "status": "verified",
        "receipts": ["artifact:verification/example.json"]
      },
      "rollback": {
        "status": "not-required",
        "receipts": []
      }
    }
  ],
  "unresolved_failures": [],
  "record_digest": "sha256:<digest of the canonical record with record_digest set to an empty string>"
}
```

## Fail-closed rules

- The top level must be one bounded JSON object, not Markdown, an array, or a scalar.
- The date, plan identity, provenance, action identities, verification receipts, rollback receipts, and record digest are mandatory where applicable.
- Every planned action must have a coherent attempted/outcome/verification/rollback combination.
- `verified` requires at least one receipt. `completed` rollback requires at least one receipt.
- Any skipped, failed, rolled-back, unverified, contradictory, or unresolved action keeps governance in `REFINEMENT` even if the statistical model score is high.
- The production transition traces are derived only from these action records. Calibration fixtures belong in tests and never enter the production evidence path.

## Decision receipt

The private governance state records the exact evidence digest, plan digest, derived trace digest, reliability score, blockers, mode, and a decision digest. A `PROGRESS` receipt remains an evaluation result; it does not merge, deploy, publish canon, or grant capability authority.
