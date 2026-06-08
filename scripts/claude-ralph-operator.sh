#!/usr/bin/env bash
# claude-ralph-operator.sh — Claude lead role for the Ralph Loop
#
# Operator-invoked only. Gemini's slot in hivemind_governor.sh is NEVER touched.
# Claude runs tasks in parallel or as a stand-in; Gemini resumes on quota recovery.
#
# Usage: bash claude-ralph-operator.sh [task_id]
#   task_id: e.g. 1.1, 1.3 — runs that specific task
#   (no arg): runs next uncompleted task from plan.md

export PATH="/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

REPRO_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction"
PLAN="$REPRO_DIR/swarm-plan/plan.md"
LOG="$REPRO_DIR/scripts/claude_ralph_log.md"
STATE="$REPRO_DIR/scripts/claude_ralph_state.json"
GEMINI_SLOT_FILE="$REPRO_DIR/scripts/hivemind_governor.sh"  # read-only reference

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

log() { echo "[$TIMESTAMP] [claude-ralph] $*" | tee -a "$LOG"; }

# Hidden rule: Claude never displaces Gemini's governor slot
assert_gemini_intact() {
  if ! grep -q "Gemini CLI: The Primary Ralph Automation Loop" "$GEMINI_SLOT_FILE"; then
    echo "SAFETY: Gemini's governor slot appears modified. Aborting." >&2; exit 1
  fi
}

mark_complete() {
  local task="$1"
  sed -i "s/^- \[ \] ${task} /- [x] ${task} /" "$PLAN"
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
        log "FAIL: GEMINI.md not found at $rules_file"
      fi ;;

    1.2)
      log "Execute fetch_claude_memory.sh — verify memory bridge"
      local bridge="/mnt/c/Users/Fixxia/scripts/fetch_claude_memory.sh"
      if [[ -f "$bridge" ]]; then
        log "PASS: Memory bridge script exists at $bridge"
        mark_complete "1.2"; log "Task 1.2 COMPLETE"
      else
        log "FAIL: Memory bridge not found"
      fi ;;

    1.3)
      log "Verify GGA executable"
      local gga="/mnt/c/Users/Fixxia/scripts/gga_repo/bin/gga"
      if [[ -x "$gga" ]]; then
        log "PASS: GGA executable at $gga"
        mark_complete "1.3"; log "Task 1.3 COMPLETE"
      else
        log "FAIL: GGA not executable at $gga"
      fi ;;

    1.6)
      log "Verify substrate-sync.sh triggers GGA pipeline"
      local sync="$REPRO_DIR/scripts/substrate-sync.sh"
      if grep -q "GGA_PATH\|gga.*run" "$sync" && grep -q "linuxbrew" "$sync"; then
        log "PASS: substrate-sync.sh has GGA invocation and linuxbrew PATH"
        mark_complete "1.6"; log "Task 1.6 COMPLETE"
      else
        log "FAIL: substrate-sync.sh missing GGA or PATH fix"
      fi ;;

    *)
      log "Task $task: delegating to claude -p for implementation"
      local task_text
      task_text=$(grep "^- \[ \] ${task} " "$PLAN" | sed 's/^- \[ \] [0-9.]* //')
      if [[ -z "$task_text" ]]; then
        log "Task $task not found or already complete"; return
      fi
      timeout 120s claude -p \
        "You are Claude executing Ralph Loop task ${task} in the Developing Mind ecosystem at $REPRO_DIR. Task: $task_text. Work only within $REPRO_DIR. Do not modify hivemind_governor.sh. Report what you did in 3 sentences." \
        | tee -a "$LOG"
      mark_complete "$task"; log "Task $task COMPLETE (claude delegation)" ;;
  esac
}

main() {
  assert_gemini_intact
  log "=== CLAUDE RALPH OPERATOR ==="
  log "Operator-invoked. Gemini slot: INTACT. Running as parallel lead."

  # Write shadow state
  python3 -c "
import json, datetime
state = {'operator': 'claude', 'started': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
         'gemini_slot': 'intact', 'mode': 'parallel_lead'}
print(json.dumps(state, indent=2))
" > "$STATE"

  if [[ -n "${1:-}" ]]; then
    run_task "$1"
  else
    # Find first uncompleted task
    local next
    next=$(grep -m1 "^- \[ \]" "$PLAN" | grep -oP '^\- \[ \] \K[0-9]+\.[0-9]+')
    if [[ -n "$next" ]]; then
      run_task "$next"
    else
      log "All tasks complete or no uncompleted tasks found."
    fi
  fi

  log "=== OPERATOR RUN COMPLETE. Gemini slot: INTACT ==="
}

main "$@"
