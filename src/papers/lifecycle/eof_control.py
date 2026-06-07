"""
Developing Mind — Lifecycle Control (Substrate Implementation)
Role: Programmatic session termination and Ctrl-D compliance.
Arxiv Anchor: 2410.02724 (Prop 3.2: Sequence Capture) - Exit conditions.
"""

import subprocess

def send_eof_to_tmux(pane_id):
    subprocess.run(["tmux", "send-keys", "-t", pane_id, "C-d"])
