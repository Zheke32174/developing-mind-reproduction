#!/usr/bin/env bash
# Developing Mind — substrate-sync (AST Validated, GGA-Gated, Autonomy-Safe)
# Arxiv Anchor: 2410.02724 & 2604.24579 (Prop 1: Analytic Reliability)
#
# Hardened for unattended cron operation:
#   - Never blocks the hivemind cycle on git/GGA failures.
#   - Adds only intended source paths (src/, scripts/, swarm-plan/, tests/, *.md).
#   - Refuses to stage runtime state, backup files, or skip flags (.gitignore filters them).
#   - All failure paths exit 0 so the governor keeps running.

export PATH="/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Environment Resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/devmind-env.sh" ]; then
    source "$SCRIPT_DIR/devmind-env.sh"
fi

REPRO_DIR="${DEVMIND_REPRO_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
GGA_PATH="${DEVMIND_GGA_PATH:-${REPRO_DIR}/../scripts/gga_repo/bin/gga}"

cd "$REPRO_DIR" || { echo "❌ Cannot enter $REPRO_DIR"; exit 0; }

# Opt-out for pure verification cycles.
if [[ "${DEVMIND_NO_PUSH:-0}" == "1" ]]; then
    echo "ℹ️  DEVMIND_NO_PUSH=1 — skipping git operations entirely."
    exit 0
fi

echo "🔍 Validating AST..."
if ! python3 scripts/ast_validator.py src/; then
    echo "❌ AST Validation failed. Continuing without sync (non-fatal)."
    exit 0
fi

# Only stage intended source paths. Never `git add .` — that catches runtime
# state, backups, and skip flags and triggers GGA rejection that blocks the cycle.
SAFE_PATHS=(
    "src"
    "scripts"
    "swarm-plan"
    "tests"
    ".gitignore"
)
git add -- "${SAFE_PATHS[@]}" 2>/dev/null || true
# Add top-level markdown one-by-one (glob safety for cron's restricted shell)
for f in *.md; do [ -f "$f" ] && git add -- "$f" 2>/dev/null || true; done

# Nothing actually staged? No source change this cycle — skip silently.
if git diff --cached --quiet; then
    echo "✅ No source changes to sync this cycle."
    exit 0
fi

echo "👼 Guardian Angel: Reviewing cognitive snapshot..."
if timeout 300s "$GGA_PATH" run; then
    echo "✅ Review passed. Syncing to GitHub..."
    MSG="${1:-PSS: Algorithmic Snapshot with AST Validation - Gated by GGA}"
    if git commit -m "$MSG" >/dev/null 2>&1; then
        if ! git push origin master 2>&1; then
            echo "⚠️  git push failed (non-fatal). Cycle continues."
        fi
    else
        echo "⚠️  git commit produced no commit (possibly empty after filters)."
    fi
else
    echo "⚠️  Guardian Angel rejected snapshot. Unstaging and continuing (non-fatal)."
    git reset HEAD -- "${SAFE_PATHS[@]}" >/dev/null 2>&1 || true
    for f in *.md; do [ -f "$f" ] && git reset HEAD -- "$f" >/dev/null 2>&1 || true; done
fi

exit 0
