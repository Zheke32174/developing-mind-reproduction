#!/usr/bin/env bash
# Developing Mind — substrate-sync (AST Validated)
# Arxiv Anchor: 2410.02724 & 2604.24579

REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
GGA_PATH="/mnt/c/Users/Fixxia/scripts/gga_repo/bin/gga"

cd "$REPRO_DIR"

echo "🔍 Validating AST..."
python3 scripts/ast_validator.py src/
if [ $? -ne 0 ]; then
    echo "❌ AST Validation failed. Aborting sync."
    exit 1
fi

echo "👼 Guardian Angel: Reviewing cognitive snapshot..."
git add src/markovian_core/ src/papers/ .gga scripts/ REPRODUCTION_NOTES.md GEMINI.md
"$GGA_PATH" run
if [ $? -eq 0 ]; then
    echo "✅ Review passed. Syncing to GitHub..."
    git commit -m "PSS: Algorithmic Snapshot with AST Validation - Gated by GGA"
    git push origin master
else
    echo " Guardian Angel rejected the snapshot."
    exit 1
fi
