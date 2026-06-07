#!/usr/bin/env bash
# Developing Mind — Parallel Hive Orchestrator (Hive v2)
# Role: Executes the multi-agent parallel harness (Gemini, Claude, Hermes, OpenCode, Codex).
# Arxiv Anchor: 2511.10621 (Section 3.1) - Multi-Agent Parallelism

REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
SCRIPTS_DIR="$REPRO_DIR/scripts"

echo "🐝 Initiating Parallel Hive Execution (v2)..."

# 1. Ingest State
bash "$SCRIPTS_DIR/substrate-sync.sh"

# 2. Parallel Launch
# We use backgrounding and wait to achieve parallelism across all five agents
echo "⚙️  Launching Agent Fleets..."

(bash "$SCRIPTS_DIR/harness_gemini.sh") &
(bash "$SCRIPTS_DIR/harness_claude.sh") &
(bash "$SCRIPTS_DIR/harness_hermes.sh") &
(bash "$SCRIPTS_DIR/autonomous_reviewer.sh") & # Includes OpenCode + Codex

# 3. Synchronize
wait

echo "✅ Parallel Hive Cycle complete. All agents reported back."

# 4. Final Gated Sync
bash "$SCRIPTS_DIR/substrate-sync.sh" "PSS: Parallel Hive Cycle Complete - Gated by GGA"
