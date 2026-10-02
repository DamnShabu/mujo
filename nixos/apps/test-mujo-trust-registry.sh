#!/usr/bin/env bash
# Self-check for the trust registry (mujo-trust.jq + mujo-trust-registry.sh).
# Needs only bash, jq and util-linux: no root, no systemd, no socket. It runs
# the real writer against a scratch registry, so every transition asserted here
# is the one the installed system executes -- there is no copy of the policy to
# drift. `nix flake check` runs it too (checks.trustRegistry).
#
# Fixtures (a session that started 100s ago, 72h already banked) are written
# with plain jq; every transition under test goes through the writer.
#
# $a etc. in the fixture programs are jq variables.
# shellcheck disable=SC2016
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export MUJO_TRUST_DB="$work/registry.json"
export MUJO_TRUST_JQ_DIR="$here"
Q_SEC=259200   # 72h
O_SEC=86400    # 24h

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
expect() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', expected '$3')"; fi
}

R() { bash "$here/mujo-trust-registry.sh" "$@"; }
Q() { jq -r "$@" "$MUJO_TRUST_DB"; }
fixture() {
  jq "$@" "$MUJO_TRUST_DB" > "$work/t" && mv "$work/t" "$MUJO_TRUST_DB"
}
evaluate() { R evaluate "$Q_SEC" "$O_SEC"; }
# The command must fail, and must leave the registry byte-for-byte alone.
refuses() {
  local label="$1" before
  shift
  before=$(cat "$MUJO_TRUST_DB")
  if R "$@" 2>/dev/null; then
    fail "$label (the writer accepted it)"
  elif [ "$(cat "$MUJO_TRUST_DB")" != "$before" ]; then
    fail "$label (refused, but the registry changed)"
  else
    pass "$label"
  fi
}

# ── socket verbs ────────────────────────────────────────────────────────

# 1. An unregistered application is quarantined, never trusted by default.
expect "begin answers with the runtime" "$(R begin firefox /nix/store/aaa-firefox)" quarantine
expect "unknown application starts in QUARANTINE" "$(Q .applications.firefox.state)" QUARANTINE

# 2. Observation credits real elapsed runtime.
fixture '.applications.firefox.session_started = (now - 100)'
R end firefox
expect "ending a session credits its runtime" "$(Q .applications.firefox.observed_seconds)" 100
expect "ending a session closes the accumulator" "$(Q .applications.firefox.session_started)" null

# 3. Parallel launches must not bank several hours per hour of real time.
fixture '.applications.firefox.session_started = 1000'
R begin firefox /nix/store/aaa-firefox > /dev/null
expect "a second launch does not open a second accumulator" \
  "$(Q '.applications.firefox.session_started == 1000')" true
fixture '.applications.firefox.session_started = null'

# ── policy ──────────────────────────────────────────────────────────────

# 4. The clean path: 72h then a further 24h.
fixture ".applications.firefox.observed_seconds = $Q_SEC"
evaluate
expect "72h clean runtime reaches OBSERVING" "$(Q .applications.firefox.state)" OBSERVING
fixture ".applications.firefox.observed_seconds = $((Q_SEC + O_SEC))"
evaluate
expect "a further 24h clean graduates" "$(Q .applications.firefox.state)" GRADUATED
expect "GRADUATED maps to the native sandbox" "$(R begin firefox /nix/store/aaa-firefox)" native
fixture '.applications.firefox.session_started = null'

# 5. The evaluator banks a session that is still running. The old copy of the
#    policy in tests/trust skipped this, so a long-running application could
#    never graduate there while it could here.
fixture '.applications.x = {state:"QUARANTINE", tier:"medium", violations:0,
  observed_seconds: 0, session_started: (now - 300)}'
evaluate
expect "evaluate credits a running session" "$(Q '.applications.x.observed_seconds >= 300')" true
expect "evaluate keeps the running session open" "$(Q '.applications.x.session_started != null')" true
fixture 'del(.applications.x)'

# 6. An update is a different application (docs/application-trust.md §5).
expect "a changed store path re-quarantines" "$(R begin firefox /nix/store/bbb-firefox)" quarantine
expect "re-quarantine resets the observation counter" "$(Q .applications.firefox.observed_seconds)" 0
expect "the previous known-good path is kept for rollback" \
  "$(Q .applications.firefox.previous_store_path)" /nix/store/aaa-firefox
R end firefox

# 7. A violation revokes, and no amount of runtime undoes it.
R violation firefox 'vault access attempt'
fixture '.applications.firefox.observed_seconds = 9999999'
evaluate
expect "a violation revokes" "$(Q .applications.firefox.state)" REVOKED
expect "the violation is logged" "$(Q '.applications.firefox.violation_log[0].reason')" 'vault access attempt'
expect "REVOKED refuses to launch" "$(R begin firefox /nix/store/bbb-firefox)" denied
R end firefox
R violation nobody probe
expect "a violation for an unknown name invents no record" "$(Q '.applications.nobody')" null

# 8. Tier policy: CRITICAL never auto-graduates (Phase 25), HIGH stops at
#    OBSERVING until a person graduates it.
R register keyring critical /nix/store/ccc
R register gcc high /nix/store/ddd
fixture '.applications.keyring.observed_seconds = 9999999 | .applications.gcc.observed_seconds = 9999999'
evaluate; evaluate
expect "a CRITICAL application never leaves QUARANTINE" "$(Q .applications.keyring.state)" QUARANTINE
expect "a HIGH application stops at OBSERVING" "$(Q .applications.gcc.state)" OBSERVING

# ── seeding (runs on every boot) ────────────────────────────────────────

# 9. A declared state never undoes a revocation. This is the bug where each
#    boot re-asserted GRADUATED over whatever the broker had revoked.
R seed steam low GRADUATED /nix/store/eee-steam
expect "seeding a new application uses the declared state" "$(Q .applications.steam.state)" GRADUATED
R violation steam 'secret request denied'
R seed steam low GRADUATED /nix/store/eee-steam
expect "re-seeding keeps REVOKED" "$(Q .applications.steam.state)" REVOKED
# An update of a revoked application is a new application (§5), so it goes to
# QUARANTINE rather than the declared state -- and its violation count stays,
# so the evaluator can never graduate it without a person.
R seed steam low GRADUATED /nix/store/fff-steam
expect "re-seeding an updated REVOKED application quarantines it" "$(Q .applications.steam.state)" QUARANTINE
expect "…and records the new path" "$(Q .applications.steam.store_path)" /nix/store/fff-steam
fixture ".applications.steam.observed_seconds = 9999999"
evaluate
expect "…and the violation count keeps it from graduating" "$(Q .applications.steam.state)" QUARANTINE
R seed zen medium GRADUATED /nix/store/ggg-zen
R seed zen high GRADUATED /nix/store/ggg-zen
expect "re-seeding synchronises the declared tier" "$(Q .applications.zen.tier)" high

# ── administration ──────────────────────────────────────────────────────

# 10. A forced quarantine sticks. Before, the banked time survived it and the
#     next hourly evaluation moved the application straight back to GRADUATED.
fixture '.applications.zen.tier = "medium" | .applications.zen.observed_seconds = 9999999'
R state zen QUARANTINE
evaluate
expect "admin quarantine survives the next evaluation" "$(Q .applications.zen.state)" QUARANTINE
expect "admin quarantine discards banked observation" "$(Q .applications.zen.observed_seconds)" 0
expect "admin actions are logged with before and after" \
  "$(Q '.applications.zen.admin_log[-1] | "\(.action):\(.from)->\(.to)"')" state:GRADUATED-\>QUARANTINE

# 11. register refuses to overwrite: overwriting erased REVOKED and its log.
refuses "register refuses an existing name" register steam medium /nix/store/zzz
expect "…and the violation history survives" "$(Q .applications.steam.violations)" 1

# 12. Admin verbs on a name nobody registered fail instead of inventing a
#     partial record with no store path.
refuses "tier refuses an unknown name" tier ghost low
refuses "state refuses an unknown name" state ghost GRADUATED
refuses "rollback refuses an unknown name" rollback ghost
refuses "tier refuses an invalid tier" tier zen extreme
refuses "state refuses an invalid state" state zen TRUSTED
refuses "register refuses an invalid tier" register newapp extreme /nix/store/hhh

# 13. Rollback returns to the previous path, which must still exist.
refuses "rollback refuses a previous path that is gone" rollback steam
prev="$work/old-steam"
touch "$prev"
fixture --arg p "$prev" '.applications.steam.previous_store_path = $p'
expect "rollback prints the path it restored" "$(R rollback steam)" "$prev"
expect "rollback restores GRADUATED" "$(Q .applications.steam.state)" GRADUATED
expect "rollback clears the violation count" "$(Q .applications.steam.violations)" 0
expect "rollback keeps the violation log" "$(Q '.applications.steam.violation_log | length')" 1

# ── the lock ────────────────────────────────────────────────────────────

# 14. Every write is a read-modify-write, and mv only makes the swap atomic.
#     Twenty concurrent writers must all survive.
writers=20
for ((i = 0; i < writers; i++)); do
  R begin "concurrent$i" "/nix/store/c$i" > /dev/null &
done
wait
expect "the lock keeps every one of $writers concurrent updates" \
  "$(Q '[.applications | keys[] | select(startswith("concurrent"))] | length')" "$writers"
expect "no temporary files are left behind" "$(find "$work" -name '.registry.*' ! -name '.registry.lock' | wc -l)" 0

echo
if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all trust registry checks passed"
