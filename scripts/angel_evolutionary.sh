#!/usr/bin/env bash
# Developing Mind — Evolutionary Angel (Hermes-powered)
# Role: Verifies forward-compatibility with Attractor NLSpecs.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)
cd /mnt/c/Users/Fixxia/developing-mind-reproduction/ && bash scripts/substrate-sync.sh
echo "[Evolutionary Angel] Verifying NLSpec alignment..."
timeout 300s bash scripts/hermes_60_day_evolution.sh --verify-only
