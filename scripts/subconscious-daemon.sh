#!/usr/bin/env bash
# Developing Mind — subconscious-daemon.sh (Codex Judge Integrated)
# Role: Orchestrates background monitoring and invokes the Codex Judge.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Background Monitoring
# SwarmMail Integration: Multi-agent event coordination (Paper 2406.03075)

DEVMIND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$DEVMIND_SCRIPT_DIR/devmind-env.sh"

LAMP_DIR="$(dirname "$DEVMIND_LOG_DIR")"
SWARMMAIL_LOG="${DEVMIND_LOG_DIR}/swarmmail_daemon.log"

# Initialize SwarmMail logging
mkdir -p "$(dirname "$SWARMMAIL_LOG")"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Subconscious Daemon Start" >> "$SWARMMAIL_LOG"

echo "Running Subconscious Daemon checks..."

# Resource Monitors with SwarmMail integration
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running disk_monitor..." >> "$SWARMMAIL_LOG"
bash "$DEVMIND_SCRIPT_DIR/disk_monitor.sh" || {
    echo "Disk check flagged an issue."
    python3 "$DEVMIND_SCRIPT_DIR/send_swarm_alert.py" \
        "Disk Monitor Alert - Daemon" \
        '{"component": "disk_monitor", "status": "flagged_issue", "source": "subconscious-daemon"}' \
        "high"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Disk alert sent" >> "$SWARMMAIL_LOG"
}

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running ram_monitor..." >> "$SWARMMAIL_LOG"
bash "$DEVMIND_SCRIPT_DIR/ram_monitor.sh" || {
    echo "RAM check flagged an issue."
    python3 "$DEVMIND_SCRIPT_DIR/send_swarm_alert.py" \
        "RAM Monitor Alert - Daemon" \
        '{"component": "ram_monitor", "status": "flagged_issue", "source": "subconscious-daemon"}' \
        "high"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] RAM alert sent" >> "$SWARMMAIL_LOG"
}

# 30-Minute Checkpoint with SwarmMail notification
python3 "$DEVMIND_SCRIPT_DIR/checkpoint-timer.py"
if [ $? -eq 1 ]; then
    echo "🚨 30-MINUTE CHECKPOINT REACHED. Refreshing state."
    python3 "$DEVMIND_SCRIPT_DIR/send_swarm_alert.py" \
        "Checkpoint Event - Daemon" \
        '{"component": "checkpoint", "action": "substrate-sync", "source": "subconscious-daemon", "event_type": "periodic_refresh"}' \
        "normal"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Checkpoint notification sent" >> "$SWARMMAIL_LOG"
    bash "$DEVMIND_SCRIPT_DIR/substrate-sync.sh"
    python3 "$DEVMIND_SCRIPT_DIR/checkpoint-timer.py" reset
fi

# Codex Judge Integration (Trigger on demand or periodically)
# We invoke the LAMP cron runner's judge capability
echo "⚖️ Invoking Codex Judge..."
if [ -f "$LAMP_DIR/ai-scaffold/cron-run.sh" ]; then
    bash "$LAMP_DIR/ai-scaffold/cron-run.sh" && {
        python3 "$DEVMIND_SCRIPT_DIR/send_swarm_alert.py" \
            "Codex Judge Executed" \
            '{"component": "codex_judge", "status": "success", "source": "subconscious-daemon"}' \
            "normal"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Codex judge notification sent" >> "$SWARMMAIL_LOG"
    }
else
    echo "⚠️ Warning: $LAMP_DIR/ai-scaffold/cron-run.sh not found. Skipping."
    python3 "$DEVMIND_SCRIPT_DIR/send_swarm_alert.py" \
        "Codex Judge Missing" \
        '{"component": "codex_judge", "status": "missing", "source": "subconscious-daemon"}' \
        "warning"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Codex judge missing warning sent" >> "$SWARMMAIL_LOG"
fi

echo "🐕 Running Ralph Watchdog..."
python3 "$DEVMIND_SCRIPT_DIR/ralph_watchdog.py"
if [ $? -eq 0 ]; then
    python3 "$DEVMIND_SCRIPT_DIR/send_swarm_alert.py" \
        "Watchdog Check Passed" \
        '{"component": "ralph_watchdog", "status": "passed", "source": "subconscious-daemon"}' \
        "normal"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Watchdog pass notification sent" >> "$SWARMMAIL_LOG"
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Daemon checks complete." >> "$SWARMMAIL_LOG"
echo "Daemon checks complete."
