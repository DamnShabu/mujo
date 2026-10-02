#!/usr/bin/env bash
# mujo-pin -- set, clear or inspect the PIN that psst's polkit prompt accepts.
#
# The hash lives in /persist/secure (0700 root, next to the vault container), so
# every subcommand needs root: `sudo mujo-pin set`. With no PIN set, polkit
# prompts behave exactly as they did before psst -- they want the password.
set -eu

hash_file=/persist/secure/psst-pin

need_root() {
  [ "$(id -u)" = 0 ] || {
    echo "mujo-pin: needs root to reach $hash_file -- try: sudo mujo-pin $1" >&2
    exit 1
  }
}

case ${1:-} in
status)
  need_root status
  # Same test psst-check-pin applies: only a yescrypt hash counts as a PIN.
  # A bare -s reported "set" for a corrupt file that PAM treats as unset.
  # shellcheck disable=SC2016  # $y$ is the literal yescrypt prefix
  if [ -r "$hash_file" ] && case $(cat "$hash_file") in '$y$'*) true ;; *) false ;; esac; then
    echo "PIN is set. polkit prompts take this PIN only; your password no longer opens them."
  else
    echo "No PIN set. polkit prompts want your password."
  fi
  ;;

clear)
  need_root clear
  rm -f "$hash_file"
  echo "PIN cleared. polkit prompts want your password again."
  ;;

set)
  need_root set
  read -rsp "New PIN: " pin
  echo
  read -rsp "Repeat:  " again
  echo
  [ "$pin" = "$again" ] || {
    echo "mujo-pin: the two entries differ, nothing changed" >&2
    exit 1
  }
  # Four is the shortest PIN worth the name; pam_faillock caps guessing at
  # three tries an hour, which is what makes a short secret defensible here.
  [ "${#pin}" -ge 4 ] || {
    echo "mujo-pin: use at least 4 characters, nothing changed" >&2
    exit 1
  }

  install -d -m 0700 -o root -g root "$(dirname "$hash_file")"
  umask 077
  printf '%s' "$pin" | mkpasswd -m yescrypt -s >"$hash_file.new"
  chown root:root "$hash_file.new"
  chmod 0600 "$hash_file.new"
  mv -f "$hash_file.new" "$hash_file"
  echo "PIN set. polkit prompts take it alone now -- sudo, login and the lock screen still want your password."
  ;;

*)
  echo "usage: mujo-pin {set|clear|status}" >&2
  exit 2
  ;;
esac
