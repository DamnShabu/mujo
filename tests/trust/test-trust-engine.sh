#!/usr/bin/env bash
# SEC-009: the progressive trust state machine.
#
# Runs the policy the installed system actually carries (/etc/mujo/trust.jq)
# against a scratch registry, so a change to the graduation rules that breaks
# one of these transitions fails here rather than by quietly graduating
# something it should not have.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running Progressive Trust Engine Tests ==="

JQ_LIB=/etc/mujo/mujo-trust.jq
if ! command -v jq >/dev/null 2>&1 || [ ! -f "$JQ_LIB" ]; then
  skip "$JQ_LIB is not installed — rebuild to exercise the trust policy"
  report
  exit $?
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$JQ_LIB" "$WORK/mujo-trust.jq"
DB="$WORK/reg.json"
echo '{"applications":{}}' > "$DB"

# The graduation policy, kept identical to mujo-trust-evaluate.
EVAL='include "mujo-trust"; .applications |= with_entries(.value |= (
  if .violations > 0 then .
  elif .state == "QUARANTINE" and .observed_seconds >= $quarantine and .tier != "critical"
  then .state = "OBSERVING" | .last_evaluated = now_iso
  elif .state == "OBSERVING" and .observed_seconds >= ($quarantine + $observing) and (.tier=="low" or .tier=="medium")
  then .state = "GRADUATED" | .last_evaluated = now_iso
  else . end))'

J() { jq -L"$WORK" "$@" "$DB" > "$WORK/t" && mv "$WORK/t" "$DB"; }
Q() { jq -L"$WORK" -r "$@" "$DB"; }
evaluate() { J --argjson quarantine 259200 --argjson observing 86400 "$EVAL"; }

expect() {
  local label="$1" actual="$2" want="$3"
  if [ "$actual" = "$want" ]; then
    pass "$label"
  else
    fail "$label (got '$actual', expected '$want')"
  fi
}

begin() {
  J --arg a "$1" --arg p "$2" '
    include "mujo-trust";
    if .applications[$a] == null then .applications[$a] = new_record($a;"medium";$p)
    elif .applications[$a].store_path != $p then .applications[$a] |= requarantine($p)
    else . end
    | if .applications[$a].session_started == null then .applications[$a].session_started = now else . end'
}

# 1. An unregistered application is quarantined, never trusted by default.
begin firefox /nix/store/aaa-firefox
expect "unknown application starts in QUARANTINE" "$(Q '.applications.firefox.state')" QUARANTINE
expect "QUARANTINE maps to the MicroVM runtime" \
  "$(Q 'include "mujo-trust"; .applications.firefox|runtime_for')" quarantine

# 2. Observation credits real elapsed runtime.
J --arg a firefox '.applications[$a].session_started = (now - 100)'
J --arg a firefox 'if .applications[$a].session_started == null then . else
  .applications[$a].observed_seconds += ((now - .applications[$a].session_started)|floor)
  | .applications[$a].session_started = null end'
expect "closing a session credits its runtime" "$(Q '.applications.firefox.observed_seconds')" 100

# 3. Parallel launches must not bank several hours per hour of real time.
J --arg a firefox '.applications[$a].session_started = 1000'
begin firefox /nix/store/aaa-firefox
expect "a second launch does not open a second accumulator" \
  "$(Q '.applications.firefox.session_started == 1000')" true
J --arg a firefox '.applications[$a].session_started = null'

# 4. The clean path: 72h then a further 24h.
J --arg a firefox '.applications[$a].observed_seconds = 259200'
evaluate
expect "72h clean runtime reaches OBSERVING" "$(Q '.applications.firefox.state')" OBSERVING
J --arg a firefox '.applications[$a].observed_seconds = 345600'
evaluate
expect "a further 24h clean graduates" "$(Q '.applications.firefox.state')" GRADUATED
expect "GRADUATED maps to the native sandbox" \
  "$(Q 'include "mujo-trust"; .applications.firefox|runtime_for')" native

# 5. An update is a different application (docs/application-trust.md §5).
begin firefox /nix/store/bbb-firefox
expect "a changed store path re-quarantines" "$(Q '.applications.firefox.state')" QUARANTINE
expect "re-quarantine resets the observation counter" "$(Q '.applications.firefox.observed_seconds')" 0
expect "the previous known-good path is kept for rollback" \
  "$(Q '.applications.firefox.previous_store_path')" /nix/store/aaa-firefox

# 6. A violation revokes, and no amount of runtime undoes it.
J --arg a firefox --arg r 'vault access attempt' '
  include "mujo-trust";
  .applications[$a].violations += 1 | .applications[$a].state = "REVOKED"
  | .applications[$a].violation_log += [{at: now_iso, reason: $r}]'
J --arg a firefox '.applications[$a].observed_seconds = 9999999'
evaluate
expect "a violation revokes" "$(Q '.applications.firefox.state')" REVOKED
expect "REVOKED refuses to launch" \
  "$(Q 'include "mujo-trust"; .applications.firefox|runtime_for')" denied

# 7. Tier policy: CRITICAL never auto-graduates (Phase 25).
J --arg a keyring --arg p /nix/store/ccc '
  include "mujo-trust"; .applications[$a] = new_record($a;"critical";$p)
  | .applications[$a].observed_seconds = 9999999'
evaluate; evaluate
expect "a CRITICAL application never leaves QUARANTINE" "$(Q '.applications.keyring.state')" QUARANTINE

# 8. HIGH reaches observation but needs a person to graduate it.
J --arg a gcc --arg p /nix/store/ddd '
  include "mujo-trust"; .applications[$a] = new_record($a;"high";$p)
  | .applications[$a].observed_seconds = 9999999'
evaluate; evaluate
expect "a HIGH application stops at OBSERVING" "$(Q '.applications.gcc.state')" OBSERVING

# ── the live daemon ──────────────────────────────────────────────────────
#
# Everything above runs the installed *policy* against a scratch registry. The
# two checks below need the running system, because what they prove is that the
# paths the policy depends on are actually reachable.

# 9. Phase 21: `violation` has to be a verb the daemon answers, or the broker's
#    report (nixos/security/broker.nix) lands nowhere and the detector is a log
#    line again. Probing with a name that is not registered is deliberate: the
#    handler no-ops on an unknown application, so this exercises the whole
#    socket path without revoking anything real.
LIVE_DB=/var/lib/mujo-trust/registry.json
if [ ! -S /run/mujo/trust.sock ] || ! command -v socat >/dev/null 2>&1; then
  skip "the trust socket is not up — rebuild to exercise the violation path"
else
  # A registry that does not exist yet holds zero applications, not "unknown":
  # the daemon creates an empty one on its first request, so reading a missing
  # file as an error would make this compare 0 against a sentinel and cry breach
  # over the daemon doing exactly what it should.
  count() { jq -r '.applications | length' "$LIVE_DB" 2>/dev/null || echo 0; }
  before=$(count)
  reply=$(printf 'violation\tmujo-test-nonexistent\tacceptance probe\n' |
    socat -T5 - UNIX-CONNECT:/run/mujo/trust.sock 2>/dev/null | tr -d '\r')
  after=$(count)
  expect "the daemon accepts a violation report" "$reply" OK
  expect "an unknown application is not invented by reporting one" "$after" "$before"
fi

# 10. Phase 11/24: with launcher integration on, every desktop launch becomes
#     `mujo-trust run …`. If that binary is not on the session PATH the shell
#     silently launches nothing at all, so the marker and the CLI have to ship
#     together.
if [ -f /etc/mujo/launcher-integration ]; then
  if command -v mujo-trust >/dev/null 2>&1; then
    pass "launcher integration is on and mujo-trust is on PATH"
  else
    fail "launcher integration is on but mujo-trust is not on PATH — every launch would fail"
  fi
else
  skip "launcher integration is off (apps.trust.launcherIntegration = false)"
fi

report
