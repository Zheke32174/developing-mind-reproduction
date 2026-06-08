#!/usr/bin/env bash
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Environment Resolution
export PATH="/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

DEVMIND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
DEVMIND_REPRO_DIR="$(cd "$DEVMIND_SCRIPT_DIR/.." 2>/dev/null && pwd)"
DEVMIND_STATE_DIR="$DEVMIND_REPRO_DIR/scripts"
DEVMIND_QUOTA_STATE="$DEVMIND_STATE_DIR/quota_state.txt"
DEVMIND_LOG_DIR="/home/fixxia/lamp/logs"
DEVMIND_WIN_HOME="/mnt/c/Users/Fixxia"
DEVMIND_GEMINI_DIR="$DEVMIND_WIN_HOME/.gemini"
DEVMIND_GGA_PATH="$DEVMIND_WIN_HOME/scripts/gga_repo/bin/gga"

export DEVMIND_REPRO_DIR DEVMIND_STATE_DIR DEVMIND_QUOTA_STATE DEVMIND_LOG_DIR DEVMIND_GEMINI_DIR DEVMIND_GGA_PATH

# Quota/skip error patterns that mean a CLI is out of usage (not just rate-limited)
DEVMIND_OUT_OF_USAGE_PATTERNS="out of usage|usage limit reached|account.*suspended|no.*credits|billing.*required|subscription.*expired|access.*revoked"
# Patterns that mean temporary rate-limit (back off 12h, don't skip permanently)
DEVMIND_RATE_LIMIT_PATTERNS="429|too many requests|quota exceeded|exhausted|rate.?limit|session limit"

# is_cli_skipped <cli_name>
# Returns 0 (true) if the CLI has a permanent skip file.
is_cli_skipped() {
    local cli="$1"
    [[ -f "$DEVMIND_STATE_DIR/skip_${cli}" ]]
}

# mark_cli_skipped <cli_name> [reason]
# Creates permanent skip file for a CLI that is out of usage.
mark_cli_skipped() {
    local cli="$1"
    local reason="${2:-out-of-usage}"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) reason=$reason" > "$DEVMIND_STATE_DIR/skip_${cli}"
    echo "[devmind] ⛔ $cli marked OUT_OF_USAGE — will skip until skip_${cli} is removed."
}

# check_output_for_quota <cli_name> <output_string>
# Inspects captured CLI output for quota/skip signals.
# Sets skip file or quota cooldown as appropriate.
# Returns 1 if a quota signal was detected (caller should abort), 0 if clean.
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

# safe_run_cli <cli_name> <log_file> <cmd...>
# Runs a CLI command, captures output, checks for quota signals.
# Prints output to stdout AND log_file. Returns exit code of command.
# Skips entirely if skip file exists for this CLI.
safe_run_cli() {
    local cli="$1"
    local log_file="$2"
    shift 2
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
    if is_cli_skipped "$cli"; then
        echo "[devmind] ⏭️  $cli is marked OUT_OF_USAGE. Skipping." | tee -a "$log_file"
        return 0
    fi
    local output
    output=$(timeout 15m "$@" 2>&1)
    local rc=$?
    echo "$output" | tee -a "$log_file"
    if ! check_output_for_quota "$cli" "$output"; then
        return 1
    fi
    return $rc
}
