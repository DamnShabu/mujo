#!/usr/bin/env bash
# SEC-006 & SEC-007: swap must not be able to hold recoverable plaintext, and
# crash dumps must never reach disk.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running Swap & Memory Leakage Tests ==="

# 1. Every active swap device must be volatile (zram) or dm-crypt backed.
#    A plain partition survives power-off with whatever pages it holds.
swap_checked=0
while read -r dev _; do
  case "$dev" in
    Filename | "") continue ;;
  esac
  swap_checked=$((swap_checked + 1))
  name=${dev#/dev/}
  if [[ $name == zram* ]]; then
    pass "$dev is zram (RAM-backed, gone at power-off)"
  elif [ -e "/sys/class/block/$name/dm/uuid" ] &&
    grep -q '^CRYPT-' "/sys/class/block/$name/dm/uuid" 2>/dev/null; then
    pass "$dev is a dm-crypt mapping (encrypted swap)"
  else
    fail "$dev is unencrypted persistent swap — pages survive power-off in plaintext"
  fi
done < /proc/swaps
[ "$swap_checked" -eq 0 ] && skip "No swap devices are active"

# 2. Hibernation writes the whole of RAM to the resume device. With random-key
#    swap encryption there is nothing to resume from, so resume must be unset.
if grep -qs 'resume=' /proc/cmdline; then
  fail "resume= is on the kernel command line — hibernation image lands on swap"
else
  pass "No resume device configured (no hibernation image on disk)"
fi

# 3. Core dumps must not be written to storage.
if [ -r /etc/systemd/coredump.conf ] || compgen -G "/etc/systemd/coredump.conf.d/*" >/dev/null; then
  if grep -rhqs '^ *Storage *= *none' /etc/systemd/coredump.conf /etc/systemd/coredump.conf.d/ 2>/dev/null; then
    pass "systemd-coredump is configured with Storage=none"
  else
    fail "systemd-coredump does not set Storage=none — dumps reach disk"
  fi
else
  fail "No systemd-coredump configuration found"
fi

# 4. Nothing left behind from before the policy was applied.
mapfile -t cores < <(
  find /persist -maxdepth 6 \( -name 'core.*' -o -name '*.core' \) -type f 2>/dev/null
  find /var/lib/systemd/coredump -type f 2>/dev/null
)
if [ "${#cores[@]}" -eq 0 ]; then
  pass "No core dumps on persistent storage"
else
  fail "${#cores[@]} core dump(s) on persistent storage — each is a plaintext RAM image"
  list_findings "${cores[@]}"
fi

report
