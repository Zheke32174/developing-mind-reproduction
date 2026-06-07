#!/usr/bin/env bash
# Developing Mind — Autonomous Reviewer (v5: Guardian Council)
# Role: Full 5-layer autonomous verification stack.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)

REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
SCRIPTS_DIR="$REPRO_DIR/scripts"

echo "🛡️  Guardian Council: Convening for Systemic Review..."

# Start Featherlight Monitor
bash "$SCRIPTS_DIR/featherlight_monitor.sh" &
MONITOR_PID=$!

# 1. Standards (OpenCode)
echo "🔍 1/5 [Standards Angel] Initiating..."
timeout 300s bash "$SCRIPTS_DIR/substrate-sync.sh" --review-only
A1=$?

# 2. Functional (Codex)
echo "⚖️ 2/5 [Functional Angel] Initiating..."
bash "$SCRIPTS_DIR/hyperbolic_judge.sh"
A2=$?

# 3. Architectural (Claude)
echo "🏛️  3/5 [Architectural Angel] Initiating..."
bash "$SCRIPTS_DIR/angel_architectural.sh"
A3=$?

# 4. Evolutionary (Hermes)
echo "🧬 4/5 [Evolutionary Angel] Initiating..."
bash "$SCRIPTS_DIR/angel_evolutionary.sh"
A4=$?

# 5. Performance (Gemini)
echo "⚡ 5/5 [Performance Angel] Initiating..."
bash "$SCRIPTS_DIR/angel_performance.sh"
A5=$?

# Final Verdict
kill "$MONITOR_PID" 2>/dev/null
echo -e "\n--- Council Verdict ---"
if [ $A1 -eq 0 ] && [ $A2 -eq 0 ] && [ $A3 -eq 0 ] && [ $A4 -eq 0 ] && [ $A5 -eq 0 ]; then
    echo "✅ CONSENSUS REACHED: Changes Approved."
    exit 0
else
    echo "🚨 CONSENSUS FAILED (S:$A1 F:$A2 A:$A3 E:$A4 P:$A5). Refinement required."
    exit 1
fi
