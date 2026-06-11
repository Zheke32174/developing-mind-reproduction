# Arxiv Anchor: 2406.03075 (Section 3.3) - Cohesion
import json
import os
import sys
from datetime import datetime

win_home = os.environ.get("DEVMIND_WIN_HOME")
if not win_home:
    win_home = os.path.expanduser("~")

MAIL_DIR = os.path.join(win_home, "swarmmail", "inbox")

def send_alert(subject, message_data, priority="normal"):
    try:
        parsed_message = json.loads(message_data)
    except Exception:
        parsed_message = message_data
        
    alert = {
        "timestamp": datetime.now().isoformat(),
        "subject": subject,
        "payload": parsed_message,
        "priority": priority
    }
    file_name = f"alert_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(os.path.join(MAIL_DIR, file_name), "w") as f:
        json.dump(alert, f, indent=2)
    print(f"Alert sent: {subject}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 send_swarm_alert.py <subject> <message>")
    else:
        send_alert(sys.argv[1], sys.argv[2])
