#!/usr/bin/env bash
# hivemind-start.sh — One-shot 48h autonomous run launcher
# Usage: bash hivemind-start.sh
#
# Starts ralph daemon, triggers governor, launches 48h operator in background.
# Safe to call multiple times — will not double-start if already running.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

OPERATOR_SCRIPT="$SCRIPT_DIR/hivemind-48h-operator.sh"
GOVERNOR_SCRIPT="$SCRIPT_DIR/hivemind_governor.sh"
RALPH_SCRIPT="/home/fixxia/ryz-build/ralph.sh"

LOG_DIR="/home/fixxia/lamp/logs"
STATE_DIR="/home/fixxia/lamp/state"
OPERATOR_LOG="$LOG_DIR/operator-48h.log"
STATE_FILE="$STATE_DIR/operator-48h.json"

PID_FILE="/tmp/hivemind-48h-operator.pid"
LOCK_FILE="/tmp/hivemind-48h.lock"

mkdir -p "$LOG_DIR" "$STATE_DIR"

# ── Banner ────────────────────────────────────────────────────────────────────
echo "============================================================"
echo "  HIVEMIND 48H AUTONOMOUS RUN — $(date)"
echo "============================================================"

# ── Guard: already running? ───────────────────────────────────────────────────
if [[ -f "$LOCK_FILE" ]]; then
    EXISTING_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$EXISTING_PID" ]] && kill -0 "$EXISTING_PID" 2>/dev/null; then
        echo "[hivemind-start] Operator already running (PID $EXISTING_PID)."
        echo "  Log:    $OPERATOR_LOG"
        echo "  State:  $STATE_FILE"
        echo "  Monitor: tail -f $OPERATOR_LOG"
        exit 0
    else
        echo "[hivemind-start] Stale lock found (PID $EXISTING_PID dead) — clearing."
        rm -f "$LOCK_FILE" "$PID_FILE"
    fi
fi

# ── Step 1: Start ralph daemon ────────────────────────────────────────────────
RALPH_PID_FILE="/home/fixxia/ryz-build/state/ralph.pid"
if [[ -f "$RALPH_PID_FILE" ]]; then
    RALPH_PID=$(cat "$RALPH_PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$RALPH_PID" ]] && kill -0 "$RALPH_PID" 2>/dev/null; then
        echo "[hivemind-start] Ralph already running (PID $RALPH_PID)."
    else
        echo "[hivemind-start] Starting ralph daemon..."
        if [[ -f "$RALPH_SCRIPT" ]]; then
            setsid nohup bash "$RALPH_SCRIPT" >> "$LOG_DIR/ralph.log" 2>&1 &
            echo "[hivemind-start] Ralph started (PID $!)."
        else
            echo "[hivemind-start] WARNING: ralph.sh not found at $RALPH_SCRIPT — skipping."
        fi
    fi
else
    echo "[hivemind-start] Starting ralph daemon..."
    if [[ -f "$RALPH_SCRIPT" ]]; then
        setsid nohup bash "$RALPH_SCRIPT" >> "$LOG_DIR/ralph.log" 2>&1 &
        echo "[hivemind-start] Ralph started (PID $!)."
    else
        echo "[hivemind-start] WARNING: ralph.sh not found at $RALPH_SCRIPT — skipping."
    fi
fi

# ── Step 2: Immediate governor cycle (background) ─────────────────────────────
if [[ -f "$GOVERNOR_SCRIPT" ]]; then
    echo "[hivemind-start] Triggering immediate governor cycle (background)..."
    bash "$GOVERNOR_SCRIPT" >> "$LOG_DIR/governor-48h.log" 2>&1 &
    echo "[hivemind-start] Governor running (PID $!)."
else
    echo "[hivemind-start] WARNING: governor script not found at $GOVERNOR_SCRIPT — skipping."
fi

# ── Step 3: Launch 48h operator ───────────────────────────────────────────────
if [[ ! -f "$OPERATOR_SCRIPT" ]]; then
    echo "[hivemind-start] ERROR: operator script not found at $OPERATOR_SCRIPT"
    exit 1
fi

echo "[hivemind-start] Launching 48h operator..."
setsid nohup bash "$OPERATOR_SCRIPT" >> "$OPERATOR_LOG" 2>&1 &
OPERATOR_PID=$!

echo ""
echo "------------------------------------------------------------"
echo "  Operator PID : $OPERATOR_PID"
echo "  Log          : $OPERATOR_LOG"
echo "  State        : $STATE_FILE"
echo "  Pillar health: $STATE_DIR/pillar-health.json"
echo "------------------------------------------------------------"
echo "  Monitor : tail -f $OPERATOR_LOG"
echo "  Status  : cat $STATE_FILE"
echo "  Stop    : kill \$(cat $PID_FILE)"
echo "------------------------------------------------------------"
echo ""
echo "[hivemind-start] 48h autonomous run underway. Good luck."
