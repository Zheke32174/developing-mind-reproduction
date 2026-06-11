#!/usr/bin/env bash
# Developing Mind — Hivemind Governor (v6: Hard Timeout Gates + Adaptive Scheduling)
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Governance Logic
#
# ARCHITECTURE: Every non-interactive AI run has a hard timeout gate.
# Total wall-clock budget = HIVEMIND_BUDGET_SECS (default 270s = 4.5 min).
# Each task gets DEVMIND_CLI_TIMEOUT (default 90s) or 300s for long tasks.
# On budget exhaustion, remaining tasks defer to next cron run.
# After each cycle, writes an end-log summary that the next run reads to
# prioritize or skip tasks based on last outcome.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

LOCK_FILE="/tmp/hivemind.lock"
MEMORY_THRESHOLD=800
HIVEMIND_BUDGET_SECS="${HIVEMIND_BUDGET_SECS:-270}"  # 4.5 min total wall clock
CYCLE_START=$(date +%s)
SESSION_LOG="$DEVMIND_LOG_DIR/hivemind_session_$(date +%Y%m%dT%H%M%S).log"
LAST_SESSION_LOG="$DEVMIND_STATE_DIR/hivemind_last_session.log"
mkdir -p "$(dirname "$SESSION_LOG")" 2>/dev/null || true

session_log() {
    local msg="[hivemind] $(date -u +%Y-%m-%dT%H:%M:%SZ) $*"
    echo "$msg" >> "$SESSION_LOG"   # per-session log (for adaptive scheduling next run)
    echo "$msg"                     # stdout → cron captures to hivemind.log (no double-write)
}

# Budget check: returns 0 if we still have budget, 1 if exhausted
budget_ok() {
    local elapsed=$(( $(date +%s) - CYCLE_START ))
    if [[ $elapsed -ge $HIVEMIND_BUDGET_SECS ]]; then
        session_log "⏱️  BUDGET EXHAUSTED (${elapsed}s ≥ ${HIVEMIND_BUDGET_SECS}s) — deferring remaining tasks."
        return 1
    fi
    return 0
}

# Remaining budget in seconds (minimum 10s)
budget_remaining() {
    local elapsed=$(( $(date +%s) - CYCLE_START ))
    local rem=$(( HIVEMIND_BUDGET_SECS - elapsed ))
    echo $(( rem < 10 ? 10 : rem ))
}

# Adaptive: read last session outcome to decide task priority
last_task_failed() {
    local task="$1"
    [[ -f "$LAST_SESSION_LOG" ]] && grep -q "FAIL:$task" "$LAST_SESSION_LOG" 2>/dev/null
}
last_task_timed_out() {
    local task="$1"
    [[ -f "$LAST_SESSION_LOG" ]] && grep -q "TIMEOUT:$task" "$LAST_SESSION_LOG" 2>/dev/null
}

# Gated safe_run: wraps safe_run_cli with budget enforcement and session logging
gated_run() {
    local task_name="$1"; shift
    local log_file="$1"; shift
    if ! budget_ok; then
        session_log "SKIP:$task_name (budget exhausted)"
        return 0
    fi
    # Cap per-task timeout to remaining budget
    local cap
    cap=$(budget_remaining)
    local prev_timeout="${DEVMIND_CLI_TIMEOUT:-90}"
    export DEVMIND_CLI_TIMEOUT=$(( cap < prev_timeout ? cap : prev_timeout ))
    session_log "START:$task_name (budget_left=${cap}s, timeout=${DEVMIND_CLI_TIMEOUT}s)"
    local t0 t1 rc
    t0=$(date +%s)
    safe_run_cli "$task_name" "$log_file" "$@"
    rc=$?
    t1=$(date +%s)
    export DEVMIND_CLI_TIMEOUT="$prev_timeout"
    local elapsed=$(( t1 - t0 ))
    if [[ $rc -eq 0 ]]; then
        session_log "OK:$task_name (${elapsed}s)"
    else
        session_log "FAIL:$task_name rc=$rc (${elapsed}s)"
    fi
    return $rc
}

# run_direct <task_name> <log_file> [max_timeout] <cmd...> — for non-AI tasks (bash, python3).
# Does budget enforcement and session logging WITHOUT the skip/quota mechanism.
# Optional max_timeout (integer, seconds) overrides the default 180s cap.
# safe_run_cli must NOT be used for bash/python3: a timeout would create skip_bash
# or skip_python3 and block ALL non-AI tasks for 6h.
run_direct() {
    local task_name="$1"; shift
    local log_file="$1"; shift
    # Optional numeric max_timeout as 3rd arg
    local max_tout=180
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        max_tout="$1"; shift
    fi
    if ! budget_ok; then
        session_log "SKIP:$task_name (budget exhausted)"
        return 0
    fi
    local cap
    cap=$(budget_remaining)
    local tout=$(( cap < max_tout ? cap : max_tout ))
    session_log "START:$task_name (budget_left=${cap}s, timeout=${tout}s)"
    local t0 t1 rc
    t0=$(date +%s)
    timeout "${tout}s" "$@" >> "$log_file" 2>&1
    rc=$?
    t1=$(date +%s)
    local elapsed=$(( t1 - t0 ))
    if [[ $rc -eq 124 ]]; then
        session_log "TIMEOUT:$task_name (${elapsed}s) — not skipped, will retry next cycle"
        python3 "$SCRIPT_DIR/send_swarm_alert.py" "Governor Timeout" "{\"task\": \"$task_name\", \"elapsed\": $elapsed}" "high"
        return 0
    elif [[ $rc -eq 0 ]]; then
        session_log "OK:$task_name (${elapsed}s)"
    else
        session_log "FAIL:$task_name rc=$rc (${elapsed}s)"
    fi
    return $rc
}

# ── Lock ──────────────────────────────────────────────────────────────────────
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        session_log "🚨 Governor already running (PID $PID). Exiting."
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; cp "$SESSION_LOG" "$LAST_SESSION_LOG" 2>/dev/null || true' EXIT

# ── Pre-flight ─────────────────────────────────────────────────────────────────
ALL_SKIPPED=true
for _cli in gemini claude codex opencode; do
    is_cli_skipped "$_cli" || { ALL_SKIPPED=false; break; }
done
if $ALL_SKIPPED; then
    session_log "💤 All CLIs out of usage. Skipping cycle."
    exit 0
fi

FREE_MEM=$(free -m | awk '/^Mem:/ {print $4}')
if [ "$FREE_MEM" -lt "$MEMORY_THRESHOLD" ]; then
    session_log "⚠️ Low memory ($FREE_MEM MB). Dropping caches..."
    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
fi

session_log "🚀 Hivemind cycle start (budget=${HIVEMIND_BUDGET_SECS}s)"

# ── Probes (30s each, version checks only — no quota burn) ────────────────────
probe_cli() {
    local cli="$1" probe_cmd="$2"
    is_cli_skipped "$cli" && return 0
    local out
    out=$(timeout 30s $probe_cmd 2>&1) || true
    check_output_for_quota "$cli" "$out" || true
}
probe_cli "codex"    "codex --version"
probe_cli "opencode" "opencode --version"
probe_cli "claude"   "claude --version"
probe_cli "gemini"   "gemini-clean --version"

# ── Task queue (ordered by priority; budget gates each one) ───────────────────
# Adaptive: tasks that timed out last session are deprioritized (skipped if budget < 60s left)

# 1. Substrate sync (bash only, no AI quota — use run_direct to avoid skip_bash)
if ! last_task_timed_out "substrate-sync" || [[ $(budget_remaining) -gt 30 ]]; then
    run_direct "substrate-sync" "$DEVMIND_LOG_DIR/substrate_sync.log" \
        bash "$DEVMIND_REPRO_DIR/scripts/substrate-sync.sh"
else
    session_log "SKIP:substrate-sync (timed out last session + low budget)"
fi

# 2. Daily governance (python, no AI quota — use run_direct to avoid skip_python3)
run_direct "daily-governance" "$DEVMIND_LOG_DIR/daily_governance.log" \
    python3 "$DEVMIND_REPRO_DIR/scripts/daily_governance.py"

# 3. GGA repo audit (quota-aware, 90s gate — skip if timed out last 2 sessions)
if ! last_task_timed_out "gga" || [[ $(budget_remaining) -gt 120 ]]; then
    budget_ok && gated_run "gga" "$DEVMIND_LOG_DIR/gga.log" \
        bash "/home/fixxia/ryz-build/scripts/gga-cycle.sh"
else
    session_log "SKIP:gga (timed out last session + insufficient budget)"
fi

# 4. Ralph goal synthesis (Gemini, 90s gate — skipped if quota exhausted or recent timeout)
if budget_ok && ! is_cli_skipped "gemini"; then
    if last_task_timed_out "ralph-goals" && [[ $(budget_remaining) -lt 150 ]]; then
        session_log "SKIP:ralph-goals (timed out last session, deferring to conserve budget)"
    else
        gated_run "ralph-goals" "$DEVMIND_LOG_DIR/ralph-goals.log" \
            bash "/home/fixxia/ryz-build/scripts/ralph-goals.sh"
    fi
else
    session_log "SKIP:ralph-goals (gemini OUT_OF_USAGE or budget exhausted)"
fi

# 5. Conductor suite (Gemini, long task — skipped if quota exhausted)
if budget_ok && ! is_cli_skipped "gemini"; then
    if last_task_timed_out "gemini" && [[ $(budget_remaining) -lt 200 ]]; then
        session_log "SKIP:conductor (timed out last session, deferring to conserve budget)"
    else
        export DEVMIND_TASK_LONG=1  # Allow up to 300s for this one
        gated_run "gemini" "$DEVMIND_LOG_DIR/conductor.log" \
            bash "$DEVMIND_REPRO_DIR/scripts/conductor_suite_orchestrator.sh"
        unset DEVMIND_TASK_LONG
    fi
else
    session_log "SKIP:conductor (gemini OUT_OF_USAGE or budget exhausted)"
fi

# 6. Codex Judge (lamp review — skipped if quota exhausted)
if budget_ok && ! is_cli_skipped "codex"; then
    gated_run "codex-judge" "$DEVMIND_LOG_DIR/codex-judge.log" \
        bash "/home/fixxia/lamp/ai-scaffold/cron-run.sh" force-judge
else
    session_log "SKIP:codex-judge (codex OUT_OF_USAGE or budget exhausted)"
fi

# ── End-of-cycle summary ──────────────────────────────────────────────────────
elapsed_total=$(( $(date +%s) - CYCLE_START ))
session_log "✅ Hivemind cycle complete (total=${elapsed_total}s / budget=${HIVEMIND_BUDGET_SECS}s)"
D_BUDGET_SECS}s)"
