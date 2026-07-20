from __future__ import annotations

import importlib.util
import json
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "daily_governance_empirical_under_test",
    ROOT / "scripts" / "daily_governance.py",
)
assert SPEC is not None and SPEC.loader is not None
GOVERNANCE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GOVERNANCE)


class FakeTraceToChain:
    score = 0.9
    alpha = None
    depth = None
    transient_states = None

    def __init__(self, transient_states, success_states, failure_states):
        type(self).transient_states = list(transient_states)

    def fit_traces(self, traces, alpha=0.5):
        type(self).alpha = alpha

    def reliability_at_step(self, d):
        type(self).depth = d
        return type(self).score


class EmpiricalGovernanceTests(unittest.TestCase):
    day = "20260719"

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name)
        self.logs = self.root / "logs"
        self.logs.mkdir()
        GOVERNANCE.LAMP_LOGS = self.logs
        GOVERNANCE.STATE_FILE = self.root / "state" / "governance.json"
        GOVERNANCE.TraceToChain = FakeTraceToChain
        FakeTraceToChain.score = 0.9
        FakeTraceToChain.alpha = None
        FakeTraceToChain.depth = None
        FakeTraceToChain.transient_states = None

    def tearDown(self):
        self.temporary.cleanup()

    def record(self, actions):
        value = {
            "schema": GOVERNANCE.EVIDENCE_SCHEMA,
            "date": self.day,
            "record_id": "daily-execution-20260719",
            "plan_id": "plan-20260719",
            "plan_digest": GOVERNANCE.digest_id({"plan": "20260719"}),
            "created_at": "2026-07-20T06:59:00Z",
            "provenance": {
                "collector": "test-recorder/v1",
                "source_refs": ["artifact:test-plan"],
            },
            "actions": actions,
            "unresolved_failures": [],
            "record_digest": "",
        }
        value["record_digest"] = GOVERNANCE.evidence_digest(value)
        return value

    def write(self, value):
        path = self.logs / f"daily-{self.day}.execution.json"
        path.write_text(json.dumps(value), encoding="utf-8")

    def test_success_uses_no_smoothing_and_evidence_horizon(self):
        self.write(
            self.record(
                [
                    {
                        "action_id": "compile",
                        "attempted": True,
                        "outcome": "success",
                        "verification": {
                            "status": "verified",
                            "receipts": ["artifact:compile"],
                        },
                        "rollback": {
                            "status": "not-required",
                            "receipts": [],
                        },
                    }
                ]
            )
        )
        receipt = GOVERNANCE.evaluate_governance(self.day)
        self.assertTrue(receipt["passed"])
        self.assertEqual(GOVERNANCE.RELIABILITY_THRESHOLD, 0.85)
        self.assertEqual(FakeTraceToChain.alpha, 0.0)
        self.assertEqual(FakeTraceToChain.depth, 5)
        self.assertEqual(
            FakeTraceToChain.transient_states,
            ["init", "execute", "verify"],
        )

    def test_longer_failure_trace_expands_horizon_but_remains_blocked(self):
        self.write(
            self.record(
                [
                    {
                        "action_id": "compile",
                        "attempted": True,
                        "outcome": "success",
                        "verification": {
                            "status": "verified",
                            "receipts": ["artifact:compile"],
                        },
                        "rollback": {
                            "status": "not-required",
                            "receipts": [],
                        },
                    },
                    {
                        "action_id": "deploy",
                        "attempted": True,
                        "outcome": "rolled-back",
                        "verification": {
                            "status": "failed",
                            "receipts": [],
                        },
                        "rollback": {
                            "status": "completed",
                            "receipts": ["artifact:rollback"],
                        },
                    },
                ]
            )
        )
        receipt = GOVERNANCE.evaluate_governance(self.day)
        self.assertFalse(receipt["passed"])
        self.assertEqual(FakeTraceToChain.alpha, 0.0)
        self.assertEqual(FakeTraceToChain.depth, 6)
        self.assertEqual(
            FakeTraceToChain.transient_states,
            ["init", "execute", "verify", "error", "refine"],
        )
        self.assertIn("action-not-proven-successful:deploy", receipt["blockers"])


if __name__ == "__main__":
    unittest.main()
