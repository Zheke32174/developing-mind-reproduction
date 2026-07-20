from __future__ import annotations

import importlib.util
import json
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "daily_governance_under_test", ROOT / "scripts" / "daily_governance.py"
)
assert SPEC is not None and SPEC.loader is not None
GOVERNANCE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GOVERNANCE)


class FakeTraceToChain:
    score = 0.9
    fitted_traces = None

    def __init__(self, transient_states, success_states, failure_states):
        self.transient_states = transient_states
        self.success_states = success_states
        self.failure_states = failure_states

    def fit_traces(self, traces, alpha=0.5):
        type(self).fitted_traces = traces
        self.alpha = alpha

    def reliability_at_step(self, d):
        self.depth = d
        return type(self).score


class DailyGovernanceEvidenceTests(unittest.TestCase):
    day = "20260718"

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name)
        self.logs = self.root / "logs"
        self.logs.mkdir()
        GOVERNANCE.LAMP_LOGS = self.logs
        GOVERNANCE.STATE_FILE = self.root / "state" / "governance.json"
        GOVERNANCE.TraceToChain = FakeTraceToChain
        GOVERNANCE.RELIABILITY_THRESHOLD = 0.45
        FakeTraceToChain.score = 0.9
        FakeTraceToChain.fitted_traces = None

    def tearDown(self):
        self.temporary.cleanup()

    def valid_record(self):
        record = {
            "schema": GOVERNANCE.EVIDENCE_SCHEMA,
            "date": self.day,
            "record_id": "daily-execution-20260718",
            "plan_id": "plan-20260718",
            "plan_digest": GOVERNANCE.digest_id(
                {"plan_id": "plan-20260718", "actions": ["compile"]}
            ),
            "created_at": "2026-07-19T06:59:00Z",
            "provenance": {
                "collector": "lamp-governance-recorder/v1",
                "source_refs": [
                    "git:Zheke32174/developing-mind-reproduction@deadbeef",
                    "artifact:verification/compile.json",
                ],
            },
            "actions": [
                {
                    "action_id": "compile",
                    "attempted": True,
                    "outcome": "success",
                    "verification": {
                        "status": "verified",
                        "receipts": ["artifact:verification/compile.json"],
                    },
                    "rollback": {"status": "not-required", "receipts": []},
                }
            ],
            "unresolved_failures": [],
            "record_digest": "",
        }
        record["record_digest"] = GOVERNANCE.evidence_digest(record)
        return record

    def write_record(self, value):
        path = self.logs / f"daily-{self.day}.execution.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_valid_record_derives_trace_and_binds_decision(self):
        record = self.valid_record()
        self.write_record(record)
        receipt = GOVERNANCE.evaluate_governance(self.day)
        self.assertTrue(receipt["passed"])
        self.assertEqual(receipt["mode"], "PROGRESS")
        self.assertEqual(receipt["evidence_digest"], record["record_digest"])
        self.assertEqual(
            FakeTraceToChain.fitted_traces,
            [["init", "execute", "verify", "success"]],
        )
        self.assertRegex(receipt["decision_digest"], r"^sha256:[0-9a-f]{64}$")

    def test_markdown_existence_is_not_governance_evidence(self):
        (self.logs / f"daily-{self.day}.md").write_text(
            "everything succeeded", encoding="utf-8"
        )
        receipt = GOVERNANCE.evaluate_governance(self.day)
        self.assertFalse(receipt["passed"])
        self.assertTrue(
            any("typed daily execution evidence is missing" in item for item in receipt["blockers"])
        )
        self.assertIsNone(FakeTraceToChain.fitted_traces)

    def test_digest_mismatch_fails_closed(self):
        record = self.valid_record()
        record["actions"][0]["outcome"] = "failure"
        self.write_record(record)
        receipt = GOVERNANCE.evaluate_governance(self.day)
        self.assertFalse(receipt["passed"])
        self.assertTrue(any("digest mismatch" in item for item in receipt["blockers"]))
        self.assertIsNone(FakeTraceToChain.fitted_traces)

    def test_failed_action_cannot_pass_with_high_model_score(self):
        record = self.valid_record()
        record["actions"][0] = {
            "action_id": "compile",
            "attempted": True,
            "outcome": "failure",
            "verification": {"status": "failed", "receipts": []},
            "rollback": {"status": "not-required", "receipts": []},
        }
        record["unresolved_failures"] = ["compile failed"]
        record["record_digest"] = GOVERNANCE.evidence_digest(record)
        self.write_record(record)
        FakeTraceToChain.score = 0.999
        receipt = GOVERNANCE.evaluate_governance(self.day)
        self.assertFalse(receipt["passed"])
        self.assertEqual(
            FakeTraceToChain.fitted_traces,
            [["init", "execute", "error", "abort"]],
        )
        self.assertIn("compile failed", receipt["blockers"])
        self.assertIn("action-not-proven-successful:compile", receipt["blockers"])

    def test_verified_without_receipt_is_rejected_before_modeling(self):
        record = self.valid_record()
        record["actions"][0]["verification"]["receipts"] = []
        record["record_digest"] = GOVERNANCE.evidence_digest(record)
        self.write_record(record)
        receipt = GOVERNANCE.evaluate_governance(self.day)
        self.assertFalse(receipt["passed"])
        self.assertTrue(
            any("claims verification without a receipt" in item for item in receipt["blockers"])
        )
        self.assertIsNone(FakeTraceToChain.fitted_traces)

    def test_contradictory_unattempted_success_is_rejected(self):
        record = self.valid_record()
        record["actions"][0]["attempted"] = False
        record["record_digest"] = GOVERNANCE.evidence_digest(record)
        self.write_record(record)
        receipt = GOVERNANCE.evaluate_governance(self.day)
        self.assertFalse(receipt["passed"])
        self.assertTrue(any("contradictory" in item for item in receipt["blockers"]))
        self.assertIsNone(FakeTraceToChain.fitted_traces)

    def test_non_object_top_level_is_rejected(self):
        self.write_record([self.valid_record()])
        receipt = GOVERNANCE.evaluate_governance(self.day)
        self.assertFalse(receipt["passed"])
        self.assertTrue(
            any("top level must be one object" in item for item in receipt["blockers"])
        )

    def test_low_reliability_keeps_refinement(self):
        self.write_record(self.valid_record())
        FakeTraceToChain.score = 0.1
        receipt = GOVERNANCE.evaluate_governance(self.day)
        self.assertFalse(receipt["passed"])
        self.assertEqual(receipt["mode"], "REFINEMENT")
        self.assertTrue(any("below gate" in item for item in receipt["blockers"]))

    def test_state_receipt_is_private_and_bound(self):
        record = self.valid_record()
        self.write_record(record)
        receipt = GOVERNANCE.evaluate_governance(self.day)
        GOVERNANCE.write_state(receipt)
        written = json.loads(GOVERNANCE.STATE_FILE.read_text(encoding="utf-8"))
        self.assertEqual(written["evidence_digest"], record["record_digest"])
        self.assertEqual(GOVERNANCE.STATE_FILE.stat().st_mode & 0o777, 0o600)
        self.assertEqual(list(GOVERNANCE.STATE_FILE.parent.glob("*.tmp")), [])


if __name__ == "__main__":
    unittest.main()
