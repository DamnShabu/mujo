# quickshell/

The `mujō` desktop shell: a Quickshell (QML runtime for Wayland) UI for the
Niri compositor — top bar, app launcher, system tray, Wi-Fi/Bluetooth/volume
menus, calendar, and an LLM usage tracker, all one shell process (`qs-bar`).
Packaged by `nixos/features/quickshell.nix` and run as a systemd user
service. Not built directly by `nix flake check` in isolation — iterate live
with `qs -p ./bar/shell.qml` (a separate instance from the live
`qs-bar` systemd service; tear it down with `qs kill -i <id>` when done),
since repo edits don't reach the running service until a full
`nh os switch` rebuild copies the tree into the Nix store (see
`_default.nix` below and root `AGENTS.md`).

## Files

- **`_default.nix`** — the Nix packaging glue, imported by
  `nixos/features/quickshell.nix` and `modules/wrappers/environment.nix`.
  Exposes three outputs:
  - `bar` — copies the entire `bar/` tree into a `runCommand` derivation
    (not just `shell.qml`) so sibling scripts (`llm-usage.sh`) and QML
    relative imports (`./modules/bar/modules`) resolve inside the store path.
  - `mujo` — wraps `mujo.sh` as a `writeShellScriptBin` package; this is the
    `mujo` CLI installed into the `environment` wrapper's `PATH`.
  - `cursor-tracker` — builds the `cursor-tracker` C helper from
    `cursor-tracker/cursor-tracker.c`; added to the `qs-bar` service `PATH`
    so `Wallpaper.qml` can spawn it for zoom/pan cursor tracking.
- **`mujo.sh`** — the `mujo` CLI's implementation:
  - `mujo wallpaper ...` — reads/writes `~/.config/quickshell/wallpaper.json`.
    Consumed by `bar/Wallpaper.qml` which polls the config every 2 s.
  - `mujo llm ...` — `model add/remove`, `tokens set/add`, `clear`, `show`.
    Writes `~/.config/qsshell/llm-status.json`, which `LlmTrackerMenu.qml`
    polls to display manually-tracked models/token counts alongside
    auto-detected local `ollama` models and auto-detected AI-assistant usage
    (via `bar/llm-usage.sh`: Claude Code, Codex, Antigravity, Gemini, opencode;
    no CLI command needed for that part).

## Subdirectories

- **`bar/`** — the shell's QML source: `shell.qml` entrypoint,
  `Wallpaper.qml` (per-screen wallpaper renderer with image/video and
  cursor-tracking zoom/pan), `llm-usage.sh` (AI-assistant usage detection),
  and `modules/bar/modules/` (all UI components, flat directory, manually
  registered in `qmldir`). Has its own `AGENTS.md` with the full
  architecture, component-registration recipe, and gotchas — read that
  first for anything touching QML.
- **`cursor-tracker/`** — small C helper that reads raw mouse input events
  from `/dev/input` and outputs normalised cursor positions as JSON. Used
  by `Wallpaper.qml`'s zoom/pan effect when `effects.motion` is enabled.
- **`keyring/`** — `mujo-keyring-prompter.py`, the Python D-Bus daemon that
  replaces GCR's GTK system prompter (see `nixos/features/keyring-prompter.nix`).

