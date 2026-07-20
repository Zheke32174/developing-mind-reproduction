from __future__ import annotations

import importlib.util
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "daily_governance_contract_under_test",
    ROOT / "scripts" / "daily_governance.py",
)
assert SPEC is not None and SPEC.loader is not None
GOVERNANCE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GOVERNANCE)


class DailyGovernanceContractTests(unittest.TestCase):
    def setUp(self):
        self.schema = json.loads(
            (ROOT / "schemas" / "daily-governance-v1.schema.json").read_text(
                encoding="utf-8"
            )
        )
        self.example = json.loads(
            (ROOT / "examples" / "daily-governance.example.json").read_text(
                encoding="utf-8"
            )
        )

    def test_schema_and_example_identify_runtime_contract(self):
        self.assertEqual(
            self.schema["properties"]["schema"]["const"],
            GOVERNANCE.EVIDENCE_SCHEMA,
        )
        self.assertEqual(self.example["schema"], GOVERNANCE.EVIDENCE_SCHEMA)
        self.assertEqual(
            set(self.schema["required"]),
            {
                "schema",
                "date",
                "record_id",
                "plan_id",
                "plan_digest",
                "created_at",
                "provenance",
                "actions",
                "unresolved_failures",
                "record_digest",
            },
        )

    def test_example_digest_and_runtime_validation_match(self):
        self.assertEqual(
            self.example["record_digest"],
            GOVERNANCE.evidence_digest(self.example),
        )
        traces, blockers = GOVERNANCE.validate_evidence(
            self.example,
            self.example["date"],
        )
        self.assertEqual(traces, [["init", "execute", "verify", "success"]])
        self.assertEqual(blockers, [])

    def test_schema_preserves_receipt_and_digest_requirements(self):
        action = self.schema["properties"]["actions"]["items"]
        self.assertFalse(action["additionalProperties"])
        self.assertIn("verification", action["required"])
        self.assertIn("rollback", action["required"])
        self.assertEqual(
            self.schema["properties"]["record_digest"]["pattern"],
            "^sha256:[0-9a-f]{64}$",
        )


if __name__ == "__main__":
    unittest.main()
