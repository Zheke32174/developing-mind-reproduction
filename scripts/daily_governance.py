#!/usr/bin/env python3
"""Developing Mind daily governance over typed, content-addressed evidence.

The governance loop never treats a Markdown file or model-calibration fixture as
proof. It derives transition traces from the previous day's immutable execution
record and fails closed on missing, malformed, contradictory, or incomplete
evidence.
"""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
REPRO_DIR = pathlib.Path(os.environ.get("DEVMIND_REPRO_DIR", SCRIPT_DIR.parent))
LAMP_DIR = pathlib.Path(os.environ.get("DEVMIND_LAMP_DIR", pathlib.Path.home() / "lamp"))
LAMP_LOGS = pathlib.Path(os.environ.get("DEVMIND_LOG_DIR", LAMP_DIR / "logs"))
STATE_FILE = pathlib.Path(
    os.environ.get(
        "DEVMIND_GOVERNANCE_STATE",
        REPRO_DIR / "scripts" / "governance_state.json",
    )
)
GOVERNANCE_TIMEZONE = ZoneInfo(
    os.environ.get("DEVMIND_GOVERNANCE_TIMEZONE", "America/New_York")
)

sys.path.append(str(REPRO_DIR / "src"))
try:
    from papers.paper_2604_24579.reliability import TraceToChain
except ImportError:
    TraceToChain = None

EVIDENCE_SCHEMA = "developing-mind.daily-execution-evidence/v1"
STATE_SCHEMA = "developing-mind.governance-state/v2"
MAX_EVIDENCE_BYTES = 4 * 1024 * 1024
MAX_ACTIONS = 4096
DIGEST_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
RELIABILITY_THRESHOLD = float(
    os.environ.get("DEVMIND_RELIABILITY_THRESHOLD", "0.85")
)
TRANSIENT_STATE_ORDER = ["init", "execute", "verify", "error", "refine"]


class GovernanceError(ValueError):
    """Raised when daily evidence cannot support a governance decision."""


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def digest_id(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical_bytes(value)).hexdigest()


def evidence_digest(record: dict[str, Any]) -> str:
    material = dict(record)
    material["record_digest"] = ""
    return digest_id(material)


def require_string(value: Any, field: str, *, maximum: int = 512) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > maximum:
        raise GovernanceError(f"{field} must be a non-empty bounded string")
    return value.strip()


def require_string_list(
    value: Any,
    field: str,
    *,
    nonempty: bool = False,
    maximum: int = 4096,
) -> list[str]:
    if not isinstance(value, list) or len(value) > maximum:
        raise GovernanceError(f"{field} must be a bounded string array")
    result = [require_string(item, f"{field}[]") for item in value]
    if nonempty and not result:
        raise GovernanceError(f"{field} must not be empty")
    if len(result) != len(set(result)):
        raise GovernanceError(f"{field} contains duplicate entries")
    return result


def validate_action(raw: Any, index: int) -> tuple[dict[str, Any], list[str], bool]:
    if not isinstance(raw, dict):
        raise GovernanceError(f"actions[{index}] must be an object")

    action_id = require_string(raw.get("action_id"), f"actions[{index}].action_id", maximum=128)
    attempted = raw.get("attempted")
    if not isinstance(attempted, bool):
        raise GovernanceError(f"actions[{index}].attempted must be boolean")
    outcome = raw.get("outcome")
    if outcome not in {"success", "failure", "rolled-back", "skipped"}:
        raise GovernanceError(f"actions[{index}].outcome is invalid")

    verification = raw.get("verification")
    if not isinstance(verification, dict):
        raise GovernanceError(f"actions[{index}].verification must be an object")
    verification_status = verification.get("status")
    if verification_status not in {"verified", "failed", "missing"}:
        raise GovernanceError(f"actions[{index}].verification.status is invalid")
    verification_receipts = require_string_list(
        verification.get("receipts"),
        f"actions[{index}].verification.receipts",
    )

    rollback = raw.get("rollback")
    if not isinstance(rollback, dict):
        raise GovernanceError(f"actions[{index}].rollback must be an object")
    rollback_status = rollback.get("status")
    if rollback_status not in {"not-required", "completed", "failed", "pending"}:
        raise GovernanceError(f"actions[{index}].rollback.status is invalid")
    rollback_receipts = require_string_list(
        rollback.get("receipts"),
        f"actions[{index}].rollback.receipts",
    )

    if verification_status == "verified" and not verification_receipts:
        raise GovernanceError(
            f"actions[{index}] claims verification without a receipt"
        )
    if rollback_status == "completed" and not rollback_receipts:
        raise GovernanceError(
            f"actions[{index}] claims rollback completion without a receipt"
        )

    trace = ["init"]
    successful = False
    if not attempted:
        if outcome != "skipped" or verification_status != "missing":
            raise GovernanceError(
                f"actions[{index}] is contradictory: unattempted work must be skipped and unverified"
            )
        if rollback_status != "not-required":
            raise GovernanceError(
                f"actions[{index}] is contradictory: unattempted work cannot have rollback state"
            )
        trace.append("abort")
    else:
        trace.append("execute")
        if outcome == "success":
            trace.append("verify")
            if verification_status == "verified" and rollback_status in {
                "not-required",
                "completed",
            }:
                trace.append("success")
                successful = True
            else:
                trace.extend(["error", "abort"])
        elif outcome == "rolled-back":
            if rollback_status != "completed":
                raise GovernanceError(
                    f"actions[{index}] claims rolled-back outcome without completed rollback"
                )
            trace.extend(["error", "refine", "abort"])
        elif outcome == "failure":
            trace.extend(["error", "abort"])
        else:
            raise GovernanceError(
                f"actions[{index}] is contradictory: attempted work cannot be skipped"
            )

    normalized = {
        "action_id": action_id,
        "attempted": attempted,
        "outcome": outcome,
        "verification": {
            "status": verification_status,
            "receipts": verification_receipts,
        },
        "rollback": {
            "status": rollback_status,
            "receipts": rollback_receipts,
        },
    }
    return normalized, trace, successful


def validate_evidence(
    record: dict[str, Any], expected_day: str
) -> tuple[list[list[str]], list[str]]:
    if record.get("schema") != EVIDENCE_SCHEMA:
        raise GovernanceError(f"evidence schema must be {EVIDENCE_SCHEMA}")
    if record.get("date") != expected_day:
        raise GovernanceError("evidence date does not match the governed day")

    require_string(record.get("record_id"), "record_id", maximum=128)
    require_string(record.get("plan_id"), "plan_id", maximum=128)
    plan_digest = record.get("plan_digest")
    if not isinstance(plan_digest, str) or not DIGEST_RE.fullmatch(plan_digest):
        raise GovernanceError("plan_digest must be a canonical sha256 identity")
    require_string(record.get("created_at"), "created_at", maximum=64)

    provenance = record.get("provenance")
    if not isinstance(provenance, dict):
        raise GovernanceError("provenance must be an object")
    require_string(provenance.get("collector"), "provenance.collector", maximum=128)
    require_string_list(
        provenance.get("source_refs"),
        "provenance.source_refs",
        nonempty=True,
    )

    unresolved = require_string_list(
        record.get("unresolved_failures"),
        "unresolved_failures",
    )
    actions = record.get("actions")
    if not isinstance(actions, list) or not actions or len(actions) > MAX_ACTIONS:
        raise GovernanceError("actions must be a non-empty bounded array")

    traces: list[list[str]] = []
    action_ids: set[str] = set()
    unsuccessful: list[str] = []
    for index, raw in enumerate(actions):
        action, trace, successful = validate_action(raw, index)
        if action["action_id"] in action_ids:
            raise GovernanceError(f"duplicate action_id: {action['action_id']}")
        action_ids.add(action["action_id"])
        traces.append(trace)
        if not successful:
            unsuccessful.append(action["action_id"])

    claimed_digest = record.get("record_digest")
    if not isinstance(claimed_digest, str) or not DIGEST_RE.fullmatch(claimed_digest):
        raise GovernanceError("record_digest must be a canonical sha256 identity")
    calculated_digest = evidence_digest(record)
    if claimed_digest != calculated_digest:
        raise GovernanceError("daily evidence digest mismatch")

    blockers = list(unresolved)
    blockers.extend(f"action-not-proven-successful:{item}" for item in unsuccessful)
    return traces, blockers


def load_daily_evidence(day: str) -> tuple[pathlib.Path, dict[str, Any]]:
    path = LAMP_LOGS / f"daily-{day}.execution.json"
    if path.is_symlink() or not path.is_file():
        raise GovernanceError(f"typed daily execution evidence is missing: {path}")
    try:
        size = path.stat().st_size
    except OSError as exc:
        raise GovernanceError(f"cannot stat daily evidence: {exc}") from exc
    if size < 2 or size > MAX_EVIDENCE_BYTES:
        raise GovernanceError(
            f"daily evidence size is outside 2..{MAX_EVIDENCE_BYTES} bytes"
        )
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise GovernanceError(f"cannot parse daily evidence: {exc}") from exc
    if not isinstance(value, dict):
        raise GovernanceError("daily evidence top level must be one object")
    return path, value


def evaluate_governance(day: str | None = None) -> dict[str, Any]:
    governed_day = day or (
        datetime.now(GOVERNANCE_TIMEZONE) - timedelta(days=1)
    ).strftime("%Y%m%d")
    receipt: dict[str, Any] = {
        "schema": STATE_SCHEMA,
        "governed_day": governed_day,
        "checked_at": utc_now(),
        "threshold": RELIABILITY_THRESHOLD,
        "mode": "REFINEMENT",
        "passed": False,
        "blockers": [],
    }

    try:
        evidence_path, record = load_daily_evidence(governed_day)
        traces, blockers = validate_evidence(record, governed_day)
        receipt["evidence_path"] = str(evidence_path)
        receipt["evidence_digest"] = record["record_digest"]
        receipt["plan_digest"] = record["plan_digest"]
        receipt["trace_digest"] = digest_id(traces)
        receipt["trace_count"] = len(traces)
        receipt["blockers"] = blockers

        if TraceToChain is None:
            raise GovernanceError(
                "TraceToChain unavailable; governance reliability cannot be derived"
            )

        transient_states = [
            state
            for state in TRANSIENT_STATE_ORDER
            if any(state in trace[:-1] for trace in traces)
        ]
        if not transient_states or transient_states[0] != "init":
            raise GovernanceError("execution evidence lacks a valid initial state")
        horizon = max(len(trace) for trace in traces) + 1
        receipt["transient_states"] = transient_states
        receipt["trace_horizon"] = horizon

        model = TraceToChain(
            transient_states=transient_states,
            success_states={"success"},
            failure_states={"abort", "timeout"},
        )
        model.fit_traces(traces, alpha=0.0)
        reliability_score = float(model.reliability_at_step(d=horizon))
        receipt["reliability_score"] = reliability_score

        if blockers:
            raise GovernanceError(
                "execution evidence contains unresolved or unsuccessful actions"
            )
        if reliability_score < RELIABILITY_THRESHOLD:
            raise GovernanceError(
                f"reliability {reliability_score:.4f} is below gate {RELIABILITY_THRESHOLD}"
            )

        decision_material = {
            "governed_day": governed_day,
            "evidence_digest": receipt["evidence_digest"],
            "plan_digest": receipt["plan_digest"],
            "trace_digest": receipt["trace_digest"],
            "reliability_score": format(reliability_score, ".12g"),
            "threshold": format(RELIABILITY_THRESHOLD, ".12g"),
            "mode": "PROGRESS",
        }
        receipt["decision_digest"] = digest_id(decision_material)
        receipt["mode"] = "PROGRESS"
        receipt["passed"] = True
        return receipt
    except (GovernanceError, ValueError, TypeError, OverflowError) as exc:
        receipt["blockers"] = list(receipt.get("blockers", [])) + [str(exc)]
        receipt["decision_digest"] = digest_id(
            {
                "governed_day": governed_day,
                "evidence_digest": receipt.get("evidence_digest"),
                "trace_digest": receipt.get("trace_digest"),
                "blockers": receipt["blockers"],
                "mode": "REFINEMENT",
            }
        )
        return receipt


def write_state(receipt: dict[str, Any]) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    data = json.dumps(receipt, sort_keys=True, indent=2, ensure_ascii=False) + "\n"
    fd, temporary_name = tempfile.mkstemp(
        prefix=f".{STATE_FILE.name}.",
        suffix=".tmp",
        dir=STATE_FILE.parent,
        text=True,
    )
    temporary = pathlib.Path(temporary_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, STATE_FILE)
        directory_fd = os.open(
            STATE_FILE.parent,
            os.O_RDONLY | getattr(os, "O_DIRECTORY", 0),
        )
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def main() -> int:
    print("Executing daily ecosystem governance verification...")
    receipt = evaluate_governance()
    write_state(receipt)
    if receipt["passed"]:
        print(
            "Governance Check Passed: typed evidence, derived traces, and "
            f"decision {receipt['decision_digest']} support PROGRESS."
        )
        print(f"Markovian Reliability Score: {receipt['reliability_score']:.4f}")
        return 0

    print("Governance Check FAILED. Ecosystem remains in REFINEMENT mode.")
    for blocker in receipt["blockers"]:
        print(f" - {blocker}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
