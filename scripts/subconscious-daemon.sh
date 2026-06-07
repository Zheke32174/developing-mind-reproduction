#!/usr/bin/env bash
# Developing Mind — subconscious-daemon.sh
# Role: Orchestrates background monitoring to bolster the Ralph loop.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Background Monitoring

SCRIPTS_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction/scripts"

echo "Running Subconscious Daemon checks..."

bash "$SCRIPTS_DIR/disk_monitor.sh" || echo "Disk check flagged an issue."
bash "$SCRIPTS_DIR/ram_monitor.sh" || echo "RAM check flagged an issue."

# Check the 30-minute rule
python3 "$SCRIPTS_DIR/checkpoint-timer.py"
if [ $? -eq 1 ]; then
    echo "🚨 30-MINUTE CHECKPOINT REACHED. Refreshing state."
    bash "$SCRIPTS_DIR/substrate-sync.sh"
    # Reset the timer after successful sync
    python3 "$SCRIPTS_DIR/checkpoint-timer.py" reset
fi

echo "Daemon checks complete."
