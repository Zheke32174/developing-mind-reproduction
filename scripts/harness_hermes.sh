#!/usr/bin/env bash
# Developing Mind — Hermes Harness (Hive v3: Quota-Aware)
# Role: Cognitive Boundary Validation & NLSpec Alignment.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

LOG_FILE="$DEVMIND_LOG_DIR/harness_hermes.log"

echo "[Hermes] Initiating Boundary Validation..."
# Hermes uses bash scripts directly (no external CLI quota exposure)
# but check if underlying dependencies are available

cd "$DEVMIND_REPRO_DIR"
timeout 180s bash scripts/hermes_60_day_evolution.sh --verify-only >> "$LOG_FILE" 2>&1
local_rc=$?
if [[ $local_rc -eq 124 ]]; then
    echo "[Hermes] WARN: hermes_60_day_evolution.sh timed out after 180s."
    local_rc=1
fi

if [ $local_rc -eq 0 ]; then
    echo "[Hermes] SUCCESS: Boundaries verified."
else
    echo "[Hermes] FAILED (rc=$local_rc): See $LOG_FILE"
    exit 1
fi
