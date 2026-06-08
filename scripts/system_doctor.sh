#!/usr/bin/env bash
# system_doctor.sh — cross-level health check + light self-heal for the whole stack.
# Levels: WSL (DNS/systemd) -> Gentoo container -> Termux tunnel -> ryz/aesh toolchain.
# Read-only by default; pass --heal to apply safe, idempotent fixes (DNS drop-in).
# Exit 0 = all green, 1 = at least one RED.  set -uo pipefail (no -e: never abort mid-scan).
set -uo pipefail

HEAL=0; [ "${1:-}" = "--heal" ] && HEAL=1
RED=0; WARN=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; RED=$((RED+1)); }
hdr()  { printf '\n\033[36m== %s ==\033[0m\n' "$1"; }

RYZ_HOME="/mnt/c/Users/Fixxia/developing-mind-reproduction/ryz"
BUN="${BUN:-$HOME/.bun/bin/bun}"; [ -x "$BUN" ] || BUN=/home/fixxia/.bun/bin/bun

hdr "WSL host"
if systemctl is-system-running >/dev/null 2>&1; then ok "systemd: running"
else
  state=$(systemctl is-system-running 2>/dev/null || echo unknown)
  if [ "$state" = "degraded" ]; then warn "systemd: degraded ($(systemctl --failed --no-legend 2>/dev/null | wc -l) failed)"
  else bad "systemd: $state"; fi
fi

hdr "DNS"
if getent hosts github.com >/dev/null 2>&1; then ok "resolution works (github.com)"
else
  bad "DNS resolution FAILED"
  if [ "$HEAL" = 1 ]; then
    echo "    [heal] writing resolved->dnscrypt drop-in"
    sudo mkdir -p /etc/systemd/resolved.conf.d
    sudo sh -c 'printf "%s\n" "[Resolve]" "DNS=127.0.2.1" "Domains=~." "DNSStubListener=yes" > /etc/systemd/resolved.conf.d/10-dnscrypt.conf'
    sudo systemctl restart systemd-resolved && sleep 1
    getent hosts github.com >/dev/null 2>&1 && echo "    [heal] DNS restored" || echo "    [heal] DNS still failing"
  fi
fi

hdr "Gentoo container"
NSPAWN_PID=$(pgrep -x systemd-nspawn | head -1 || true)
if [ -n "$NSPAWN_PID" ]; then
  CHILD=$(pgrep -P "$NSPAWN_PID" | head -1 || true)
  ok "nspawn running (pid $NSPAWN_PID, container pid ${CHILD:-?})"
else
  if systemctl is-active pleiades-container.service >/dev/null 2>&1; then
    warn "nspawn not live but pleiades-container.service active (oneshot launcher; ok if intentional)"
  else warn "no nspawn container running"; fi
fi

hdr "Termux tunnel"
if timeout 12 ssh -o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=accept-new termux-lab 'echo ok' >/dev/null 2>&1; then
  ok "termux-lab reachable (192.168.1.233:8022)"
else
  warn "termux-lab unreachable (phone off-network/asleep — external dependency)"
fi

hdr "ryz / aesh toolchain"
if [ -x "$BUN" ]; then ok "real bun: $("$BUN" --version)"; else bad "real bun missing (~/.bun/bin/bun)"; fi
if [ -f "$RYZ_HOME/bun/test/run_tests.ts" ] && [ -x "$BUN" ]; then
  if "$BUN" "$RYZ_HOME/bun/test/run_tests.ts" >/tmp/ryz_doctor.log 2>&1; then
    ok "ryz interpreter tests: $(grep -oE '[0-9]+ passed' /tmp/ryz_doctor.log | head -1)"
  else bad "ryz interpreter tests FAILING (see /tmp/ryz_doctor.log)"; fi
fi
if [ -f "$RYZ_HOME/aesh/test/run_tests.ts" ] && [ -x "$BUN" ]; then
  if "$BUN" "$RYZ_HOME/aesh/test/run_tests.ts" >/tmp/aesh_doctor.log 2>&1; then
    ok "aesh shell tests: $(grep -oE '[0-9]+ passed' /tmp/aesh_doctor.log | head -1)"
  else bad "aesh shell tests FAILING (see /tmp/aesh_doctor.log)"; fi
fi
# warn if the /usr/local/bin/bun->node shim is shadowing real bun
if command -v bun >/dev/null 2>&1; then
  if ! head -c4 "$(command -v bun)" 2>/dev/null | grep -q $'\x7fELF'; then
    warn "PATH 'bun' is the node shim ($(command -v bun)); use bin/ryz or ~/.bun/bin/bun"
  fi
fi

hdr "Summary"
printf '  RED=%d  WARN=%d\n' "$RED" "$WARN"
[ "$RED" -eq 0 ] && { echo "  STATUS: HEALTHY"; exit 0; } || { echo "  STATUS: NEEDS ATTENTION"; exit 1; }
