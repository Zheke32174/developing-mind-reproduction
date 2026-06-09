#!/usr/bin/env bash
# Developing Mind — Static Audit Utility
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Static Verification

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/devmind-env.sh" ]; then
    source "$SCRIPT_DIR/devmind-env.sh"
fi

REPRO_DIR="${DEVMIND_REPRO_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BACKUP_DIR="${DEVMIND_BACKUP_DIR:-$SCRIPT_DIR/backups}"

echo "🔍 Initiating Static Audit (skipping $BACKUP_DIR)..."

# Patterns to find:
# 1. Hardcoded /home/fixxia
# 2. Hardcoded /mnt/c/Users/
# 3. Hardcoded /substrate/mind

grep -rE "/home/fixxia|/mnt/c/Users/|/substrate/mind" "$REPRO_DIR" \
    --exclude-dir="$(basename "$BACKUP_DIR")" \
    --exclude="devmind-env.sh" \
    --exclude="PATH_AUDIT_REPORT.md" \
    --exclude="DEBUG_WEEK_HANDOFF.md" \
    --exclude="PHASE_2_LEDGER.md" \
    --exclude="RALPH_100_TASKS.md"

echo "✅ Static Audit complete."
