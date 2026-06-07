#!/usr/bin/env bash
# Developing Mind — Hivemind Governor
# Role: Orchestrates the multi-CLI ecosystem (Copilot, OpenCode, Hermes, Gemini, Claude, Codex).
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Ecosystem Governance & Quota Management

export PATH="/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=scripts/devmind-env.sh
source "$SCRIPT_DIR/devmind-env.sh"

STATE_FILE="${DEVMIND_QUOTA_STATE:-$DEVMIND_STATE_DIR/quota_state.txt}"

cd "$REPRO_DIR" || exit 1

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

echo "Initiating Hivemind Orchestration Loop..."

run_cli() {
    local CLI_NAME="$1"
    shift
    echo "Invoking $CLI_NAME..."
    
    local OUTPUT
    OUTPUT=$(timeout 10m "$CLI_NAME" "$@" 2>&1)
    
    if echo "$OUTPUT" | grep -iE "429|too many requests|quota exceeded|exhausted|rate limit|session limit"; then
        echo "$CLI_NAME quota exceeded! Triggering 12-hour ecosystem hibernation."
        date +%s > "$STATE_FILE"
        exit 1
    fi
    echo "$CLI_NAME execution verified."
}

# 1. Hermes: Evolution Validation (60-day rule check)
run_cli bash scripts/hermes_60_day_evolution.sh

# 2. Codex: Governance & Judging (7:00 AM rules)
run_cli python3 scripts/daily_governance.py

# 3. OpenCode: Substrate Quality Review
run_cli opencode --pure --print-logs status

# 4. Claude Code: Hivemind Synthesis Oracle
# Reads all agent state files and writes a coordination directive for the next cycle.
# Sovereign role: bookend intelligence above the Ralph Loop, not replacing it.
run_cli claude -p "You are the Hivemind Synthesis Oracle. Read $REPRO_DIR/PHASE_2_LEDGER.md, $REPRO_DIR/scripts/governance_state.json, $REPRO_DIR/scripts/evolution_state.json. Synthesize current state in 3 sentences: overall status, the single most blocking issue, and the next priority action. Write only to $REPRO_DIR/scripts/hivemind_directive.md. Touch no other file."

# 4.5 Conductor Suite: Ecosystem Coherence
run_cli bash scripts/conductor_suite_orchestrator.sh

# 5. Gemini CLI: The Primary Ralph Automation Loop
echo "Triggering Gemini CLI to progress the 100-Task Ralph Loop..."
OUTPUT=$(timeout 30m gemini -p "continue ralph loop from state" 2>&1)
if echo "$OUTPUT" | grep -iE "429|too many requests|quota exceeded|exhausted|rate limit|session limit"; then
    echo "Gemini CLI quota exceeded! Triggering 12-hour ecosystem hibernation."
    date +%s > "$STATE_FILE"
    exit 1
fi

echo "Hivemind multi-framework cycle complete. Awaiting next cron execution."
