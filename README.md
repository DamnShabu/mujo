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
