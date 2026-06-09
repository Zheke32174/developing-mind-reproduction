# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)
import json
import os
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(os.environ.get("DEVMIND_REPRO_DIR", Path(__file__).resolve().parent.parent))
# Prefer repo-local state for portability in this substrate
RALPH_STATE = REPO_ROOT / ".gemini" / "ralph" / "state.json"

if not RALPH_STATE.exists():
    GEMINI_DIR = Path(os.environ.get("DEVMIND_GEMINI_DIR", Path.home() / ".gemini"))
    potential_gemini_dirs = [
        Path.home() / ".gemini",
        Path("/mnt/c/Users") / os.environ.get("USER", "Fixxia") / ".gemini"
    ]
    for d in potential_gemini_dirs:
        if d.exists():
            GEMINI_DIR = d
            break
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

    def test_no_orphaned_backups(self):
        """Ensure no .bak files exist outside the backups directory."""
        orphaned = []
        backup_dir = REPO_ROOT / "scripts" / "backups"
        for root, dirs, files in os.walk(REPO_ROOT):
            if Path(root) == backup_dir or backup_dir in Path(root).parents:
                continue
            if ".git" in Path(root).parts:
                continue
            for f in files:
                if ".bak" in f:
                    orphaned.append(os.path.join(root, f))
        self.assertEqual(len(orphaned), 0, f"Found orphaned backup files: {orphaned}")


if __name__ == "__main__":
    unittest.main()
