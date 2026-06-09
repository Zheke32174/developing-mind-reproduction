#!/usr/bin/env bash
# Developing Mind — Sub-Hermes Evolution
# Role: Triggers a micro-evolution round every 2 days.
# Arxiv Anchor: 2511.10621 (Foundation Algorithms) - Continuous Evolution

DEVMIND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$DEVMIND_SCRIPT_DIR/devmind-env.sh"
REPRO_DIR="$DEVMIND_REPRO_DIR"
SCRIPTS_DIR="$REPRO_DIR/scripts"
LOG_FILE="$DEVMIND_LOG_DIR/sub_hermes.log"

echo "🧬 Starting Bi-Daily Sub-Hermes Evolution..."

# Execute evolution
bash "$SCRIPTS_DIR/hermes_60_day_evolution.sh" --sub-round > "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    echo "🚨 Sub-Hermes failure detected. Invoking Parallel Debugger..."
    bash "$SCRIPTS_DIR/parallel_debugger.sh" "$LOG_FILE" "sub-hermes-evolution"
    exit 1
fi

echo "✅ Sub-evolution cycle complete."
exit 0
