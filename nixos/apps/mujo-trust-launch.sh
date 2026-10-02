# shellcheck shell=bash
# mujo-trust-launch: the one place that knows what an application *is* and
# how each runtime starts it.
#
#   resolve <argv...>            -> "<name>\t<kind>\t<identity>"
#   plan <runtime> <argv...>     -> the command to exec, NUL-separated
#
# <kind> is `flatpak` or `native`; <runtime> is what the trust daemon answered
# (`quarantine` or `native`). The name is the key everything else agrees on:
# the registry record, the broker socket (security.mujo.broker.acl) and the
# sandbox's persistent home. It is derived, never configured -- a Flatpak's
# application id, or the basename of the program being run -- so there is no
# second place a name can come from and drift.
#
# The CLI, the seeder and the launcher all call this; none of them looks at
# /var/lib/flatpak or PATH on its own. Before this existed there were seven
# copies of that logic, and they disagreed: one Flatpak path skipped the tier
# narrowing and native applications never got their broker socket.
#
# MUJO_FLATPAK_ROOT, MUJO_TRUST_DB and MUJO_TRUST_NARROWING exist for the
# self-check (test-mujo-trust-launch.sh). They grant nothing: this only reads,
# and what it prints is run by the caller as the caller.
set -euo pipefail

FLATPAK_ROOT="${MUJO_FLATPAK_ROOT:-/var/lib/flatpak}"
DB="${MUJO_TRUST_DB:-/var/lib/mujo-trust/registry.json}"
NARROWING="${MUJO_TRUST_NARROWING:-/etc/mujo/flatpak-narrowing.json}"

die() { echo "mujo-trust-launch: $*" >&2; exit 1; }

is_flatpak_app() { [ -d "$FLATPAK_ROOT/app/$1" ]; }

# Sets: name kind identity, and for a Flatpak also fp_opts (the `flatpak run`
# options the caller gave) and fp_args (what follows the application id).
resolve_into() {
  [ "$#" -ge 1 ] || die "nothing to resolve"
  fp_opts=()
  fp_args=()

  if [ "$(basename -- "$1")" = flatpak ]; then
    [ "${2:-}" = run ] || die "only 'flatpak run <app>' can be launched through the trust engine"
    shift 2
    # The id is the first argument that names an installed application. That
    # skips options without needing flatpak's option table: a value given as a
    # separate word (`--command sh`) is not an installed application id.
    while [ "$#" -gt 0 ]; do
      if [ "${1#-}" = "$1" ] && is_flatpak_app "$1"; then break; fi
      fp_opts+=("$1")
      shift
    done
    [ "$#" -gt 0 ] || die "flatpak run: no installed application in the arguments"
    name="$1"
    shift
    fp_args=("$@")
  elif is_flatpak_app "$1"; then
    name="$1"
    shift
    fp_args=("$@")
  else
    local bin
    bin=$(type -P -- "$1") || die "$1: not found"
    name=$(basename -- "$1")
    kind=native
    identity=$(readlink -f -- "$bin")
    return 0
  fi

  kind=flatpak
  local active="$FLATPAK_ROOT/app/$name/current/active"
  [ -e "$active" ] || die "$name: Flatpak has no active deployment"
  identity=$(readlink -f -- "$active")
}

# A GRADUATED Flatpak's capability narrowing, into `narrow`. A per-application
# override wins outright, so an empty override is a real opt-out and not a
# fall-through to the tier profile (jq's `//` keeps an empty array).
narrow_for() {
  local tier
  tier=$(jq -r --arg a "$1" '.applications[$a].tier // "medium"' "$DB" 2>/dev/null) || tier=medium
  mapfile -t narrow < <(jq -r --arg a "$1" --arg t "$tier" \
    '(.overrides[$a] // .tiers[$t] // .default)[]' "$NARROWING")
}

emit() { printf '%s\0' "$@"; }

verb="${1:-}"
[ -n "$verb" ] || die "usage: mujo-trust-launch resolve|plan ..."
shift

case "$verb" in
  resolve)
    resolve_into "$@"
    printf '%s\t%s\t%s\n' "$name" "$kind" "$identity"
    ;;

  plan)
    runtime="${1:-}"
    shift || true
    resolve_into "$@"
    case "$runtime:$kind" in
      native:native)
        # --app always: it names the sandbox's persistent home, and attaches
        # the application's broker socket when the ACL gave it one.
        emit mujo-sandbox-run --app "$name" -- "$@"
        ;;
      native:flatpak)
        # flatpak reads its own options only before the application id, so the
        # narrowing goes straight after `run`. Anywhere later it would reach the
        # application and leave this an unnarrowed way in.
        narrow_for "$name"
        emit flatpak run "${narrow[@]}" "${fp_opts[@]}" "$name" "${fp_args[@]}"
        ;;
      quarantine:native)
        emit mujo-quarantine-run "$@"
        ;;
      quarantine:flatpak)
        emit mujo-quarantine-run flatpak run "${fp_opts[@]}" "$name" "${fp_args[@]}"
        ;;
      *)
        die "unknown runtime '$runtime'"
        ;;
    esac
    ;;

  *)
    die "unknown verb '$verb'"
    ;;
esac
