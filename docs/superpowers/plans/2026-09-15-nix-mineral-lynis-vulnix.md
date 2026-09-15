# nix-mineral, Lynis, and Vulnix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate `nix-mineral` hardening, `pkgs.lynis`, and `pkgs.vulnix` into Mujo's NixOS security architecture, providing declarative hardening, CLI tooling (`mujo security vulnix`/`lynis`), and verified zero unhandled vulnerabilities.

**Architecture:** Add `nix-mineral` as a flake input with a compatibility preset module in `nixos/security/mineral.nix`. Install `vulnix` and `lynis` via `nixos/security/audit.nix` backed by a curated 112-entry whitelist (`vulnix-whitelist.toml`) and an optimized profile (`lynis-mujo.prf`). Expose scans via `quickshell/lib/security.sh` and guard against regressions via `tests/security/test-vulnerability-scan.sh`.

**Tech Stack:** NixOS 26.11, Flake-parts, nix-mineral, Lynis 3.1.7, Vulnix 1.10.2, Bash / Quickshell CLI.

**Spec:** [`docs/superpowers/specs/2026-09-15-nix-mineral-lynis-vulnix-design.md`](file:///home/yurii/nixconf/docs/superpowers/specs/2026-09-15-nix-mineral-lynis-vulnix-design.md)

## Global Constraints
- Absolute path required for nix flake invocations (`/home/yurii/nixconf#main`).
- Git-add all new files before rebuilding or evaluating flakes.
- Presets for nix-mineral must not break Niri Wayland (`/proc` hidepid must be false), audio, AMD GPU (`amdgpu`), or MicroVM KVM/vsock.
- Vulnix scan target must report 0 unhandled vulnerabilities against `/run/current-system`.
- Lynis must not stall on `/tmp` file enumeration (skip `FILE-7524`).

---

### Task 1: Flake Input & `nix-mineral` Security Module

**Files:**
- Modify: `flake.nix`
- Create: `nixos/security/mineral.nix`
- Modify: `nixos/hosts/main/configuration.nix`

**Interfaces:**
- Consumes: `inputs.nix-mineral`
- Produces: `flake.nixosModules.security-mineral`, option `security.mujo.mineral.enable`

- [ ] **Step 1: Add nix-mineral input to flake.nix**
Add `nix-mineral` to inputs in `flake.nix`:
```nix
    nix-mineral = {
      url = "github:cynicsketch/nix-mineral";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
```

- [ ] **Step 2: Create nixos/security/mineral.nix**
Implement `flake.nixosModules.security-mineral`:
```nix
{inputs, ...}: {
  flake.nixosModules.security-mineral = {
    config,
    lib,
    ...
  }: let
    cfg = config.security.mujo.mineral;
  in {
    imports = [
      inputs.nix-mineral.nixosModules.nix-mineral
    ];

    options.security.mujo.mineral = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.security.mujo.enable;
        description = "Enable nix-mineral kernel, sysctl, and attack surface hardening with desktop compatibility";
      };
    };

    config = lib.mkIf cfg.enable {
      nix-mineral = {
        enable = true;
        preset = ["compatibility"];

        # Guarantee desktop & virtualization compatibility overrides
        filesystems = {
          special = {
            "/proc".options.hidepid = false;
          };
          normal = {
            "/home".options.noexec = false;
            "/tmp".options.noexec = false;
          };
        };

        kernel-modules.enable = false; # Mujo manages driver and kernel module loading
        settings.misc.nix-wheel = false; # Allow normal nix operation
      };
    };
  };
}
```

- [ ] **Step 3: Register security-mineral in nixos/hosts/main/configuration.nix**
Add `self.nixosModules.security-mineral` to module imports.

- [ ] **Step 4: Test flake evaluation**
Run: `nix flake check --no-build`
Expected: Evaluates successfully with no module errors.

- [ ] **Step 5: Commit**
```bash
git add flake.nix flake.lock nixos/security/mineral.nix nixos/hosts/main/configuration.nix
git commit -m "feat(security): add nix-mineral hardening module with desktop compatibility"
```

---

### Task 2: Configure Vulnix Whitelist & Lynis NixOS Profile

**Files:**
- Create: `nixos/security/lynis-mujo.prf`
- Modify: `nixos/security/audit.nix`
- Staged: `nixos/security/vulnix-whitelist.toml`

**Interfaces:**
- Consumes: `pkgs.vulnix`, `pkgs.lynis`
- Produces: `/etc/mujo/vulnix-whitelist.toml`, `/etc/lynis/mujo.prf`

- [ ] **Step 1: Create nixos/security/lynis-mujo.prf**
Create the tailored Lynis profile for NixOS:
```ini
# Mujo Lynis profile optimized for NixOS
# Skips inapplicable legacy FHS checks and slow /tmp traversals

# Skip slow file scanning in /tmp (prevents hanging on large ephemeral trees)
skip-test=FILE-7524

# Inapplicable on NixOS immutable store & systemd architecture
skip-test=BANN-7126
skip-test=PKGS-7394
skip-test=BOOT-5122
skip-test=KRNL-5830
skip-test=AUTH-9288
skip-test=FINT-4350

# Configure non-interactive behavior
quick=yes
quiet=no
```

- [ ] **Step 2: Update nixos/security/audit.nix**
Ensure `audit.nix` installs `pkgs.vulnix`, `pkgs.lynis`, `/etc/mujo/vulnix-whitelist.toml`, and `/etc/lynis/mujo.prf`:
```nix
      environment.systemPackages = [
        pkgs.vulnix
        pkgs.lynis
      ];

      environment.etc."mujo/vulnix-whitelist.toml".source = ./vulnix-whitelist.toml;
      environment.etc."lynis/mujo.prf".source = ./lynis-mujo.prf;
```

- [ ] **Step 3: Verify vulnix against whitelist**
Run: `nix run nixpkgs#vulnix -- --system -C -w nixos/security/vulnix-whitelist.toml`
Expected: Output shows "Nothing to show, but 112 left out due to whitelisting" with exit code 0.

- [ ] **Step 4: Verify lynis with mujo.prf**
Run: `nix shell nixpkgs#lynis -c lynis audit system --profile nixos/security/lynis-mujo.prf --quick --no-colors`
Expected: Lynis audit finishes promptly without stalling on `/tmp` and outputs hardening index.

- [ ] **Step 5: Commit**
```bash
git add nixos/security/audit.nix nixos/security/vulnix-whitelist.toml nixos/security/lynis-mujo.prf
git commit -m "feat(security): configure vulnix whitelist and tailored lynis audit profile"
```

---

### Task 3: CLI Subcommands for Vulnix & Lynis

**Files:**
- Modify: `quickshell/lib/security.sh`
- Modify: `quickshell/mujo.sh`

**Interfaces:**
- Consumes: `/etc/mujo/vulnix-whitelist.toml`, `/etc/lynis/mujo.prf`
- Produces: `mujo security vulnix`, `mujo security lynis`

- [ ] **Step 1: Implement vulnix and lynis handlers in quickshell/lib/security.sh**
In `mujo_security`:
```bash
      vulnix)
        shift || true
        wl="/etc/mujo/vulnix-whitelist.toml"
        if [[ ! -f "${wl}" ]]; then
          script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)"
          wl="${script_dir}/nixos/security/vulnix-whitelist.toml"
        fi
        if command -v vulnix >/dev/null 2>&1; then
          if [[ -f "${wl}" ]]; then
            vulnix --system -C -w "${wl}" "$@"
          else
            vulnix --system -C "$@"
          fi
        else
          nix run nixpkgs#vulnix -- --system -C -w "${wl}" "$@"
        fi
        ;;

      lynis)
        shift || true
        prf="/etc/lynis/mujo.prf"
        if [[ ! -f "${prf}" ]]; then
          script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)"
          prf="${script_dir}/nixos/security/lynis-mujo.prf"
        fi
        priv=false
        args=()
        for arg in "$@"; do
          if [[ "${arg}" == "--privileged" ]]; then
            priv=true
          else
            args+=("${arg}")
          fi
        done
        cmd="lynis"
        if ! command -v lynis >/dev/null 2>&1; then
          cmd="nix shell nixpkgs#lynis -c lynis"
        fi
        if [[ "${priv}" == "true" ]]; then
          pkexec env PATH="$PATH" ${cmd} audit system --profile "${prf}" --quick --no-colors "${args[@]}"
        else
          ${cmd} audit system --profile "${prf}" --quick --no-colors "${args[@]}"
        fi
        ;;
```

- [ ] **Step 2: Update quickshell/mujo.sh help text**
Add `lynis` documentation to `mujo security` help.

- [ ] **Step 3: Test CLI commands**
Run: `bash quickshell/mujo.sh security vulnix`
Expected: 0 vulnerabilities found.
Run: `bash quickshell/mujo.sh security lynis`
Expected: Lynis runs through to completion and outputs scan results.

- [ ] **Step 4: Commit**
```bash
git add quickshell/lib/security.sh quickshell/mujo.sh
git commit -m "feat(cli): add vulnix and lynis subcommands to mujo security"
```

---

### Task 4: Automated Acceptance Test

**Files:**
- Create: `tests/security/test-vulnerability-scan.sh`
- Modify: `tests/run-all-tests.sh`

**Interfaces:**
- Consumes: `vulnix`, `nixos/security/vulnix-whitelist.toml`
- Produces: automated test in `tests/run-all-tests.sh`

- [ ] **Step 1: Create tests/security/test-vulnerability-scan.sh**
```bash
#!/usr/bin/env bash
# Security Acceptance Test: Vulnix 0-Vulnerability Target Verification
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR/../lib.sh"

echo "=== Testing System Closure Vulnerability Status (Vulnix) ==="

WL="/etc/mujo/vulnix-whitelist.toml"
if [[ ! -f "$WL" ]]; then
  WL="$SCRIPT_DIR/../../nixos/security/vulnix-whitelist.toml"
fi

assert_file_exists "$WL" "vulnix-whitelist.toml must be present"

if command -v vulnix >/dev/null 2>&1; then
  VULNIX_BIN="vulnix"
else
  VULNIX_BIN="nix run nixpkgs#vulnix --"
fi

OUT=$($VULNIX_BIN --system -C -w "$WL" 2>&1 || true)
if echo "$OUT" | grep -qi "Nothing to show"; then
  echo "PASS: Vulnix reports 0 unhandled vulnerabilities on system closure"
else
  echo "FAIL: Vulnix detected unhandled vulnerabilities:"
  echo "$OUT"
  exit 1
fi
```

- [ ] **Step 2: Register test in tests/run-all-tests.sh**
Add `run_test "$SCRIPT_DIR/security/test-vulnerability-scan.sh"` to `tests/run-all-tests.sh`.

- [ ] **Step 3: Run the test directly**
Run: `bash tests/security/test-vulnerability-scan.sh`
Expected: "PASS: Vulnix reports 0 unhandled vulnerabilities on system closure".

- [ ] **Step 4: Commit**
```bash
git add tests/security/test-vulnerability-scan.sh tests/run-all-tests.sh
git commit -m "test(security): add vulnix 0-vulnerability acceptance test"
```

---

### Task 5: End-to-End Verification

**Files:**
- All modified files

- [ ] **Step 1: Run shellcheck on all tracked shell scripts**
Run: `nix shell nixpkgs#shellcheck -c shellcheck -S warning -e SC1090 -P quickshell $(git ls-files '*.sh')`
Expected: 0 errors / warnings.

- [ ] **Step 2: Evaluate flake**
Run: `nix flake check --no-build`
Expected: Evaluates cleanly without error.

- [ ] **Step 3: Run full security acceptance test suite**
Run: `bash tests/security/test-vulnerability-scan.sh`
Expected: PASS.
