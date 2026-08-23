# modules/

Flake-parts modules that aren't NixOS host/feature modules: theming, per-system
package builds, and program wrappers. Everything here is imported explicitly
from `flake.nix` (or, for `wrappers/`, auto-discovered by `importTree` per
`AGENTS.md`) rather than wired through `nixos/hosts/main/configuration.nix`.

## Files

- **`theme.nix`** — defines the single color palette (`base00`..`base0F`,
  base16-style: `base00`/`base01` backgrounds, `base05` foreground, `base08`
  red through `base0F` brown) and exposes it as `self.theme`. Every wrapper
  config (kitty, etc.) and the quickshell `Theme.qml` singleton's defaults
  trace back to these values — change the palette here, not per-consumer.
- **`perSystem.nix`** — imports the `wrapper-modules` flake-parts module and
  defines `perSystem.packages` for things vendored/built locally rather than
  pulled from nixpkgs:
  - `quicksnip` — a `writeShellApplication` wrapping a screenshot/OCR tool
    fetched from an external Git repo, with its runtime deps (`grim`,
    `tesseract`, `wl-clipboard`, etc.) pinned.
  - Also home to other vendored packages referenced by `AGENTS.md`
    (`preload`, `skeuos-gtk`, `pibble`) — check this file before
    assuming a package comes from nixpkgs directly.

## Subdirectories

- **`wrappers/`** — program wrapper modules (fish, kitty, niri, the
  top-level `environment`/`terminal` wrappers). See
  `modules/wrappers/README.md`.
- **`preload/`** — a single patch file
  (`0001-prevent-building-to-var-directories.patch`) applied when building
  the vendored `preload` package (see `nixos/features/preload.nix`); not a
  flake-parts module itself.
