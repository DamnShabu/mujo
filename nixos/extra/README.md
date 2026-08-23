# nixos/extra/

Cross-cutting infrastructure modules that other modules depend on but that
aren't a "feature" in their own right (compare `nixos/features/`). Each
defines a `flake.nixosModules.extra_*`; they're wired into the host via
`nixos/hosts/main/configuration.nix` (directly, or transitively through
`nixos/features/impermanence.nix`).

## Files

- **`hjem.nix`** — `flake.nixosModules.extra_hjem`. Enables `hjem` (this
  repo's dotfile/user-file manager — **not** home-manager, see root
  `AGENTS.md`) for `config.preferences.user.name`, with
  `clobberByDefault = true`. Currently manages exactly one file:
  `~/.gitconfig`, hardcoded to `DamnShabu <DamnShabu@porkbuns.xyz>`.
- **`impermanence.nix`** — `flake.nixosModules.extra_impermanence`. The
  mechanics behind the `persistence.*` options declared in
  `nixos/base.nix`: imports the `impermanence` flake input and, when
  `persistence.enable` is set, wires three persistent bind-mount roots under
  `/persist` (which is `neededForBoot`):
  - `/persist/userdata` — `persistence.data.*` (per-user files/dirs, plus
    `.face.icon` always symlinked).
  - `/persist/usercache` — `persistence.cache.*`.
  - `/persist/system` — fixed system paths (`/etc/nixos`, `/var/log`,
    bluetooth/NetworkManager/zerotier state, `/etc/machine-id`, etc.) plus
    whatever `persistence.directories`/`files` a feature module adds.

  Also contains a one-time, self-disabling `cleanup-removed-features`
  activation script that unmounts and deletes leftover state from features
  that no longer exist (old mullvad cache, removed searxng/sops-age dirs) —
  see the in-file comment before touching it; delete the whole block once
  migration is confirmed done.

  When `persistence.nukeRoot.enable` is set, adds an initrd step that wipes
  the root btrfs subvolume on every boot (moving the old one under
  `old_roots/<timestamp>`, pruning entries older than 30 days) — this is the
  literal "impermanence" the repo's `mujō` name and root `AGENTS.md` refer
  to.
- **`nixos-plymouth.nix`** — `flake.nixosModules.extra_plymouth`. Builds and
  enables a custom Plymouth (boot splash) theme, `nixos-mac-style`, from the
  assets in `nixos-plymouth/`. Rewrites the theme's hardcoded
  `/usr/share/...` image path to the built Nix store path at build time.

## Subdirectory

- **`nixos-plymouth/`** — theme assets consumed by `nixos-plymouth.nix`:
  `nixos-mac-style.plymouth` (theme descriptor), `images/animation-00..80.png`
  + `progress-00..50.png` (boot animation frames), and standalone icons
  (`bullet`, `capslock`, `entry`, `keyboard`, `keymap-render`, `lock`).
  `Screenshot.png` is a preview of the theme, not consumed by the build.
