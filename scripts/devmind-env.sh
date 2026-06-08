#!/usr/bin/env bash
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Environment Resolution
# Autonomy-safe: skip files auto-expire after a TTL so the system self-heals
# without requiring an operator to delete them.
export PATH="/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

DEVMIND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
DEVMIND_REPRO_DIR="$(cd "$DEVMIND_SCRIPT_DIR/.." 2>/dev/null && pwd)"
DEVMIND_STATE_DIR="$DEVMIND_REPRO_DIR/scripts"
DEVMIND_QUOTA_STATE="$DEVMIND_STATE_DIR/quota_state.txt"
DEVMIND_LOG_DIR="/home/fixxia/lamp/logs"
DEVMIND_WIN_HOME="/mnt/c/Users/Fixxia"
DEVMIND_GEMINI_DIR="$DEVMIND_WIN_HOME/.gemini"
DEVMIND_GGA_PATH="$DEVMIND_WIN_HOME/scripts/gga_repo/bin/gga"

# Skip-file TTL in seconds. Default 6h — after this, the next cycle re-probes
# the CLI and re-enables it if quota has reset. Override with DEVMIND_SKIP_TTL.
DEVMIND_SKIP_TTL="${DEVMIND_SKIP_TTL:-21600}"

# Non-interactive flags applied to every gemini call from this stack.
DEVMIND_GEMINI_FLAGS=(--yolo --skip-trust)

export DEVMIND_REPRO_DIR DEVMIND_STATE_DIR DEVMIND_QUOTA_STATE DEVMIND_LOG_DIR \
       DEVMIND_GEMINI_DIR DEVMIND_GGA_PATH DEVMIND_SKIP_TTL

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
# Expired skip files are auto-removed so the next cycle re-probes the CLI.
is_cli_skipped() {
    local cli="$1"
    local age
    age=$(_skip_file_age "$cli")
    if [[ "$age" -lt 0 ]]; then
        return 1
    fi
    if [[ "$age" -ge "$DEVMIND_SKIP_TTL" ]]; then
        echo "[devmind] ⏰ skip_${cli} expired (age ${age}s ≥ TTL ${DEVMIND_SKIP_TTL}s) — auto-clearing for re-probe."
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
    local output rc
    output=$(timeout 15m "$@" 2>&1)
    rc=$?
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
            out=$(timeout 45s gemini "${DEVMIND_GEMINI_FLAGS[@]}" -p "ok" 2>&1)
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
