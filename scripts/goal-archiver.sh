#!/usr/bin/env bash
# goal-archiver.sh — Archive completed Task Master tasks into long-term memory
# Reads tasks.json, groups done tasks by week, summarizes via Gemini (optional),
# writes to goal-archive.json and engram-archive.json.
# Does NOT remove tasks from tasks.json.
set -uo pipefail

TASKS_JSON="/workspaces/gentoo/.taskmaster/tasks/tasks.json"
ARCHIVE_DIR="/home/fixxia/ryz-build/state"
ARCHIVE_FILE="${ARCHIVE_DIR}/goal-archive.json"
ENGRAM_FILE="${ARCHIVE_DIR}/engram-archive.json"
LOG_FILE="/home/fixxia/lamp/logs/goal-archiver.log"
CUTOFF_DAYS=7
NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Ensure required directories exist
mkdir -p "${ARCHIVE_DIR}"
mkdir -p "$(dirname "${LOG_FILE}")"

log() {
    local msg="[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"
    echo "${msg}" | tee -a "${LOG_FILE}"
}

log "=== goal-archiver start ==="

# Validate input
if [[ ! -f "${TASKS_JSON}" ]]; then
    log "ERROR: tasks.json not found at ${TASKS_JSON}"
    exit 1
fi

# Load existing archive to find already-archived task IDs
ALREADY_ARCHIVED_IDS="[]"
if [[ -f "${ARCHIVE_FILE}" ]]; then
    ALREADY_ARCHIVED_IDS=$(python3 -c "
import json, sys
try:
    with open('${ARCHIVE_FILE}') as f:
        data = json.load(f)
    ids = []
    for batch in data.get('batches', []):
        ids.extend(batch.get('task_ids', []))
    print(json.dumps(ids))
except Exception as e:
    print('[]')
" 2>/dev/null || echo "[]")
fi
log "Already archived IDs: ${ALREADY_ARCHIVED_IDS}"

# Extract done tasks older than CUTOFF_DAYS (or all done tasks if updatedAt missing)
BATCHES_JSON=$(python3 -c "
import json, sys, datetime

tasks_file = '${TASKS_JSON}'
cutoff_days = ${CUTOFF_DAYS}
already_archived = ${ALREADY_ARCHIVED_IDS}
already_set = set(str(i) for i in already_archived)

with open(tasks_file) as f:
    data = json.load(f)

# Support both flat list and nested master.tasks
if isinstance(data, list):
    tasks = data
elif isinstance(data, dict) and 'master' in data:
    tasks = data['master'].get('tasks', [])
elif isinstance(data, dict) and 'tasks' in data:
    tasks = data['tasks']
else:
    tasks = []

now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
cutoff = now - datetime.timedelta(days=cutoff_days)

# Filter: done, not already archived, older than cutoff (or no date)
to_archive = []
for t in tasks:
    if t.get('status') != 'done':
        continue
    tid = str(t.get('id', ''))
    if tid in already_set:
        continue
    updated_raw = t.get('updatedAt', '')
    if updated_raw:
        try:
            updated = datetime.datetime.fromisoformat(updated_raw.replace('Z', '+00:00')).replace(tzinfo=None)
            if updated > cutoff:
                # Recent — skip for now
                continue
        except ValueError:
            pass  # If unparseable, include it
    to_archive.append(t)

# Group by ISO week
from collections import defaultdict
weeks = defaultdict(list)
for t in to_archive:
    updated_raw = t.get('updatedAt', '')
    if updated_raw:
        try:
            dt = datetime.datetime.fromisoformat(updated_raw.replace('Z', '+00:00')).replace(tzinfo=None)
            week_key = dt.strftime('%Y-W%W')
        except ValueError:
            week_key = 'unknown'
    else:
        week_key = 'unknown'
    weeks[week_key].append(t)

result = {}
for week, task_list in sorted(weeks.items()):
    result[week] = [
        {
            'id': str(t.get('id','')),
            'title': t.get('title',''),
            'description': t.get('description',''),
            'updatedAt': t.get('updatedAt','')
        }
        for t in task_list
    ]

print(json.dumps(result))
" 2>/dev/null)

if echo "${BATCHES_JSON}" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    log "Parsed task batches OK"
else
    log "ERROR parsing task batches: ${BATCHES_JSON}"
    exit 1
fi

WEEK_COUNT=$(echo "${BATCHES_JSON}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))")
log "Weeks to archive: ${WEEK_COUNT}"

if [[ "${WEEK_COUNT}" -eq 0 ]]; then
    log "No new tasks to archive. Done."
    exit 0
fi

# For each week, optionally summarize via Gemini
FINAL_BATCHES=$(python3 -c "
import json, sys, subprocess, os, shutil

batches_raw = '''${BATCHES_JSON}'''
batches = json.loads(batches_raw)
gemini_bin = '/home/fixxia/.local/bin/gemini-clean'
results = []

for week, tasks in sorted(batches.items()):
    task_ids = [t['id'] for t in tasks]
    titles_block = '\n'.join(f'- [{t[\"id\"]}] {t[\"title\"]}: {t[\"description\"][:120]}' for t in tasks)

    summary = None
    if os.path.exists(gemini_bin):
        prompt = (
            'Summarize these completed development tasks as a single paragraph for long-term memory:\n'
            + titles_block
            + '\nOutput: one paragraph, max 200 words.'
        )
        try:
            result = subprocess.run(
                [gemini_bin, '--yolo', '--skip-trust', '-p', prompt],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode == 0 and result.stdout.strip():
                summary = result.stdout.strip()[:1000]
        except (subprocess.TimeoutExpired, FileNotFoundError, Exception):
            pass

    if not summary:
        # Quota exhausted or Gemini unavailable — use raw titles
        summary = 'Raw task archive (no Gemini summary): ' + '; '.join(
            f'[{t[\"id\"]}] {t[\"title\"]}' for t in tasks
        )

    results.append({
        'week': week,
        'task_count': len(tasks),
        'summary': summary,
        'task_ids': task_ids
    })

print(json.dumps(results))
" 2>/dev/null)

if ! echo "${FINAL_BATCHES}" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    log "ERROR generating batch summaries: ${FINAL_BATCHES}"
    exit 1
fi

log "Generated summaries for ${WEEK_COUNT} week(s)"

# Merge with existing archive
python3 -c "
import json

archive_file = '${ARCHIVE_FILE}'
now_iso = '${NOW_ISO}'
new_batches_raw = '''${FINAL_BATCHES}'''
new_batches = json.loads(new_batches_raw)

# Load existing
existing = {'archived_at': now_iso, 'batches': []}
try:
    with open(archive_file) as f:
        existing = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    pass

# Merge: add new batches, update archived_at
existing_weeks = {b['week'] for b in existing.get('batches', [])}
for b in new_batches:
    if b['week'] not in existing_weeks:
        existing.setdefault('batches', []).append(b)
    else:
        # Merge task_ids for same week
        for eb in existing['batches']:
            if eb['week'] == b['week']:
                eb['task_ids'] = list(set(eb['task_ids'] + b['task_ids']))
                eb['task_count'] = len(eb['task_ids'])
existing['archived_at'] = now_iso

with open(archive_file, 'w') as f:
    json.dump(existing, f, indent=2)
print('wrote', archive_file)
" 2>&1 | tee -a "${LOG_FILE}"

# Write Engram-compatible format
python3 -c "
import json

archive_file = '${ARCHIVE_FILE}'
engram_file = '${ENGRAM_FILE}'
now_iso = '${NOW_ISO}'

with open(archive_file) as f:
    data = json.load(f)

engram_memories = []
for b in data.get('batches', []):
    engram_memories.append({
        'kind': 'lesson',
        'content': b['summary'],
        'tags': ['taskmaster', 'completed-tasks', 'week:' + b['week']],
        'meta': {
            'week': b['week'],
            'task_count': b['task_count'],
            'task_ids': b['task_ids'],
            'archived_at': now_iso,
            'source': 'goal-archiver'
        }
    })

with open(engram_file, 'w') as f:
    json.dump(engram_memories, f, indent=2)
print('wrote', engram_file)
" 2>&1 | tee -a "${LOG_FILE}"

log "=== goal-archiver complete ==="
