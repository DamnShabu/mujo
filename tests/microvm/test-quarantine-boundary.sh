#!/usr/bin/env bash
# SEC-005: QUARANTINE must be a virtual machine boundary, not a namespace one.
#
# docs/application-trust.md promises that a quarantined application runs behind
# KVM. Until this file existed, that promise was only ever checked by reading
# the module. Every assertion below asks the running system instead.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
UNIT="microvm@mujo-quarantine.service"

echo "=== Running Quarantine MicroVM Boundary Tests ==="

# 1. KVM has to be usable at all, or quarantine silently has no home.
if [ -c /dev/kvm ]; then
  pass "/dev/kvm is present"
else
  fail "/dev/kvm is absent — the quarantine domain cannot start on this machine"
fi

# 2. The vsock transport the control channel and the Wayland bridge both ride on.
if [ -c /dev/vhost-vsock ]; then
  pass "/dev/vhost-vsock is present (vhost_vsock loaded)"
else
  fail "/dev/vhost-vsock is absent — load vhost_vsock, then re-run"
fi

if ! command -v mujo-quarantine-run >/dev/null 2>&1; then
  skip "mujo-quarantine-run is not installed — rebuild to run the containment checks"
  report
  exit $?
fi

# 3. The unit must exist. A missing unit means mujo-quarantine-run would fail
#    open-ended rather than isolate anything.
if systemctl cat "$UNIT" >/dev/null 2>&1; then
  pass "$UNIT is defined"
else
  fail "$UNIT is not defined — the microvm host module is not in the host config"
fi

if ! systemctl is-active --quiet "$UNIT"; then
  skip "quarantine domain is not running — start it (mujo-quarantine-run true) and re-run for the containment checks"
  report
  exit $?
fi

# The agent returns the command's output over vsock but not its exit status,
# so every probe below reports its own verdict in the output text.
probe() {
  mujo-quarantine-run sh -c "$1" 2>/dev/null || true
}

# 4. The distinguishing assertion: inside must be a VM. bubblewrap would say
#    "none" here, which is exactly the regression this test exists to catch.
virt=$(probe 'systemd-detect-virt || echo unknown' | tr -d '\r' | tail -1)
case "$virt" in
  kvm | qemu)
    pass "quarantined process reports virtualisation '$virt' (KVM boundary)"
    ;;
  none)
    fail "quarantined process reports 'none' — this is a namespace, not a VM"
    ;;
  *)
    fail "quarantined process reported unexpected virtualisation '$virt'"
    ;;
esac

# 5..7. The three things the guest must never see. They are absent because they
#       are never shared in, so a pass here is structural, not a filter.
for target in /persist /run/mujo/vault "/home/$(id -un)/.ssh"; do
  verdict=$(probe "ls '$target' >/dev/null 2>&1 && echo LEAK || echo CONTAINED" | tr -d '\r' | tail -1)
  if [ "$verdict" = "CONTAINED" ]; then
    pass "quarantine cannot reach $target"
  else
    fail "quarantine can reach $target"
  fi
done

# 8. The host's Nix store is shared, and must be read-only.
verdict=$(probe 'touch /nix/store/mujo-write-probe >/dev/null 2>&1 && echo WRITABLE || echo READONLY' | tr -d '\r' | tail -1)
if [ "$verdict" = "READONLY" ]; then
  pass "shared /nix/store is read-only inside quarantine"
else
  fail "quarantine can write to the host's /nix/store"
fi

# 9. The filtered session bus. It is the one host service the guest is handed,
#    so both halves have to hold: notifications and the tray need it to work,
#    and the keyring must stay out of reach behind the xdg-dbus-proxy policy.
verdict=$(probe 'dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetId >/dev/null 2>&1 && echo REACHABLE || echo UNREACHABLE' | tr -d '\r' | tail -1)
if [ "$verdict" = "REACHABLE" ]; then
  pass "quarantine reaches the host session bus through the proxy"
else
  fail "quarantine has no session bus — tray icons and notifications are dead"
fi

verdict=$(probe 'dbus-send --session --print-reply --dest=org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.freedesktop.DBus.Properties.Get string:org.kde.StatusNotifierWatcher string:IsStatusNotifierHostRegistered >/dev/null 2>&1 && echo REACHABLE || echo UNREACHABLE' | tr -d '\r' | tail -1)
if [ "$verdict" = "REACHABLE" ]; then
  pass "quarantine reaches the host's StatusNotifierWatcher (tray works)"
else
  fail "quarantine cannot reach org.kde.StatusNotifierWatcher — tray icons will not appear"
fi

verdict=$(probe 'dbus-send --session --print-reply --dest=org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.DBus.Properties.Get string:org.freedesktop.Secret.Service string:Collections >/dev/null 2>&1 && echo LEAK || echo CONTAINED' | tr -d '\r' | tail -1)
if [ "$verdict" = "CONTAINED" ]; then
  pass "quarantine cannot reach org.freedesktop.secrets on the host bus"
else
  fail "quarantine can talk to the host keyring — the D-Bus filter is not holding"
fi

# 10. Regression guard: quarantine must not quietly fall back to bubblewrap.
if grep -q 'bwrap' "$REPO_ROOT/nixos/apps/microvm.nix" 2>/dev/null; then
  fail "nixos/apps/microvm.nix still contains a bubblewrap path — quarantine must be a VM"
else
  pass "quarantine has no namespace-only fallback"
fi

report
