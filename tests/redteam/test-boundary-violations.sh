#!/usr/bin/env bash
# Red-team matrix (docs/security-tests.md §1, plan Phase 41).
#
# Every check below is an attempt to *violate* a guarantee Mujo makes. The
# expected result is always DENIED. A check that cannot run says so; a check
# that succeeds in breaking out is a failure, never a skip.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running Red-Team Boundary Violation Tests ==="

# denied <label> <command...> — the command is the attack; it must not succeed.
denied() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    fail "$label — the boundary was crossed"
  else
    pass "$label"
  fi
}

# ── graduated native sandbox ─────────────────────────────────────────────
if command -v mujo-sandbox-run >/dev/null 2>&1; then
  denied "sandbox -> vault mountpoint"        mujo-sandbox-run sh -c 'ls /run/mujo/vault'
  denied "sandbox -> vault container file"    mujo-sandbox-run sh -c 'cat /persist/secure/mujo-vault.luks'
  denied "sandbox -> /persist"                mujo-sandbox-run sh -c 'ls /persist'
  denied "sandbox -> user SSH private key"    mujo-sandbox-run sh -c 'cat "$HOME"/.ssh/id_*'
  denied "sandbox -> GnuPG keyring"           mujo-sandbox-run sh -c 'ls "$HOME"/.gnupg'
  denied "sandbox -> host NetworkManager secrets" \
    mujo-sandbox-run sh -c 'cat /etc/NetworkManager/system-connections/*'
  denied "sandbox -> credential broker without a grant" \
    mujo-sandbox-run sh -c 'test -S /run/mujo/secret.sock'

  # A sandbox that can see host processes can also ptrace or signal them.
  visible=$(mujo-sandbox-run sh -c 'ls /proc | grep -c "^[0-9]*$"' 2>/dev/null || echo 999)
  if [ "$visible" -le 5 ]; then
    pass "sandbox -> host process table (isolated, $visible visible)"
  else
    fail "sandbox -> host process table — $visible host processes visible"
  fi
else
  skip "mujo-sandbox-run is not installed — rebuild to run the sandbox escape checks"
fi

# ── quarantine MicroVM ───────────────────────────────────────────────────
if command -v mujo-quarantine-run >/dev/null 2>&1 &&
   systemctl is-active --quiet microvm@mujo-quarantine.service; then
  # The agent returns output but not exit status, so these probes report their
  # own verdict in the text they print.
  vm_denied() {
    local label="$1" target="$2" verdict
    verdict=$(mujo-quarantine-run sh -c \
      "ls '$target' >/dev/null 2>&1 && echo LEAK || echo CONTAINED" 2>/dev/null |
      tr -d '\r' | tail -1)
    if [ "$verdict" = "CONTAINED" ]; then
      pass "$label"
    else
      fail "$label — the boundary was crossed"
    fi
  }
  vm_denied "quarantine VM -> host /persist"       /persist
  vm_denied "quarantine VM -> vault mountpoint"    /run/mujo/vault
  vm_denied "quarantine VM -> host home"           "/home/$(id -un)"
  vm_denied "quarantine VM -> host trust registry" /var/lib/mujo-trust

  writable=$(mujo-quarantine-run sh -c \
    'touch /nix/store/redteam-probe >/dev/null 2>&1 && echo WRITABLE || echo READONLY' 2>/dev/null |
    tr -d '\r' | tail -1)
  if [ "$writable" = "READONLY" ]; then
    pass "quarantine VM -> write to the host Nix store"
  else
    fail "quarantine VM -> write to the host Nix store — the shared store is writable"
  fi
else
  skip "quarantine domain is not running — start it (mujo-quarantine-run true) for the VM escape checks"
fi

# ── privilege and trust escalation ───────────────────────────────────────
if [ -f /var/lib/mujo-trust/registry.json ]; then
  # The registry decides where every application runs. If the user can write it,
  # anything running as the user can promote itself out of quarantine.
  #
  # Asked as ownership and mode rather than `test -w`: root passes `test -w` on
  # everything, so the access check would report a breach every time the suite is
  # run under sudo while the invariant was in fact intact.
  reg_owner=$(stat -c '%U' /var/lib/mujo-trust/registry.json 2>/dev/null || echo "?")
  reg_mode=$(stat -c '%04a' /var/lib/mujo-trust/registry.json 2>/dev/null || echo "????")
  reg_group_w=$(( ${reg_mode: -2:1} & 2 ))
  reg_other_w=$(( ${reg_mode: -1} & 2 ))
  if [ "$reg_owner" = root ] && [ "$reg_group_w" -eq 0 ] && [ "$reg_other_w" -eq 0 ]; then
    pass "trust registry is root-owned and not group/other writable (mode $reg_mode)"
  else
    fail "trust registry is $reg_owner-owned, mode $reg_mode — an application could graduate itself"
  fi

  if [ "$(id -u)" -ne 0 ] && command -v mujo-trust >/dev/null 2>&1; then
    denied "unprivileged 'mujo-trust graduate'" mujo-trust graduate redteam-probe
  fi
else
  skip "trust registry not present — rebuild and launch something via mujo-trust run"
fi

# ── kernel surface ───────────────────────────────────────────────────────
# kexec is how a local root turns "I own this boot" into "I own the next one"
# without touching the bootloader.
if [ -r /proc/sys/kernel/kexec_load_disabled ]; then
  if [ "$(cat /proc/sys/kernel/kexec_load_disabled)" = "1" ]; then
    pass "kexec -> replace the running kernel (disabled)"
  else
    fail "kexec -> replace the running kernel — kexec_load_disabled is 0"
  fi
else
  skip "kernel.kexec_load_disabled is not exposed by this kernel"
fi

# kernel.dmesg_restrict gates on CAP_SYSLOG, which root holds. Running this as
# root would report a breach on a correctly configured system, so say what could
# not be tested instead of failing the invariant.
if [ "$(id -u)" -eq 0 ]; then
  skip "kernel ring buffer read — running as root, which holds CAP_SYSLOG; re-run as the user"
else
  denied "unprivileged read of the kernel ring buffer" sh -c 'dmesg'
fi

report
