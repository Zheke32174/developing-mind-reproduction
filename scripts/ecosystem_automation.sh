#!/usr/bin/env bash
# ecosystem_automation.sh — one cross-level heartbeat tying the whole stack together.
# Runs: health (system_doctor) -> verification (ryz/aesh/operator/tool test suites) ->
# operator proposal (read-only) -> "unknown new data" scan -> dated report.
# Safe/read-only by default (no outward action; operator only PROPOSES). set -uo pipefail.
#
# Wire it (opt-in, operator runs these — this script never self-installs):
#   WSL/cron:   (crontab -e) */30 * * * * /mnt/c/.../scripts/ecosystem_automation.sh >>~/eco.log 2>&1
#   WSL/systemd: a .timer calling this (user unit)
#   Windows:    schtasks /create /tn ecosystem /tr "wsl -d Ubuntu -- bash <path>" /sc hourly
#   Termux:     ~/.termux/boot hook -> ssh wsl-bridge bash <path>   (when phone online)
set -uo pipefail

R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
BUN="${BUN:-$HOME/.bun/bin/bun}"
LOGDIR="${ECO_LOGDIR:-$HOME/lamp/logs}"; mkdir -p "$LOGDIR" 2>/dev/null || LOGDIR=/tmp
STAMP="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || echo unknown)"
REPORT="$LOGDIR/ecosystem-$STAMP.md"
RED=0

say() { echo "$1"; echo "$1" >> "$REPORT"; }
sec() { echo; echo "## $1"; echo -e "\n## $1" >> "$REPORT"; }

echo "# Ecosystem heartbeat $STAMP" > "$REPORT"

sec "Health (system_doctor)"
if bash "$R/scripts/system_doctor.sh" >/tmp/eco_doctor.txt 2>&1; then say "doctor: HEALTHY"; else say "doctor: NEEDS ATTENTION"; RED=1; fi
grep -E '✓|✗|!|STATUS' /tmp/eco_doctor.txt | sed 's/^/  /' | tee -a "$REPORT"

sec "Verification (test suites)"
run_suite() { local name="$1" file="$2"; if [ -f "$file" ]; then
    if "$BUN" "$file" >/tmp/eco_$name.txt 2>&1; then say "  $name: $(grep -oE '[0-9]+ (passed|tests)' /tmp/eco_$name.txt | head -1) ✓";
    else say "  $name: FAILING ✗"; RED=1; fi
  fi; }
run_suite ryz      "$R/ryz/bun/test/run_tests.ts"
run_suite aesh     "$R/ryz/aesh/test/run_tests.ts"
run_suite operator "$R/operator/test/run_tests.ts"
if bash "$R/ryz/tools/ab_test.sh" >/tmp/eco_ab.txt 2>&1; then say "  tool A/B parity: ✓"; else say "  tool A/B parity: ✗"; RED=1; fi

sec "Operator (next brick — proposal only, no action)"
"$BUN" "$R/operator/operator.ts" status 2>&1 | sed 's/^/  /' | tee -a "$REPORT"

sec "Unknown-new-data scan"
# uncommitted changes in the repo + recently-modified files under the repo (last 24h)
changes=$(git -C "$R" status --porcelain 2>/dev/null | wc -l)
say "  repo uncommitted changes: $changes"
recent=$(find "$R" -type f -mmin -1440 -not -path '*/.git/*' -not -path '*/dist/*' 2>/dev/null | wc -l)
say "  files modified in last 24h: $recent"
# tunnel reachability (termux) — surfaces when new device data could flow
if timeout 8 ssh -o ConnectTimeout=5 -o BatchMode=yes termux-remote 'echo ok' >/dev/null 2>&1; then say "  termux: reachable (device data path open)"; else say "  termux: offline"; fi

sec "Summary"
[ "$RED" -eq 0 ] && say "STATUS: GREEN — stack healthy, verified, operator idle/proposing." || say "STATUS: ATTENTION — see sections above."
echo "report: $REPORT"
exit "$RED"
