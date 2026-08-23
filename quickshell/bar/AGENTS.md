# AGENTS.md

## What this is

Quickshell desktop shell for Niri (Wayland): top bar, app launcher, system
tray, Wi-Fi/Bluetooth/volume menus, calendar, and an LLM usage tracker — all
QML.

## Stack

- **Framework:** Quickshell 0.3.0 (QML runtime for Wayland shells)
- **Compositor:** Niri (Wayland) — connected via the `Niri` QML plugin
  (`qml-niri` flake input)
- **Language:** QML/JS (all UI), Perl (one helper script)
- **Live service data:** `Quickshell.Networking`, `Quickshell.Bluetooth`,
  `Quickshell.Services.Pipewire`, `Quickshell.Services.SystemTray` — native
  bindings, no `nmcli`/`bluetoothctl`/`wpctl` shelling out.
- **Config:** `~/.config/qsshell/llm-status.json` (LLM tracker state,
  written by `mujo llm`). `Theme.qml` values are hardcoded defaults for now
  — no settings UI/persistence in this build.
- **`qs-bar`'s systemd service `path`** (`nixos/features/quickshell.nix`)
  must list every binary any Process spawned from QML shells out to —
  currently `bash coreutils findutils jq perl curl wl-clipboard xdg-utils
  quickshell`. Forgetting to add a new one here means the feature works
  under `qs -p` (your interactive shell's PATH masks the gap) but silently
  fails under the real systemd service.

## Architecture

```
shell.qml                  ← entrypoint: Niri connection, launcher IPC/state,
                              one PanelWindow per screen
modules/bar/modules/       ← all UI components, flat dir, registered in qmldir
llm-usage.sh               ← bash+jq: detects installed AI assistants (Claude,
                              Codex, Antigravity, Gemini, opencode) and emits a
                              providers[] JSON, polled by LlmTrackerMenu.qml
```

The launcher is opened by niri's `Mod+Space` bind, which runs
`qs -p /etc/xdg/quickshell/bar/shell.qml ipc call launcher toggle` (see
`modules/wrappers/niri.nix`). The `-p` path must match the qs-bar daemon's
launch path (quickshell.nix `barConfig`) or a bare `qs ipc` can't pick between
the running quickshell instances (qs-bar) and silently no-ops.

**Theme singleton** (`modules/bar/modules/Theme.qml`): every visual
component reads colors/sizes/fonts from here — never hardcode a color, radius,
or font family in a component. It's a full design-token set: a near-black
warm-dark surface stack (`bg`→`surface`→`surfaceHover`→`surfaceActive`) with
hairline `border`/`borderStrong`, a single Ayu-blue `accent` (+ `accentDim`
tint fill, `accentText` for text on accent), `success`/`warning`/`error`
semantics, a radius scale (`radiusSm`/`radiusMd`/`radiusLg`), font tokens
(`fontFamily` = Ubuntu Sans, `fontMono` = JetBrains Mono) and label styling
(`fontSizeLabel`, `labelSpacing`).

**Design language** — the bar is *floating grouped pills*, not an edge-to-edge
slab: the panel is transparent and each cluster is a `BarGroup` (rounded
`surface` container) detached from the screen edge by `Theme.barMargin`. Panel
height is `barHeight + barMargin*2`. Shared primitives:
- `BarGroup.qml` — the rounded floating cluster container (uses a `RowLayout`;
  give children `Layout.alignment: Qt.AlignVCenter`).
- `SectionLabel.qml` — uppercase, letter-spaced monospace eyebrow used as the
  header of every popup card and sub-section (`WI-FI`, `OUTPUT DEVICE`, …).
- Popup cards: `color: Theme.bg`, `radius: Theme.radiusLg`, `border: Theme.border`,
  `anchors.margins: 14`. Interactive rows/inputs/chips use `radiusMd`.
- Numbers/times/percentages/keycaps render in `Theme.fontMono`; prose in
  `Theme.fontFamily`.

**Bar layout** (`Bar.qml`): left group = `LauncherPill` + divider +
`Workspaces` (numbered pills, active pill elongates + fills accent), center =
`ClockPill` (mono time + muted date, opens `CalendarMenu`), right group =
`LlmTrackerMenu`, `NetworkMenu`, `BluetoothMenu`, `VolumeMenu`, `SystemTray`.

**Trigger + popup pattern:** every right-side widget is an `Item` holding an
`IconButton` trigger and a `PopupWindow` with `anchor.window: panelWindow`,
`anchor.item: trigger`, `anchor.edges`/`anchor.gravity` set to `Edges.Bottom`
(plus `Left`/`Right` to pick which corner) and `anchor.adjustment:
PopupAdjustment.Slide` so it stays on-screen. This anchors declaratively to
the trigger item itself — don't go back to computing `anchor.rect.x/y`
manually via `mapToItem` in a click handler; that was tried first and every
popup ended up positioned at the same point regardless of which trigger was
clicked (imperative writes to `anchor.rect`'s grouped value-type properties
are unreliable — `anchor.item` sidesteps it entirely). Copy `NetworkMenu.qml`
or `SystemTray.qml` as the template for a new one.

**LLM tracker's provider auto-detection:** `llm-usage.sh` probes each known
AI-assistant CLI's on-disk config and emits a `providers[]` array
(`{id, name, icon, email, plan, usage[]}`); `LlmTrackerMenu.qml` renders one
card per detected provider. Only providers that cache real limit data locally
get `usage[]` gauges — currently just **Claude Code**, from
`~/.claude.json`'s `.cachedUsageUtilization.utilization` (the same
session/weekly percentages and reset times shown on claude.ai/usage). The
rest (**Codex** `~/.codex/auth.json` JWT → plan/email; **Antigravity**
`~/.gemini/antigravity/`; **Gemini CLI** `~/.gemini/`; **opencode**
`~/.local/share/opencode/auth.json`) are presence-detected with whatever
account/plan can be read and an empty `usage[]` — never a fabricated quota.
Add a provider by writing a `<name>_provider()` function that prints one
provider JSON object (or nothing when absent) and adding it to the final
`jq -s` pipeline.

**Launcher:** opened by niri's `Mod+Space` bind (→ IPC `launcher` target in
`shell.qml`) or by clicking `LauncherPill`. `shell.qml` owns
`launcherOpen`/`launcherScreen` globally (so the toggle opens on the
*focused* screen); each `PanelWindow` derives its own
`launcherOpen: root.launcherOpen && root.launcherScreen === modelData.name`
and hands that down to `LauncherPill`, which owns the actual `PopupWindow`
locally (mirrors the old `DynamicIsland` split — global flag is an
edge-triggered input, not the source of truth for popup visibility).

## Running

```bash
qs -p ./shell.qml            # launch a throwaway instance from the working tree
qs ipc call launcher toggle  # toggle launcher
qs list --all                # find instance ids; qs kill -i <id> to tear down
```

## Adding a new component

1. Create `YourComponent.qml` in `modules/bar/modules/`.
2. Register it in `modules/bar/modules/qmldir`: `YourComponent YourComponent.qml`.
3. It's automatically importable from anything else in that directory (and
   from `shell.qml` via `import "./modules/bar/modules"`, already imported).

## Gotchas

- **`qmldir` is manual** — new QML files won't be discovered unless
  registered there. This is the #1 source of "component not found" errors.
- **niri's `WorkspaceModel`** has no per-field change notification —
  `Workspaces.qml` polls `niri.workspaces.get(i)` on a 500ms `Timer` rather
  than binding directly. Fields are duck-typed (`isFocused` vs `isActive`)
  since the exact role name isn't guaranteed across niri/plugin versions.
- **`UntypedObjectModel` properties** (`SystemTray.items`,
  `Networking.devices`, `Bluetooth.defaultAdapter.devices`,
  `Pipewire.nodes`, `DesktopEntries.applications`, …) can be passed directly
  as a `Repeater`/`ListView` `model:`, but for length/filtering in JS use
  `.values` (a real array) — the object itself doesn't behave like one.
- **Pipewire nodes need `PwObjectTracker`** — `Pipewire.defaultAudioSink`/
  `defaultAudioSource`'s `.audio` properties don't update reactively unless
  the node is held by a `PwObjectTracker { objects: [...] }` somewhere
  (see `VolumeMenu.qml`).
- **`PopupWindow` positioning** — use `anchor.item` + `anchor.edges`/
  `anchor.gravity` (see the trigger + popup pattern above), not manual
  `anchor.rect.x/y` math.
- **No build step** — QML is interpreted at runtime. Edit, then `qs -r` (or
  relaunch `qs -p`) to reload.
- **No settings UI in this build** — `Theme.qml` is a plain singleton with
  hardcoded defaults. A prior iteration had a full `SettingsMenu.qml` with
  live theme editing + persistence to `~/.config/qsshell/settings.json`;
  that wasn't rebuilt here since it wasn't asked for. If you want it back,
  `shell.qml`'s config-load block and `Theme.qml`'s property list are the
  places to extend.
