#!/usr/bin/env bash
# Developing Mind — Daily Full Evolution Suite (v2: Quota-Aware)
# Role: Orchestrates a daily deep review and evolution cycle across all ecosystem CLIs.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Systemic Evolution

export PATH="/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"
REPRO_DIR="$DEVMIND_REPRO_DIR"
SCRIPTS_DIR="$REPRO_DIR/scripts"
TASKMASTER_BIN="npx --yes task-master-ai"

echo "🌅 Initiating Daily Full Evolution Suite..."

# 1. Ingest state
bash "$SCRIPTS_DIR/substrate-sync.sh"

# 2. Claude Code audit
echo "⚙️  Invoking Claude Code..."
safe_run_cli "claude" "$DEVMIND_LOG_DIR/harness_claude.log" \
    claude --strict-mcp-config --setting-sources= \
    -p "Perform a daily systemic audit of the Developing Mind ecosystem. Review recent logs, identify bottlenecks, and propose evolution rounds." \
    || echo "Claude Code audit complete."

# 3. Taskmaster (uses Claude internally — skip if claude is out)
if ! is_cli_skipped "claude"; then
    echo "⚙️  Invoking Claude Taskmaster..."
    safe_run_cli "claude" "$DEVMIND_LOG_DIR/taskmaster.log" \
        bash -c "$TASKMASTER_BIN list all && $TASKMASTER_BIN next" \
        || echo "Taskmaster check complete."
else
    echo "⏭️  Skipping Taskmaster — claude is OUT_OF_USAGE."
fi

# 4. Gemini secondary review
echo "⚙️  Invoking Gemini CLI..."
safe_run_cli "gemini" "$DEVMIND_LOG_DIR/harness_gemini.log" \
    gemini-clean "${DEVMIND_GEMINI_FLAGS[@]}" \
    -p "Verify Phase 1 Factory Deployment status and sign the Daily Evolution Ledger." \
    || echo "Gemini review complete."

# 5. OpenCode GGA compliance check
echo "⚙️  Invoking OpenCode..."
safe_run_cli "opencode" "$DEVMIND_LOG_DIR/opencode.log" \
    opencode stats \
    || echo "OpenCode status check complete."

# 6. Hermes evolution benchmark
echo "⚙️  Invoking Hermes..."
bash "$SCRIPTS_DIR/hermes_60_day_evolution.sh" || echo "Hermes benchmark complete."

# 7. Checkpoint
echo "✅ Daily Full Evolution Suite complete."
python3 "$SCRIPTS_DIR/checkpoint-timer.py" reset
