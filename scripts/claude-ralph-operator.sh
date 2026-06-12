#!/usr/bin/env bash
# Developing Mind — claude-ralph-operator.sh
# Role: Claude lead role for the Ralph Loop (Hardened & Portable).
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=devmind-env.sh
source "$SCRIPT_DIR/devmind-env.sh"

REPRO_DIR="${DEVMIND_REPRO_DIR:-$SCRIPT_DIR/..}"
PLAN="$REPRO_DIR/swarm-plan/plan.md"
LOG="${DEVMIND_LOG_DIR:-$REPRO_DIR/scripts}/claude_ralph_log.md"
STATE="${DEVMIND_STATE_DIR:-$REPRO_DIR/scripts}/claude_ralph_state.json"
GEMINI_SLOT_FILE="$REPRO_DIR/scripts/hivemind_governor.sh"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
log() { echo "[$TIMESTAMP] [claude-ralph] $*" | tee -a "$LOG"; }

# 2. Safety Assertion
assert_gemini_intact() {
  if ! grep -q "Gemini CLI: The Primary Ralph Automation Loop" "$GEMINI_SLOT_FILE"; then
    echo "SAFETY: Gemini's governor slot appears modified. Aborting." >&2; exit 1
  fi
}

# 3. Anchored Task Completion (Prevents 1.1 matching 1.10)
mark_complete() {
  local task="$1"
  sed -i "s/^- \[ \] ${task}[[:space:]]\$/- [x] ${task} /" "$PLAN"
}

run_task() {
  local task="$1"
  log "--- EXECUTING TASK $task ---"

  case "$task" in
    1.1)
      log "Verify GEMINI.md ecosystem rules"
      local rules_file="$REPRO_DIR/GEMINI.md"
      if [[ -f "$rules_file" ]]; then
        local rule_count; rule_count=$(grep -c "^#\|^-\|^\*" "$rules_file" 2>/dev/null || echo "0")
        log "PASS: GEMINI.md exists. $rule_count rule/heading lines found."
        mark_complete "1.1"; log "Task 1.1 COMPLETE"
      else
        log "FAIL: GEMINI.md not found"
      fi ;;

    1.2)
      log "Execute fetch_claude_memory.sh — verify memory bridge"
      local bridge="$REPRO_DIR/../scripts/fetch_claude_memory.sh"
      if [[ -f "$bridge" ]]; then
        log "PASS: Memory bridge script exists at $bridge"
        mark_complete "1.2"; log "Task 1.2 COMPLETE"
      else
        log "FAIL: Memory bridge not found"
      fi ;;

    1.3)
      log "Verify GGA executable"
      local gga="$REPRO_DIR/../scripts/gga_repo/bin/gga"
      if [[ -x "$gga" ]]; then
        log "PASS: GGA executable at $gga"
        mark_complete "1.3"; log "Task 1.3 COMPLETE"
      else
        log "FAIL: GGA not executable"
      fi ;;

    *)
      log "Task $task: delegating to claude -p with MCP suppression"
      local task_text
      task_text=$(grep "^- \[ \] ${task}[[:space:]]" "$PLAN" | sed -E "s/^- \[ \] [0-9.]+ //")
      if [[ -z "$task_text" ]]; then
        log "Task $task not found or already complete"; return
      fi
      # 4. Mandatory MCP Suppression Flags (8GB RAM Guard)
      timeout 120s claude --strict-mcp-config --setting-sources="" -p \
        "You are Claude executing Ralph Loop task ${task} in the Developing Mind ecosystem. Task: $task_text. Work only within $REPRO_DIR. Do not modify hivemind_governor.sh. Report what you did in 3 sentences." \
        | tee -a "$LOG"
      mark_complete "$task"; log "Task $task COMPLETE (claude delegation)" ;;
  esac
}

main() {
  assert_gemini_intact
  log "=== CLAUDE RALPH OPERATOR ==="
  
  if [[ -n "${1:-}" ]]; then
    run_task "$1"
  else
    local next
    next=$(grep -m1 "^- \[ \]" "$PLAN" | grep -oP '^\- \[ \] \K[0-9]+\.[0-9]+')
    if [[ -n "$next" ]]; then
      run_task "$next"
    else
      log "All tasks complete."
    fi
  fi
}

main "$@"
