#!/usr/bin/env bash
# Developing Mind — Ralph Loop Progressor (Cron-Driven Iteration Engine)
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Forward Progress
#
# In interactive Gemini sessions, the Ralph stop-hook automatically re-feeds the
# loop prompt and increments the iteration counter. Cron-mode has no interactive
# hook, so this script simulates the same behaviour:
#   1. Read .gemini/ralph/state.json
#   2. If active and iteration < max, re-feed the original_prompt to gemini
#   3. Increment current_iteration and persist
#   4. Honor skip flag — defer if gemini is OUT_OF_USAGE
# All failure paths exit 0 so cron does not raise alarms; failures are logged.

export PATH="/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=devmind-env.sh
source "$SCRIPT_DIR/devmind-env.sh"

REPRO_DIR="${DEVMIND_REPRO_DIR:-/mnt/c/Users/Fixxia/developing-mind-reproduction}"
STATE_FILE="${DEVMIND_RALPH_STATE:-$REPRO_DIR/.gemini/ralph/state.json}"
LOG_FILE="$DEVMIND_LOG_DIR/ralph_progressor.log"
LOCK_FILE="/tmp/ralph_progressor.lock"

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$STATE_FILE")" 2>/dev/null || true

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG_FILE"; }

# Concurrency guard — one progressor at a time.
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$PID" ] && ps -p "$PID" >/dev/null 2>&1; then
        log "Already running (PID $PID). Exiting."
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

if [ ! -f "$STATE_FILE" ]; then
    log "No state.json — watchdog will initialize next pass."
    exit 0
fi

if is_cli_skipped "gemini"; then
    log "gemini OUT_OF_USAGE — deferring progression."
    exit 0
fi

# Read state with jq.
if ! command -v jq >/dev/null 2>&1; then
    log "jq not installed — cannot parse state.json."
    exit 0
fi

ACTIVE=$(jq -r '.active // false' "$STATE_FILE")
ITER=$(jq -r '.current_iteration // 0' "$STATE_FILE")
MAX=$(jq -r '.max_iterations // 0' "$STATE_FILE")
PROMPT=$(jq -r '.original_prompt // ""' "$STATE_FILE")
PROMISE=$(jq -r '.completion_promise // ""' "$STATE_FILE")

if [ "$ACTIVE" != "true" ]; then
    log "Loop inactive. Watchdog handles restart."
    exit 0
fi
if [ "$MAX" -gt 0 ] && [ "$ITER" -ge "$MAX" ]; then
    log "Loop reached max ($ITER/$MAX). Marking inactive."
    jq '.active=false' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    exit 0
fi
if [ -z "$PROMPT" ]; then
    log "Empty original_prompt in state.json — cannot progress."
    exit 0
fi

cd "$REPRO_DIR" || exit 0
log "Advancing Ralph iteration $ITER → $((ITER+1)) of $MAX"

# Compose the iteration message — same shape the stop-hook would have used.
ITER_PROMPT="Ralph iteration $((ITER+1))/$MAX. Continue the loop. Original goal:
$PROMPT"
if [ -n "$PROMISE" ]; then
    ITER_PROMPT="$ITER_PROMPT

Completion promise: output <promise>$PROMISE</promise> when done."
fi

OUT=$(timeout 12m gemini "${DEVMIND_GEMINI_FLAGS[@]}" -p "$ITER_PROMPT" 2>&1)
RC=$?
echo "$OUT" >> "$LOG_FILE"

# Quota detection — set skip flag so next cycle defers.
check_output_for_quota "gemini" "$OUT" || {
    log "Quota signal detected — skip flag set, iteration NOT incremented."
    exit 0
}

if [ $RC -ne 0 ]; then
    log "Gemini exit=$RC (non-quota). Iteration NOT incremented — will retry next cron tick."
    exit 0
fi

# Detect completion-promise signal so the loop ends cleanly.
if [ -n "$PROMISE" ] && echo "$OUT" | grep -qF "<promise>$PROMISE</promise>"; then
    log "Promise fulfilled. Marking loop inactive."
    jq --arg p "$PROMISE" '.active=false | .completed_promise=$p' "$STATE_FILE" \
        > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    exit 0
fi

# Increment iteration.
jq '.current_iteration += 1 | .last_advance=now|todate' "$STATE_FILE" \
    > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
log "Iteration advanced successfully."
exit 0
