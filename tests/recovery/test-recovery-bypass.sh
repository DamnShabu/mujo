#!/usr/bin/env bash
# SEC-011: recovery and boot-tampering bypass attempts (plan Phases 27-28).
#
# The guarantee under test: an attacker at the keyboard must not be able to
# reach a root shell or an unauthenticated recovery path, and a recovery path
# must still exist for the owner. Both halves matter -- removing recovery
# entirely turns a failed mount into an unrecoverable machine.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running Recovery & Boot Tampering Bypass Tests ==="

# 1. The single setting that decides whether the emergency console hands out a
#    root shell without asking. Its *absence* is the fix.
if grep -rqs 'SYSTEMD_SULOGIN_FORCE' /etc/systemd/ 2>/dev/null; then
  fail "SYSTEMD_SULOGIN_FORCE is set — the emergency console would skip authentication"
else
  pass "SYSTEMD_SULOGIN_FORCE is not set — emergency console demands the root password"
fi

# 2. ...and the recovery path still has to be there to demand it.
if systemctl cat emergency.service >/dev/null 2>&1; then
  pass "emergency.target is available (recovery path not removed)"
else
  fail "emergency.service is missing — a failed mount would have no console to diagnose from"
fi

# 3. Hibernation writes the contents of RAM, unlocked vault included, to swap.
if grep -qw nohibernate /proc/cmdline; then
  pass "hibernation is disabled on the kernel command line"
else
  fail "'nohibernate' is absent from /proc/cmdline — RAM could be written to swap on suspend"
fi

# 4. Bootloader state. Which check applies depends on which loader is live, and
#    the repo ships GRUB by default (see AGENTS.md).
if [ -d /sys/firmware/efi/efivars ] && command -v bootctl >/dev/null 2>&1 &&
   bootctl status >/dev/null 2>&1 && [ -d /boot/loader/entries ]; then
  if grep -rqs '^editor[[:space:]]*no' /boot/loader/loader.conf; then
    pass "systemd-boot kernel command-line editing is disabled"
  else
    fail "systemd-boot allows command-line editing — 'e' then init=/bin/sh is a root shell"
  fi

  sb=$(bootctl status 2>/dev/null | grep -i 'Secure Boot:' | head -1 || true)
  case "$sb" in
    *enabled*) pass "Secure Boot is enabled" ;;
    *)         skip "Secure Boot is not enabled (security.mujo.boot.secureBoot = false by design; see docs/physical-security.md §2a)" ;;
  esac
else
  skip "systemd-boot is not the active loader — GRUB is live, so physical access is root access (AGENTS.md)"
fi

# 5. Kernel lockdown, when the boot chain is signed, is what stops root from
#    reading the vault key straight out of kernel memory.
if [ -r /sys/kernel/security/lockdown ]; then
  mode=$(sed -n 's/.*\[\(.*\)\].*/\1/p' /sys/kernel/security/lockdown)
  case "$mode" in
    integrity | confidentiality) pass "kernel lockdown is active ($mode)" ;;
    *) skip "kernel lockdown is '$mode' — it takes effect with Secure Boot, which is off by design" ;;
  esac
else
  skip "kernel lockdown is not exposed by this kernel"
fi

# 6. An older generation is a legitimate rollback for the owner and an
#    unauthenticated downgrade path for an attacker. It must exist; the
#    protection against abusing it is Secure Boot plus a firmware password,
#    not removing it.
if [ -d /nix/var/nix/profiles ] && [ -e /nix/var/nix/profiles/system ]; then
  gens=$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' | wc -l)
  pass "$gens bootable generations available for rollback"
else
  fail "no system profile generations found — rollback would be impossible"
fi

report
