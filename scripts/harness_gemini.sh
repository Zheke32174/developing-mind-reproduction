#!/usr/bin/env bash
# Developing Mind — Gemini Harness (Hive v3: Quota-Aware)
# Role: Task Execution & Swarm Synthesis.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
LOG_FILE="$DEVMIND_LOG_DIR/harness_gemini.log"

echo "[Gemini] Initiating Task Execution..."
if is_cli_skipped "gemini"; then
    echo "[Gemini] ⏭️  OUT_OF_USAGE. Skipping."
    exit 0
fi

cd "$REPRO_DIR"
safe_run_cli "gemini" "$LOG_FILE" \
    gemini "${DEVMIND_GEMINI_FLAGS[@]}" \
    -p "continue ralph loop from state and verify the next 3 tasks in the 100-task swarm"

if [ $? -eq 0 ]; then
    echo "[Gemini] SUCCESS: Tasks processed."
else
    echo "[Gemini] FAILED or quota hit: See $LOG_FILE (cycle continues)."
    exit 0
fi
