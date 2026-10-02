# shellcheck shell=bash
# mujo-trust-registry: the only writer of the trust registry.
#
# The socket handler, the evaluator, the seeder and the root CLI all call this
# with one verb. It owns the lock and the atomic swap; the transitions
# themselves are the functions in mujo-trust.jq.
#
# MUJO_TRUST_DB and MUJO_TRUST_JQ_DIR exist for the self-check
# (test-mujo-trust-registry.sh), which runs this against a scratch registry.
# They grant nothing: whoever sets them can already write the file they name.
#
# $a / $p / $t in the jq programs below are jq variables, not shell ones.
# shellcheck disable=SC2016
set -euo pipefail
umask 022

DB="${MUJO_TRUST_DB:-/var/lib/mujo-trust/registry.json}"
JQ_DIR="${MUJO_TRUST_JQ_DIR:-/etc/mujo}"
DIR=$(dirname -- "$DB")

die() { echo "mujo-trust-registry: $*" >&2; exit 1; }

# Every verb is a read-modify-write of one JSON file, and `mv` only makes the
# final swap atomic -- it does not stop two writers from both reading the
# pre-update registry and the second one discarding the first one's write. The
# write most likely to be lost is `begin`'s requarantine of an application
# whose store path changed, which would leave an updated binary sitting on its
# old GRADUATED state. So every verb runs under one lock. The fd is scoped to
# this block and this process, so nothing the caller spawns can inherit it.
locked() {
  mkdir -p -- "$DIR"
  {
    flock -w 5 9 || { echo "mujo-trust-registry: registry is busy, try again" >&2; exit 75; }
    [ -f "$DB" ] || echo '{"applications":{}}' > "$DB"
    "$@"
  } 9>"$DIR/.registry.lock"
}

# jq cannot write in place, and a half-written registry is worse than a stale
# one: swap it atomically or not at all.
apply() {
  local tmp
  tmp=$(mktemp "$DIR/.registry.XXXXXX")
  if jq -L"$JQ_DIR" "$@" "$DB" > "$tmp"; then
    chmod 644 "$tmp"
    mv "$tmp" "$DB"
  else
    rm -f "$tmp"
    return 1
  fi
}

# begin commits, then answers with the runtime under the same lock, so the
# answer is the state this very request produced.
begin_locked() {
  apply --arg a "$1" --arg p "$2" 'include "mujo-trust"; begin($a; $p)'
  jq -L"$JQ_DIR" -r --arg a "$1" 'include "mujo-trust"; .applications[$a] | runtime_for' "$DB"
}

rollback_locked() {
  local prev
  prev=$(jq -r --arg a "$1" '.applications[$a].previous_store_path // ""' "$DB")
  if [ -z "$prev" ] || [ ! -e "$prev" ]; then
    die "no previous known-good version of '$1' is still in the store"
  fi
  apply --arg a "$1" --arg p "$prev" 'include "mujo-trust"; rollback($a; $p)'
  echo "$prev"
}

need() { [ "$1" -ge "$2" ] || die "'$verb' needs $2 argument(s)"; }

verb="${1:-}"
[ -n "$verb" ] || die "usage: mujo-trust-registry <verb> [args...]"
shift

case "$verb" in
  begin)     need $# 2; locked begin_locked "$1" "$2" ;;
  end)       need $# 1; locked apply --arg a "$1" 'include "mujo-trust"; end_session($a)' ;;
  violation) need $# 2; locked apply --arg a "$1" --arg r "$2" 'include "mujo-trust"; violation($a; $r)' ;;
  evaluate)  need $# 2; locked apply --argjson q "$1" --argjson o "$2" 'include "mujo-trust"; evaluate($q; $o)' ;;
  seed)      need $# 4; locked apply --arg a "$1" --arg t "$2" --arg s "$3" --arg p "$4" 'include "mujo-trust"; seed($a; $t; $s; $p)' ;;
  register)  need $# 3; locked apply --arg a "$1" --arg t "$2" --arg p "$3" 'include "mujo-trust"; register($a; $t; $p)' ;;
  tier)      need $# 2; locked apply --arg a "$1" --arg t "$2" 'include "mujo-trust"; set_tier($a; $t)' ;;
  state)
    need $# 2
    case "$2" in QUARANTINE | OBSERVING | GRADUATED | REVOKED) ;; *) die "unknown state '$2'" ;; esac
    locked apply --arg a "$1" --arg s "$2" 'include "mujo-trust"; set_state($a; $s)'
    ;;
  rollback)  need $# 1; locked rollback_locked "$1" ;;
  *)         die "unknown verb '$verb'" ;;
esac
