# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)
import unittest
import subprocess
import os
import json

class TestEcosystem(unittest.TestCase):
    
    def test_ralph_loop_active(self):
        state_file = "/home/fixxia/.gemini/ralph/state.json"
        self.assertTrue(os.path.exists(state_file), "Ralph state file does not exist")
        with open(state_file, 'r') as f:
            state = json.load(f)
            self.assertTrue(state.get('active', False), "Ralph loop is not marked as active")
            
    def test_subconscious_daemon_executable(self):
        daemon_path = "/mnt/c/Users/Fixxia/developing-mind-reproduction/scripts/subconscious-daemon.sh"
        self.assertTrue(os.path.exists(daemon_path), "Subconscious daemon script is missing")
        self.assertTrue(os.access(daemon_path, os.X_OK), "Subconscious daemon script is not executable")
        
    def test_disk_space_monitor_healthy(self):
        # We run the script to see if it exits with 0 (healthy)
        result = subprocess.run(["bash", "/mnt/c/Users/Fixxia/developing-mind-reproduction/scripts/disk_monitor.sh"], capture_output=True)
        self.assertEqual(result.returncode, 0, f"Disk monitor reported an issue: {result.stdout}")

    def test_governance_file_exists(self):
        gov_path = "/mnt/c/Users/Fixxia/developing-mind-reproduction/scripts/daily_governance.py"
        self.assertTrue(os.path.exists(gov_path), "Daily governance script is missing")

if __name__ == '__main__':
    unittest.main()
