# Design Specification: nix-mineral, Lynis, and Vulnix Integration

**Date**: 2026-09-15  
**Topic**: System Hardening, Auditing, and Vulnerability Scanning  
**Status**: Approved  

---

## 1. Context & Objectives
Mujo 2.0 provides a modular security architecture for a personal NixOS workstation (Intel CPU + AMD GPU, Niri Wayland, btrfs impermanence, MicroVM quarantine). To deepen defense-in-depth and ensure zero known unhandled vulnerabilities across the system closure:
1. **nix-mineral**: Integrate `cynicsketch/nix-mineral` system hardening to enforce secure sysctl parameters, entropy settings, and attack surface reductions without breaking desktop Wayland, audio, or virtualization.
2. **Lynis**: Integrate the Lynis security auditing suite with a customized profile (`mujo.prf`) optimized for NixOS declarative architecture, skipping slow recursive `/tmp` scanning and inapplicable traditional mutable FHS checks.
3. **Vulnix**: Integrate Vulnix CVE scanning for the system runtime closure, backed by a curated false-positive and build-time artifact whitelist (`vulnix-whitelist.toml`), asserting **0 unhandled vulnerabilities**.
4. **Tooling & Acceptance**: Expose `mujo security vulnix` and `mujo security lynis` in the CLI, and add an automated acceptance test in `tests/security/` run by `tests/run-all-tests.sh`.

---

## 2. Architecture & Components

### 2.1 Flake Input (`flake.nix`)
Add `nix-mineral` to `flake.nix`:
```nix
inputs.nix-mineral = {
  url = "github:cynicsketch/nix-mineral";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.follows = "flake-parts";
};
```

### 2.2 Security Module (`nixos/security/mineral.nix`)
* Declare `flake.nixosModules.security-mineral` controlled by `security.mujo.mineral.enable = lib.mkDefault true`.
* Import `inputs.nix-mineral.nixosModules.nix-mineral`.
* Apply `nix-mineral.preset = [ "compatibility" ];`.
* Specify overrides:
  * `filesystems.special."/proc".options.hidepid = false;` (guarantees session tracking for Wayland/Niri and user services).
  * `filesystems.normal."/home".options.noexec = false;` and `filesystems.normal."/tmp".options.noexec = false;`.
  * `kernel-modules.enable = false;` (keeps kernel module loading governed by Mujo to ensure AMD GPU, PipeWire, and MicroVM KVM/vsock drivers load cleanly).
  * `settings.misc.nix-wheel = false;` (allows normal non-wheel nix operations as configured by Mujo).

### 2.3 Host Wiring (`nixos/hosts/main/configuration.nix`)
Add `self.nixosModules.security-mineral` to the host's active module imports list.

### 2.4 Audit & Vulnerability Scanning (`nixos/security/audit.nix`)
* Add `pkgs.vulnix` and `pkgs.lynis` to `environment.systemPackages`.
* Wire `/etc/mujo/vulnix-whitelist.toml` from `./vulnix-whitelist.toml`.
* Wire `/etc/lynis/mujo.prf` from `./lynis-mujo.prf`.

### 2.5 Curated Whitelist (`nixos/security/vulnix-whitelist.toml`)
* Whitelists 112 verified build-time, non-runtime, and name-collision false positives (such as Haskell `Diff` library confused with Drupal Diff plugin, Plotly Dash confused with Debian Almquist shell, build-only rust compilers and tools like `yasm`).
* Target state: `vulnix --system -C -w /etc/mujo/vulnix-whitelist.toml` reports **0 unhandled vulnerabilities** and exits with code 0.

### 2.6 Tailored Lynis Profile (`nixos/security/lynis-mujo.prf`)
* Skip `FILE-7524` (old `/tmp` file iteration) to avoid freezing on massive build/scratch trees.
* Skip inapplicable FHS checks:
  * `BANN-7126` (login banners like `/etc/issue`).
  * `PKGS-7394` (traditional package manager database checks).
  * `BOOT-5122` (legacy grub/lilo configuration presence).
  * `KRNL-5830` (standalone sysctl configuration files outside systemd-sysctl).
* Configure quiet report mode and non-interactive execution.

### 2.7 CLI Subcommands (`quickshell/lib/security.sh` & `quickshell/mujo.sh`)
* `mujo security vulnix [args]`: Runs `vulnix --system -C -w "${wl}" "$@"`.
* `mujo security lynis [--privileged] [args]`: Runs `lynis audit system --profile "${prf}" --quick --no-colors`. When `--privileged` is specified, runs under `pkexec` or `sudo` to perform full system auditing.

### 2.8 Automated Acceptance Test (`tests/security/test-vulnerability-scan.sh`)
* Validates that `vulnix` is executable.
* Executes scan with whitelist and verifies 0 vulnerabilities are reported.
* Validates that `lynis` runs cleanly using `mujo.prf` without hanging.
* Registered in `tests/run-all-tests.sh`.

---

## 3. Testing & Verification
1. **Flake Evaluation**: `nix flake check` passes without option conflicts.
2. **Vulnix Verification**: `mujo security vulnix` exits 0 with 0 findings.
3. **Lynis Verification**: `mujo security lynis` completes the audit in seconds without stalling on `/tmp` and reports the hardening index.
4. **Security Acceptance Suite**: `bash tests/run-all-tests.sh` passes all tests including `test-vulnerability-scan.sh`.
