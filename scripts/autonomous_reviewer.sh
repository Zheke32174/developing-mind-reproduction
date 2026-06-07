#!/usr/bin/env bash
# Developing Mind — Autonomous Reviewer (v4)
# Role: Operator substitution via Hyperbolic Judge + OpenCode with Accurate Monitor.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)

REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
SCRIPTS_DIR="$REPRO_DIR/scripts"

echo "🤖 Initiating Autonomous Review (Accurate Telemetry Mode)..."

# Stage 1: OpenCode Review (Timed)
echo "🔍 Stage 1: OpenCode Review (Gentleman Guardian Angel)..."
timeout 300s bash "$SCRIPTS_DIR/substrate-sync.sh" --review-only
GGA_EXIT=$?

# Stage 2: Hyperbolic Judge (Timed & Isolated) with Accurate Progress Tracking
echo "⚖️ Stage 2: Hyperbolic Judge Audit..."

# Start Accurate Featherlight Monitor in background
bash "$SCRIPTS_DIR/featherlight_monitor.sh" &
MONITOR_PID=$!

# Execute Judge
bash "$SCRIPTS_DIR/hyperbolic_judge.sh"
JUDGE_EXIT=$?

# Allow final logs to be processed, then kill monitor
sleep 2
kill "$MONITOR_PID" 2>/dev/null

if [ $GGA_EXIT -eq 0 ] && [ $JUDGE_EXIT -eq 0 ]; then
    echo "✅ ALL AUDITORS APPROVED."
    exit 0
else
    echo "🚨 VERIFICATION FAILED (GGA: $GGA_EXIT, JUDGE: $JUDGE_EXIT)"
    exit 1
fi
