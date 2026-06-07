#!/usr/bin/env bash
# Developing Mind — substrate-sync (Guardian Gated)
# Role: Automates the semantic memory loop with quality enforcement.
# Arxiv Anchor: 2410.02724 (Prop 3.2: Sequence Capture) & 2604.24579 (Prop 1: Analytic Reliability)

REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
GGA_PATH="/mnt/c/Users/Fixxia/scripts/gga_repo/bin/gga"

cd "$REPRO_DIR"

echo "👼 Guardian Angel: Reviewing cognitive snapshot..."

# Atomic Staging
git add src/markovian_core/ src/papers/ .gga scripts/ REPRODUCTION_NOTES.md GEMINI.md

# Run gga run
"$GGA_PATH" run
if [ $? -eq 0 ]; then
    echo "✅ Review passed. Syncing to GitHub..."
    git commit -m "PSS: Pure Algorithmic Reproduction of 8 Markovian Papers - Gated by GGA"
    git push origin master
else
    echo "❌ Guardian Angel rejected the snapshot."
    exit 1
fi
