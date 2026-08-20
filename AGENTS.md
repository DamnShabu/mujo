# NixOS Flake & Quickshell Agent Instructions

## Flake structure
* Single host `main`. `nixos/hosts/main/configuration.nix` defines both `nixosConfigurations.main` and `nixosModules.hostMain`; host-specific fragments are underscore files (`_boot.nix`, `_networking.nix`, `_hardware-and-services.nix`) imported there.

## Module auto-discovery (high risk of error)
* `flake.nix` auto-imports every `.nix` file **without** a leading `_` from `./nixos/` and `./modules/wrappers/` via `importTree`.
* Auto-import only *evaluates* the file — it does NOT activate it on the host. A feature module must define `flake.nixosModules.<name>` and be added to the `imports` list in `nixos/hosts/main/configuration.nix` (`self.nixosModules.<name>`). A new feature file not wired there silently does nothing.
* Underscore files (`_foo.nix`) are fragments; import them explicitly where needed.
* `modules/theme.nix` and `modules/perSystem.nix` are flake-parts modules imported explicitly in `flake.nix` (outside `importTree`).

## Rebuilding
* Apply: `nh os switch ~/nixconf/`. Passwordless because a sudo rule whitelists `/nix/store/*-nixos-system-*/bin/nixos-rebuild`; don't invoke `nixos-rebuild` by hand.
* Validate: `nix flake check` / `nix flake show`.

## User identity
* Never hardcode `"yurii"`. Username resolves from gitignored `secrets/username` (fallback `"yurii"` in `nixos/features/user.nix`). Always use `config.preferences.user.name`.

## Impermanence & home config
* btrfs root subvolume is nuked on boot; persistent state lives under `/persist`. Anything that must survive reboot goes into `persistence.data.directories`, `persistence.cache.directories`, or `persistence.directories`/`persistence.files` (system paths). Convention: each feature module declares its own persistence entries.
* User config uses **hjem** (`hjem.users."${user}".files/...`), not home-manager.

## Secrets
* Custom Vaultwarden-backed option (SecretSpec + `bw` CLI), implemented in `nixos/features/vaultwarden.nix`; enable with `secrets.vaultwarden.enable = true`:
  ```nix
  secrets.vaultwarden.files.myservice = { item = "item"; field = "field"; type = "login"; };
  ```
  Also `secrets.vaultwarden.sshKeys.*` / `gpgKeys.*`.

## Quickshell shell (`quickshell/`)
* This is a full desktop shell (launcher, settings UI, tray, weather), not just a status bar. Two shells run as systemd user services from Nix-built copies (`quickshell/_default.nix`): `qs-bar` (main shell, `quickshell/bar/shell.qml`) and `qs-combined` (`Shell.qml` + `Wallpaper.qml`). Repo edits do NOT go live until rebuild; iterate from the working tree with `qs -r ./quickshell/bar/shell.qml`.
* New QML components MUST be registered manually in `quickshell/bar/modules/bar/modules/qmldir` as `<Name> <Name.qml>`.
* Theme singleton: a new property needs sync in three places — `Theme.qml` (decl), `SettingsMenu.qml` (load/apply/write), `shell.qml` (config load).
* Details: `quickshell/bar/AGENTS.md`.

## Misc
* `modules/theme.nix` exposes palette `self.theme.base00..base0F`; wrapper configs (kitty, etc.) read colors from it.
* `modules/perSystem.nix` vendors packages removed/broken in nixpkgs (preload, psst, skeuos-gtk, quicksnip, pibble, cursor-tracker).

## Linting & formatting
* `trunk check` / `trunk fmt` only. Don't run standalone formatters (prettier/ruff/nixpkgs-fmt) manually — trunk manages them.
