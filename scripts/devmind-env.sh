#!/usr/bin/env bash
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Environment Resolution

DEVMIND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
DEVMIND_REPRO_DIR="$(cd "$DEVMIND_SCRIPT_DIR/.." 2>/dev/null && pwd)"
DEVMIND_STATE_DIR="$DEVMIND_REPRO_DIR/scripts"
DEVMIND_QUOTA_STATE="$DEVMIND_STATE_DIR/quota_state.txt"
DEVMIND_LOG_DIR="/home/fixxia/lamp/logs"
DEVMIND_WIN_HOME="/mnt/c/Users/Fixxia"
DEVMIND_GEMINI_DIR="$DEVMIND_WIN_HOME/.gemini"
DEVMIND_GGA_PATH="$DEVMIND_WIN_HOME/scripts/gga_repo/bin/gga"

export DEVMIND_REPRO_DIR DEVMIND_STATE_DIR DEVMIND_QUOTA_STATE DEVMIND_LOG_DIR DEVMIND_GEMINI_DIR DEVMIND_GGA_PATH
