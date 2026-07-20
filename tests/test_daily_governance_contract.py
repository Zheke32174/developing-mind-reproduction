from __future__ import annotations

import importlib.util
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "daily_governance.py"
SPEC = importlib.util.spec_from_file_location("daily_governance_contract", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
GOVERNANCE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GOVERNANCE)


class DailyGovernanceContractTests(unittest.TestCase):
    def test_schema_and_example_are_valid_json(self) -> None:
        schema = json.loads(
            (ROOT / "schemas" / "daily-governance-v1.schema.json").read_text(
                encoding="utf-8"
            )
        )
        example = json.loads(
            (ROOT / "examples" / "daily-governance.example.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(
            schema["$schema"], "https://json-schema.org/draft/2020-12/schema"
        )
        self.assertEqual(
            schema["properties"]["schema"]["const"],
            GOVERNANCE.DAILY_RECORD_SCHEMA,
        )
        self.assertEqual(example["schema"], GOVERNANCE.DAILY_RECORD_SCHEMA)

    def test_published_example_passes_runtime_validation(self) -> None:
        path = ROOT / "examples" / "daily-governance.example.json"
        record = GOVERNANCE.load_daily_record(path, "20260719")
        self.assertEqual(record["plan_id"], "lamp-plan-20260719")
        self.assertEqual(
            [action["outcome"] for action in record["actions"]],
            ["success", "recovered"],
        )
        self.assertEqual(record["unresolved_failures"], [])

    def test_schema_requires_runtime_fields(self) -> None:
        schema = json.loads(
            (ROOT / "schemas" / "daily-governance-v1.schema.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertTrue(
            {
                "schema",
                "date",
                "plan_id",
                "actions",
                "unresolved_failures",
                "provenance",
            }.issubset(set(schema["required"]))
        )
        self.assertTrue(
            {
                "action_id",
                "objective",
                "attempted",
                "outcome",
                "verification",
                "rollback",
                "provenance",
            }.issubset(set(schema["$defs"]["action"]["required"]))
        )


if __name__ == "__main__":
    unittest.main()
