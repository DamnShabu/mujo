# AGENTS.md

## What this is

Quickshell desktop shell for Niri (Wayland). A status bar, app launcher, system tray, settings UI, and weather widget — all QML.

## Stack

- **Framework:** Quickshell (QML runtime for Wayland shells)
- **Compositor:** Niri (Wayland) — connected via `Niri` QML plugin
- **Language:** QML/JS (all UI), Perl (one helper script)
- **Config:** `~/.config/qsshell/settings.json` (JSON, loaded at startup)

## Architecture

```
shell.qml                  ← entrypoint, Niri connection, IPC handlers, panel per screen
modules/bar/modules/       ← all UI components (registered in qmldir)
super-monitor.pl           ← Perl: raw evdev reader for Super key tap → toggles launcher via IPC
```

**Theme singleton** (`modules/bar/modules/Theme.qml`): every visual component reads colors/sizes from here. SettingsMenu writes to it and persists to `~/.config/qsshell/settings.json`.

**IPC targets:** `launcher` (toggle/open/close), `settings` (toggle/open/close). Triggered via `qs ipc <target> <method>`.

**Launcher:** opened by Super key tap (detected in `super-monitor.pl`) or by clicking the clock pill / DynamicIsland. It's a `PopupWindow` anchored to the panel.

## Running

```bash
qs ./shell.qml              # launch
qs -r ./shell.qml           # reload
qs ipc launcher toggle      # toggle launcher
qs ipc settings toggle      # toggle settings
```

## Adding a new component

1. Create `YourComponent.qml` in `modules/bar/modules/`
2. Register it in `modules/bar/modules/qmldir`: `YourComponent YourComponent.qml`
3. Import from `shell.qml` via `import "./modules/bar/modules"` (already imported)

## Gotchas

- **Theme is a singleton** — all properties are global. Adding a new theme property requires updates in three places: `Theme.qml` (declaration), `SettingsMenu.qml` (`loadFromTheme` + `applySettings` + `writeConfig`), and `shell.qml` (config load block).
- **`qmldir` is manual** — new QML files won't be discovered unless registered there.
- **`super-monitor.pl`** reads raw `/dev/input/event*` evdev. It auto-detects keyboards by capability bitmask. If it prints "No keyboard devices found", it exits cleanly (bar still works, just no Super key toggle).
- **Settings save is debounced** (400ms). `applySettings()` validates hex colors with `#[0-9a-fA-F]{6}` regex before applying.
- **No build step** — QML is interpreted at runtime. Edit, then `qs -r` to reload.
- **Predefined themes** are hardcoded in `SettingsMenu.qml` `themes` property (Default, Nord, Dracula, Gruvbox, Catppuccin, Tokyo Night, Rose Pine, Solarized). "Custom" is for manual color editing.
