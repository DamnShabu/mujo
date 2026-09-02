#!/usr/bin/env bash
# SEC-003 & SEC-004: ephemeral root, vault permissions, and the core invariant
# that no sensitive plaintext lives on unencrypted persistent storage.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running Storage & Vault Isolation Tests ==="

if [ "$(findmnt -n -o FSTYPE / || echo unknown)" = "tmpfs" ]; then
  pass "Root filesystem is tmpfs (ephemeral)"
else
  fail "Root filesystem is $(findmnt -n -o FSTYPE / || echo unknown), not tmpfs"
fi

if [ -d /persist/secure ]; then
  perms=$(stat -c '%a %U' /persist/secure)
  if [ "$perms" = "700 root" ]; then
    pass "/persist/secure is 0700 root-owned"
  else
    fail "/persist/secure is '$perms' (expected '700 root')"
  fi
else
  fail "/persist/secure is missing — the vault container has nowhere to live"
fi

if [ -f /persist/secure/mujo-vault.luks ]; then
  if cryptsetup isLuks /persist/secure/mujo-vault.luks 2>/dev/null; then
    pass "Vault container carries a valid LUKS2 header"
  else
    fail "/persist/secure/mujo-vault.luks exists but is not a LUKS container"
  fi
else
  skip "Vault container not initialised yet — run 'sudo mujo-vault init'"
fi

# Invariant #1: no plaintext private keys outside the vault.
if persist_roots_present; then
  leaks=""
  for marker in "BEGIN OPENSSH PRIVATE KEY" "BEGIN RSA PRIVATE KEY" "BEGIN PGP PRIVATE KEY BLOCK"; do
    found=$(scan_sensitive "$marker")
    [ -n "$found" ] && leaks+="$found"$'\n'
  done
  mapfile -t leaked < <(printf '%s' "$leaks" | sed '/^$/d')
  if [ "${#leaked[@]}" -eq 0 ]; then
    pass "No plaintext private keys on unencrypted persistent storage"
  else
    fail "${#leaked[@]} plaintext private key(s) on unencrypted persistent storage"
    list_findings "${leaked[@]}"
  fi
else
  skip "No /persist roots on this system — nothing to scan"
fi

report
