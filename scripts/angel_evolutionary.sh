#!/usr/bin/env bash
# Developing Mind — Evolutionary Angel (Hermes-powered)
# Role: Verifies forward-compatibility with Attractor NLSpecs.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"
cd "$DEVMIND_REPRO_DIR" && bash "$SCRIPT_DIR/substrate-sync.sh"
echo "[Evolutionary Angel] Verifying NLSpec alignment..."
timeout 300s bash "$SCRIPT_DIR/hermes_60_day_evolution.sh" --verify-only
