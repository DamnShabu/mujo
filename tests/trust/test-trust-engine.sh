#!/usr/bin/env bash
# SEC-009: the progressive trust engine, on the running system.
#
# The state machine itself (every transition, the graduation policy, the lock)
# is checked offline by nixos/apps/test-mujo-trust-registry.sh, which
# `nix flake check` also runs. What is left here needs the installed system:
# the daemon answering on its socket, the launcher marker, Flatpak narrowing.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running Progressive Trust Engine Tests ==="

expect() {
  local label="$1" actual="$2" want="$3"
  if [ "$actual" = "$want" ]; then
    pass "$label"
  else
    fail "$label (got '$actual', expected '$want')"
  fi
}

# ── the live daemon ──────────────────────────────────────────────────────
#
# What these prove is that the paths the policy depends on are actually
# reachable.

# 1. Phase 21: `violation` has to be a verb the daemon answers, or the broker's
#    report (nixos/security/broker.nix) lands nowhere and the detector is a log
#    line again -- and it has to be answered *only* on the root-only report
#    socket, or any process of the user's can revoke any application by name.
#    Probing with a name that is not registered is deliberate: the handler
#    no-ops on an unknown application, so this exercises the whole socket path
#    without revoking anything real.
LIVE_DB=/var/lib/mujo-trust/registry.json
probe() {
  printf 'violation\tmujo-test-nonexistent\tacceptance probe\n' |
    socat -T5 - "UNIX-CONNECT:$1" 2>/dev/null | tr -d '\r'
}
if [ ! -S /run/mujo/trust.sock ] || ! command -v socat >/dev/null 2>&1; then
  skip "the trust socket is not up — rebuild to exercise the violation path"
else
  expect "the user socket refuses a violation report" \
    "$(probe /run/mujo/trust.sock)" "ERR violation is not accepted on this socket"
  if [ "$(id -u)" -ne 0 ]; then
    skip "not root — cannot reach the report socket to check the broker's path"
  elif [ ! -S /run/mujo/trust-report.sock ]; then
    fail "the report socket is missing — broker violations land nowhere"
  else
    # A registry that does not exist yet holds zero applications, not
    # "unknown": the daemon creates an empty one on its first request, so
    # reading a missing file as an error would make this compare 0 against a
    # sentinel and cry breach over the daemon doing exactly what it should.
    count() { jq -r '.applications | length' "$LIVE_DB" 2>/dev/null || echo 0; }
    before=$(count)
    reply=$(probe /run/mujo/trust-report.sock)
    after=$(count)
    expect "the report socket accepts a violation report" "$reply" OK
    expect "an unknown application is not invented by reporting one" "$after" "$before"
  fi
fi

# 2. Phase 11/24: with launcher integration on, every desktop launch becomes
#    `mujo-trust run …`. If that binary is not on the session PATH the shell
#    silently launches nothing at all, so the marker and the CLI have to ship
#    together.
if [ -f /etc/mujo/launcher-integration ]; then
  if command -v mujo-trust >/dev/null 2>&1; then
    pass "launcher integration is on and mujo-trust is on PATH"
  else
    fail "launcher integration is on but mujo-trust is not on PATH — every launch would fail"
  fi
else
  skip "launcher integration is off (apps.trust.launcherIntegration = false)"
fi

# 3. A GRADUATED Flatpak brings its own sandbox, so the engine cannot wrap it
#    in bwrap the way it wraps a native application — it narrows the manifest
#    with subtractive `flatpak run` overrides instead. Without them a Flatpak
#    declaring `devices=all` sees the host's whole /dev, including
#    /dev/input/event* (every keystroke) and the raw disks, which makes §7's
#    "enforced, not advisory" false for every Flatpak on the system.
#
#    `--command=ls` asks the question without starting the application.
dev_of() {
  mujo-trust run flatpak run --command=ls "$1" /dev 2>/dev/null | tr -d '\r'
}

graduated_flatpak() {
  jq -r --arg t "$1" '.applications | to_entries[]
    | select(.value.state == "GRADUATED" and .value.tier == $t) | .key' "$LIVE_DB" 2>/dev/null |
    while read -r a; do
      # `if`, not `&&`: a last record that is not a Flatpak (kitty, fish) made
      # the loop return 1, and under set -e that ended the whole suite here.
      if [ -d "/var/lib/flatpak/app/$a" ]; then
        echo "$a"
        break
      fi
    done
}

if ! command -v flatpak >/dev/null 2>&1 || ! command -v mujo-trust >/dev/null 2>&1 ||
   [ ! -S /run/mujo/trust.sock ]; then
  skip "flatpak or the trust daemon is absent — cannot check Flatpak capability narrowing"
else
  narrowed=$(graduated_flatpak medium)
  if [ -z "$narrowed" ]; then
    skip "no GRADUATED medium-tier Flatpak installed — nothing to narrow"
  elif [ -z "$(dev_of "$narrowed")" ]; then
    skip "$narrowed did not answer — cannot check its device set"
  elif dev_of "$narrowed" | grep -qx input; then
    fail "$narrowed (medium, GRADUATED) still sees /dev/input — the tier profile is not being applied"
  else
    pass "a GRADUATED medium-tier Flatpak is launched without raw device access"
  fi

  # The other half: narrowing that ignored the tier would break the tier that
  # was classified as needing the least of it. Steam is low and genuinely wants
  # devices=all for controllers.
  wide=$(graduated_flatpak low)
  if [ -z "$wide" ]; then
    skip "no GRADUATED low-tier Flatpak installed — cannot check the exemption"
  elif dev_of "$wide" | grep -qx input; then
    pass "a GRADUATED low-tier Flatpak keeps the devices its manifest asked for"
  else
    fail "$wide (low, GRADUATED) lost its device access — low tier must not be narrowed"
  fi
fi

report
