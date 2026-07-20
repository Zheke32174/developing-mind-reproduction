#!/usr/bin/env python3
"""Developing Mind daily governance verification.

The governance decision is derived from a typed execution/evidence record. A
Markdown file's existence is never treated as proof, and synthetic traces are
not accepted as evidence of plan success.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

# Substrate paths. Prefer explicit env, then repo-relative discovery, then
# normal home paths. Legacy WSL paths are fallback-only.
SCRIPT_DIR = Path(__file__).resolve().parent
REPRO_DIR = Path(os.environ.get("DEVMIND_REPRO_DIR", SCRIPT_DIR.parent))
LAMP_DIR = Path(os.environ.get("DEVMIND_LAMP_DIR", Path.home() / "lamp"))
LAMP_LOGS = Path(os.environ.get("DEVMIND_LOG_DIR", LAMP_DIR / "logs"))
STATE_FILE = Path(
    os.environ.get(
        "DEVMIND_GOVERNANCE_STATE", REPRO_DIR / "scripts" / "governance_state.json"
    )
)

# Dynamic import from the Markovian core substrate.
sys.path.append(str(REPRO_DIR / "src"))
try:
    from papers.paper_2604_24579.reliability import TraceToChain
except ImportError:
    TraceToChain = None

DAILY_RECORD_SCHEMA = "developing-mind.daily-governance/v1"
RELIABILITY_THRESHOLD = float(
    os.environ.get("DEVMIND_RELIABILITY_THRESHOLD", "0.85")
)
SUCCESS_OUTCOMES = {"success", "recovered"}
ALL_OUTCOMES = SUCCESS_OUTCOMES | {"failed", "aborted", "timeout"}
VERIFICATION_STATUSES = {"passed", "failed", "missing"}
ROLLBACK_STATUSES = {"not-required", "succeeded", "failed", "not-attempted"}


class GovernanceRecordError(ValueError):
    """Raised when a daily evidence record is malformed or self-contradictory."""


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


def record_digest(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical_bytes(value)).hexdigest()


def require_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise GovernanceRecordError(f"{field} must be a non-empty string")
    return value.strip()


def require_refs(value: Any, field: str, *, allow_empty: bool = False) -> list[str]:
    if not isinstance(value, list) or (not allow_empty and not value):
        raise GovernanceRecordError(f"{field} must be an evidence-reference array")
    if not all(isinstance(item, str) and item.strip() for item in value):
        raise GovernanceRecordError(f"{field} contains an invalid evidence reference")
    return [item.strip() for item in value]


def validate_action(raw: Any, index: int) -> dict[str, Any]:
    field = f"actions[{index}]"
    if not isinstance(raw, dict):
        raise GovernanceRecordError(f"{field} must be an object")

    action_id = require_string(raw.get("action_id"), f"{field}.action_id")
    objective = require_string(raw.get("objective"), f"{field}.objective")
    attempted = raw.get("attempted")
    if not isinstance(attempted, bool):
        raise GovernanceRecordError(f"{field}.attempted must be boolean")

    outcome = raw.get("outcome")
    if outcome not in ALL_OUTCOMES:
        raise GovernanceRecordError(
            f"{field}.outcome must be one of {sorted(ALL_OUTCOMES)}"
        )

    verification = raw.get("verification")
    if not isinstance(verification, dict):
        raise GovernanceRecordError(f"{field}.verification must be an object")
    verification_status = verification.get("status")
    if verification_status not in VERIFICATION_STATUSES:
        raise GovernanceRecordError(
            f"{field}.verification.status must be one of "
            f"{sorted(VERIFICATION_STATUSES)}"
        )
    verification_refs = require_refs(
        verification.get("evidence_refs", []),
        f"{field}.verification.evidence_refs",
        allow_empty=verification_status != "passed",
    )

    rollback = raw.get("rollback")
    if not isinstance(rollback, dict):
        raise GovernanceRecordError(f"{field}.rollback must be an object")
    rollback_status = rollback.get("status")
    if rollback_status not in ROLLBACK_STATUSES:
        raise GovernanceRecordError(
            f"{field}.rollback.status must be one of {sorted(ROLLBACK_STATUSES)}"
        )
    rollback_refs = require_refs(
        rollback.get("evidence_refs", []),
        f"{field}.rollback.evidence_refs",
        allow_empty=rollback_status != "succeeded",
    )

    provenance = raw.get("provenance")
    if not isinstance(provenance, dict):
        raise GovernanceRecordError(f"{field}.provenance must be an object")
    actor = require_string(provenance.get("actor"), f"{field}.provenance.actor")
    source_refs = require_refs(
        provenance.get("source_refs"), f"{field}.provenance.source_refs"
    )

    if outcome in SUCCESS_OUTCOMES and not attempted:
        raise GovernanceRecordError(f"{field} cannot succeed without an attempt")
    if outcome == "success" and verification_status != "passed":
        raise GovernanceRecordError(f"{field} success requires passed verification")
    if outcome == "recovered":
        if verification_status != "passed":
            raise GovernanceRecordError(
                f"{field} recovered outcome requires passed verification"
            )
        if rollback_status != "succeeded":
            raise GovernanceRecordError(
                f"{field} recovered outcome requires succeeded rollback/refinement"
            )
    if outcome in {"failed", "timeout"} and not attempted:
        raise GovernanceRecordError(f"{field} {outcome} outcome requires an attempt")

    return {
        "action_id": action_id,
        "objective": objective,
        "attempted": attempted,
        "outcome": outcome,
        "verification": {
            "status": verification_status,
            "evidence_refs": verification_refs,
        },
        "rollback": {"status": rollback_status, "evidence_refs": rollback_refs},
        "provenance": {"actor": actor, "source_refs": source_refs},
    }


def validate_daily_record(raw: Any, expected_date: str) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise GovernanceRecordError("daily governance record must be an object")
    if raw.get("schema") != DAILY_RECORD_SCHEMA:
        raise GovernanceRecordError("daily governance record schema mismatch")
    if raw.get("date") != expected_date:
        raise GovernanceRecordError(
            f"daily governance record date must be {expected_date}"
        )

    plan_id = require_string(raw.get("plan_id"), "plan_id")
    actions_raw = raw.get("actions")
    if not isinstance(actions_raw, list) or not actions_raw:
        raise GovernanceRecordError("actions must be a non-empty array")
    actions = [validate_action(action, index) for index, action in enumerate(actions_raw)]
    action_ids = [action["action_id"] for action in actions]
    if len(action_ids) != len(set(action_ids)):
        raise GovernanceRecordError("action_id values must be unique")

    failures_raw = raw.get("unresolved_failures", [])
    if not isinstance(failures_raw, list):
        raise GovernanceRecordError("unresolved_failures must be an array")
    unresolved_failures: list[dict[str, Any]] = []
    seen_failure_ids: set[str] = set()
    for index, failure in enumerate(failures_raw):
        field = f"unresolved_failures[{index}]"
        if not isinstance(failure, dict):
            raise GovernanceRecordError(f"{field} must be an object")
        failure_id = require_string(failure.get("failure_id"), f"{field}.failure_id")
        if failure_id in seen_failure_ids:
            raise GovernanceRecordError("failure_id values must be unique")
        seen_failure_ids.add(failure_id)
        unresolved_failures.append(
            {
                "failure_id": failure_id,
                "summary": require_string(failure.get("summary"), f"{field}.summary"),
                "evidence_refs": require_refs(
                    failure.get("evidence_refs"), f"{field}.evidence_refs"
                ),
            }
        )

    provenance = raw.get("provenance")
    if not isinstance(provenance, dict):
        raise GovernanceRecordError("provenance must be an object")
    normalized = {
        "schema": DAILY_RECORD_SCHEMA,
        "date": expected_date,
        "plan_id": plan_id,
        "actions": actions,
        "unresolved_failures": unresolved_failures,
        "provenance": {
            "generated_by": require_string(
                provenance.get("generated_by"), "provenance.generated_by"
            ),
            "source_refs": require_refs(
                provenance.get("source_refs"), "provenance.source_refs"
            ),
        },
    }
    return normalized


def load_daily_record(path: Path, expected_date: str) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise GovernanceRecordError(f"regular daily evidence record required: {path}")
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise GovernanceRecordError(f"cannot read daily evidence record: {exc}") from exc
    return validate_daily_record(raw, expected_date)


def action_trace(action: dict[str, Any]) -> list[str]:
    if not action["attempted"]:
        return ["init", "abort"]
    outcome = action["outcome"]
    if outcome == "success":
        return ["init", "execute", "verify", "success"]
    if outcome == "recovered":
        return ["init", "execute", "error", "refine", "verify", "success"]
    if outcome == "timeout":
        return ["init", "execute", "timeout"]
    if outcome == "failed":
        return ["init", "execute", "error", "abort"]
    return ["init", "execute", "abort"]


def derive_blockers(record: dict[str, Any]) -> list[str]:
    blockers = [
        f"unresolved-failure:{failure['failure_id']}"
        for failure in record["unresolved_failures"]
    ]
    for action in record["actions"]:
        action_id = action["action_id"]
        if not action["attempted"]:
            blockers.append(f"action:{action_id}:not-attempted")
        if action["outcome"] not in SUCCESS_OUTCOMES:
            blockers.append(f"action:{action_id}:outcome:{action['outcome']}")
        if action["verification"]["status"] != "passed":
            blockers.append(
                f"action:{action_id}:verification:{action['verification']['status']}"
            )
    return list(dict.fromkeys(blockers))


def calculate_reliability(traces: list[list[str]]) -> float:
    if TraceToChain is None:
        raise GovernanceRecordError(
            "TraceToChain unavailable; governance reliability cannot be proven"
        )
    transient_order = ["init", "execute", "verify", "error", "refine"]
    transient_states = [
        state
        for state in transient_order
        if any(state in trace[:-1] for trace in traces)
    ]
    if not transient_states or transient_states[0] != "init":
        raise GovernanceRecordError("execution traces lack a valid init state")
    model = TraceToChain(
        transient_states=transient_states,
        success_states={"success"},
        failure_states={"abort", "timeout"},
    )
    # No synthetic smoothing: every transition is estimated from the supplied
    # evidence-derived traces. Validation guarantees each transient state has an
    # outgoing transition, so alpha=0 does not create an empty row.
    model.fit_traces(traces, alpha=0.0)
    horizon = max(len(trace) for trace in traces) + 1
    return float(model.reliability_at_step(d=horizon))


def evaluate_record(record: dict[str, Any]) -> dict[str, Any]:
    traces = [action_trace(action) for action in record["actions"]]
    blockers = derive_blockers(record)
    reliability_score = calculate_reliability(traces)
    if reliability_score < RELIABILITY_THRESHOLD:
        blockers.append("reliability-below-threshold")
    blockers = list(dict.fromkeys(blockers))
    return {
        "passed": not blockers,
        "record_date": record["date"],
        "plan_id": record["plan_id"],
        "record_digest": record_digest(record),
        "action_count": len(record["actions"]),
        "reliability_score": reliability_score,
        "reliability_threshold": RELIABILITY_THRESHOLD,
        "blockers": blockers,
    }


def expected_record_date() -> str:
    explicit = os.environ.get("DEVMIND_GOVERNANCE_DATE")
    if explicit:
        if len(explicit) != 8 or not explicit.isdigit():
            raise GovernanceRecordError(
                "DEVMIND_GOVERNANCE_DATE must use YYYYMMDD"
            )
        return explicit
    return (datetime.now() - timedelta(days=1)).strftime("%Y%m%d")


def verify_success() -> dict[str, Any]:
    print("Executing 7:00 AM EST Ecosystem Governance Verification...")
    checked_at = utc_now()
    try:
        record_date = expected_record_date()
    except GovernanceRecordError as exc:
        print(f"❌ {exc}")
        return {"passed": False, "last_check": checked_at, "blockers": [str(exc)]}

    record_path = LAMP_LOGS / f"daily-{record_date}.json"
    try:
        record = load_daily_record(record_path, record_date)
        result = evaluate_record(record)
    except GovernanceRecordError as exc:
        print(f"❌ {exc}")
        return {
            "passed": False,
            "last_check": checked_at,
            "record_date": record_date,
            "record_path": str(record_path),
            "blockers": [str(exc)],
        }

    result["last_check"] = checked_at
    result["record_path"] = str(record_path)
    print(
        f"Evidence-derived Markovian Reliability Score: "
        f"{result['reliability_score']:.4f}"
    )
    if result["blockers"]:
        for blocker in result["blockers"]:
            print(f"❌ Governance blocker: {blocker}")
    return result


def atomic_write_state(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    data = json.dumps(value, sort_keys=True, indent=2).encode("utf-8") + b"\n"
    fd = os.open(temporary, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    try:
        offset = 0
        while offset < len(data):
            written = os.write(fd, data[offset:])
            if written <= 0:
                raise OSError("state write made no progress")
            offset += written
        os.fsync(fd)
    except BaseException:
        os.close(fd)
        temporary.unlink(missing_ok=True)
        raise
    else:
        os.close(fd)
    os.replace(temporary, path)
    try:
        directory_fd = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    except OSError:
        return
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)


if __name__ == "__main__":
    outcome = verify_success()
    state = {
        "mode": "PROGRESS" if outcome.get("passed") else "REFINEMENT",
        **outcome,
    }
    atomic_write_state(STATE_FILE, state)
    if outcome.get("passed"):
        print(
            "✅ Governance Check Passed. Proceeding with new Attractor SNF daily "
            "orchestration."
        )
        sys.exit(0)
    print("🚨 Governance Check FAILED. Ecosystem locked to REFINEMENT mode for the day.")
    sys.exit(1)
