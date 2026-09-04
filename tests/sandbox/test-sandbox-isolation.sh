#!/usr/bin/env bash
# SEC-010: the native sandbox must actually contain a process, not merely exist.
# Every check below runs the sandbox and tries to break out of it.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

echo "=== Running Sandbox Boundary Isolation Tests ==="

if ! command -v mujo-sandbox-run >/dev/null 2>&1; then
  skip "mujo-sandbox-run is not installed — rebuild to run the containment checks"
else
  # 1. The vault mountpoint must be invisible inside the sandbox.
  if mujo-sandbox-run sh -c 'ls /run/mujo/vault' >/dev/null 2>&1; then
    fail "Sandbox can reach /run/mujo/vault"
  else
    pass "Sandbox cannot reach the vault mountpoint"
  fi

  # 2. /persist must not be bound into the sandbox at all.
  if mujo-sandbox-run sh -c 'ls /persist' >/dev/null 2>&1; then
    fail "Sandbox can reach /persist"
  else
    pass "Sandbox cannot reach /persist"
  fi

  # 3. The user's real SSH key must not be readable.
  if mujo-sandbox-run sh -c 'cat "$HOME"/.ssh/id_*' >/dev/null 2>&1; then
    fail "Sandbox can read the user's SSH private key"
  else
    pass "Sandbox cannot read the user's SSH private key"
  fi

  # 4. PID namespace: a contained process must not see host processes.
  visible=$(mujo-sandbox-run sh -c 'ls /proc | grep -c "^[0-9]*$"' 2>/dev/null || echo 999)
  if [ "$visible" -le 5 ]; then
    pass "Sandbox has its own PID namespace ($visible processes visible)"
  else
    fail "Sandbox sees $visible host processes — PID namespace is not unshared"
  fi

  # 5. The D-Bus policy, both halves. A GApplication must own its own app id
  #    before g_application_register() succeeds, and xdg-dbus-proxy answers a
  #    RequestName its policy does not cover with a faked ServiceUnknown — so
  #    without the grant every GTK application exits with "Failed to register"
  #    before it draws a window. The grant has to stay narrow: the id comes from
  #    the desktop entry the package ships beside the binary, and nothing else
  #    on the host bus may be claimed.
  #
  #    --gapplication-service registers on the bus and returns no window, so
  #    this asks the real question without putting a file manager on screen.
  if command -v nautilus >/dev/null 2>&1; then
    rc=0
    timeout 6 mujo-sandbox-run nautilus --gapplication-service >/dev/null 2>&1 || rc=$?
    if [ "$rc" -eq 124 ]; then
      pass "Sandboxed GTK application owns its app id and stays up"
    else
      fail "Sandboxed GTK application exited with $rc instead of running — it could not own its app id"
    fi
  else
    skip "nautilus is not installed — cannot check the GApplication name grant"
  fi

  if mujo-sandbox-run dbus-send --session --print-reply \
       --dest=org.freedesktop.DBus /org/freedesktop/DBus \
       org.freedesktop.DBus.RequestName string:org.freedesktop.secrets uint32:0 \
       2>/dev/null | grep -q 'uint32 1'; then
    fail "Sandbox can own org.freedesktop.secrets on the host bus — the name grant is too wide"
  else
    pass "Sandbox cannot own an unrelated host bus name"
  fi
fi

# 5. Disposable-guest boot parameters must never reach the *host* kernel.
#
# The previous form of this check grepped for the parameters outside
# nixos/sandbox/ and failed the moment the quarantine MicroVM grew the same
# ones. That was a proxy for the invariant, not the invariant: what matters is
# the host command line, and a guest module setting `boot.kernelParams` inside
# `microvm.vms.<name>.config` never touches it. The check now reads the running
# kernel, which no file layout can fool.
host_cmdline=$(tr ' ' '\n' < /proc/cmdline)
mapfile -t leaked < <(printf '%s\n' "$host_cmdline" | grep -E '^(mitigations=off|audit=0|nowatchdog)$' || true)
if [ "${#leaked[@]}" -eq 0 ]; then
  pass "Host kernel booted without any disposable-guest parameter"
else
  fail "Host kernel booted with a disposable-guest parameter"
  list_findings "${leaked[@]}"
fi

# 5b. Source guard: only the two disposable-guest trees may name them, so a
# third copy landing in a host module is caught before it is ever booted.
mapfile -t bleed < <(
  grep -rl 'mitigations=off\|audit=0\|nowatchdog' "$REPO_ROOT/nixos" 2>/dev/null |
    grep -vE '^'"$REPO_ROOT"'/nixos/(sandbox/|apps/microvm\.nix$)'
)
if [ "${#bleed[@]}" -eq 0 ]; then
  pass "Only nixos/sandbox/ and the quarantine guest name those parameters"
else
  fail "A host module names a disposable-guest parameter"
  list_findings "${bleed[@]}"
fi

report
