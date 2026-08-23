# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Start here

This repo already has a detailed **AGENTS.md** at the root covering flake structure, module auto-discovery, rebuilding, user identity, impermanence, secrets, and the quickshell shell — read it first. `quickshell/bar/AGENTS.md` has the same for the quickshell bar specifically. This file only adds what those don't cover.

## What this is

`mujō` — a personal NixOS flake config (flake-parts based) for a single host, `main` (AMD desktop — AMD CPU + AMD GPU via `amdgpu`, dual monitor). Not a library or app repo; changes are validated by evaluating/building the flake, not by a test suite.

## Commands

The agent is allowed to rebuild the NixOS system by using `pkexec nixos-rebuild switch --flake .#main`. The user will accept the pkexec authorization prompt.

```bash
pkexec nixos-rebuild switch --flake .#main   # apply config — run from ~/nixconf
nix flake check             # validate the flake evaluates
nix flake show               # inspect outputs
trunk check                  # lint (nixpkgs-fmt, shellcheck, markdownlint, ruff, etc.)
trunk fmt                    # format — don't run prettier/ruff/nixpkgs-fmt standalone, trunk owns this
qs -p ./quickshell/bar/shell.qml   # launch a separate test instance from the working tree (repo edits aren't picked up by the running qs-bar systemd service until rebuild); qs kill -i <id> to tear it down
```

There is no unit test suite; correctness is checked via `nix flake check` and, for quickshell, manual `qs -p` test-instance verification.

## Architecture (beyond AGENTS.md)

- **Entry point:** `flake.nix` wires `flake-parts`. `modules/theme.nix` and `modules/perSystem.nix` are imported explicitly; everything else under `nixos/` and `modules/wrappers/` is auto-discovered via `importTree` (any `.nix` file without a leading `_`).
- **Host wiring:** `nixos/hosts/main/configuration.nix` is the single place that turns an auto-discovered feature module into something that actually applies to the host — it lists `self.nixosModules.<name>` in `imports`. A feature file under `nixos/features/` that isn't in this list evaluates but does nothing.
- **Host fragments:** `nixos/hosts/main/_boot.nix`, `_networking.nix`, `_hardware-and-services.nix` are underscore-prefixed (not auto-imported) and pulled in explicitly by `configuration.nix`.
- **Features vs wrappers:** `nixos/features/*.nix` are NixOS feature modules (one concern each — gaming, steam, quickshell, vaultwarden secrets, etc.); `modules/wrappers/*.nix` wrap specific programs (fish, kitty, niri, environment) using the `nix-wrapper-modules` input.
- **Vendored packages:** `modules/perSystem.nix` builds packages removed/broken upstream in nixpkgs (preload, skeuos-gtk, quicksnip) — check here before assuming a package comes from nixpkgs directly.
- **Theming:** `modules/theme.nix` defines the palette (`self.theme.base00..base0F`); wrapper configs read from it rather than hardcoding colors.
- **Persistence:** btrfs root is wiped on boot (impermanence). Anything that must survive goes into `persistence.data.directories` / `persistence.cache.directories` / `persistence.directories` / `persistence.files`; each feature module owns its own persistence entries rather than a central list.
- **User identity:** never hardcode `"yurii"` — use `config.preferences.user.name`, sourced from gitignored `secrets/username` with `"yurii"` as fallback (`nixos/features/user.nix`).

## Agent skills

### Issue tracker

Issues live as GitHub issues in `DamnShabu/mujo`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context (`CONTEXT.md` + `docs/adr/` at the repo root). See `docs/agents/domain.md`.
