# Factory Operator (v0) — gradual, self-orchestrating, human-in-the-loop

The seed of the self-orchestrated AI operator. It reads the **Task Master** schedule, proposes the
next actionable brick, and **never takes an outward/destructive action without explicit human
approval**. Gated by design (QUALITY_BAR Phase-6 gate); started only after ryz (31 tests) and aesh
(17 tests) reached the bar.

## Use
```bash
bun operator/operator.ts status            # schedule summary + next actionable
bun operator/operator.ts propose           # propose next brick — NO action taken (default-safe)
bun operator/operator.ts approve <id>       # record a human approval (still no execution)
bun operator/operator.ts execute <id> --i-am-the-operator   # only runs with approval + human flag
bun operator/test/run_tests.ts             # 5/5 — HITL gating
```

## Human-in-the-loop guarantees (tested)
- `propose` and `status` are read-only; they only emit a proposal receipt.
- `execute` **refuses** unless (a) a human `approve <id>` receipt exists AND (b) `--i-am-the-operator`
  is passed. Either missing → exit 3, no action.
- v0 dispatch is a **stub**: even when authorized it performs no outward action — it logs an
  `execute-authorized` receipt. Wiring to the hive (`scripts/parallel_hive_orchestrator.sh` / an
  agent) is the next, deliberately separate step.
- Every decision is appended to `operator_ledger.jsonl` (receipts).

## Why this shape
"Gradual" = propose → gate → log first; autonomy is earned increment by increment, never by
removing the human. This is the opposite of a runaway agent: the operator can *think* freely but
can only *act* through an approved, audited gate.

## Roadmap
- Wire authorized execution to the hive harnesses (still behind the gate).
- Operator proposes a plan + risk class per task; auto-allow only read-only classes.
- Self-review loop: operator critiques its own proposal before presenting it.
