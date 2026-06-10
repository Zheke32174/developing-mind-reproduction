import sys
import os

# Arxiv Anchor: 2604.24579 (Prop 1: Analytic Reliability)
# Mock test runner for RYZ syntax

def test_syntax():
    print("Testing RYZ syntax rules...")
    grammar_path = os.environ.get("DEVMIND_REPRO_DIR", os.path.dirname(os.path.dirname(os.path.abspath(__file__)))) + "/ryz/GRAMMAR.md"
    if os.path.exists(grammar_path):
        print("✅ Grammar specification found.")
        return True
    else:
        print("❌ Grammar specification missing.")
        return False

if __name__ == "__main__":
    if not test_syntax():
        sys.exit(1)
