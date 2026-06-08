#!/usr/bin/env bash
# wordfreq (ORIGINAL bash) — kept untouched for A/B testing against the ryz port.
# Whitespace-splits a file, counts word frequencies, prints "word count" sorted by word.
set -uo pipefail
f="${1:-}"
if [ -z "$f" ]; then echo "usage: wordfreq <file>"; exit 2; fi
LC_ALL=C tr -s '[:space:]' '\n' < "$f" | grep -v '^$' | LC_ALL=C sort | uniq -c \
  | awk '{ print $2" "$1 }' | LC_ALL=C sort
