#!/usr/bin/env bash
# Self-check for the mujo-trust registry lock. Needs only jq and util-linux --
# no root, no systemd, no socket.
#
# What it pins down: every writer of /var/lib/mujo-trust/registry.json does a
# read-modify-write through `jq > tmp && mv tmp registry`. The mv is atomic, so
# the file is never half-written, and that used to be mistaken for the whole
# story. It is not: two writers that both read the pre-update registry produce
# two complete files, and the second mv silently discards the first writer's
# change. The write most likely to be lost is `begin`'s requarantine of an
# application whose store path moved, which would leave an updated binary
# sitting on its old GRADUATED state -- exactly the supply-chain case
# docs/threat-model.md A4 says is detected.
#
# So this asserts the locked writer keeps every concurrent update, and reports
# (without asserting) what the unlocked writer loses on the same workload --
# because a test that cannot distinguish the two would not be a test.
set -uo pipefail

writers=20

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# One writer: add key $2 to the registry at $1, the way trust.nix does.
# $3 selects locking.
write_one() {
  local db="$1" key="$2" mode="$3" tmp
  tmp=$(mktemp "$(dirname "$db")/.registry.XXXXXX")
  if [ "$mode" = locked ]; then
    {
      flock -w 10 8 || return 1
      # Re-read under the lock; that is the part that makes it safe.
      jq --arg k "$key" '.applications[$k] = {state:"QUARANTINE"}' "$db" >"$tmp" &&
        mv "$tmp" "$db"
    } 8>"$db.lock"
  else
    # Widen the window the real code has, so the race is reliable rather than
    # occasional. The unlocked code is racy either way; this only makes the
    # demonstration deterministic.
    local snapshot
    snapshot=$(cat "$db")
    sleep 0.05
    jq --arg k "$key" '.applications[$k] = {state:"QUARANTINE"}' <<<"$snapshot" >"$tmp" &&
      mv "$tmp" "$db"
  fi
  rm -f "$tmp"
}

run_round() {
  local mode="$1" db="$work/$1.json" i
  echo '{"applications":{}}' >"$db"
  for ((i = 0; i < writers; i++)); do
    write_one "$db" "app$i" "$mode" &
  done
  wait
  jq -r '.applications | length' "$db"
}

unlocked=$(run_round unlocked)
locked=$(run_round locked)

echo "unlocked: $unlocked/$writers records survived $writers concurrent writers"
echo "locked:   $locked/$writers records survived $writers concurrent writers"

if [ "$locked" -ne "$writers" ]; then
  echo "FAIL: the locked writer lost $((writers - locked)) of $writers updates"
  exit 1
fi

if [ "$unlocked" -eq "$writers" ]; then
  echo "FAIL: the unlocked writer lost nothing, so this check is not exercising"
  echo "      the race it exists to catch -- fix the harness, not the lock."
  exit 1
fi

echo "ok: registry lock keeps every concurrent update (unlocked loses $((writers - unlocked)))"
