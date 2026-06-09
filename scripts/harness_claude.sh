#!/usr/bin/env bash
# Developing Mind — Claude Harness (Hive v3: Quota-Aware)
# Role: Global Strategic Reflection & Architecture Audit.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

LOG_FILE="$DEVMIND_LOG_DIR/harness_claude.log"

echo "[Claude] Initiating Strategic Reflection..."
if is_cli_skipped "claude"; then
    echo "[Claude] ⏭️  OUT_OF_USAGE. Skipping."
    exit 0
fi

cd "$DEVMIND_REPRO_DIR"
safe_run_cli "claude" "$LOG_FILE" \
    claude --strict-mcp-config --setting-sources= \
    -p "Perform a deep architectural reflection on the current ecosystem state. Identify structural weaknesses and propose next-gen evolution rounds."

if [ $? -eq 0 ]; then
    echo "[Claude] SUCCESS: Reflection complete."
else
    echo "[Claude] FAILED or quota hit: See $LOG_FILE"
    exit 1
fi
