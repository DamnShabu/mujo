#!/usr/bin/env bash
# Shared helpers for the Mujo security acceptance suite.
#
# Rule for this suite: a check either proves the invariant holds or it FAILS.
# "configured in the module but not active yet" is a failure of the running
# system, not a pass — rebuild, then re-run.

PASS=0
FAIL=0
SKIP=0

pass() {
  echo "  [PASS] $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  [FAIL] $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo "  [SKIP] $1"
  SKIP=$((SKIP + 1))
}

# check_sysctl <key> <expected> — compares the RUNNING kernel, not the config.
check_sysctl() {
  local key="$1" expected="$2"
  local proc_path="/proc/sys/${key//.//}"
  local actual

  if [ ! -e "$proc_path" ]; then
    fail "$key is absent from the running kernel (expected $expected)"
    return
  fi
  if ! actual=$(cat "$proc_path" 2>/dev/null); then
    # Unreadable by an unprivileged caller is itself the hardening for some keys,
    # but we cannot confirm the value, so this is inconclusive rather than proven.
    skip "$key is unreadable as $(id -un); re-run as root to verify it equals $expected"
    return
  fi
  if [ "$actual" = "$expected" ]; then
    pass "$key = $actual"
  else
    fail "$key = $actual (expected $expected) — rebuild if the module was just changed"
  fi
}

# Impermanence layout: bind-mount sources live under these roots, so a scan of
# "persistent storage" must look here, not at the runtime paths.
PERSIST_ROOTS=(/persist/system /persist/userdata /persist/usercache)

persist_roots_present() {
  local r
  for r in "${PERSIST_ROOTS[@]}"; do
    [ -d "$r" ] && return 0
  done
  return 1
}

# The sensitive-data inventory (docs/storage-model.md Phase 6): the paths a
# secret is actually expected to land in. /persist is ~560G here, so a full
# sweep is not a test — it is an afternoon. Deep sweeps go through
# scan_persist_deep, which callers opt into explicitly.
SENSITIVE_GLOBS=(
  'home/*/.ssh'
  'home/*/.gnupg'
  'home/*/.password-store'
  'home/*/.aws'
  'home/*/.docker'
  'home/*/.config/gh'
  'home/*/.config/sops'
  'home/*/.local/share/keyrings'
  'home/*/.zen'
  'home/*/.mozilla'
  'etc/NetworkManager/system-connections'
  'etc/ssh'
  'var/lib/mullvad-vpn'
)

# sensitive_paths — every inventory path that exists under the persist roots.
sensitive_paths() {
  local root glob
  for root in "${PERSIST_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    for glob in "${SENSITIVE_GLOBS[@]}"; do
      # shellcheck disable=SC2086
      for p in $root/$glob; do
        [ -e "$p" ] && printf '%s\n' "$p"
      done
    done
  done
}

# scan_sensitive <pattern> — files under the inventory paths matching <pattern>.
scan_sensitive() {
  local -a paths
  mapfile -t paths < <(sensitive_paths)
  [ "${#paths[@]}" -eq 0 ] && return 0
  grep -rIl --binary-files=without-match -- "$1" "${paths[@]}" 2>/dev/null || true
}

# scan_persist_deep <pattern> — full sweep of every persist root, bounded to
# files under 1 MiB (a leaked secret is small; media files are not). Slow by
# construction; only the physical-extraction test runs it.
scan_persist_deep() {
  local -a roots=()
  local r
  for r in "${PERSIST_ROOTS[@]}"; do
    [ -d "$r" ] && roots+=("$r")
  done
  [ "${#roots[@]}" -eq 0 ] && return 0
  find "${roots[@]}" -type f -size -1M -print0 2>/dev/null |
    xargs -0 -r grep -Il --binary-files=without-match -- "$1" 2>/dev/null || true
}

# list_findings <label> <path...> — prints at most 10, then a count.
list_findings() {
  local -a items=("$@")
  printf '           %s\n' "${items[@]:0:10}"
  [ "${#items[@]}" -gt 10 ] && printf '           ... and %d more\n' "$((${#items[@]} - 10))"
  return 0
}

report() {
  echo "Summary: $PASS passed, $FAIL failed, $SKIP skipped."
  [ "$FAIL" -eq 0 ]
}
