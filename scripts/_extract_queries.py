#!/usr/bin/env python3
"""Extract numbered queries from an 'Active Queries' section in a spec.md file."""
import re
import sys

if len(sys.argv) < 2:
    sys.exit(1)

spec_file = sys.argv[1]
try:
    with open(spec_file) as f:
        content = f.read()
except OSError:
    sys.exit(1)

in_section = False
queries = []
for line in content.splitlines():
    if re.search(r'## Active Queries', line, re.IGNORECASE):
        in_section = True
        continue
    if in_section and re.match(r'^##', line):
        break
    if in_section:
        # Match: 1. "query" or 1. query
        m = re.match(r'^\d+\.\s+"?(.+?)"?\s*$', line)
        if m:
            q = m.group(1).strip().strip('"').strip("'")
            if q:
                queries.append(q)

for q in queries:
    print(q)
