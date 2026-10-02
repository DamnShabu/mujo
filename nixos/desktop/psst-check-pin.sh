#!/usr/bin/env bash
# psst-check-pin -- the PIN half of the polkit-1 PAM stack (nixos/desktop/psst.nix).
#
#   psst-check-pin <hash-file>           verify the secret on stdin against the hash
#   psst-check-pin --unset <hash-file>   succeed only when no PIN is configured
#
# pam_exec(8) runs the first form with `expose_authtok`: it prompts for the
# secret itself, then hands it to us on stdin with no trailing newline. The rule
# passes `seteuid`, so we run as root and can read the 0600 root-only hash file.
#
# The second form is the password fallback's gate. It runs as a `required` rule
# in front of pam_unix, so when a PIN *is* configured it fails and no later
# `sufficient` module can grant access -- that is what makes the PIN the only
# answer pkexec takes. With no PIN configured it succeeds, pam_unix decides, and
# a machine that has been rebuilt but not yet had `mujo-pin set` run on it still
# has a working polkit prompt. Both forms agree on what "configured" means
# because they share the check below; that is the point of one script.
set -eu

mode="verify"
if [ "${1:-}" = "--unset" ]; then
  mode="unset"
  shift
fi

hash_file=${1:?usage: psst-check-pin [--unset] <hash-file>}

stored=
if [ -r "$hash_file" ]; then
  stored=$(cat "$hash_file")
fi

# `mujo-pin set` only ever writes yescrypt. Anything else -- missing, empty,
# truncated, another crypt scheme -- counts as "no PIN configured" rather than
# being fed to crypt(3) to see what comes back.
# shellcheck disable=SC2016  # $y$ is the literal yescrypt prefix, not an expansion
case $stored in
'$y$'*) configured="yes" ;;
*) configured="no" ;;
esac

if [ "$mode" = "unset" ]; then
  [ "$configured" = "no" ] || exit 1
  exit 0
fi

[ "$configured" = "yes" ] || exit 1

# Fields 3 and 4 of $y$<params>$<salt>$<hash> are the parameters and the salt.
# Re-hashing the candidate under them is the crypt(3) verification dance: same
# salt, same password, same output.
salt=$(printf '%s' "$stored" | cut -d'$' -f3-4)
[ -n "$salt" ] || exit 1

pin=$(cat)
[ -n "$pin" ] || exit 1

candidate=$(printf '%s' "$pin" | mkpasswd -m yescrypt -S "$salt" -s) || exit 1
[ "$candidate" = "$stored" ] || exit 1
