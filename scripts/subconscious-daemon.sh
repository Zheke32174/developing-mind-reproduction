#!/usr/bin/env bash
# Developing Mind — subconscious-daemon.sh (Codex Judge Integrated)
# Role: Orchestrates background monitoring and invokes the Codex Judge.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Background Monitoring

DEVMIND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$DEVMIND_SCRIPT_DIR/devmind-env.sh"

LAMP_DIR="$(dirname "$DEVMIND_LOG_DIR")"

echo "Running Subconscious Daemon checks..."

# Resource Monitors
bash "$DEVMIND_SCRIPT_DIR/disk_monitor.sh" || echo "Disk check flagged an issue."
bash "$DEVMIND_SCRIPT_DIR/ram_monitor.sh" || echo "RAM check flagged an issue."

# 30-Minute Checkpoint
python3 "$DEVMIND_SCRIPT_DIR/checkpoint-timer.py"
if [ $? -eq 1 ]; then
    echo "🚨 30-MINUTE CHECKPOINT REACHED. Refreshing state."
    bash "$DEVMIND_SCRIPT_DIR/substrate-sync.sh"
    python3 "$DEVMIND_SCRIPT_DIR/checkpoint-timer.py" reset
fi

# Codex Judge Integration (Trigger on demand or periodically)
# We invoke the LAMP cron runner's judge capability
echo "⚖️ Invoking Codex Judge..."
if [ -f "$LAMP_DIR/ai-scaffold/cron-run.sh" ]; then
    bash "$LAMP_DIR/ai-scaffold/cron-run.sh" 
else
    echo "⚠️ Warning: $LAMP_DIR/ai-scaffold/cron-run.sh not found. Skipping."
fi

echo "🐕 Running Ralph Watchdog..."
python3 "$DEVMIND_SCRIPT_DIR/ralph_watchdog.py"

echo "Daemon checks complete."
