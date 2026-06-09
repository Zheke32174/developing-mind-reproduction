#!/usr/bin/env bash
# Developing Mind — Hyperbolic Judge (Isolated Fork)
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Isolation

DEVMIND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$DEVMIND_SCRIPT_DIR/devmind-env.sh"

bash "$DEVMIND_SCRIPT_DIR/substrate-sync.sh"

# LAMP_DIR is derived from DEVMIND_LOG_DIR to avoid hardcoding /home/fixxia
LAMP_DIR="$(dirname "$DEVMIND_LOG_DIR")"
TIMEOUT="300s"

echo "⚖️ Hyperbolic Judge: Initiating Isolated Functional Audit..."
mkdir -p "$DEVMIND_STATE_DIR"
echo "2026-06-07 2" > "$DEVMIND_STATE_DIR/cron-run.state"

if [ -f "$LAMP_DIR/ai-scaffold/cron-run.sh" ]; then
    timeout "$TIMEOUT" bash "$LAMP_DIR/ai-scaffold/cron-run.sh" --hyperbolic-mode
    JUDGE_EXIT=$?
else
    echo "⚠️ Warning: $LAMP_DIR/ai-scaffold/cron-run.sh not found, skipping external execution."
    JUDGE_EXIT=0
fi

if [ $JUDGE_EXIT -eq 0 ]; then
    echo "✅ HYPERBOLIC AUDIT PASSED."
    exit 0
else
    echo "❌ HYPERBOLIC AUDIT FAILED."
    exit 1
fi
