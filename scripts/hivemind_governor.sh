#!/usr/bin/env bash
# Developing Mind — Hivemind Governor (v4: Quota-Aware)
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Governance Logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

LOCK_FILE="/tmp/hivemind.lock"
MEMORY_THRESHOLD=800

if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "🚨 Governor already running (PID $PID). Exiting."
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Global quota cooldown check (12h after any rate-limit)
if [ -f "$DEVMIND_QUOTA_STATE" ]; then
    QUOTA_TIME=$(cat "$DEVMIND_QUOTA_STATE")
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - QUOTA_TIME)) -lt 43200 ]; then
        echo "💤 Quota cooldown active ($(( (43200 - (CURRENT_TIME - QUOTA_TIME)) / 60 ))m remaining). Skipping."
        exit 0
    fi
fi

FREE_MEM=$(free -m | awk '/^Mem:/ {print $4}')
if [ "$FREE_MEM" -lt "$MEMORY_THRESHOLD" ]; then
    echo "⚠️ Low memory ($FREE_MEM MB). Dropping caches..."
    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
fi

echo "🚀 Initiating Hivemind Orchestration Loop..."

# Probe each CLI for availability before running the full suite.
# This catches "out of usage" early without burning a real task invocation.
probe_cli() {
    local cli="$1"
    local probe_cmd="$2"
    if is_cli_skipped "$cli"; then
        echo "⏭️  $cli is OUT_OF_USAGE (skip file exists). Skipping probe."
        return 0
    fi
    local out
    out=$(timeout 30s $probe_cmd 2>&1) || true
    check_output_for_quota "$cli" "$out" || true
}

probe_cli "codex"    "codex --version"
probe_cli "opencode" "opencode --version"
probe_cli "claude"   "claude --version"
probe_cli "gemini"   "gemini --version"

# Run substrate sync and governance (no quota exposure)
safe_run_cli "bash" "$DEVMIND_LOG_DIR/substrate_sync.log" \
    bash "$DEVMIND_REPRO_DIR/scripts/substrate-sync.sh"

safe_run_cli "python3" "$DEVMIND_LOG_DIR/daily_governance.log" \
    python3 "$DEVMIND_REPRO_DIR/scripts/daily_governance.py"

# Probe opencode status
safe_run_cli "opencode" "$DEVMIND_LOG_DIR/opencode_status.log" \
    opencode --version

# Run conductor suite (calls Gemini internally — skipped if gemini is OUT_OF_USAGE)
if ! is_cli_skipped "gemini"; then
    safe_run_cli "gemini" "$DEVMIND_LOG_DIR/conductor.log" \
        bash "$DEVMIND_REPRO_DIR/scripts/conductor_suite_orchestrator.sh"
else
    echo "⏭️  Skipping conductor suite — gemini is OUT_OF_USAGE."
fi

echo "✅ Hivemind cycle complete."
