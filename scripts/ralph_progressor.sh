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

export PATH="/home/fixxia/.local/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=devmind-env.sh
source "$SCRIPT_DIR/devmind-env.sh"

# Ingest most recent repo state before processing (amnesia prevention)
if [[ -x "$SCRIPT_DIR/substrate-sync.sh" ]]; then
    timeout 60s bash "$SCRIPT_DIR/substrate-sync.sh" >/dev/null 2>&1 || true
fi

REPRO_DIR="${DEVMIND_REPRO_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
STATE_FILE="${DEVMIND_RALPH_STATE:-$REPRO_DIR/.gemini/ralph/state.json}"
LOG_FILE="$DEVMIND_LOG_DIR/ralph_progressor.log"
LOCK_FILE="/tmp/ralph_progressor.lock"

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$STATE_FILE")" 2>/dev/null || true

log() {
    local msg="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
    echo "$msg" >> "$LOG_FILE"
    [[ -t 1 ]] && echo "$msg" || true
}

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

# Operator pause switch (set via Telegram 'pause'/'resume'). Honored = real control.
if [ -f /home/fixxia/lamp/state/hive.paused ]; then
    log "hive.paused present — mind loop halted by operator. Skipping iteration."
    exit 0
fi

if [ ! -f "$STATE_FILE" ]; then
    log "No state.json — watchdog will initialize next pass."
    exit 0
fi

SELECTED_AGENT=$(select_agent)
if [ -z "$SELECTED_AGENT" ]; then
    log "Entire agent tier OUT_OF_USAGE (gemini→opencode→codex→copilot→claude) — deferring progression."
    exit 0
fi
log "Tier head available: $SELECTED_AGENT (failover chain active)."

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
# A5 gate: a concrete shell check that MUST pass for the <promise> to be honored.
# When set in state.json, the promise is ignored unless promise_check exits 0 — this
# kills "promise-on-iter-0" (an agent claiming done with no checkable artifact).
PROMISE_CHECK=$(jq -r '.promise_check // ""' "$STATE_FILE")
# A6 work-locus: per-goal working directory. Bounty goals run in the bounty-pipeline,
# NOT the devmind repo, so their commands (pool-triage.sh, jq queue/*.json) resolve.
WORK_DIR=$(jq -r '.work_dir // ""' "$STATE_FILE")

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

# A6: honor per-goal work_dir when present + valid; else default to the devmind repo.
RUN_DIR="$REPRO_DIR"
if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    RUN_DIR="$WORK_DIR"
    log "Per-goal work_dir honored: $RUN_DIR"
elif [ -n "$WORK_DIR" ]; then
    log "work_dir '$WORK_DIR' not a directory — falling back to $REPRO_DIR"
fi
cd "$RUN_DIR" || exit 0
log "Advancing Ralph iteration $ITER → $((ITER+1)) of $MAX (cwd=$RUN_DIR)"

# Compose the iteration message — same shape the stop-hook would have used.
ITER_PROMPT="Ralph iteration $((ITER+1))/$MAX. Continue the loop. Original goal:
$PROMPT"
if [ -n "$PROMISE" ]; then
    ITER_PROMPT="$ITER_PROMPT

Completion promise: output <promise>$PROMISE</promise> when done."
fi

# Dispatch through the cost-tiered failover router (gemini→opencode→codex→
# copilot→claude). Each agent's quota is auto-detected; an exhausted agent is
# skip-flagged and the next tier is tried — the loop only defers if ALL are out.
DEVMIND_CLI_TIMEOUT=270 run_with_failover "$ITER_PROMPT" "$LOG_FILE"
RC=$?
if [ $RC -ne 0 ]; then
    log "All tier agents unavailable this cycle — iteration NOT incremented, will retry next tick."
    exit 0
fi
OUT="$DEVMIND_LAST_OUTPUT"
log "Iteration executed by agent: ${DEVMIND_LAST_AGENT:-unknown}."

# Detect completion-promise signal so the loop ends cleanly.
if [ -n "$PROMISE" ] && echo "$OUT" | grep -qF "<promise>$PROMISE</promise>"; then
    # A5 PROMISE GATE: a <promise> is honored ONLY if a concrete checkable artifact
    # exists. If promise_check is set, it MUST exit 0; otherwise the promise is a
    # claim with no proof (the classic promise-on-iter-0) and we REJECT it — the
    # iteration still counts but the loop is NOT marked done.
    if [ -n "$PROMISE_CHECK" ]; then
        if ( cd "$RUN_DIR" && bash -c "$PROMISE_CHECK" >/dev/null 2>&1 ); then
            log "Promise fulfilled AND artifact check passed ($PROMISE_CHECK). Marking loop inactive."
            jq --arg p "$PROMISE" '.active=false | .completed_promise=$p' "$STATE_FILE" \
                > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
            exit 0
        else
            log "Promise CLAIMED but artifact check FAILED ($PROMISE_CHECK) — rejecting promise, loop continues."
        fi
    else
        log "Promise signalled but no promise_check defined — honoring (legacy path). Set .promise_check to gate."
        jq --arg p "$PROMISE" '.active=false | .completed_promise=$p' "$STATE_FILE" \
            > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        exit 0
    fi
fi

# Increment iteration.
jq '.current_iteration += 1 | .last_advance=now|todate' "$STATE_FILE" \
    > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
log "Iteration advanced successfully."
exit 0
