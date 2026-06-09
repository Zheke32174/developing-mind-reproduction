#!/usr/bin/env python3
# Developing Mind — Secretary Service Worker
# Role: Performs daily brief monitor sweeps and aggregates security data for the Sub-Governor.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Data Aggregation

import os
import json
import subprocess
from datetime import datetime

# Use canonical environment variables, falling back to dynamic paths if run out-of-context
DEVMIND_LOG_DIR = os.environ.get("DEVMIND_LOG_DIR")

if not DEVMIND_LOG_DIR:
    # Attempt to derive from script location if env not set
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    REPRO_DIR = os.path.dirname(SCRIPT_DIR)
    DEVMIND_LOG_DIR = os.path.join(REPRO_DIR, "logs")

STAGING_DIR = os.path.join(DEVMIND_LOG_DIR, "secretary_staging")

try:
    os.makedirs(STAGING_DIR, exist_ok=True)
except Exception as e:
    print(f"⚠️ Warning: Could not create staging directory at {STAGING_DIR}: {e}")
    # Fallback to local /tmp if strict isolation prevents creation
    STAGING_DIR = "/tmp/secretary_staging"
    os.makedirs(STAGING_DIR, exist_ok=True)

def daily_sweep():
    print("🧹 Secretary Service Worker: Initiating daily monitor sweep...")
    report = {
        "timestamp": datetime.now().isoformat(),
        "disk": subprocess.getoutput("df -h /"),
        "processes": subprocess.getoutput("ps aux --sort=-%mem | head -n 10"),
        "security_events": subprocess.getoutput("grep 'sudo:' /var/log/auth.log | tail -n 5 2>/dev/null || echo 'No events'"),
        "mcp_health": subprocess.getoutput("gemini mcp list 2>/dev/null || echo 'MCP status check failed'")
    }
    
    file_name = f"sweep_{datetime.now().strftime('%Y%m%d')}.json"
    sweep_path = os.path.join(STAGING_DIR, file_name)
    try:
        with open(sweep_path, "w") as f:
            json.dump(report, f, indent=2)
        print(f"✅ Daily sweep collected: {file_name} at {sweep_path}")
    except Exception as e:
        print(f"❌ Failed to write daily sweep: {e}")

if __name__ == "__main__":
    daily_sweep()
