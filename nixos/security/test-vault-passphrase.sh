#!/usr/bin/env bash
# Self-check for mujo-vault's non-interactive passphrase path.
#
# The greeter drives `mujo-vault init` / `open` with the passphrase on stdin
# instead of a terminal, which is the one thing about that CLI that cannot be
# checked by reading it: cryptsetup decides between prompting and reading a key
# file at runtime, and luksFormat additionally refuses to proceed without a tty
# unless --batch-mode is given. Getting either wrong hangs the greeter forever
# on a vault the user can no longer create.
#
# Everything happens in a throwaway container under a temp dir. The real vault
# at /persist/secure/mujo-vault.luks is never opened, read or referenced.
#
# Needs root for device-mapper, and e2fsprogs — which this host does not carry in
# systemPackages, because the vault CLI gets it privately through
# writeShellApplication's runtimeInputs:
#
#   E2FS=$(nix build nixpkgs#e2fsprogs.bin --no-link --print-out-paths)
#   pkexec env "PATH=$E2FS/bin:/run/current-system/sw/bin" \
#     bash nixos/security/test-vault-passphrase.sh
set -uo pipefail

PASS="self-check-passphrase"
WRONG="not-the-passphrase"
MAPPER="mujo_vault_selfcheck"
failures=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

if [ "$(id -u)" -ne 0 ]; then
  echo "SKIP: needs root for device-mapper (sudo bash $0)"
  exit 0
fi

MKFS="$(command -v mkfs.ext4 || echo /run/current-system/sw/bin/mkfs.ext4)"
if [ ! -x "$MKFS" ]; then
  echo "SKIP: mkfs.ext4 not on PATH — see the header for the invocation that supplies it"
  exit 0
fi

TMP="$(mktemp -d)"
cleanup() {
  cryptsetup close "$MAPPER" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

CONTAINER="$TMP/selfcheck.luks"
truncate -s 64M "$CONTAINER"

# ── init: format with the passphrase on stdin ───────────────────────────────
# --batch-mode is what stands in for the "YES" confirmation and the
# type-it-twice prompt that a terminal would provide. Without it this hangs.
# --pbkdf-force-iterations keeps Argon2id from spending seconds on a container
# that is deleted at the end of the test; the CLI itself uses the real defaults.
if printf '%s' "$PASS" | timeout 60 cryptsetup luksFormat --type luks2 --pbkdf argon2id \
     --pbkdf-force-iterations 4 --pbkdf-memory 32 --batch-mode "$CONTAINER" --key-file - 2>/dev/null; then
  pass "luksFormat accepts a passphrase on stdin without a terminal"
else
  fail "luksFormat with --batch-mode --key-file - did not complete"
fi

# ── open: the same passphrase unlocks it ────────────────────────────────────
if printf '%s' "$PASS" | timeout 60 cryptsetup open "$CONTAINER" "$MAPPER" --key-file - 2>/dev/null; then
  pass "open unlocks with the passphrase that formatted it"
  if [ -e "/dev/mapper/$MAPPER" ]; then
    pass "mapper device appears"
    # pkexec sanitises PATH, and e2fsprogs is not on root's default one. The
    # real CLI carries it in writeShellApplication's runtimeInputs, so this is
    # the harness catching up with the derivation, not a difference in behaviour.
    if "$MKFS" -q -L mujo_selfcheck "/dev/mapper/$MAPPER"; then
      pass "filesystem is created inside the unlocked container"
    else
      fail "mkfs.ext4 failed inside the unlocked container"
    fi
  else
    fail "open reported success but /dev/mapper/$MAPPER is missing"
  fi
  cryptsetup close "$MAPPER" 2>/dev/null
else
  fail "open rejected the passphrase that formatted the container"
fi

# ── A wrong passphrase must fail, and must fail *fast* ──────────────────────
# The failure mode this guards is the interesting one: if the --key-file - is
# ever dropped, cryptsetup falls back to prompting on the terminal and this
# blocks until the timeout instead of returning non-zero.
start=$SECONDS
if printf '%s' "$WRONG" | timeout 30 cryptsetup open "$CONTAINER" "$MAPPER" --key-file - 2>/dev/null; then
  fail "a wrong passphrase unlocked the container"
  cryptsetup close "$MAPPER" 2>/dev/null
elif [ $((SECONDS - start)) -ge 30 ]; then
  fail "a wrong passphrase hung instead of being rejected (prompting on a tty?)"
else
  pass "a wrong passphrase is rejected without prompting"
fi

if [ "$failures" -eq 0 ]; then
  echo "ALL PASS"
  exit 0
fi
echo "$failures FAILED"
exit 1
