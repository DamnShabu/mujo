# NixOS Flake & Quickshell Agent Instructions

## Flake structure
* Single host `main`. `nixos/hosts/main/configuration.nix` defines both `nixosConfigurations.main` and `nixosModules.hostMain`; host-specific fragments are underscore files (`_boot.nix`, `_networking.nix`, `_hardware-and-services.nix`) imported there.

## Module auto-discovery (high risk of error)
* `flake.nix` auto-imports every `.nix` file **without** a leading `_` from `./nixos/` and `./modules/wrappers/` via `importTree`.
* Auto-import only *evaluates* the file — it does NOT activate it on the host. A feature module must define `flake.nixosModules.<name>` and be added to the `imports` list in `nixos/hosts/main/configuration.nix` (`self.nixosModules.<name>`). A new feature file not wired there silently does nothing.
* Underscore files (`_foo.nix`) are fragments; import them explicitly where needed.
* `modules/theme.nix` and `modules/perSystem.nix` are flake-parts modules imported explicitly in `flake.nix` (outside `importTree`).

## Rebuilding
* The agent is allowed to rebuild the NixOS system by using `pkexec nixos-rebuild switch --flake .#main`. The user will accept the pkexec authorization prompt.
* Apply: `pkexec nixos-rebuild switch --flake .#main` (run from `~/nixconf`). Escalates via polkit's pkexec wrapper (`security.polkit.enablePkexecWrapper`, see `nixos/features/desktop.nix`).
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
* This is a full desktop shell (launcher, settings UI, tray, weather, wallpaper) — one shell, `quickshell/bar/shell.qml`, run as the `qs-bar` systemd user service from a Nix-built copy (`quickshell/_default.nix`). `Wallpaper.qml` lives alongside `shell.qml` in `quickshell/bar/` and is instantiated as `Wallpaper {}` inside `shell.qml`'s `ShellRoot`. Repo edits do NOT go live until rebuild; iterate from the working tree with `qs -p ./quickshell/bar/shell.qml` (spawns a separate instance from the live systemd one — `qs kill -i <id>` afterward, see `qs list --all`).
* New QML components MUST be registered manually in `quickshell/bar/modules/bar/modules/qmldir` as `<Name> <Name.qml>`.
* Theme singleton: a new property needs sync in three places — `Theme.qml` (decl), `SettingsMenu.qml` (load/apply/write), `shell.qml` (config load).
* Details: `quickshell/bar/AGENTS.md`.

## Misc
* `modules/theme.nix` exposes palette `self.theme.base00..base0F`; wrapper configs (kitty, etc.) read colors from it.
* `modules/perSystem.nix` vendors packages removed/broken in nixpkgs (preload, skeuos-gtk, quicksnip).

## Linting & formatting
* `trunk check` / `trunk fmt` only. Don't run standalone formatters (prettier/ruff/nixpkgs-fmt) manually — trunk manages them.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- Nix/QML support is a local patch (adapted from Graphify-Labs/graphify#1048 + a QML component-reference walker), NOT upstream. After any `uv tool install --upgrade graphifyy`, re-apply with `nix-shell -p uv --run ~/nixconf/tools/graphify/apply.sh` (idempotent; installs tree-sitter-nix/tree-sitter-qmljs and rewires the venv).
