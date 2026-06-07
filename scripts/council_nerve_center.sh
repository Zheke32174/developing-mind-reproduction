#!/usr/bin/env bash
# Developing Mind — Council Nerve Center
# Role: Orchestrates the Guardian Council and triggers the Nerve Fixer on failure.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Self-Repair

SCRIPTS_DIR="/mnt/c/Users/Fixxia/developing-mind-reproduction/scripts"
ERROR_LOG="/home/fixxia/lamp/logs/council_error.log"

run_council() {
    echo "🛡️  Nerve Center: Executing Guardian Council Audit..."
    # We run the autonomous reviewer and capture its full output to the error log
    bash "$SCRIPTS_DIR/autonomous_reviewer.sh" 2>&1 | tee "$ERROR_LOG"
    return ${PIPESTATUS[0]}
}

# 1. First Attempt
run_council
if [ $? -ne 0 ]; then
    echo "🚨 Council failure detected. Triggering Nerve Fixer..."
    
    # 2. Hotfix Phase
    python3 "$SCRIPTS_DIR/nerve_fixer.py" "$ERROR_LOG"
    
    if [ $? -eq 0 ]; then
        echo "♻️  Retry Phase: Re-executing Council after hotfix..."
        run_council
        if [ $? -eq 0 ]; then
            echo "✅ NERVE CO-MIND RECOVERY SUCCESSFUL."
            exit 0
        fi
    fi
    echo "❌ NERVE CO-MIND RECOVERY FAILED. Critical failure in the Lattucesphere."
    exit 1
else
    echo "✅ Council passed on first attempt."
    exit 0
fi
