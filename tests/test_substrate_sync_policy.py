from __future__ import annotations

import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "substrate-sync.sh"


class SubstrateSyncPolicyTests(unittest.TestCase):
    def run_script(self, **overrides: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            env = os.environ.copy()
            env.update(
                {
                    "DEVMIND_REPRO_DIR": directory,
                    "DEVMIND_NO_PUSH": "0",
                    "DEVMIND_ALLOW_PUSH": "0",
                }
            )
            env.update(overrides)
            return subprocess.run(
                ["bash", str(SCRIPT)],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env=env,
            )

    def test_publication_is_disabled_by_default(self) -> None:
        result = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertIn("Repository publication disabled", result.stdout)

    def test_protected_default_branch_is_refused(self) -> None:
        result = self.run_script(DEVMIND_ALLOW_PUSH="1", DEVMIND_PUSH_BRANCH="master")
        self.assertEqual(result.returncode, 0)
        self.assertIn("protected default branch is forbidden", result.stdout)

    def test_push_is_scoped_to_the_named_proposal_branch(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("git push origin master", text)
        self.assertNotIn("git push origin main", text)
        self.assertIn('git push origin "HEAD:refs/heads/$PUSH_BRANCH"', text)
        self.assertIn('CURRENT_BRANCH" != "$PUSH_BRANCH', text)


if __name__ == "__main__":
    unittest.main()
