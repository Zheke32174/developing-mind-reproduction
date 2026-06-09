#!/usr/bin/env bash
# Developing Mind — Performance Angel (Gemini-powered)
# Role: Audits for resource waste and command efficiency.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"
cd "$DEVMIND_REPRO_DIR" && bash "$SCRIPT_DIR/substrate-sync.sh"
echo "[Performance Angel] Auditing resource efficiency..."
timeout 300s bash "$SCRIPT_DIR/subconscious-daemon.sh"
