# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Time-based Checkpoints
import json
import os
from datetime import datetime, timedelta
import sys

# Use canonical environment variables
STATE_DIR = os.environ.get("DEVMIND_STATE_DIR")

if not STATE_DIR:
    # Attempt to derive from script location if env not set
    STATE_DIR = os.path.dirname(os.path.abspath(__file__))

STATE_FILE = os.path.join(STATE_DIR, "checkpoint_state.json")

def check_timer():
    if not os.path.exists(STATE_FILE):
        return True
    with open(STATE_FILE, "r") as f:
        state = json.load(f)
    last_sync = datetime.fromisoformat(state["last_sync"])
    return (datetime.now() - last_sync) > timedelta(minutes=30)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "reset":
        with open(STATE_FILE, "w") as f:
            json.dump({"last_sync": datetime.now().isoformat()}, f)
    else:
        sys.exit(1 if check_timer() else 0)
