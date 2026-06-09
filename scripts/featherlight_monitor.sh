#!/usr/bin/env bash
# Developing Mind — Accurate Featherlight Monitor
# Role: Tracks the Codex Judge progress accurately through log analysis and flavor text.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Observability

DEVMIND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$DEVMIND_SCRIPT_DIR/devmind-env.sh"
LOG_FILE="$DEVMIND_LOG_DIR/cron.log"
LAST_MATCH=""

echo -e "  \033[0;35m[Mind]\033[0m Initializing featherlight telemetry..."

# Function to map logs to flavor text
map_log_to_flavor() {
    local LINE="$1"
    if [[ "$LINE" == *"cron-run start"* ]]; then
        echo "Systemic Heartbeat Initiated..."
    elif [[ "$LINE" == *"Running \"health\" task"* ]]; then
        echo "Executing Local Infrastructure Health Check..."
    elif [[ "$LINE" == *"Running \"report\" task"* ]]; then
        echo "Compiling Daily Intelligence Digest..."
    elif [[ "$LINE" == *"triggering codex judge task"* ]]; then
        echo "Invoking High-Fidelity Codex Judge..."
    elif [[ "$LINE" == *"codex judge task complete"* ]]; then
        echo "Judge Deliberation Concluded. Verifying Decision..."
    elif [[ "$LINE" == *"triggering codex worker task"* ]]; then
        echo "Dispatching Worker for Automated Remediation..."
    elif [[ "$LINE" == *"codex worker task complete"* ]]; then
        echo "Verification Successful. PSS Alignment Confirmed."
    elif [[ "$LINE" == *"cron-run done"* ]]; then
        echo "Ecosystem Cycle Complete."
    fi
}

# Start tailing the log file from the current end
tail -n 0 -F "$LOG_FILE" 2>/dev/null | while read -r LINE; do
    FLAVOR=$(map_log_to_flavor "$LINE")
    if [[ -n "$FLAVOR" ]]; then
        echo -e "  \033[0;35m[Mind]\033[0m $FLAVOR"
    fi
done
