#!/usr/bin/env bash
# Developing Mind — shared environment resolver.
#
# Purpose: keep the ecosystem portable across WSL, Linux, Termux-adjacent
# shells, and future rehydration hosts. Scripts should source this file
# instead of hardcoding /mnt/c/Users/Fixxia or /home/fixxia paths.
#
# This file is intentionally read-mostly: it exports paths and creates log
# directories, but it does not clone, install, decrypt, commit, or push.

# Resolve this file even when sourced.
_DEVMIND_ENV_SCRIPT="${BASH_SOURCE[0]:-${0}}"
_DEVMIND_ENV_DIR="$(cd "$(dirname "$_DEVMIND_ENV_SCRIPT")" 2>/dev/null && pwd)"

# Repository root: parent of scripts/ by default.
if [ -z "${DEVMIND_REPRO_DIR:-}" ]; then
    if [ -n "$_DEVMIND_ENV_DIR" ] && [ -f "$_DEVMIND_ENV_DIR/../PHASE_1_MANIFEST.md" ]; then
        DEVMIND_REPRO_DIR="$(cd "$_DEVMIND_ENV_DIR/.." && pwd)"
    elif [ -d "$HOME/developing-mind-reproduction" ]; then
        DEVMIND_REPRO_DIR="$HOME/developing-mind-reproduction"
    elif [ -d "/mnt/c/Users/Fixxia/developing-mind-reproduction" ]; then
        DEVMIND_REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
    else
        DEVMIND_REPRO_DIR="$(pwd)"
    fi
fi

# Compatibility aliases used by older scripts.
REPRO_DIR="${REPRO_DIR:-$DEVMIND_REPRO_DIR}"

# LAMP/runtime paths. Prefer caller-provided env, then normal home paths,
# then the legacy WSL altar path as a final fallback.
DEVMIND_LAMP_DIR="${DEVMIND_LAMP_DIR:-${LAMP_DIR:-$HOME/lamp}}"
if [ ! -d "$DEVMIND_LAMP_DIR" ] && [ -d "/home/fixxia/lamp" ]; then
    DEVMIND_LAMP_DIR="/home/fixxia/lamp"
fi
LAMP_DIR="${LAMP_DIR:-$DEVMIND_LAMP_DIR}"

DEVMIND_LOG_DIR="${DEVMIND_LOG_DIR:-$DEVMIND_LAMP_DIR/logs}"
DEVMIND_STATE_DIR="${DEVMIND_STATE_DIR:-$DEVMIND_REPRO_DIR/scripts}"
DEVMIND_LEDGER="${DEVMIND_LEDGER:-$DEVMIND_REPRO_DIR/PHASE_2_LEDGER.md}"

# Ralph/Gemini paths.
DEVMIND_GEMINI_DIR="${DEVMIND_GEMINI_DIR:-$HOME/.gemini}"
if [ ! -d "$DEVMIND_GEMINI_DIR" ] && [ -d "/mnt/c/Users/Fixxia/.gemini" ]; then
    DEVMIND_GEMINI_DIR="/mnt/c/Users/Fixxia/.gemini"
fi
DEVMIND_RALPH_STATE="${DEVMIND_RALPH_STATE:-$DEVMIND_GEMINI_DIR/ralph/state.json}"
DEVMIND_RALPH_SETUP="${DEVMIND_RALPH_SETUP:-$DEVMIND_GEMINI_DIR/extensions/ralph/scripts/setup.sh}"

# Guardian/GGA fallback path used by substrate-sync.sh.
DEVMIND_GGA_PATH="${DEVMIND_GGA_PATH:-$DEVMIND_REPRO_DIR/../scripts/gga_repo/bin/gga}"
if [ ! -f "$DEVMIND_GGA_PATH" ] && [ -f "/mnt/c/Users/Fixxia/scripts/gga_repo/bin/gga" ]; then
    DEVMIND_GGA_PATH="/mnt/c/Users/Fixxia/scripts/gga_repo/bin/gga"
fi

# Keep logs creatable where possible, but do not fail if the host is read-only.
mkdir -p "$DEVMIND_LOG_DIR" "$DEVMIND_STATE_DIR" 2>/dev/null || true

export DEVMIND_REPRO_DIR REPRO_DIR
export DEVMIND_LAMP_DIR LAMP_DIR DEVMIND_LOG_DIR DEVMIND_STATE_DIR DEVMIND_LEDGER
export DEVMIND_GEMINI_DIR DEVMIND_RALPH_STATE DEVMIND_RALPH_SETUP DEVMIND_GGA_PATH
