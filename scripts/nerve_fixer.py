#!/usr/bin/env python3
# Developing Mind — Council Nerve Fixer
# Role: Parses errors from the Guardian Council and applies real-time hotfixes.
# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Self-Repair

import os
import re
import sys

# Use canonical environment variables
repro_dir = os.environ.get("DEVMIND_REPRO_DIR")
if not repro_dir:
    repro_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SCRIPTS_DIR = os.path.join(repro_dir, "scripts")

def apply_hotfixes(error_text):
    print("🧠 Nerve Fixer: Analyzing error patterns...")
    fixed = False
    
    # Pattern 1: Relative path failure in scripts directory
    if "scripts/substrate-sync.sh: No such file or directory" in error_text:
        print("🛠️  Detected relative path error. Fixing script calls...")
        for filename in os.listdir(SCRIPTS_DIR):
            if filename.endswith(".sh") or filename.endswith(".py"):
                path = os.path.join(SCRIPTS_DIR, filename)
                with open(path, "r") as f:
                    content = f.read()
                
                # Fix 'bash scripts/substrate-sync.sh' to use the correct local path check
                new_content = content.replace("bash scripts/substrate-sync.sh", "bash $(dirname \"$0\")/substrate-sync.sh")
                new_content = new_content.replace("python3 scripts/", "python3 $(dirname \"$0\")/ ")
                
                if content != new_content:
                    with open(path, "w") as f:
                        f.write(new_content)
                    print(f"✅ Hotfixed: {filename}")
                    fixed = True
    
    # Pattern 2: Wrong state paths
    if "cron-run.state: No such file" in error_text:
        print("🛠️  Detected state path drift. Correcting...")
        # Add more logic here as patterns emerge
        pass

    return fixed

if __name__ == "__main__":
    if len(sys.argv) > 1:
        with open(sys.argv[1], "r") as f:
            error_log = f.read()
        if apply_hotfixes(error_log):
            print("🚀 Hotfix applied successfully. Signaling retry.")
            sys.exit(0)
        else:
            print("❌ No known fix patterns found.")
            sys.exit(1)
