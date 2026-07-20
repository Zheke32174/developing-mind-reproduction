from __future__ import annotations

import importlib.util
import json
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "daily_governance.py"
SPEC = importlib.util.spec_from_file_location("daily_governance", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
governance = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(governance)


class FakeTraceToChain:
    last_traces: list[list[str]] = []

    def __init__(self, transient_states, success_states, failure_states):
        self.transient_states = transient_states
        self.success_states = success_states
        self.failure_states = failure_states

    def fit_traces(self, traces, alpha=1.0):
        self.__class__.last_traces = traces
        self.alpha = alpha

    def reliability_at_step(self, d):
        traces = self.__class__.last_traces
        return sum(trace[-1] == "success" for trace in traces) / len(traces)


class DailyGovernanceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name)
        self.original_chain = governance.TraceToChain
        governance.TraceToChain = FakeTraceToChain

    def tearDown(self):
        governance.TraceToChain = self.original_chain
        self.temporary.cleanup()

    def action(
        self,
        action_id: str,
        *,
        outcome: str = "success",
        verification_status: str = "passed",
        attempted: bool = True,
        rollback_status: str = "not-required",
    ) -> dict:
        return {
            "action_id": action_id,
            "objective": f"Execute {action_id}",
            "attempted": attempted,
            "outcome": outcome,
            "verification": {
                "status": verification_status,
                "evidence_refs": (
                    [f"evidence://verification/{action_id}"]
                    if verification_status == "passed"
                    else []
                ),
            },
            "rollback": {
                "status": rollback_status,
                "evidence_refs": (
                    [f"evidence://rollback/{action_id}"]
                    if rollback_status == "succeeded"
                    else []
                ),
            },
            "provenance": {
                "actor": "developing-mind/test",
                "source_refs": [f"plan://{action_id}"],
            },
        }

    def record(self, actions: list[dict] | None = None) -> dict:
        return {
            "schema": governance.DAILY_RECORD_SCHEMA,
            "date": "20260719",
            "plan_id": "plan-20260719",
            "actions": actions or [self.action("action-1")],
            "unresolved_failures": [],
            "provenance": {
                "generated_by": "developing-mind/test",
                "source_refs": ["plan://20260719", "log://20260719"],
            },
        }

    def write_record(self, value: dict) -> pathlib.Path:
        path = self.root / "daily-20260719.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_valid_record_builds_traces_from_actual_actions(self):
        raw = self.record(
            [
                self.action("clean-success"),
                self.action(
                    "recovered-success",
                    outcome="recovered",
                    rollback_status="succeeded",
                ),
            ]
        )
        record = governance.load_daily_record(self.write_record(raw), "20260719")
        result = governance.evaluate_record(record)

        self.assertTrue(result["passed"])
        self.assertEqual(result["action_count"], 2)
        self.assertEqual(result["reliability_score"], 1.0)
        self.assertEqual(
            FakeTraceToChain.last_traces,
            [
                ["init", "execute", "verify", "success"],
                ["init", "execute", "error", "refine", "verify", "success"],
            ],
        )

    def test_markdown_file_existence_is_not_accepted_as_proof(self):
        (self.root / "daily-20260719.md").write_text(
            "Everything passed.", encoding="utf-8"
        )
        with self.assertRaisesRegex(
            governance.GovernanceRecordError, "regular daily evidence record required"
        ):
            governance.load_daily_record(
                self.root / "daily-20260719.json", "20260719"
            )

    def test_claimed_success_without_verification_is_rejected(self):
        raw = self.record(
            [self.action("unverified", verification_status="missing")]
        )
        with self.assertRaisesRegex(
            governance.GovernanceRecordError,
            "success requires passed verification",
        ):
            governance.load_daily_record(self.write_record(raw), "20260719")

    def test_unresolved_failure_blocks_progress_even_when_actions_pass(self):
        raw = self.record()
        raw["unresolved_failures"] = [
            {
                "failure_id": "failure-1",
                "summary": "A planned verification receipt is still missing.",
                "evidence_refs": ["failure://failure-1"],
            }
        ]
        record = governance.load_daily_record(self.write_record(raw), "20260719")
        result = governance.evaluate_record(record)

        self.assertFalse(result["passed"])
        self.assertIn("unresolved-failure:failure-1", result["blockers"])

    def test_failed_action_produces_failure_trace_and_blockers(self):
        raw = self.record(
            [
                self.action("passed"),
                self.action(
                    "failed",
                    outcome="failed",
                    verification_status="failed",
                ),
            ]
        )
        record = governance.load_daily_record(self.write_record(raw), "20260719")
        result = governance.evaluate_record(record)

        self.assertFalse(result["passed"])
        self.assertEqual(result["reliability_score"], 0.5)
        self.assertIn("action:failed:outcome:failed", result["blockers"])
        self.assertIn("action:failed:verification:failed", result["blockers"])
        self.assertIn("reliability-below-threshold", result["blockers"])
        self.assertEqual(
            FakeTraceToChain.last_traces[-1],
            ["init", "execute", "error", "abort"],
        )

    def test_state_publication_is_atomic_and_private(self):
        path = self.root / "state" / "governance_state.json"
        governance.atomic_write_state(path, {"mode": "REFINEMENT", "passed": False})
        self.assertEqual(
            json.loads(path.read_text(encoding="utf-8")),
            {"mode": "REFINEMENT", "passed": False},
        )
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertFalse(any(path.parent.glob(f".{path.name}.tmp.*")))


if __name__ == "__main__":
    unittest.main()
