# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)
import json
import os
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(os.environ.get("DEVMIND_REPRO_DIR", Path(__file__).resolve().parent.parent))
GEMINI_DIR = Path(os.environ.get("DEVMIND_GEMINI_DIR", Path.home() / ".gemini"))
if not GEMINI_DIR.exists() and Path("/mnt/c/Users/Fixxia/.gemini").exists():
    GEMINI_DIR = Path("/mnt/c/Users/Fixxia/.gemini")

RALPH_STATE = Path(os.environ.get("DEVMIND_RALPH_STATE", GEMINI_DIR / "ralph" / "state.json"))


class TestEcosystem(unittest.TestCase):

    def test_ralph_loop_active(self):
        self.assertTrue(RALPH_STATE.exists(), f"Ralph state file does not exist: {RALPH_STATE}")
        with RALPH_STATE.open("r") as f:
            state = json.load(f)
        self.assertTrue(state.get("active", False), "Ralph loop is not marked as active")

    def test_subconscious_daemon_executable(self):
        daemon_path = REPO_ROOT / "scripts" / "subconscious-daemon.sh"
        self.assertTrue(daemon_path.exists(), f"Subconscious daemon script is missing: {daemon_path}")
        self.assertTrue(os.access(daemon_path, os.X_OK), "Subconscious daemon script is not executable")

    def test_disk_space_monitor_healthy(self):
        monitor = REPO_ROOT / "scripts" / "disk_monitor.sh"
        self.assertTrue(monitor.exists(), f"Disk monitor script is missing: {monitor}")
        result = subprocess.run(["bash", str(monitor)], capture_output=True)
        self.assertEqual(result.returncode, 0, f"Disk monitor reported an issue: {result.stdout}")

    def test_governance_file_exists(self):
        gov_path = REPO_ROOT / "scripts" / "daily_governance.py"
        self.assertTrue(gov_path.exists(), f"Daily governance script is missing: {gov_path}")


if __name__ == "__main__":
    unittest.main()
