#!/usr/bin/env bash
# Developing Mind — substrate-sync (AST Validated, GGA-Gated, Promotion-Safe)
# Arxiv Anchor: 2410.02724 & 2604.24579 (Prop 1: Analytic Reliability)
#
# Hardened for unattended operation:
#   - Never blocks the hivemind cycle on git/GGA failures.
#   - Performs no repository mutation unless branch publication is explicitly enabled.
#   - Refuses direct publication to main/master and requires the checked-out branch
#     to match the named proposal branch.
#   - Adds only intended source paths (src/, scripts/, swarm-plan/, tests/, *.md).
#   - Refuses to stage runtime state, backup files, or skip flags (.gitignore filters them).

export PATH="/home/fixxia/.local/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Environment Resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/devmind-env.sh" ]; then
    source "$SCRIPT_DIR/devmind-env.sh"
fi

REPRO_DIR="${DEVMIND_REPRO_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
GGA_PATH="${DEVMIND_GGA_PATH:-${REPRO_DIR}/../scripts/gga_repo/bin/gga}"

cd "$REPRO_DIR" || { echo "❌ Cannot enter $REPRO_DIR"; exit 0; }

# Repository publication is opt-in. DEVMIND_NO_PUSH remains a hard legacy veto.
if [[ "${DEVMIND_NO_PUSH:-0}" == "1" || "${DEVMIND_ALLOW_PUSH:-0}" != "1" ]]; then
    echo "ℹ️  Repository publication disabled; set DEVMIND_ALLOW_PUSH=1 and DEVMIND_PUSH_BRANCH=<proposal-branch> explicitly."
    exit 0
fi

PUSH_BRANCH="${DEVMIND_PUSH_BRANCH:-}"
if [[ -z "$PUSH_BRANCH" ]]; then
    echo "⚠️  DEVMIND_PUSH_BRANCH is required when publication is enabled. Skipping sync."
    exit 0
fi
case "$PUSH_BRANCH" in
    main|master|refs/heads/main|refs/heads/master)
        echo "⚠️  Direct publication to the protected default branch is forbidden. Use a proposal branch and PR."
        exit 0
        ;;
esac
if [[ ! "$PUSH_BRANCH" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$ || "$PUSH_BRANCH" == *".."* ]]; then
    echo "⚠️  DEVMIND_PUSH_BRANCH is not a safe branch name. Skipping sync."
    exit 0
fi

CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || true)"
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" != "$PUSH_BRANCH" ]]; then
    echo "⚠️  Checked-out branch '$CURRENT_BRANCH' does not match proposal branch '$PUSH_BRANCH'. Skipping sync."
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
    echo "✅ Review passed. Publishing proposal branch..."
    MSG="${1:-PSS: Algorithmic Snapshot with AST Validation - Gated by GGA}"
    if git commit -m "$MSG" >/dev/null 2>&1; then
        if ! git push origin "HEAD:refs/heads/$PUSH_BRANCH" 2>&1; then
            echo "⚠️  proposal-branch push failed (non-fatal). Cycle continues."
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
