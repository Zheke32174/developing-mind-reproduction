# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Auto Recovery
import json
import os
import subprocess
from pathlib import Path

HOME = Path.home()
GEMINI_DIR = Path(os.environ.get("DEVMIND_GEMINI_DIR", HOME / ".gemini"))
if not GEMINI_DIR.exists() and Path("/mnt/c/Users/Fixxia/.gemini").exists():
    GEMINI_DIR = Path("/mnt/c/Users/Fixxia/.gemini")

STATE_FILE = Path(os.environ.get("DEVMIND_RALPH_STATE", GEMINI_DIR / "ralph" / "state.json"))
SETUP_SCRIPT = Path(os.environ.get("DEVMIND_RALPH_SETUP", GEMINI_DIR / "extensions" / "ralph" / "scripts" / "setup.sh"))
PLAN_PROMPT = "deliberate based on the available data you have and decide the next 100 meaningful pre post and primary tasks and subtasks and run it as a looping goal until satisfactory conclusion"


def check_and_recover():
    print("Checking Ralph Loop stability...")
    needs_restart = False

    if not STATE_FILE.exists():
        needs_restart = True
    else:
        try:
            with STATE_FILE.open("r") as f:
                state = json.load(f)
            if not state.get("active", False):
                needs_restart = True
            elif state.get("current_iteration", 0) >= state.get("max_iterations", 100):
                print("Ralph loop completed successfully.")
                return
        except Exception as e:
            print(f"State file corrupted: {e}")
            needs_restart = True

    if needs_restart:
        print("🚨 Ralph Loop aborted or missing. Initiating auto-recovery...")
        if not SETUP_SCRIPT.exists():
            print(f"❌ Ralph setup script missing: {SETUP_SCRIPT}")
            return
        # In a real environment, we'd pipe the last error to a debugging agent here.
        subprocess.run(["bash", str(SETUP_SCRIPT), "--max-iterations", "100", PLAN_PROMPT], check=False)
        print("Ralph Loop restarted.")
    else:
        print("Ralph Loop is active and healthy.")


if __name__ == "__main__":
    check_and_recover()
