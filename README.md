# mujō

Personal NixOS flake configuration.

## Hosts

- **main** — Primary desktop (AMD, Nvidia VR, dual monitor)

## Usage

```bash
nh os switch ~/nixconf/
```

## Architecture

The host configuration is organized into focused Nix modules under the host directory to keep the main entrypoint readable and easier to evolve:

- `nixos/hosts/main/configuration.nix` — host entrypoint and module wiring
- `nixos/hosts/main/_boot.nix` — bootloader and kernel configuration
- `nixos/hosts/main/_networking.nix` — hostname and networking defaults
- `nixos/hosts/main/_hardware-and-services.nix` — graphics, services, desktop integration, and system packages

This keeps platform-specific concerns separated from the broader feature modules in `nixos/features/` while preserving the existing flake structure and behavior.

## Repo map

Start with `AGENTS.md` (flake structure, auto-discovery, rebuilding,
persistence, secrets) and `CLAUDE.md` (Claude Code-specific notes) at the
root. Every major directory has its own `README.md` with a per-file
breakdown:

- [`modules/`](modules/README.md) — theming, vendored per-system packages
  - [`modules/wrappers/`](modules/wrappers/README.md) — fish/kitty/niri program wrappers
- [`nixos/`](nixos/README.md) — shared options + host wiring
  - [`nixos/extra/`](nixos/extra/README.md) — hjem, impermanence, Plymouth theme
  - [`nixos/features/`](nixos/features/README.md) — one module per concern (desktop, gaming, quickshell, vaultwarden, apps, ...)
  - [`nixos/hosts/main/`](nixos/hosts/main/README.md) — the `main` host: entrypoint, boot/hardware/networking, disk layout
- [`quickshell/`](quickshell/README.md) — the `mujō` desktop shell (bar, launcher, tray, settings, wallpaper)
  - `quickshell/bar/AGENTS.md` — shell architecture, component recipe, gotchas
  - [`quickshell/bar/modules/bar/modules/`](quickshell/bar/modules/bar/modules/README.md) — every QML component

## Fresh Install

> Run from a **NixOS live USB**, not from the system being replaced.

```bash
# 1. Partition & format
sudo nix run github:nix-community/disko -- --mode disko ./nixos/hosts/main/disko.nix

# 2. Install
sudo nixos-install --flake .#main --root /mnt

# 3. Reboot, then apply
nh os switch ~/nixconf/
```

> Reinstall over existing: use `nixos-rebuild switch` (not `nixos-install`) to keep persist data.
