#!/usr/bin/env bash
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Environment Resolution
# Autonomy-safe: skip files auto-expire after a TTL so the system self-heals
# without requiring an operator to delete them.
export PATH="/home/fixxia/.local/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

DEVMIND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
DEVMIND_REPRO_DIR="$(cd "$DEVMIND_SCRIPT_DIR/.." 2>/dev/null && pwd)"
DEVMIND_STATE_DIR="$DEVMIND_REPRO_DIR/scripts"
DEVMIND_QUOTA_STATE="$DEVMIND_STATE_DIR/quota_state.txt"
DEVMIND_LOG_DIR="$HOME/lamp/logs"
DEVMIND_WIN_HOME="${DEVMIND_WIN_HOME:-/mnt/c/Users/Fixxia}"
DEVMIND_GEMINI_DIR="$DEVMIND_WIN_HOME/.gemini"
DEVMIND_GGA_PATH="$DEVMIND_WIN_HOME/scripts/gga_repo/bin/gga"
DEVMIND_BACKUP_DIR="$DEVMIND_STATE_DIR/backups"

# Ensure directories exist
mkdir -p "$DEVMIND_LOG_DIR" "$DEVMIND_STATE_DIR" "$DEVMIND_BACKUP_DIR"

# Skip-file TTL in seconds. Default 6h — after this, the next cycle re-probes
# the CLI and re-enables it if quota has reset. Override with DEVMIND_SKIP_TTL.
DEVMIND_SKIP_TTL="${DEVMIND_SKIP_TTL:-21600}"

# Non-interactive flags applied to every gemini call from this stack.
DEVMIND_GEMINI_FLAGS=(--yolo --skip-trust)

export DEVMIND_REPRO_DIR DEVMIND_STATE_DIR DEVMIND_QUOTA_STATE DEVMIND_LOG_DIR \
       DEVMIND_GEMINI_DIR DEVMIND_GGA_PATH DEVMIND_SKIP_TTL DEVMIND_BACKUP_DIR DEVMIND_WIN_HOME

# Quota patterns: CLI is out of paid usage (needs longer cooldown but NOT permanent).
DEVMIND_OUT_OF_USAGE_PATTERNS="out of usage|usage limit reached|account.*suspended|no.*credits|billing.*required|subscription.*expired|access.*revoked"
# Rate-limit patterns: temporary, shorter cooldown.
DEVMIND_RATE_LIMIT_PATTERNS="429|too many requests|quota exceeded|exhausted|rate.?limit|session limit"

# _skip_file_age <cli>   — seconds since the skip file was written, or -1 if absent.
_skip_file_age() {
    local f="$DEVMIND_STATE_DIR/skip_$1"
    [[ -f "$f" ]] || { echo "-1"; return; }
    local now mtime
    now=$(date +%s)
    mtime=$(stat -c %Y "$f" 2>/dev/null || echo "$now")
    echo $((now - mtime))
}

# is_cli_skipped <cli> — returns 0 (true) ONLY if a non-expired skip file exists.
# TTL is read from the skip file itself (ttl=Ns field) if present, else DEVMIND_SKIP_TTL.
# Expired skip files are auto-removed so the next cycle re-probes the CLI.
is_cli_skipped() {
    local cli="$1"
    local age
    age=$(_skip_file_age "$cli")
    if [[ "$age" -lt 0 ]]; then
        return 1
    fi
    # Read per-file TTL from the skip file content (ttl=<N>s)
    local effective_ttl="$DEVMIND_SKIP_TTL"
    local file_ttl
    file_ttl=$(grep -oP 'ttl=\K[0-9]+' "$DEVMIND_STATE_DIR/skip_${cli}" 2>/dev/null || echo "")
    if [[ -n "$file_ttl" ]]; then
        effective_ttl="$file_ttl"
    fi
    if [[ "$age" -ge "$effective_ttl" ]]; then
        echo "[devmind] ⏰ skip_${cli} expired (age ${age}s ≥ TTL ${effective_ttl}s) — auto-clearing for re-probe."
        rm -f "$DEVMIND_STATE_DIR/skip_${cli}"
        return 1
    fi
    return 0
}

# mark_cli_skipped <cli> [reason]
mark_cli_skipped() {
    local cli="$1"
    local reason="${2:-out-of-usage}"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) reason=$reason ttl=${DEVMIND_SKIP_TTL}s" \
        > "$DEVMIND_STATE_DIR/skip_${cli}"
    echo "[devmind] ⛔ $cli marked OUT_OF_USAGE — will auto-re-probe in ${DEVMIND_SKIP_TTL}s."
}

# clear_cli_skip <cli> — explicit recovery, e.g. when a probe succeeds.
clear_cli_skip() {
    local cli="$1"
    rm -f "$DEVMIND_STATE_DIR/skip_${cli}" 2>/dev/null && \
        echo "[devmind] ✅ $cli recovered — skip flag cleared."
}

# check_output_for_quota <cli> <output>
check_output_for_quota() {
    local cli="$1"
    local output="$2"
    if echo "$output" | grep -iqE "$DEVMIND_OUT_OF_USAGE_PATTERNS"; then
        mark_cli_skipped "$cli" "out-of-usage-detected"
        return 1
    fi
    if echo "$output" | grep -iqE "$DEVMIND_RATE_LIMIT_PATTERNS"; then
        echo "[devmind] ⚠️  $cli rate-limited. Setting 12h cooldown."
        date +%s > "$DEVMIND_QUOTA_STATE"
        return 1
    fi
    return 0
}

# safe_run_cli <cli> <log> <cmd...> — captures output, applies quota detection.
safe_run_cli() {
    local cli="$1"
    local log_file="$2"
    shift 2
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
    if is_cli_skipped "$cli"; then
        echo "[devmind] ⏭️  $cli is marked OUT_OF_USAGE. Skipping." | tee -a "$log_file"
        return 0
    fi
    # Hard timeout gate: 90s for small tasks, 300s for long tasks.
    # DEVMIND_CLI_TIMEOUT overrides the default (90s).
    # DEVMIND_CLI_TIMEOUT_LONG (300s) is used when cli name ends in -long or when
    # the caller exports DEVMIND_TASK_LONG=1 before calling safe_run_cli.
    local base_timeout="${DEVMIND_CLI_TIMEOUT:-90}"
    if [[ "${DEVMIND_TASK_LONG:-0}" == "1" ]]; then
        base_timeout="${DEVMIND_CLI_TIMEOUT_LONG:-300}"
    fi
    local output rc
    output=$(timeout "${base_timeout}s" "$@" 2>&1)
    rc=$?
    if [[ $rc -eq 124 ]]; then
        echo "[devmind] ⏱️  $cli TIMED OUT after ${base_timeout}s — 10min cooldown (slow, not quota)." | tee -a "$log_file"
        DEVMIND_SKIP_TTL=600 mark_cli_skipped "$cli" "timeout-gate-${base_timeout}s" 2>/dev/null || true
        return 0
    fi
    echo "$output" | tee -a "$log_file"
    if ! check_output_for_quota "$cli" "$output"; then
        return 1
    fi
    return $rc
}

# probe_cli_live <cli>
# A real, lightweight, non-quota-burning probe that confirms the CLI is reachable
# AND that auth is valid. Each CLI gets a probe known to fail fast on quota.
probe_cli_live() {
    local cli="$1"
    if is_cli_skipped "$cli"; then
        echo "[devmind] ⏭️  $cli already skipped (within TTL). Probe deferred."
        return 1
    fi
    local out rc
    case "$cli" in
        gemini)
            out=$(timeout 45s gemini-clean "${DEVMIND_GEMINI_FLAGS[@]}" -p "ok" 2>&1)
            rc=$?
            ;;
        codex)
            out=$(timeout 45s codex exec --skip-git-repo-check "echo ok" 2>&1)
            rc=$?
            ;;
        claude)
            out=$(timeout 45s claude --strict-mcp-config --setting-sources= -p "ok" 2>&1)
            rc=$?
            ;;
        opencode)
            out=$(timeout 30s opencode --version 2>&1)
            rc=$?
            ;;
        *)
            out=$(timeout 30s "$cli" --version 2>&1)
            rc=$?
            ;;
    esac
    if ! check_output_for_quota "$cli" "$out"; then
        echo "[devmind] ⚠️  $cli probe surfaced quota signal — will skip this cycle."
        return 1
    fi
    if [[ $rc -ne 0 ]]; then
        echo "[devmind] ⚠️  $cli probe failed (rc=$rc) without quota signal — soft-skip this cycle."
        return 1
    fi
    # If we got here, the CLI is healthy — clear any lingering skip flag.
    clear_cli_skip "$cli" >/dev/null 2>&1 || true
    return 0
}

# ────────────────────────────────────────────────────────────────────────────
# TIER ROUTER — cost-ordered failover across the agent fleet.
# Without this, callers hard-coded to one CLI just defer when it is OUT_OF_USAGE.
# Operator cost tiering: gemini (primary/free) > opencode (free) > codex (sometimes)
#   > copilot (limited) > claude (very limited last resort).
# hermes is a LOCAL bash validator (not a prompt executor) — it runs on its own
# cron and is intentionally NOT in the prompt tier.
# Override the order/set with DEVMIND_AGENT_TIER_OVERRIDE="gemini opencode ...".
# ────────────────────────────────────────────────────────────────────────────
# Named task-type tier presets (operator). Use via:
#   DEVMIND_AGENT_TIER_OVERRIDE="$(devmind_tier plan)" run_with_failover "$PROMPT"
#   or  DEVMIND_AGENT_TIER_OVERRIDE="$DEVMIND_TIER_PLAN" ...
# DEFAULT/IMPORTANT: cost-ordered, claude-code + copilot as last-resort fallbacks so important
#   tasks almost never die when one CLI is out-of-usage.
# PLAN: brainstorming / planning / blueprint-greenlight — codex PRIMARY, gemini + claude fallbacks.
DEVMIND_TIER_DEFAULT="gemini opencode codex copilot claude"
DEVMIND_TIER_IMPORTANT="gemini opencode codex copilot claude"
DEVMIND_TIER_PLAN="codex gemini claude"
# devmind_tier <type> — echo the tier for a task type (default|important|plan|brainstorm|blueprint).
devmind_tier() {
    case "$1" in
        plan|planning|brainstorm|brainstorming|blueprint|greenlight|design) echo "$DEVMIND_TIER_PLAN";;
        important|critical) echo "$DEVMIND_TIER_IMPORTANT";;
        *) echo "$DEVMIND_TIER_DEFAULT";;
    esac
}
DEVMIND_AGENT_TIER=(${DEVMIND_AGENT_TIER_OVERRIDE:-gemini opencode codex copilot claude})

# Set by run_agent so callers can inspect the winning agent's output (e.g. for
# completion-promise detection) without re-capturing stdout.
DEVMIND_LAST_OUTPUT=""
DEVMIND_LAST_AGENT=""

# _agent_bin <cli> — map a tier name to the executable that must exist on PATH.
_agent_bin() { [[ "$1" == gemini ]] && echo "gemini-clean" || echo "$1"; }

# select_agent — echo the first tier agent that is installed AND not skip-flagged.
# Returns 0 + prints the cli name, or 1 if the whole tier is exhausted. No quota burn.
select_agent() {
    local cli
    for cli in "${DEVMIND_AGENT_TIER[@]}"; do
        command -v "$(_agent_bin "$cli")" >/dev/null 2>&1 || continue
        is_cli_skipped "$cli" >/dev/null 2>&1 && continue
        echo "$cli"; return 0
    done
    return 1
}

# run_agent <cli> <prompt> [logfile] — dispatch a prompt to one CLI using its
# correct non-interactive invocation, with quota detection. Sets DEVMIND_LAST_*.
# Returns: 0 success; 1 quota/timeout/skip (caller should try next tier); 2 unknown cli.
run_agent() {
    local cli="$1" prompt="$2" log="${3:-$DEVMIND_LOG_DIR/run_agent.log}"
    local to="${DEVMIND_CLI_TIMEOUT:-270}" out rc
    local LK="${DEVMIND_AGENT_LOCK:-/tmp/devmind-agent.lock}"
    if is_cli_skipped "$cli" >/dev/null 2>&1; then return 1; fi
    # GLOBAL agent serialization: the 5.8GB box CANNOT run 2 heavy agents (~3GB each) at once.
    # flock makes every agent call across the whole system serial → no RAM thrashing (load hit 18).
    # -w 90: wait up to 90s for the running agent to finish; if not, defer (failover/skip this cycle).
    case "$cli" in
        gemini)   out=$(flock -w 90 "$LK" timeout "${to}s" gemini-clean "${DEVMIND_GEMINI_FLAGS[@]}" -p "$prompt" 2>&1); rc=$? ;;
        opencode) out=$(flock -w 90 "$LK" timeout "${to}s" opencode run "$prompt" 2>&1); rc=$? ;;
        codex)    out=$(flock -w 90 "$LK" timeout "${to}s" codex exec --skip-git-repo-check "$prompt" 2>&1); rc=$? ;;
        copilot)  out=$(flock -w 90 "$LK" timeout "${to}s" copilot -p "$prompt" --allow-all-tools 2>&1); rc=$? ;;
        claude)   out=$(flock -w 90 "$LK" timeout "${to}s" claude --strict-mcp-config --setting-sources= -p "$prompt" 2>&1); rc=$? ;;
        *)        echo "[devmind] run_agent: unknown cli '$cli'" >> "$log"; return 2 ;;
    esac
    DEVMIND_LAST_OUTPUT="$out"; DEVMIND_LAST_AGENT="$cli"
    echo "$out" >> "$log"
    if [[ $rc -eq 124 ]]; then
        # A timeout means SLOW (agent was working), not quota-out. Short cooldown so the
        # whole tier doesn't get banned for 6h by one slow heavy iteration.
        echo "[devmind] ⏱️  $cli timed out after ${to}s — 10min cooldown (slow, not quota)." >> "$log"
        DEVMIND_SKIP_TTL=600 mark_cli_skipped "$cli" "timeout-${to}s" >/dev/null 2>&1 || true
        return 1
    fi
    check_output_for_quota "$cli" "$out" || return 1   # quota → try next tier
    return $rc
}

# run_with_failover <prompt> [logfile] — walk the tier until one agent succeeds
# (non-quota). On success: DEVMIND_LAST_AGENT/OUTPUT are set and 0 is returned.
# Returns 1 only if the entire tier is exhausted this cycle.
run_with_failover() {
    local prompt="$1" log="${2:-$DEVMIND_LOG_DIR/run_agent.log}" cli
    for cli in "${DEVMIND_AGENT_TIER[@]}"; do
        command -v "$(_agent_bin "$cli")" >/dev/null 2>&1 || continue
        if is_cli_skipped "$cli" >/dev/null 2>&1; then
            echo "[devmind] ⏭️  $cli skipped — next tier." >> "$log"; continue
        fi
        echo "[devmind] ▶ dispatching to $cli" >> "$log"
        if run_agent "$cli" "$prompt" "$log"; then
            echo "[devmind] ✅ $cli completed." >> "$log"; return 0
        fi
        echo "[devmind] ↪ $cli failed/quota — failover." >> "$log"
    done
    echo "[devmind] ⛔ entire agent tier exhausted this cycle." >> "$log"
    return 1
}
