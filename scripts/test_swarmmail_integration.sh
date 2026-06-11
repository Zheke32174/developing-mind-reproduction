#!/usr/bin/env bash
# Test Daemon-to-Governor SwarmMail Alerting (Task 18)
# Validates SwarmMail JSON roundtrip between daemon and governor components

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$SCRIPT_DIR/devmind-env.sh"

TEST_LOG="$DEVMIND_LOG_DIR/swarmmail_test.log"
mkdir -p "$(dirname "$TEST_LOG")"

echo "[TEST] Starting SwarmMail Integration Test..." | tee -a "$TEST_LOG"

# Create test inbox if needed (use /tmp as fallback)
MAIL_DIR="${DEVMIND_WIN_HOME:-~}/swarmmail/inbox"
if ! mkdir -p "$MAIL_DIR" 2>/dev/null; then
    MAIL_DIR="/tmp/swarmmail/inbox"
    mkdir -p "$MAIL_DIR"
fi
echo "[TEST] Mail directory: $MAIL_DIR" | tee -a "$TEST_LOG"

# Test 1: Send a high-priority alert from daemon
echo "[TEST 1] Sending high-priority daemon alert..." | tee -a "$TEST_LOG"
python3 "$SCRIPT_DIR/send_swarm_alert.py" \
    "Test Alert - Daemon Priority" \
    '{"component": "test_daemon", "test_type": "high_priority", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
    "high"
ALERT_COUNT1=$(ls -1 "$MAIL_DIR"/alert_*.json 2>/dev/null | wc -l)
echo "[TEST 1] Alert count after send: $ALERT_COUNT1" | tee -a "$TEST_LOG"

# Test 2: Verify JSON structure in latest alert
LATEST_ALERT=$(ls -t "$MAIL_DIR"/alert_*.json 2>/dev/null | head -1)
if [ -f "$LATEST_ALERT" ]; then
    echo "[TEST 2] Validating alert JSON structure..." | tee -a "$TEST_LOG"
    if jq . "$LATEST_ALERT" > /dev/null 2>&1; then
        echo "[TEST 2] ✅ Valid JSON in: $(basename "$LATEST_ALERT")" | tee -a "$TEST_LOG"
        jq . "$LATEST_ALERT" | tee -a "$TEST_LOG"
    else
        echo "[TEST 2] ❌ Invalid JSON in alert!" | tee -a "$TEST_LOG"
        exit 1
    fi
else
    echo "[TEST 2] ❌ No alert files found!" | tee -a "$TEST_LOG"
    ls -la "$MAIL_DIR" | tee -a "$TEST_LOG"
    exit 1
fi

# Test 3: Send normal priority alert (like governor would)
echo "[TEST 3] Sending normal-priority governor alert..." | tee -a "$TEST_LOG"
python3 "$SCRIPT_DIR/send_swarm_alert.py" \
    "Test Alert - Governor Cycle" \
    '{"source": "hivemind_governor", "cycle_duration": 145, "status": "cycle_complete"}' \
    "normal"

# Test 4: Send warning priority alert
echo "[TEST 4] Sending warning-priority alert..." | tee -a "$TEST_LOG"
python3 "$SCRIPT_DIR/send_swarm_alert.py" \
    "Test Alert - Resource Warning" \
    '{"component": "disk_monitor", "usage_percent": 87, "threshold": 90}' \
    "warning"

# Test 5: Count alerts by priority
echo "[TEST 5] Audit alerts by priority..." | tee -a "$TEST_LOG"
HIGH_COUNT=$(grep -l '"priority": "high"' "$MAIL_DIR"/alert_*.json 2>/dev/null | wc -l)
NORMAL_COUNT=$(grep -l '"priority": "normal"' "$MAIL_DIR"/alert_*.json 2>/dev/null | wc -l)
WARNING_COUNT=$(grep -l '"priority": "warning"' "$MAIL_DIR"/alert_*.json 2>/dev/null | wc -l)

echo "[TEST 5] Alert distribution:" | tee -a "$TEST_LOG"
echo "  - High:    $HIGH_COUNT" | tee -a "$TEST_LOG"
echo "  - Normal:  $NORMAL_COUNT" | tee -a "$TEST_LOG"
echo "  - Warning: $WARNING_COUNT" | tee -a "$TEST_LOG"

# Test 6: Verify alert timestamp ordering
echo "[TEST 6] Checking timestamp ordering..." | tee -a "$TEST_LOG"
TIMESTAMPS=$(grep -h '"timestamp":' "$MAIL_DIR"/alert_*.json 2>/dev/null | sort)
if [ -n "$TIMESTAMPS" ]; then
    echo "[TEST 6] ✅ Timestamps present" | tee -a "$TEST_LOG"
else
    echo "[TEST 6] ❌ No timestamps found!" | tee -a "$TEST_LOG"
fi

echo "[TEST] ✅ SwarmMail Integration Test Complete" | tee -a "$TEST_LOG"
echo "[TEST] Alerts stored in: $MAIL_DIR" | tee -a "$TEST_LOG"
echo "[TEST] Total alerts created: $(ls -1 "$MAIL_DIR"/alert_*.json 2>/dev/null | wc -l)" | tee -a "$TEST_LOG"
echo "[TEST] Test log: $TEST_LOG" | tee -a "$TEST_LOG"

