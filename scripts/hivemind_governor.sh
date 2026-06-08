#!/usr/bin/env bash
# Developing Mind — Hivemind Governor
# Role: Orchestrates the multi-CLI ecosystem (Copilot, OpenCode, Hermes, Gemini, Claude, Codex).
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Ecosystem Governance & Quota Management

export PATH="/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

<<<<<<< HEAD
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=scripts/devmind-env.sh
source "$SCRIPT_DIR/devmind-env.sh"

STATE_FILE="${DEVMIND_QUOTA_STATE:-$DEVMIND_STATE_DIR/quota_state.txt}"

cd "$REPRO_DIR" || exit 1
=======
STATE_FILE="/mnt/c/Users/Fixxia/developing-mind-reproduction/scripts/quota_state.txt"
REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
LOG_DIR="/home/fixxia/lamp/logs"
CYCLE_LOG="$LOG_DIR/governor_cycle_$(date -u +%Y%m%d_%H%M%S).log"
EVOLUTION_STATE="$REPRO_DIR/scripts/evolution_state.json"

mkdir -p "$LOG_DIR"

# --- Concurrency Guard ---
LOCK_FILE="/tmp/hivemind_governor.lock"
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE")
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "Governor already running (PID $LOCK_PID). Exiting to prevent stacking."
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# --- Memory Guard ---
AVAIL_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
if [ "$AVAIL_MB" -lt 800 ]; then
    echo "Memory pressure: only ${AVAIL_MB}MB available (need 800MB). Deferring governor cycle."
    exit 0
fi
echo "Memory OK: ${AVAIL_MB}MB available."
>>>>>>> b4d2636 (PSS: Algorithmic Snapshot with AST Validation - Gated by GGA)

echo "Checking Hivemind Quota State..."

if [ -f "$STATE_FILE" ]; then
    QUOTA_TIME=$(cat "$STATE_FILE")
    CURRENT_TIME=$(date +%s)
    DIFF=$((CURRENT_TIME - QUOTA_TIME))
    if [ "$DIFF" -lt 43200 ]; then
        HOURS_LEFT=$(( (43200 - DIFF) / 3600 ))
        echo "Quota cooldown active. $HOURS_LEFT hours remaining until Hivemind re-awakens."
        exit 0
    else
        echo "12-Hour Quota cooldown expired. Resuming continuous operations."
        rm -f "$STATE_FILE"
    fi
fi

echo "Amnesia Prevention: Ingesting the most recent state..."
bash scripts/substrate-sync.sh

echo "Initiating Hivemind Orchestration Loop..." | tee -a "$CYCLE_LOG"

# run_cli: wraps each agent invocation with quota detection, exit-code checking, and logging.
# Claude calls MUST use --strict-mcp-config --setting-sources= to suppress MCP server spawning.
# Without those flags, each claude -p call loads 10+ npm processes (~1.7GB extra RAM).
run_cli() {
    local CLI_NAME="$1"
    shift
    local LABEL="$CLI_NAME"
    local LOG_FILE="$LOG_DIR/${CLI_NAME##*/}_last.log"
    echo "[$(date -u +%H:%MZ)] Invoking $LABEL..." | tee -a "$CYCLE_LOG"

    local OUTPUT EXIT_CODE
    OUTPUT=$(timeout 10m "$CLI_NAME" "$@" 2>&1)
    EXIT_CODE=$?

    # Persist output for inspection
    echo "$OUTPUT" > "$LOG_FILE"

    if echo "$OUTPUT" | grep -qiE "429|too many requests|quota exceeded|exhausted|rate limit|session limit"; then
        echo "$LABEL quota exceeded! Triggering 12-hour ecosystem hibernation." | tee -a "$CYCLE_LOG"
        date +%s > "$STATE_FILE"
        exit 1
    fi

    if [ "$EXIT_CODE" -ne 0 ]; then
        echo "$LABEL exited with code $EXIT_CODE. Log: $LOG_FILE" | tee -a "$CYCLE_LOG"
    else
        echo "$LABEL OK. Log: $LOG_FILE" | tee -a "$CYCLE_LOG"
    fi
}

# 1. Hermes: Evolution Validation (60-day rule check)
run_cli bash scripts/hermes_60_day_evolution.sh

# 2. Codex: Governance & Judging (7:00 AM rules)
run_cli python3 scripts/daily_governance.py

# 3. OpenCode: Substrate Quality Review
run_cli opencode --pure --print-logs status

# 4. Claude Code: Hivemind Synthesis Oracle
# Lean flags: --strict-mcp-config --setting-sources= suppress all MCP server spawning.
# This drops per-invocation overhead from ~1.7GB to ~380MB.
run_cli claude --strict-mcp-config --setting-sources= -p \
    "You are the Hivemind Synthesis Oracle. Read $REPRO_DIR/PHASE_2_LEDGER.md, $REPRO_DIR/scripts/governance_state.json, $REPRO_DIR/scripts/evolution_state.json. Synthesize current state in 3 sentences: overall status, the single most blocking issue, and the next priority action. Write only to $REPRO_DIR/scripts/hivemind_directive.md. Touch no other file."

# 4.5 Conductor Suite: Ecosystem Coherence (substrate-sync is NOT repeated inside; governor owns it)
run_cli bash scripts/conductor_suite_orchestrator.sh

# 5. Gemini CLI: The Primary Ralph Automation Loop
echo "[$(date -u +%H:%MZ)] Triggering Gemini CLI for Ralph Loop..." | tee -a "$CYCLE_LOG"
OUTPUT=$(timeout 30m gemini -p "continue ralph loop from state" 2>&1)
echo "$OUTPUT" > "$LOG_DIR/gemini_last.log"
if echo "$OUTPUT" | grep -qiE "429|too many requests|quota exceeded|exhausted|rate limit|session limit"; then
    echo "Gemini CLI quota exceeded! Triggering 12-hour ecosystem hibernation." | tee -a "$CYCLE_LOG"
    date +%s > "$STATE_FILE"
    exit 1
fi
echo "Gemini OK." | tee -a "$CYCLE_LOG"

# Update evolution state timestamp so downstream agents know a cycle completed
python3 -c "
import json, datetime
with open('$EVOLUTION_STATE', 'w') as f:
    json.dump({'last_evolution': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S')}, f)
" && echo "Evolution state updated." | tee -a "$CYCLE_LOG"

echo "Hivemind multi-framework cycle complete. Log: $CYCLE_LOG"
