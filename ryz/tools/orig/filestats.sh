#!/usr/bin/env bash
# filestats (ORIGINAL bash) — kept untouched for A/B testing against the ryz port.
# Reports: total lines, non-empty (after trim) lines, longest raw line length.
set -uo pipefail
shopt -s extglob
f="${1:-}"
if [ -z "$f" ]; then echo "usage: filestats <file>"; exit 2; fi

mapfile -t lines < "$f"
total=${#lines[@]}
nonempty=0
longest=0
for l in "${lines[@]}"; do
  t="${l##+([[:space:]])}"; t="${t%%+([[:space:]])}"
  [ -n "$t" ] && nonempty=$((nonempty+1))
  [ "${#l}" -gt "$longest" ] && longest=${#l}
done
echo "lines=$total nonempty=$nonempty longest=$longest"
