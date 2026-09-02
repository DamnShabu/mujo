#!/usr/bin/env bash
# Build and boot nixosConfigurations.main as a real installed system.
#
#   bash tests/vm/run.sh
#
# The disk image is a temporary qcow2 overlay that disko-vm deletes on exit, so
# every run starts from a freshly formatted disk and nothing you do inside the
# VM survives. Log in is automatic as root; the user's password is "vmtest".
# `poweroff` shuts it down; Ctrl-a x kills qemu if it stops responding.
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

# The flake source is git: an unstaged tests/vm/disko-vm.nix is invisible here.
if ! git -C "$repo" ls-files --error-unmatch tests/vm/disko-vm.nix >/dev/null 2>&1; then
  echo "tests/vm/disko-vm.nix is not tracked by git; run 'git add' first." >&2
  exit 1
fi

echo "Building the disk image (first run formats and installs; later runs are cached)..." >&2
vm=$(nix build --impure --no-link --print-out-paths --expr "
  let f = builtins.getFlake \"$repo\";
  in (f.nixosConfigurations.main.extendModules {
       modules = [ $repo/tests/vm/disko-vm.nix ];
     }).config.system.build.vmWithDisko
")

# Run from a scratch dir: run-*-vm drops an EFI vars file in the cwd, and that
# is not something to leave in the repo.
rundir=$(mktemp -d)
trap 'rm -rf "$rundir"' EXIT
cd "$rundir"

exec "$vm/bin/disko-vm" "$@"
