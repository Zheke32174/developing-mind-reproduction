#!/usr/bin/env bash
# Developing Mind — substrate-sync
# Role: Automates the semantic memory loop. 
# Commits daily learning to the PSS (Persistent Semantic Substrate).

REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
cd "$REPRO_DIR"

echo "Syncing Developing Mind state to GitHub..."
git add .
git commit -m "Cognitive Snapshot: $(date +'%Y-%m-%d %H:%M:%S') - Learned Markovian dynamics"
# git push origin main # Requires user to set remote
