#!/usr/bin/env bash
# Developing Mind — Hivemind Governor (v3: Hardened)
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Governance Logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

LOCK_FILE="/tmp/hivemind.lock"
MEMORY_THRESHOLD=800

if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p "$PID" > /dev/null; then
        echo "🚨 Governor already running (PID $PID). Exiting."
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

if [ -f "$DEVMIND_QUOTA_STATE" ]; then
    QUOTA_TIME=$(cat "$DEVMIND_QUOTA_STATE")
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - QUOTA_TIME)) -lt 43200 ]; then
        echo "💤 Quota cooldown active. Skipping."
        exit 0
    fi
fi

FREE_MEM=$(free -m | awk '/^Mem:/ {print $4}')
if [ "$FREE_MEM" -lt "$MEMORY_THRESHOLD" ]; then
    echo "⚠️ Low memory ($FREE_MEM MB). Dropping caches..."
    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
fi

echo "🚀 Initiating Hivemind Orchestration Loop..."

run_cli() {
    local CLI_NAME="$1"
    shift
    if [ -f "$DEVMIND_STATE_DIR/skip_$CLI_NAME" ]; then
        echo "⏭️  $CLI_NAME marked OUT_OF_USAGE. Skipping."
        return 0
    fi
    local OUTPUT
    OUTPUT=$(timeout 10m "$CLI_NAME" "$@" 2>&1)
    if echo "$OUTPUT" | grep -iE "429|too many requests|quota exceeded|exhausted|rate limit|session limit|out of usage"; then
        echo "🚨 $CLI_NAME error detected."
        if echo "$OUTPUT" | grep -iq "out of usage"; then
             touch "$DEVMIND_STATE_DIR/skip_$CLI_NAME"
        else
             date +%s > "$DEVMIND_QUOTA_STATE"
             exit 1
        fi
    fi
}

run_cli bash "$DEVMIND_REPRO_DIR/scripts/substrate-sync.sh"
run_cli python3 "$DEVMIND_REPRO_DIR/scripts/daily_governance.py"
run_cli opencode --pure status
run_cli bash "$DEVMIND_REPRO_DIR/scripts/conductor_suite_orchestrator.sh"

echo "✅ Hivemind cycle complete."
