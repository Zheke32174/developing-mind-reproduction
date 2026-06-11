# Arxiv Anchor: 2406.03075 (Section 3.3) - Cohesion
import os
import json

win_home = os.environ.get("DEVMIND_WIN_HOME")
if not win_home:
    # Attempt to use home directory as fallback
    win_home = os.path.expanduser("~")

MAIL_DIR = os.path.join(win_home, "swarmmail", "inbox")

def get_alerts():
    alerts = []
    for f in os.listdir(MAIL_DIR):
        if f.endswith(".json"):
            with open(os.path.join(MAIL_DIR, f), "r") as alert_file:
                alerts.append(json.load(alert_file))
            os.remove(os.path.join(MAIL_DIR, f)) # Destructive read (pop)
    return alerts

if __name__ == "__main__":
    alerts = get_alerts()
    if alerts:
        print(f"--- Received {len(alerts)} Swarm Alerts ---")
        for a in alerts:
            payload = a.get('payload', a.get('message', ''))
            if isinstance(payload, dict) or isinstance(payload, list):
                payload_str = json.dumps(payload, indent=2)
            else:
                payload_str = str(payload)
            print(f"[{a['priority'].upper()}] {a['subject']}:\n{payload_str}")
    else:
        print("No new alerts.")
