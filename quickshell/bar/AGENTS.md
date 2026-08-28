# Quickshell — shell architecture

The mujō desktop for Niri/Wayland: floating grouped top bar, overlay launcher, notifications, parallax wallpaper, Cava visualiser, staging shelf, system dialogs, and the standalone settings app. Repo-wide rules live in the root **`AGENTS.md`**.

## STACK

| Layer | Choice |
|---|---|
| Runtime | Quickshell 0.3.0 (QML for Wayland shells) |
| Compositor | Niri, via the `Niri` QML plugin (`qml-niri` flake input) |
| Languages | QML/JS for all UI; Python and C for helpers; Bash + jq for the `mujo` CLI |
| Live data | `Quickshell.Networking`, `.Bluetooth`, `.Services.Pipewire`, `.Services.SystemTray` |

## CONFIG & STATE

- **Config** — `~/.config/qsshell/*.json` and `~/.config/quickshell/*.json`. Key files: `settings.json` (reactive store owned by `services/SettingsBus.qml`), `theme.json` (palette, hot-reloaded), `wallpaper.json`.
- **Ephemeral state** — `~/.local/state/qsshell/*.json` (shelf, notifications, backups, desktop icon grid slots).
- **Desktop items** — `~/Desktop` is the source of truth for what exists; `desktop-icons.json` holds only grid slots, never anything the user would miss. `mujo desktop list|mkdir|new-file|rename|trash|open|info|path|into|copy|cut|paste|import|terminal|pos|pos-batch|forget` owns every read and write, takes an flock, and deletes via trash rather than `rm`. Anything it spawns that outlives the call (`wl-copy`, a terminal, `gio open`) must be given `9>&-` or it inherits the flock and wedges the next command. Cut/copy/paste go through the system clipboard in `x-special/gnome-copied-files`, so they interoperate with GTK file managers.
- **Desktop geometry** — the icon/widget surface is inset by `Theme.desktopInset` (+ the bar's reserved band on the bar's edge), which mirrors niri's `layout.gaps + layout.struts` in `modules/wrappers/niri.nix`. That is what keeps widgets from showing in the gap niri leaves around an open window; the wallpaper surface is separate and still edge to edge.
- **All writes go through the `mujo` CLI** (`quickshell/mujo.sh`), never bare shell tools — it is a `makeWrapper` package with jq/curl/git/tmux on `PATH` and writes atomically. QML invokes it via `Quickshell.execDetached`.

## ICONS

- **Standard actions use the system icon theme.** `components/MaterialIcon.qml` looks the Material Symbol name up in `theme/Icons.qml`, draws the theme's `*-symbolic` icon recoloured to `color` when there is one, and falls back to the Material Symbols glyph when there is not. Call sites keep passing Material Symbol names; add a mapping in `Icons.qml` rather than at the call site, and leave a name unmapped if no freedesktop icon honestly matches it.
- **File-type icons are full colour** (`Icons.fileIcon`), the desktop convention, keyed by extension.
- The theme comes from `QS_ICON_THEME`, set session-wide in `nixos/desktop/gtk.nix` and again in the `qs-bar` service. Without it Qt resolves nothing and every icon silently falls back to a glyph — `qs -p ./test-icons.qml` is the check.

## DIRECTORIES

```
shell.qml       desktop shell entrypoint (bar, launcher, overlays, prompts)
settings.qml    standalone settings app entrypoint
llm-usage.sh    AI-assistant token usage scanner
theme/          Theme.qml (design tokens), Anim.qml (motion), Brand.qml (identity)
components/     shared UI primitives
services/       singletons: settings bus, notifications, launch, lock, weather, cava, …
modules/        feature domains: bar/ launcher/ notifications/ desktop/ system/ settings/
```

Every directory carries a `qmldir`. Read it to see what a domain exposes rather than listing the tree.

## RUNNING

```bash
qs -p ./shell.qml                 # desktop shell from the working tree
qs -p ./settings.qml              # settings app from the working tree
qs -p ./test-icons.qml            # icon-theme resolution self-check — prints PASS/FAIL, then exits
qs -p ./test-grid.qml             # DesktopGrid occupancy self-check — prints PASS/FAIL, then exits
qs -p ./test-notifications.qml    # notification daemon & popup self-check — prints PASS/FAIL, then exits
qs -p ./test-shelf.qml            # staging shelf state & icon resolution self-check — prints PASS/FAIL, then exits
qs -p ./test-desktop.qml          # icon placement vs. a widget, against the real ~/Desktop
qs list --all                     # active instances
qs kill -i <id>                   # terminate one
qs -p /etc/xdg/quickshell/bar/shell.qml ipc call launcher toggle
```

**The live `qs-bar` service runs from the Nix store**, so working-tree edits reach it only after `nh os switch`. If a rebuild lands but the bar keeps old code, `systemctl --user restart qs-bar.service`.

## ADDING A COMPONENT

1. Create the file in the directory matching its role: `components/` (primitive), `services/` (engine or singleton), `modules/<domain>/` (feature).
2. **Register it in that directory's `qmldir`** — unregistered types fail as `"X is not a type"` or a runtime `ReferenceError`. Singletons need the `singleton` keyword: `singleton MyService MyService.qml`.
3. Import the shared domains it uses:
   ```qml
   import "../../theme"
   import "../../components"
   import "../../services"
   ```
   Same-directory types need no import.
4. Persist any new config path by declaring it in the owning NixOS module (see root `AGENTS.md` → **CORE CONSTRAINTS**).
