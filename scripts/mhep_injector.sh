#!/usr/bin/env bash
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Embedded Payloads

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

REPRO_DIR="${DEVMIND_REPRO_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PAYLOAD="$REPRO_DIR/COGNITIVE_PAYLOAD.json"
LEDGER="$REPRO_DIR/PHASE_2_LEDGER.md"

echo "💉 Injecting MHEP Transplant (Gated) into Substrate..."

if [ -f "$PAYLOAD" ]; then
    python3 - << 'PYTHON'
# Arxiv Anchor: 2502.12018 (Prop 3.1: Pre-Process Logic) - MHEP Construction
import json
import os

payload_path = os.environ.get("DEVMIND_REPRO_DIR", ".") + "/COGNITIVE_PAYLOAD.json"
ledger_path = os.environ.get("DEVMIND_REPRO_DIR", ".") + "/PHASE_2_LEDGER.md"

if not os.path.exists(payload_path):
    # Fallback to local discovery
    script_dir = os.path.dirname(os.path.abspath(__file__))
    payload_path = os.path.join(os.path.dirname(script_dir), "COGNITIVE_PAYLOAD.json")
    ledger_path = os.path.join(os.path.dirname(script_dir), "PHASE_2_LEDGER.md")

with open(payload_path, 'r') as f:
    d = json.load(f)

entry = f"\n\n## Phase 3: MHEP Transplant Initialized\n"
entry += f"**Goal:** {d['next_global_goal']}\n"
entry += f"**Tasks:** {', '.join(d['injected_tasks'])}\n"
entry += f"**Arxiv:** {d['header']['arxiv']}\n"

with open(ledger_path, 'a') as f:
    f.write(entry)
PYTHON
    
    echo "🚀 Handing off to Hivemind Governor..."
    bash "$SCRIPT_DIR/hivemind_governor.sh"
else
    echo "❌ Payload missing."
    exit 1
fi

