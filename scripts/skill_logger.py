# Arxiv Anchor: 2511.10621 (Section 3.1: Hierarchical Discovery) - Autonomous Skill Discovery
import json
import os
from datetime import datetime
import sys

# Use canonical environment variables
repro_dir = os.environ.get("DEVMIND_REPRO_DIR")
if not repro_dir:
    repro_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LOG_FILE = os.path.join(repro_dir, "SKILL_INVOCATION_LOG.json")

def log_invocation(skill_name, context):
    timestamp = datetime.now().isoformat()
    entry = {"timestamp": timestamp, "skill": skill_name, "context": context, "autonomous": True}
    log = []
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE, "r") as f:
            log = json.load(f)
    log.append(entry)
    with open(LOG_FILE, "w") as f:
        json.dump(log, f, indent=2)
    print("Skill Discovery Logged: " + skill_name)

if __name__ == "__main__":
    if len(sys.argv) > 2:
        log_invocation(sys.argv[1], sys.argv[2])
