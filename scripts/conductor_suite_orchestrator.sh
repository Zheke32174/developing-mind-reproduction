#!/usr/bin/env bash
# Developing Mind — Conductor Suite Orchestrator (Autonomy-Safe)
# Role: Non-interactively invokes the full Conductor suite to maintain ecosystem coherence.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Verification Loop
export PATH="/home/fixxia/.local/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=devmind-env.sh
source "$SCRIPT_DIR/devmind-env.sh"

# substrate-sync is owned by the governor / daily-suite; not repeated here.
echo "🎼 Initiating Non-Interactive Conductor Suite..."

if is_cli_skipped "gemini"; then
    echo "⏭️  gemini is currently OUT_OF_USAGE — conductor suite deferred until skip TTL expires."
    exit 0
fi

# --yolo + --skip-trust = zero approval prompts, zero trust-workspace prompts.
GEMINI_OPTS=("${DEVMIND_GEMINI_FLAGS[@]}")

GEMINI_CLEAN="${GEMINI_CLEAN:-/home/fixxia/.local/bin/gemini-clean}"
[[ -x "$GEMINI_CLEAN" ]] || GEMINI_CLEAN="gemini-clean"  # fallback to PATH lookup

run_conductor_step() {
    local step="$1"
    local prompt="$2"
    local out rc
    # Use is_cli_skipped guard here too so quota set by step 1 stops steps 2+3 immediately.
    if is_cli_skipped "gemini"; then
        echo "⏭️  Conductor $step deferred — gemini quota hit during this run."
        return 1
    fi
    out=$(timeout 270s "$GEMINI_CLEAN" "${GEMINI_OPTS[@]}" -p "$prompt" 2>&1)
    rc=$?
    echo "$out"
    # Surface quota signals into skip-flag state so the next cycle defers automatically.
    check_output_for_quota "gemini" "$out" || {
        echo "⚠️  Conductor $step aborted by quota signal."
        return 1
    }
    if [[ $rc -ne 0 ]]; then
        echo "ℹ️  Conductor $step exit=$rc (non-fatal — cycle continues)."
    fi
    return 0
}

run_conductor_step "setup"     "/conductor:setup --auto"     || true
run_conductor_step "implement" "/conductor:implement --auto" || true
run_conductor_step "review"    "/conductor:review --auto"    || true

echo "✅ Conductor Suite Orchestration complete. Ecosystem coherence maintained."
