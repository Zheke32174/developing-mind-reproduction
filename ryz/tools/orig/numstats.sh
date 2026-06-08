#!/usr/bin/env bash
# numstats (ORIGINAL bash) — kept for A/B testing against the ryz port.
# Reads integers (one per line, blank lines ignored), prints count/sum/min/max.
set -uo pipefail
f="${1:-}"
if [ -z "$f" ]; then echo "usage: numstats <file>"; exit 2; fi
awk 'NF>0 { v=$1+0; c++; s+=v; if(c==1){mn=v;mx=v} else {if(v<mn)mn=v; if(v>mx)mx=v} }
     END { if(c==0) print "count=0 sum=0 min=0 max=0"; else printf "count=%d sum=%d min=%d max=%d\n", c, s, mn, mx }' "$f"
