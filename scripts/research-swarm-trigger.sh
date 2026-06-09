#!/usr/bin/env bash
# research-swarm-trigger.sh — Trigger Gemini research swarm on active conductor tracks
# Reads spec.md from each track, extracts queries, calls Gemini, appends to log.
set -uo pipefail

CONDUCTOR_DIR="/mnt/c/Users/Fixxia/conductor"
SWARM_LOG="/home/fixxia/lamp/logs/research-swarm.log"
FINDINGS_FILE="/home/fixxia/ryz-build/state/research-findings.json"
NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$(dirname "${SWARM_LOG}")"
mkdir -p "$(dirname "${FINDINGS_FILE}")"

log() {
    local msg="[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"
    echo "${msg}" | tee -a "${SWARM_LOG}"
}

log "=== research-swarm-trigger start ==="

if [[ ! -d "${CONDUCTOR_DIR}/tracks" ]]; then
    log "ERROR: conductor tracks dir not found at ${CONDUCTOR_DIR}/tracks"
    exit 1
fi

GEMINI_BIN=$(which gemini 2>/dev/null || echo "/home/linuxbrew/.linuxbrew/bin/gemini")
if [[ ! -x "${GEMINI_BIN}" ]]; then
    log "ERROR: gemini not found at ${GEMINI_BIN}"
    exit 1
fi

NEW_FINDINGS=()
QUOTA_EXHAUSTED=0

# Iterate over all track directories
for track_dir in "${CONDUCTOR_DIR}/tracks"/*/; do
    spec_file="${track_dir}spec.md"
    track_name=$(basename "${track_dir}")

    if [[ ! -f "${spec_file}" ]]; then
        log "SKIP ${track_name}: no spec.md"
        continue
    fi

    log "Processing track: ${track_name}"

    # Extract queries from the ## Active Queries section
    # Format: numbered list lines like: 1. "query text"
    QUERIES=$(python3 /mnt/c/Users/Fixxia/developing-mind-reproduction/scripts/_extract_queries.py "${spec_file}" 2>/dev/null)

    if [[ -z "${QUERIES}" ]]; then
        log "  No queries found in ${track_name}/spec.md"
        continue
    fi

    while IFS= read -r QUERY; do
        [[ -z "${QUERY}" ]] && continue

        if [[ "${QUOTA_EXHAUSTED}" -eq 1 ]]; then
            log "  SKIP (quota exhausted): ${QUERY:0:60}"
            continue
        fi

        log "  Query: ${QUERY:0:80}..."

        PROMPT="Research query: ${QUERY}

Provide a concise technical summary (max 300 words) with:
- Key finding
- Relevance to RYZ/Fixxia ecosystem
- Specific actionable next step

Output as JSON: {\"query\": \"...\", \"finding\": \"...\", \"relevance\": \"...\", \"action\": \"...\"}"

        RESPONSE=$(timeout 120s "${GEMINI_BIN}" --yolo --skip-trust -p "${PROMPT}" 2>&1)
        EXIT_CODE=$?

        if [[ ${EXIT_CODE} -eq 124 ]]; then
            log "  TIMEOUT for query: ${QUERY:0:60}"
            continue
        fi

        # Detect quota exhaustion
        if echo "${RESPONSE}" | grep -qiE "quota|rate.?limit|429|exceeded"; then
            log "  Gemini quota exhausted — stopping queries"
            QUOTA_EXHAUSTED=1
            continue
        fi

        if [[ ${EXIT_CODE} -ne 0 ]]; then
            log "  Gemini error (exit ${EXIT_CODE}): ${RESPONSE:0:100}"
            continue
        fi

        # Try to extract JSON from response
        FINDING_JSON=$(echo "${RESPONSE}" | python3 -c "
import sys, json, re

raw = sys.stdin.read()
# Try direct parse first
try:
    obj = json.loads(raw.strip())
    print(json.dumps(obj))
    sys.exit(0)
except Exception:
    pass
# Try to find JSON block
m = re.search(r'\{[^{}]*\"query\"[^{}]*\"finding\"[^{}]*\}', raw, re.DOTALL)
if m:
    try:
        obj = json.loads(m.group(0))
        print(json.dumps(obj))
        sys.exit(0)
    except Exception:
        pass
# Fall back to wrapping entire response
print(json.dumps({'query': '${QUERY//\'/\'\\\'\'}', 'finding': raw[:500], 'relevance': 'unknown', 'action': 'manual review'}))
" 2>/dev/null || echo "{\"query\": \"${QUERY:0:100}\", \"finding\": \"parse error\", \"relevance\": \"unknown\", \"action\": \"review raw log\"}")

        # Annotate with track and timestamp
        ANNOTATED=$(echo "${FINDING_JSON}" | python3 -c "
import json, sys
obj = json.load(sys.stdin)
obj['track'] = '${track_name}'
obj['timestamp'] = '${NOW_ISO}'
print(json.dumps(obj))
" 2>/dev/null || echo "${FINDING_JSON}")

        log "  Finding: $(echo "${ANNOTATED}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('finding','')[:100])" 2>/dev/null)"

        NEW_FINDINGS+=("${ANNOTATED}")

    done <<< "${QUERIES}"
done

log "Total new findings: ${#NEW_FINDINGS[@]}"

if [[ "${#NEW_FINDINGS[@]}" -gt 0 ]]; then
    # Merge new findings into research-findings.json
    python3 -c "
import json, sys

findings_file = '${FINDINGS_FILE}'
new_findings_raw = sys.stdin.read().strip()

# Parse new findings (one JSON per line)
new_findings = []
for line in new_findings_raw.splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        new_findings.append(json.loads(line))
    except Exception:
        pass

# Load existing
existing = []
try:
    with open(findings_file) as f:
        existing = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    pass

existing.extend(new_findings)

with open(findings_file, 'w') as f:
    json.dump(existing, f, indent=2)
print(f'Wrote {len(new_findings)} new findings to {findings_file} (total: {len(existing)})')
" <<< "$(printf '%s\n' "${NEW_FINDINGS[@]}")" 2>&1 | tee -a "${SWARM_LOG}"
fi

log "=== research-swarm-trigger complete ==="
