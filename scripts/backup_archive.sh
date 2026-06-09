#!/usr/bin/env bash
# Developing Mind — Backup Archive Utility
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - State Preservation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/devmind-env.sh" ]; then
    source "$SCRIPT_DIR/devmind-env.sh"
fi

BACKUP_DIR="${DEVMIND_BACKUP_DIR:-$SCRIPT_DIR/backups}"
mkdir -p "$BACKUP_DIR"

echo "🧹 Sweeping repository for orphaned backup files..."

# Find .bak files excluding the backup directory itself
# Matches both .bak and .bak.timestamp
find "$DEVMIND_REPRO_DIR" -type f \( -name "*.bak" -o -name "*.bak.[0-9]*" \) \
    -not -path "$BACKUP_DIR/*" | while read -r bak_file; do
    
    filename=$(basename "$bak_file")
    # If the file doesn't already have a timestamp suffix, add one to prevent collisions
    if [[ ! "$filename" =~ \.bak\.[0-9]+$ ]]; then
        timestamp=$(date +%s)
        target_name="${filename}.${timestamp}"
    else
        target_name="$filename"
    fi
    
    echo "📦 Archiving: $bak_file -> $BACKUP_DIR/$target_name"
    mv "$bak_file" "$BACKUP_DIR/$target_name"
done

echo "✅ Backup sweep complete."
