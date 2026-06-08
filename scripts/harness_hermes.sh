#!/usr/bin/env bash
# Developing Mind — Hermes Harness (Hive v3: Quota-Aware)
# Role: Cognitive Boundary Validation & NLSpec Alignment.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
LOG_FILE="$DEVMIND_LOG_DIR/harness_hermes.log"

echo "[Hermes] Initiating Boundary Validation..."
# Hermes uses bash scripts directly (no external CLI quota exposure)
# but check if underlying dependencies are available

cd "$REPRO_DIR"
safe_run_cli "bash" "$LOG_FILE" \
    bash scripts/hermes_60_day_evolution.sh --verify-only

if [ $? -eq 0 ]; then
    echo "[Hermes] SUCCESS: Boundaries verified."
else
    echo "[Hermes] FAILED: See $LOG_FILE"
    exit 1
fi
