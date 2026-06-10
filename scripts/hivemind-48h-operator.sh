#!/usr/bin/env bash
# hivemind-48h-operator.sh — Autonomous 48h improvement loop
# Win condition: meaningful improvements across all ecosystem pillars
# Usage: bash hivemind-48h-operator.sh [--duration 48h] &
#
# Pillars driven: Revenue Hub, Pleiades Swarm, RYZ Language,
#                 Task Master, Ralph Loop, Engram memory
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)

set -uo pipefail

# ── Parse arguments ─────────────────────────────────────────────────────────
DURATION_ARG="${1:-}"
DURATION_SECS=172800  # 48h default

if [[ "$DURATION_ARG" == "--duration" && -n "${2:-}" ]]; then
    RAW="${2}"
    if [[ "$RAW" =~ ^([0-9]+)h$ ]]; then
        DURATION_SECS=$(( ${BASH_REMATCH[1]} * 3600 ))
    elif [[ "$RAW" =~ ^([0-9]+)m$ ]]; then
        DURATION_SECS=$(( ${BASH_REMATCH[1]} * 60 ))
    elif [[ "$RAW" =~ ^([0-9]+)$ ]]; then
        DURATION_SECS="$RAW"
    fi
fi

# ── Paths & config ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

GOVERNOR_SCRIPT="$SCRIPT_DIR/hivemind_governor.sh"
RALPH_GOALS_SCRIPT="/home/fixxia/ryz-build/scripts/ralph-goals.sh"
GGA_CYCLE_SCRIPT="/home/fixxia/ryz-build/scripts/gga-cycle.sh"
TASK_MASTER="/home/linuxbrew/.linuxbrew/bin/task-master"
TASKS_FILE="/workspaces/gentoo/.taskmaster/tasks/tasks.json"
RALPH_STATE="/home/fixxia/ryz-build/state/ralph.json"
REVENUE_LEDGER="/home/fixxia/revenue-hub/REVENUE_LEDGER.json"

LOG_DIR="/home/fixxia/lamp/logs"
STATE_DIR="/home/fixxia/lamp/state"
LOG_FILE="$LOG_DIR/operator-48h.log"
STATE_FILE="$STATE_DIR/operator-48h.json"
PILLAR_FILE="$STATE_DIR/pillar-health.json"

PID_FILE="/tmp/hivemind-48h-operator.pid"
LOCK_FILE="/tmp/hivemind-48h.lock"

CYCLE_INTERVAL=1800   # 30 minutes

# ── Ensure dirs ──────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR" "$STATE_DIR"

# ── Lockfile guard ───────────────────────────────────────────────────────────
if [[ -f "$LOCK_FILE" ]]; then
    EXISTING_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$EXISTING_PID" ]] && kill -0 "$EXISTING_PID" 2>/dev/null; then
        echo "[operator-48h] Already running (PID $EXISTING_PID). Exiting." >&2
        exit 1
    fi
fi
echo $$ > "$LOCK_FILE"
echo $$ > "$PID_FILE"

# ── Signal handling ──────────────────────────────────────────────────────────
_SLEEP_PID=""
_SHUTDOWN=0
_shutdown_clean() {
    _SHUTDOWN=1
    [[ -n "$_SLEEP_PID" ]] && kill "$_SLEEP_PID" 2>/dev/null || true
}
trap '_shutdown_clean' SIGTERM SIGINT

cleanup() {
    rm -f "$LOCK_FILE" "$PID_FILE"
}
trap 'cleanup' EXIT

# ── Logging ──────────────────────────────────────────────────────────────────
operator_log() {
    local msg="$1"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "[$ts] $msg" | tee -a "$LOG_FILE"
}

# ── State helpers ─────────────────────────────────────────────────────────────
START_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START_EPOCH=$(date +%s)
DEADLINE_EPOCH=$(( START_EPOCH + DURATION_SECS ))
DEADLINE_TS=$(date -u -d "@$DEADLINE_EPOCH" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
              python3 -c "import datetime; print(datetime.datetime.utcfromtimestamp($DEADLINE_EPOCH).strftime('%Y-%m-%dT%H:%M:%SZ'))")

CYCLE=0
TASKS_EXECUTED=0
TASKS_CREATED=0

write_state() {
    local status="${1:-running}"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    python3 -c "
import json
d = {
    'started': '$START_TS',
    'deadline': '$DEADLINE_TS',
    'duration_secs': $DURATION_SECS,
    'cycle': $CYCLE,
    'last_cycle': '$ts',
    'tasks_executed': $TASKS_EXECUTED,
    'tasks_created': $TASKS_CREATED,
    'status': '$status',
    'pid': $$
}
print(json.dumps(d, indent=2))
" > "$STATE_FILE" 2>/dev/null || true
}

# ── Pillar health check ───────────────────────────────────────────────────────
check_pillars() {
    # Revenue Hub
    local rev_last
    rev_last=$(python3 -c "
import json, sys
try:
    d = json.load(open('$REVENUE_LEDGER'))
    print(d.get('total_usd', 0))
except Exception:
    print(0)
" 2>/dev/null || echo "0")

    # RYZ tests
    local ryz_tests
    ryz_tests=$(cd /home/fixxia/ryz-build && \
        python3 bin/ryzc lang/test/test_markov.ryz 2>/dev/null | grep -c "PASS" || echo "0")

    # Pleiades
    local pleiades_alive
    pleiades_alive=$(pgrep -c -f "pleiades\|maia\|taygete" 2>/dev/null || echo "0")

    # Ralph tick
    local ralph_tick
    ralph_tick=$(python3 -c "
import json, sys
try:
    d = json.load(open('$RALPH_STATE'))
    print(d.get('tick', 0))
except Exception:
    print(0)
" 2>/dev/null || echo "0")

    # Task Master pending count
    local tasks_pending
    tasks_pending=$(python3 -c "
import json, sys
try:
    d = json.load(open('$TASKS_FILE'))
    tasks = d.get('master', {}).get('tasks', d.get('tasks', []))
    print(sum(1 for t in tasks if t.get('status') == 'pending'))
except Exception:
    print(-1)
" 2>/dev/null || echo "-1")

    python3 -c "
import json
d = {
    'revenue_usd': $rev_last,
    'ryz_tests_pass': $ryz_tests,
    'pleiades_procs': $pleiades_alive,
    'ralph_tick': $ralph_tick,
    'tasks_pending': $tasks_pending
}
print(json.dumps(d, indent=2))
" > "$PILLAR_FILE" 2>/dev/null || true

    operator_log "PILLARS revenue=${rev_last}usd ryz_tests=${ryz_tests} ralph_tick=${ralph_tick} pending_tasks=${tasks_pending}"
}

# ── Task executor ─────────────────────────────────────────────────────────────
execute_next_task() {
    local task_json
    task_json=$("$TASK_MASTER" list --status pending --format json 2>/dev/null | \
        python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    tasks = d.get('master', {}).get('tasks', d.get('tasks', []))
    pending = [t for t in tasks if t.get('status') == 'pending']
    if not pending:
        print('NONE')
        sys.exit(0)
    pmap = {'high': 0, 'medium': 1, 'low': 2}
    pending.sort(key=lambda t: pmap.get(t.get('priority', 'medium'), 1))
    t = pending[0]
    print(json.dumps({
        'id': t['id'],
        'title': t['title'],
        'description': t.get('description', ''),
        'details': t.get('details', '')
    }))
except Exception as e:
    print('NONE')
" 2>/dev/null || echo "NONE")

    [[ "$task_json" == "NONE" ]] && { operator_log "TASK_EXECUTOR no pending tasks"; return 0; }
    [[ -z "$task_json" ]] && { operator_log "TASK_EXECUTOR empty result from task-master"; return 0; }

    local task_id title description details
    task_id=$(echo "$task_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
    title=$(echo "$task_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])" 2>/dev/null || echo "unknown")
    description=$(echo "$task_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description',''))" 2>/dev/null || echo "")
    details=$(echo "$task_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('details',''))" 2>/dev/null || echo "")

    [[ -z "$task_id" ]] && { operator_log "TASK_EXECUTOR could not parse task id"; return 0; }

    operator_log "TASK_START id=$task_id title=$title"

    # Mark in-progress
    "$TASK_MASTER" set-status --id="$task_id" --status=in_progress 2>/dev/null || true

    # Build execution prompt
    local prompt
    prompt="You are an autonomous executor in the Fixxia AI ecosystem.
Execute this task completely and independently. Make real changes.

Task: $title
Description: $description
Details: $details

Working directory: /home/fixxia/ryz-build
Ecosystem context: WSL2 Ubuntu 26.04, RYZ language project, autonomous agent stack.
Available tools: bash, python3, git, task-master, ryzc (at /home/fixxia/ryz-build/bin/ryzc).

Rules:
- Make concrete, real changes (edit files, run tests, fix bugs, etc.)
- Do NOT just plan or describe — actually do the work
- When fully done, your final output line MUST be: TASK_COMPLETE: <one-line summary>
- If you cannot complete the task, output: TASK_BLOCKED: <reason>"

    local result=""

    if ! is_cli_skipped "gemini"; then
        operator_log "TASK_EXEC using gemini for id=$task_id"
        result=$(timeout 270s gemini-clean --yolo --skip-trust -p "$prompt" 2>&1 || echo "GEMINI_TIMEOUT")
        check_output_for_quota "gemini" "$result" || true
    elif ! is_cli_skipped "claude"; then
        operator_log "TASK_EXEC falling back to claude for id=$task_id"
        result=$(timeout 600s claude --strict-mcp-config --setting-sources= -p "$prompt" 2>&1 || echo "CLAUDE_TIMEOUT")
        check_output_for_quota "claude" "$result" || true
    else
        operator_log "TASK_SKIPPED id=$task_id — all CLIs out of usage"
        "$TASK_MASTER" set-status --id="$task_id" --status=pending 2>/dev/null || true
        return 0
    fi

    # Append task log
    echo "=== TASK $task_id ($title) ===" >> "$LOG_DIR/task-executor.log"
    echo "$result" >> "$LOG_DIR/task-executor.log"
    echo "===" >> "$LOG_DIR/task-executor.log"

    if echo "$result" | grep -q "TASK_COMPLETE"; then
        "$TASK_MASTER" set-status --id="$task_id" --status=done 2>/dev/null || true
        TASKS_EXECUTED=$(( TASKS_EXECUTED + 1 ))
        local summary
        summary=$(echo "$result" | grep "TASK_COMPLETE" | head -1)
        operator_log "TASK_DONE id=$task_id $summary"
    else
        # Revert to pending so it can be retried next cycle
        "$TASK_MASTER" set-status --id="$task_id" --status=pending 2>/dev/null || true
        operator_log "TASK_DEFERRED id=$task_id (no TASK_COMPLETE signal)"
    fi
}

# ── Goal synthesis ────────────────────────────────────────────────────────────
run_goal_synthesis() {
    if is_cli_skipped "gemini"; then
        operator_log "GOAL_SYNTHESIS skipped — gemini out of usage"
        return 0
    fi
    operator_log "GOAL_SYNTHESIS starting ralph-goals"
    local before_count
    before_count=$(python3 -c "
import json
try:
    d = json.load(open('$TASKS_FILE'))
    tasks = d.get('master', {}).get('tasks', d.get('tasks', []))
    print(sum(1 for t in tasks if t.get('status') == 'pending'))
except Exception:
    print(0)
" 2>/dev/null || echo "0")

    timeout 300s bash "$RALPH_GOALS_SCRIPT" >> "$LOG_DIR/ralph-goals.log" 2>&1 || \
        operator_log "GOAL_SYNTHESIS ralph-goals returned non-zero (may be normal)"

    local after_count
    after_count=$(python3 -c "
import json
try:
    d = json.load(open('$TASKS_FILE'))
    tasks = d.get('master', {}).get('tasks', d.get('tasks', []))
    print(sum(1 for t in tasks if t.get('status') == 'pending'))
except Exception:
    print(0)
" 2>/dev/null || echo "0")

    local new_tasks=$(( after_count - before_count ))
    if [[ $new_tasks -gt 0 ]]; then
        TASKS_CREATED=$(( TASKS_CREATED + new_tasks ))
        operator_log "GOAL_SYNTHESIS created $new_tasks new tasks (total pending: $after_count)"
    else
        operator_log "GOAL_SYNTHESIS complete (no new pending tasks added)"
    fi
}

# ── All-CLIs-skipped check ────────────────────────────────────────────────────
all_clis_skipped() {
    local any_available=false
    for _cli in gemini claude codex opencode; do
        is_cli_skipped "$_cli" || { any_available=true; break; }
    done
    [[ "$any_available" == "false" ]]
}

# ── Main loop ─────────────────────────────────────────────────────────────────
operator_log "OPERATOR_START duration=${DURATION_SECS}s deadline=$DEADLINE_TS pid=$$"
write_state "running"

while true; do
    # ── Exit condition: elapsed time ─────────────────────────────────────────
    NOW_EPOCH=$(date +%s)
    if [[ $NOW_EPOCH -ge $DEADLINE_EPOCH ]]; then
        operator_log "OPERATOR_COMPLETE 48h deadline reached after $CYCLE cycles"
        write_state "completed"
        exit 0
    fi

    # ── Exit condition: user-requested shutdown ──────────────────────────────
    if [[ $_SHUTDOWN -eq 1 ]]; then
        operator_log "OPERATOR_INTERRUPTED SIGTERM/SIGINT received at cycle $CYCLE"
        write_state "interrupted"
        exit 0
    fi

    CYCLE=$(( CYCLE + 1 ))
    operator_log "CYCLE_START cycle=$CYCLE"

    # ── All-CLIs exhausted handling ─────────────────────────────────────────
    if all_clis_skipped; then
        operator_log "QUOTA_EXHAUSTED all CLIs skipped — sleeping 1h before retry"
        write_state "quota_exhausted"
        sleep 3600 & _SLEEP_PID=$!; wait $_SLEEP_PID 2>/dev/null; _SLEEP_PID=""
        continue
    fi

    # ── Step 1: Write heartbeat ──────────────────────────────────────────────
    write_state "running"

    # ── Step 2: Full governor cycle ──────────────────────────────────────────
    operator_log "GOVERNOR_START cycle=$CYCLE"
    if [[ -f "$GOVERNOR_SCRIPT" ]]; then
        timeout 300s bash "$GOVERNOR_SCRIPT" >> "$LOG_DIR/governor-48h.log" 2>&1 || \
            operator_log "GOVERNOR returned non-zero (continuing)"
    else
        operator_log "GOVERNOR_MISSING script not found: $GOVERNOR_SCRIPT"
    fi
    operator_log "GOVERNOR_DONE cycle=$CYCLE"

    # ── Step 3: Task executor ────────────────────────────────────────────────
    operator_log "TASK_EXECUTOR_START cycle=$CYCLE"
    if [[ -f "$TASK_MASTER" ]]; then
        execute_next_task
    else
        operator_log "TASK_MASTER_MISSING $TASK_MASTER not found"
    fi

    # ── Step 4: Goal synthesis (every 4 cycles = every 2h) ──────────────────
    if (( CYCLE % 4 == 0 )); then
        run_goal_synthesis
    fi

    # ── Step 5: Pillar health check ──────────────────────────────────────────
    check_pillars

    # ── Step 6: Cycle summary ────────────────────────────────────────────────
    ELAPSED=$(( $(date +%s) - START_EPOCH ))
    REMAINING=$(( DEADLINE_EPOCH - $(date +%s) ))
    ELAPSED_H=$(( ELAPSED / 3600 ))
    REMAINING_H=$(( REMAINING / 3600 ))
    operator_log "CYCLE_DONE cycle=$CYCLE elapsed=${ELAPSED_H}h remaining=${REMAINING_H}h tasks_executed=$TASKS_EXECUTED tasks_created=$TASKS_CREATED"
    write_state "running"

    # ── Sleep until next cycle (interruptible) ───────────────────────────────
    if [[ $_SHUTDOWN -eq 0 ]]; then
        operator_log "CYCLE_SLEEP ${CYCLE_INTERVAL}s until next cycle"
        sleep "$CYCLE_INTERVAL" & _SLEEP_PID=$!; wait $_SLEEP_PID 2>/dev/null; _SLEEP_PID=""
    fi
done
