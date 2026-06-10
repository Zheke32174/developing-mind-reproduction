# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability) - Auto Recovery
# Autonomy-safe Ralph Loop watchdog. Points at the canonical state location
# the ralph extension actually writes to (relative to the repro dir PWD).
import json
import os
import subprocess
from pathlib import Path

# Use canonical environment variables
_repro_env = os.environ.get("DEVMIND_REPRO_DIR")
REPRO_DIR = Path(_repro_env) if _repro_env else None
if not REPRO_DIR:
    # Attempt to derive from script location if env not set
    SCRIPT_DIR = Path(__file__).resolve().parent
    REPRO_DIR = SCRIPT_DIR.parent

STATE_FILE = Path(os.environ.get(
    "DEVMIND_RALPH_STATE",
    REPRO_DIR / ".gemini" / "ralph" / "state.json",
))
SETUP_SCRIPT = Path(os.environ.get(
    "DEVMIND_RALPH_SETUP",
    Path.home() / ".gemini" / "extensions" / "ralph" / "scripts" / "setup.sh",
))
PLAN_PROMPT = (
    "deliberate based on the available data you have and decide the next 100 "
    "meaningful pre post and primary tasks and subtasks and run it as a looping "
    "goal until satisfactory conclusion"
)
MAX_ITERATIONS = "50"


def _skip_flag_active() -> bool:
    """Honor devmind-env's skip flag — don't restart Ralph if gemini is OUT_OF_USAGE."""
    skip = REPRO_DIR / "scripts" / "skip_gemini"
    if not skip.exists():
        return False
    ttl = int(os.environ.get("DEVMIND_SKIP_TTL", "21600"))
    age = abs(int(__import__("time").time()) - int(skip.stat().st_mtime))
    if age >= ttl:
        try:
            skip.unlink()
            print(f"⏰ skip_gemini expired (age {age}s); cleared.")
            return False
        except OSError:
            return True
    print(f"⏭️  gemini skip flag active ({age}s old, TTL {ttl}s). Watchdog deferring restart.")
    return True


def check_and_recover() -> None:
    print(f"Checking Ralph Loop stability… state={STATE_FILE}")
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
                print("Ralph loop reached max_iterations — marking inactive.")
                state["active"] = False
                STATE_FILE.write_text(json.dumps(state, indent=2))
                return
        except Exception as e:
            print(f"State file corrupted: {e}")
            needs_restart = True

    if not needs_restart:
        print("Ralph Loop is active and healthy.")
        return

    print("🚨 Ralph Loop aborted or missing. Initiating auto-recovery…")
    if _skip_flag_active():
        return
    if not SETUP_SCRIPT.exists():
        print(f"❌ Ralph setup script missing: {SETUP_SCRIPT}")
        return

    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["bash", str(SETUP_SCRIPT), "--max-iterations", MAX_ITERATIONS, PLAN_PROMPT],
        cwd=str(REPRO_DIR),
        check=False,
    )
    print("Ralph Loop restarted.")


if __name__ == "__main__":
    check_and_recover()
