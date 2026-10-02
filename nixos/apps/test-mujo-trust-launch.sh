#!/usr/bin/env bash
# Self-check for application launch resolution (mujo-trust-launch.sh). Needs
# only bash, coreutils and jq: a fake Flatpak installation and a fake PATH in a
# scratch directory, and the real script run against them. `nix flake check`
# runs it too (checks.trustLaunch).
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

launch() { bash "$here/mujo-trust-launch.sh" "$@"; }
plan() { launch plan "$@" | tr '\0' '|'; }

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
expect() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', expected '$3')"; fi
}
refuses() {
  if launch "${@:2}" >/dev/null 2>&1; then fail "$1 (accepted)"; else pass "$1"; fi
}

# ── fixtures ────────────────────────────────────────────────────────────────
fp="$work/flatpak"
mkdir -p "$fp/app/org.example.Zen/stable/c0ffee/files" "$fp/app/org.example.Broken"
ln -s c0ffee "$fp/app/org.example.Zen/stable/active"
ln -s stable "$fp/app/org.example.Zen/current"
zen_identity=$(readlink -f "$fp/app/org.example.Zen/current/active")

store="$work/store/kitty-1.0/bin"
mkdir -p "$store" "$work/bin"
printf '#!/bin/sh\n' > "$store/kitty"
chmod +x "$store/kitty"
ln -s "$store/kitty" "$work/bin/kitty"

cat > "$work/narrowing.json" <<'EOF'
{
  "default": ["--nodevice=all", "--device=dri"],
  "tiers": {"low": [], "high": ["--nodevice=all", "--device=dri", "--disallow=devel"]},
  "overrides": {"org.example.OptOut": []}
}
EOF
mkdir -p "$fp/app/org.example.OptOut/stable/beef/files"
ln -s beef "$fp/app/org.example.OptOut/stable/active"
ln -s stable "$fp/app/org.example.OptOut/current"

export MUJO_FLATPAK_ROOT="$fp"
export MUJO_TRUST_DB="$work/registry.json"
export MUJO_TRUST_NARROWING="$work/narrowing.json"
export PATH="$work/bin:$PATH"

# ── resolve ─────────────────────────────────────────────────────────────────
expect "a program on PATH resolves to its store path" \
  "$(launch resolve kitty)" "kitty	native	$store/kitty"
expect "an absolute path is named by its basename, not the path" \
  "$(launch resolve "$work/bin/kitty" --hold)" "kitty	native	$store/kitty"
expect "a bare Flatpak id resolves to its active commit" \
  "$(launch resolve org.example.Zen)" "org.example.Zen	flatpak	$zen_identity"
expect "a desktop entry's flatpak run resolves to the application, not flatpak" \
  "$(launch resolve flatpak run --branch=stable --command=zen org.example.Zen --new-window)" \
  "org.example.Zen	flatpak	$zen_identity"
expect "an option value given as its own word is not taken for the id" \
  "$(launch resolve /run/current-system/sw/bin/flatpak run --command sh org.example.Zen)" \
  "org.example.Zen	flatpak	$zen_identity"
refuses "an unknown program is refused" resolve no-such-program
refuses "flatpak run with no installed application is refused" resolve flatpak run --command=sh
refuses "flatpak without run is refused" resolve flatpak update
refuses "a Flatpak with no active deployment is refused" resolve org.example.Broken

# ── plan: GRADUATED ─────────────────────────────────────────────────────────
expect "a native application gets the sandbox and its broker socket name" \
  "$(plan native kitty --hold)" "mujo-sandbox-run|--app|kitty|--|kitty|--hold|"
expect "an unregistered Flatpak gets the medium (default) narrowing" \
  "$(plan native org.example.Zen)" "flatpak|run|--nodevice=all|--device=dri|org.example.Zen|"
expect "narrowing goes before the caller's flatpak options, never after the id" \
  "$(plan native flatpak run --command=zen org.example.Zen --new-window)" \
  "flatpak|run|--nodevice=all|--device=dri|--command=zen|org.example.Zen|--new-window|"

echo '{"applications":{"org.example.Zen":{"tier":"high"}}}' > "$MUJO_TRUST_DB"
expect "the registry's tier picks the narrowing" \
  "$(plan native org.example.Zen)" \
  "flatpak|run|--nodevice=all|--device=dri|--disallow=devel|org.example.Zen|"
echo '{"applications":{"org.example.Zen":{"tier":"low"}}}' > "$MUJO_TRUST_DB"
expect "the low tier narrows nothing" \
  "$(plan native org.example.Zen)" "flatpak|run|org.example.Zen|"
expect "an empty override is an opt-out, not a fall-through" \
  "$(plan native org.example.OptOut)" "flatpak|run|org.example.OptOut|"

# ── plan: QUARANTINE ────────────────────────────────────────────────────────
expect "a quarantined native application goes to the MicroVM as given" \
  "$(plan quarantine kitty --hold)" "mujo-quarantine-run|kitty|--hold|"
expect "a quarantined Flatpak id is spelled as flatpak run for the MicroVM" \
  "$(plan quarantine org.example.Zen)" "mujo-quarantine-run|flatpak|run|org.example.Zen|"
expect "an absolute flatpak path is normalised for the MicroVM" \
  "$(plan quarantine /run/current-system/sw/bin/flatpak run --command=zen org.example.Zen)" \
  "mujo-quarantine-run|flatpak|run|--command=zen|org.example.Zen|"
refuses "an unknown runtime is refused" plan denied kitty

echo
if [ "$failures" -eq 0 ]; then
  echo "trust launch self-check: all passed"
else
  echo "trust launch self-check: $failures failure(s)"
  exit 1
fi
