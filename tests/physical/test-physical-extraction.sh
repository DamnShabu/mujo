#!/usr/bin/env bash
# SEC-009: the offline-extraction invariant. A secret written the way an
# application would write one must not be recoverable from persistent storage.
#
# The old version of this test wrote its canary to /tmp and then searched
# /persist/etc, /persist/home and /persist/data — none of which exist under the
# impermanence layout, so it could only ever pass. /tmp is itself a bind mount
# from /persist/system/tmp, which is exactly why that mattered.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running Offline Physical Extraction Simulation ==="

if ! persist_roots_present; then
  skip "No /persist roots on this system — nothing to extract"
  report
  exit $?
fi

CANARY="MUJO_CANARY_$(date +%s)_$$"

# 1. /tmp is persistent here, so a secret dropped there is a disk secret.
tmp_canary=$(mktemp /tmp/mujo-canary.XXXXXX)
printf '%s\n' "$CANARY" > "$tmp_canary"
sync
if grep -qsr -- "$CANARY" /persist/system/tmp 2>/dev/null; then
  fail "A secret written to /tmp is readable from persistent storage ($tmp_canary)"
else
  pass "/tmp does not expose its contents to persistent storage"
fi
rm -f "$tmp_canary"

# 2. The vault is the only sanctioned home for a secret. If it is unlocked,
#    a secret stored through the broker must not appear in the ciphertext file.
if mountpoint -q /run/mujo/vault 2>/dev/null; then
  if printf '%s' "$CANARY" | mujo-secret store canary-test canary >/dev/null 2>&1; then
    sync
    if grep -qs -- "$CANARY" /persist/secure/mujo-vault.luks 2>/dev/null; then
      fail "Vault secret appears in plaintext inside the LUKS container file"
    else
      pass "Vault secret is not recoverable from the container file"
    fi
    rm -f /run/mujo/vault/credentials/canary-test/canary 2>/dev/null || true
  else
    skip "Could not store a canary through mujo-secret"
  fi
else
  skip "Vault is locked — run 'sudo mujo-vault open' for the full extraction test"
fi

# 3. Deep sweep: the canary must not have landed anywhere else on disk.
#    Bounded to files under 1 MiB; slow, so it is opt-in.
if [ "${MUJO_DEEP_SCAN:-0}" = "1" ]; then
  mapfile -t hits < <(scan_persist_deep "$CANARY")
  if [ "${#hits[@]}" -eq 0 ]; then
    pass "Deep sweep: canary absent from every persistent root"
  else
    fail "Deep sweep: canary found on persistent storage"
    list_findings "${hits[@]}"
  fi
else
  skip "Deep sweep not run (set MUJO_DEEP_SCAN=1 to sweep every persistent root)"
fi

report
