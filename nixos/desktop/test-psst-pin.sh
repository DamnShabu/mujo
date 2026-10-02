#!/usr/bin/env bash
# Self-check for psst-check-pin, the PIN verifier the polkit-1 PAM stack calls.
# Offline, no running system, no PAM: it drives the tracked script against
# throwaway hash files the way mujo-pin writes them.
#
#   nix shell nixpkgs#mkpasswd -c bash nixos/desktop/test-psst-pin.sh
set -u

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
check=$here/psst-check-pin.sh

command -v mkpasswd >/dev/null || {
  echo "SKIP no mkpasswd on PATH -- run under: nix shell nixpkgs#mkpasswd -c bash $0"
  exit 0
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# Exactly how psst-pin.sh writes it, trailing newline and all.
good=$tmp/good
printf '%s' "4812" | mkpasswd -m yescrypt -s >"$good"

printf 'not-a-hash\n' >"$tmp/garbage"
printf '%s' "4812" | mkpasswd -m sha512crypt -s >"$tmp/sha512"
: >"$tmp/empty"

expect() { # description accept|reject pin hash-file
  local desc=$1 want=$2 pin=$3 file=$4 rc=0
  printf '%s' "$pin" | bash "$check" "$file" >/dev/null 2>&1 || rc=$?
  local got=accept
  [ "$rc" = 0 ] || got=reject
  if [ "$got" = "$want" ]; then
    echo "PASS $desc"
  else
    echo "FAIL $desc: wanted $want, got $got (exit $rc)"
    failures=$((failures + 1))
  fi
}

expect "the PIN it was set to"          accept "4812" "$good"
expect "a different PIN"                reject "4813" "$good"
expect "a prefix of the PIN"            reject "481" "$good"
expect "the PIN with a digit appended"  reject "48120" "$good"
expect "an empty entry"                 reject "" "$good"
expect "a missing hash file"            reject "4812" "$tmp/absent"
expect "an empty hash file"             reject "4812" "$tmp/empty"
expect "a corrupt hash file"            reject "4812" "$tmp/garbage"
expect "a hash in another crypt scheme" reject "4812" "$tmp/sha512"


# --unset is the password fallback's gate: it must succeed only while no PIN is
# configured, and a missing file is the common case on a freshly rebuilt host.
gate() { # description allow|block hash-file
  local desc=$1 want=$2 file=$3 rc=0
  bash "$check" --unset "$file" >/dev/null 2>&1 || rc=$?
  local got=allow
  [ "$rc" = 0 ] || got=block
  if [ "$got" = "$want" ]; then
    echo "PASS $desc"
  else
    echo "FAIL $desc: wanted $want, got $got (exit $rc)"
    failures=$((failures + 1))
  fi
}

gate "password fallback with a PIN set"        block "$good"
gate "password fallback with no hash file"     allow "$tmp/absent"
gate "password fallback with an empty file"    allow "$tmp/empty"
gate "password fallback with a corrupt file"   allow "$tmp/garbage"
gate "password fallback with another scheme"   allow "$tmp/sha512"
if [ "$failures" = 0 ]; then
  echo "OK psst PIN verifier"
else
  echo "$failures check(s) failed"
fi
exit $((failures > 0))
