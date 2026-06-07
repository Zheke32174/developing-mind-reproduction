#!/usr/bin/env bash
# Developing Mind — substrate-sync (Distilled & Gated)
# Role: Automates the semantic memory loop with auto-distillation.
# Arxiv Anchor: 2410.02724 (Prop 3.2: Sequence Capture) & 2604.24579 (Prop 1: Analytic Reliability)

REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
GGA_PATH="/mnt/c/Users/Fixxia/scripts/gga_repo/bin/gga"

cd "$REPRO_DIR"

echo "🧠 Distilling cognitive delta..."
python3 scripts/distill-session.py >> REPRODUCTION_NOTES.md

echo "👼 Guardian Angel: Reviewing distilled snapshot..."
git add src/markovian_core/ src/papers/ .gga scripts/ REPRODUCTION_NOTES.md GEMINI.md

# Run gga run
"$GGA_PATH" run
if [ $? -eq 0 ]; then
    echo "✅ Review passed. Syncing to GitHub..."
    MSG="PSS: Distilled Cognitive Snapshot - Gated by GGA"
    git commit -m "$MSG"
    git push origin master
else
    echo "❌ Guardian Angel rejected the snapshot. Please review failures in REPRODUCTION_NOTES.md."
    exit 1
fi
