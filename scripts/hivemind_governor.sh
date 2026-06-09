#!/usr/bin/env bash
# Developing Mind — Hivemind Governor (v5: Per-CLI Quota, Ralph+GGA+Codex Judge)
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

# Per-CLI quota model: only skip if ALL primary CLIs are out of usage.
# A single CLI hitting a rate-limit no longer blocks the whole governor cycle.
# The legacy quota_state.txt global cooldown has been retired.
ALL_SKIPPED=true
for _cli in gemini claude codex opencode; do
    is_cli_skipped "$_cli" || { ALL_SKIPPED=false; break; }
done
if $ALL_SKIPPED; then
    echo "💤 All CLIs out of usage. Skipping cycle."
    exit 0
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

# Ralph goal synthesis (Gemini-powered, quota-aware)
if ! is_cli_skipped "gemini"; then
    safe_run_cli "ralph-goals" "$DEVMIND_LOG_DIR/ralph-goals.log" \
        bash "/home/fixxia/ryz-build/scripts/ralph-goals.sh"
fi

# GGA periodic repo audit (quota-aware)
safe_run_cli "gga" "$DEVMIND_LOG_DIR/gga.log" \
    bash "/home/fixxia/ryz-build/scripts/gga-cycle.sh"

# Codex Judge (lamp automation review — uses lamp cron-run.sh)
if ! is_cli_skipped "codex"; then
    safe_run_cli "codex-judge" "$DEVMIND_LOG_DIR/codex-judge.log" \
        bash "/home/fixxia/lamp/ai-scaffold/cron-run.sh" force-judge
fi

echo "✅ Hivemind cycle complete."
