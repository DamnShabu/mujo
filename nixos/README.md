# nixos/

All NixOS-side flake modules: shared option declarations, one-concern
feature modules, cross-cutting "extra" modules, and per-host configuration.
Everything here except `hosts/` and `extra/`'s underscore-free files is
auto-discovered by `importTree` from `flake.nix` — see root `AGENTS.md` for
the auto-discovery contract (evaluated ≠ activated; a module must also be
listed in `nixos/hosts/main/configuration.nix`'s `imports` to apply).

## Files

- **`base.nix`** — `flake.nixosModules.base`. Declares the shared option
  surface every other module reads from, rather than each defining its own:
  - `preferences.user.name` / `preferences.locale.*` — identity/locale,
    defaulted here and overridden by `nixos/features/user.nix`.
  - `persistence.*` — the impermanence option tree (`enable`,
    `nukeRoot.enable`, `volumeGroup`, `user`, and `directories`/`files`
    split into plain/`data`/`cache`) that `nixos/extra/impermanence.nix`
    consumes and that individual feature modules populate.

## Subdirectories

- **`features/`** — one NixOS feature module per concern (desktop, gaming,
  quickshell, vaultwarden, individual apps, ...). See
  `nixos/features/README.md`.
- **`extra/`** — cross-cutting infrastructure modules (hjem, impermanence,
  plymouth boot theme) that feature modules build on but aren't themselves
  "a feature". See `nixos/extra/README.md`.
- **`hosts/main/`** — the single host `main`: entrypoint, hardware/boot
  fragments, disk layout. See `nixos/hosts/main/README.md`.
