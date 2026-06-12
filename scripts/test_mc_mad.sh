#!/usr/bin/env bash
# Test MC-MAD Conflict Resolution (Task 24)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

MAIL_DIR="${DEVMIND_WIN_HOME:-~}/swarmmail/inbox"
rm -f "$MAIL_DIR"/alert_*.json

echo "[TEST] Running MC-MAD Debate with valid claim..."
python3 "$SCRIPT_DIR/mc_mad_coordinator.py" "This is a valid claim."

echo "[TEST] Running MC-MAD Debate with invalid claim..."
python3 "$SCRIPT_DIR/mc_mad_coordinator.py" "This is a false claim."

echo "[TEST] Verifying SwarmMail Event Bus Messages..."
MESSAGE_COUNT=$(ls -1 "$MAIL_DIR"/alert_*.json 2>/dev/null | wc -l)

echo "[TEST] Total messages generated: $MESSAGE_COUNT"
if [ "$MESSAGE_COUNT" -eq 14 ]; then
    echo "[TEST] ✅ MC-MAD Event bus successfully recorded 14 messages (7 per debate)."
else
    echo "[TEST] ❌ Expected 14 messages, found $MESSAGE_COUNT."
    exit 1
fi

CONSENSUS_MESSAGES=$(grep -l '"subject": "MC-MAD Consensus"' "$MAIL_DIR"/alert_*.json 2>/dev/null | wc -l)
if [ "$CONSENSUS_MESSAGES" -eq 2 ]; then
    echo "[TEST] ✅ Found 2 consensus broadcasts."
else
    echo "[TEST] ❌ Expected 2 consensus broadcasts, found $CONSENSUS_MESSAGES."
    exit 1
fi

echo "[TEST] ✅ MC-MAD Coordination Test Complete."
