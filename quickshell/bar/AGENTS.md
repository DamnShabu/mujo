# Quickshell — shell architecture

The mujō desktop for Niri/Wayland: floating grouped top bar, notifications, parallax wallpaper, Cava visualiser, staging shelf, system dialogs, and the standalone settings app. Repo-wide rules live in the root **`AGENTS.md`**.

## STACK

| Layer | Choice |
|---|---|
| Runtime | Quickshell 0.3.0 (QML for Wayland shells) |
| Compositor | Niri, via the `Niri` QML plugin (`qml-niri` flake input) |
| Languages | QML/JS for all UI; Python and C for helpers; Bash + jq for the `mujo` CLI |
| Live data | `Quickshell.Networking`, `.Bluetooth`, `.Services.Pipewire`, `.Services.SystemTray` |

## CONFIG & STATE

- **Config** — `~/.config/qsshell/*.json` and `~/.config/quickshell/*.json`. Key files: `settings.json` (reactive store owned by `services/SettingsBus.qml`), `theme.json` (palette, hot-reloaded).
- **Ephemeral state** — `~/.local/state/qsshell/*.json` (shelf, notifications, backups, desktop icon grid slots).
- **Desktop items** — `~/Desktop` is the source of truth for what exists; `desktop-icons.json` holds only grid slots, never anything the user would miss. `mujo desktop list|mkdir|new-file|rename|trash|open|info|path|into|copy|cut|paste|import|terminal|pos|pos-batch|forget` owns every read and write, takes an flock, and deletes via trash rather than `rm`. Anything it spawns that outlives the call (`wl-copy`, a terminal, `gio open`) must be given `9>&-` or it inherits the flock and wedges the next command. Cut/copy/paste go through the system clipboard in `x-special/gnome-copied-files`, so they interoperate with GTK file managers.
- **Desktop geometry** — the icon/widget surface is inset by `Theme.desktopInset` (+ the bar's reserved band on the bar's edge), which mirrors niri's `layout.gaps + layout.struts` in `modules/wrappers/niri.nix`. That is what keeps widgets from showing in the gap niri leaves around an open window; the wallpaper surface is separate and still edge to edge.
- **All writes go through the `mujo` CLI** (`quickshell/mujo.sh`), never bare shell tools — it is a `makeWrapper` package with jq/curl/git/tmux on `PATH` and writes atomically. QML invokes it via `Quickshell.execDetached`. The dispatcher sources its six largest subcommands (`vm`, `desktop`, `sentinel`, `crash`, `security`, `clean`) from `quickshell/lib/*.sh`, only when that subcommand is reached; `MUJO_LIB` points at them and the wrapper sets it. A new one goes in `lib/` as `mujo_<name>()` and gets a two-line arm here.

## ICONS

- **Standard actions use Material Symbols.** `components/MaterialIcon.qml` renders Material Symbols directly (`Material Symbols Rounded`), ensuring consistent, scalable vector glyphs across all controls, bars, menus, and settings.
- **File-type icons are full colour** (`Icons.fileIcon`), the desktop convention, keyed by extension.
- Application launcher and window icons resolve via `Icons.appIcon` / `Icons.iconSource` against the desktop icon theme.
- That theme comes from `QS_ICON_THEME`, set session-wide in `nixos/desktop/gtk.nix` and again in the `qs-bar` service. Without it Qt resolves nothing on those three functions and every file and application icon falls back to the generic executable icon. `qs -p ./test-icons.qml` is the check; since `Icons.actions` was removed it covers the 48 file types, and nothing now guards a Material Symbol name that no glyph covers.

## DIRECTORIES

```
shell.qml       desktop shell entrypoint (bar, launcher, overlays, prompts)
settings.qml    standalone settings app entrypoint — a frame; see SETTINGS APP
llm-usage.sh    AI-assistant token usage scanner
theme/          Theme.qml (design tokens), Anim.qml (motion), Brand.qml (identity)
components/     shared UI primitives
services/       singletons: settings bus, notifications, launch, lock, weather, cava, …
modules/        feature domains: bar/ notifications/ desktop/ system/ screenshot/ settings/
```

Every directory carries a `qmldir`. Read it to see what a domain exposes rather than listing the tree.

## RUNNING

```bash
qs -p ./shell.qml                 # desktop shell from the working tree
qs -p ./settings.qml              # settings app from the working tree
qs -p ./test-icons.qml            # icon-theme resolution
qs -p ./test-grid.qml             # DesktopGrid occupancy
qs -p ./test-notifications.qml    # notification daemon, icon resolver, grouping, history
qs -p ./test-shelf.qml            # staging shelf state & icon resolution
qs -p ./test-settings-ui.qml      # settings row binding & routing
qs -p ./test-security-ui.qml      # SecurityService binding & the trust tab
qs -p ./test-greeter.qml          # boot greeter: unlock/setup mode + submit guards
qs -p ./test-desktop.qml          # icon placement vs. a widget, against the real ~/Desktop
qs -p ./test-scroll.qml           # shared wheel scrolling, and that Flickable's enum still matches
qs -p ./test-vm-service.qml       # VmService progress parsing and log cap
qs -p ./test-reorder-list.qml     # MujoReorderList drag, drop, and button reordering
qs -p ./test-bar-modular.qml      # modular topbar registry, style presenters, slot resilience
qs list --all                     # active instances
qs kill -i <id>                   # terminate one
qs -p /etc/xdg/quickshell/bar/shell.qml ipc call launcher toggle
```

Each `test-*.qml` prints one `PASS`/`FAIL` line and exits 0 or 1, so the whole
set runs in a loop. **Put the checks in a `Timer { interval: 0 }`, not in
`Component.onCompleted`** — Quickshell connects `Qt.exit()` only once the config
has finished loading, so a check that exits from `onCompleted` prints its
verdict and then hangs forever.

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
   Same-directory types need no import. Anything from the Quickshell API itself
   (`DesktopEntries`, `Quickshell.execDetached`, `Process`) needs its own
   `import Quickshell` / `import Quickshell.Io` — omitting it is a runtime
   `ReferenceError` per binding, not a load failure, so it survives a clean start.
4. Persist any new config path by declaring it in the owning NixOS module (see root `AGENTS.md` → **CORE CONSTRAINTS**).

## THE BAR

`shell.qml` gives each screen a `PanelWindow` of `barHeight + barMargin * 2` and
puts one `Bar` in it. `Bar.qml` is a `Loader` over `bar.style`; the five
presenters in `modules/bar/styles/` are thin, and all but `dock` are a
**`BarLayout`** with different margins.

`BarLayout` owns the three-zone geometry and is the only place that arbitrates
between the zones. The right zone is measured first (its width depends on
nothing else), the centre is screen-centred while it fits and slides into
whatever gap is left when it does not, and the left zone is capped at
`leftBudget` — what the other two leave. Every budget is derived from the
*right* and *centre* widths only: reading the left zone's width back in is a
binding loop. When there is no gap at all the centre zone is dropped rather than
drawn over its neighbours. Before this, three independently anchored `BarSlot`s
simply overlapped. `test-bar-modular.qml` asserts the zones stay disjoint at
several widths and self-calibrates its narrow case from the measured zone
widths, so it keeps its teeth when a module changes size.

**A module that hides itself must expose `barVisible`.** A `Loader` takes its
implicit size from the item regardless of the item's visibility, so a hidden
module keeps its cell: a battery-less desktop had a 28px hole between the volume
and notification icons, and the island reserved 56px for an idle visualiser.
`BarSlot` and `Island` hide the *Loader* on `item.barVisible !== false`. It has
to be a separate property — Qt reflects a hidden parent back down into the
child's `visible`, so binding the Loader to `item.visible` would latch the module
off for good.

**Sizes come from `Theme`, not from each module.** `barItemHeight`,
`barItemSquare` and `barItemPadding` are the height, icon-only width and
horizontal padding of everything that sits inside a group; they derive from
`bar.height` and scale by `bar.density`. Modules used to pick their own (22, 28
and 34px tall, padded by 8 to 26), so hover plates of three sizes sat side by
side and raising `bar.height` stretched some and not others.

Slot defaults live once, in `BarModuleRegistry.defaultSlots`; read a zone with
`BarModuleRegistry.slot("left"|"center"|"right")`, which also guards against a
zone stored as a JSON *string* — what `mujo settings set bar.slots.left '[…]'`
writes without `--json`, and what silently empties the bar.

## SETTINGS APP

`settings.qml` is only a frame: the window, the five sidebar categories, and the
omni-search index — all data. The machinery lives in `modules/settings/`.

**A settings page is a flat plane, not a stack of cards.** Grouping is carried
by a heading, a hairline rule and the space between sections; the only things
that draw a surface are controls and objects you can operate (a display, a VM, a
search hit). Four filled, rounded, bordered slabs on a page read as four
floating panels with no hierarchy between them, and every toggle ended up inside
three nested rectangles. Three type levels do the work: the page title
(`fontSizeHeading + 3`, bold), the section heading (`fontSizeTitle`, demibold)
and `SectionLabel` for a sub-group inside a section.

- **`SettingsLayout.qml`** — the app: state, routing, and the sidebar/content
  composition. `SettingsBus.onNavigate` and `~/.config/qsshell/settings-target`
  (what `mujo settings <key>` writes) both go through `route()`, which resolves a
  category key or any key a category claims in `keys: [...]`. `railRows` flattens
  the categories plus the sub-categories of whichever one is open, so one
  Repeater renders the tree, arrow keys walk a single index, and the selection
  highlight sits on the row instead of a glider doing index arithmetic a
  variable-height tree would break.
- **`SettingsSidebar.qml`** / **`SettingsNavRow.qml`** / **`SettingsSearchResults.qml`**
  — the sidebar (236px, 60px compact), one tree row, and the omni-search overlay.
  The accent appears in the sidebar exactly once, on the active row's marker.
- **`SettingsPage.qml`** — a category expressed as data. `sections: [{ id, label,
  description, component, fill }]` builds one pane per sub-category, each with
  its own heading, scroll position and lazy `Loader`; `cardMap` (card title →
  section id) and `aliases` (extra routing ids → section id) drive `revealCard()`.
  `fill: true` hands the whole pane to a component that scrolls itself, like the
  wallpaper browsers. The content column is capped at `contentMax` and centred, so
  a label never sits half a screen from its control. **Navigation stops at a
  section.** No sub-pages and no modal overlays — an "open X" affordance becomes
  an inline card the way VM provisioning did.
- **`<Category>Page.qml`** — the five category pages, each ~50 lines of data on
  `SettingsPage`. They used to hand-roll a stack of Flickables plus identical
  copies of `_findCard` / `_scrollFlickToCard` / `_getActiveFlickable`, ninety
  duplicated lines apiece. A page with its own inner navigation overrides
  `revealCard` and delegates to `revealSection` (see `AppearancePage`).
- **`SettingRow.qml`** — one store-backed setting: `path` + `kind` (`toggle` |
  `slider` | `segment` | `text`). A slider also shows its value permanently; the
  control's own bubble only appears while you point at it, which left a page of
  sliders showing no numbers. Anything with a bespoke control uses
  `MujoSettingRow` directly and fills its default control slot.
- **`components/MujoCard.qml`** — a section: heading, rule, rows. It draws no
  surface and no icon (`iconName` is accepted and ignored — an icon in front of
  the heading indents it away from the rows beneath). `collapsible` defaults to
  false; sections stand open.
- **`components/MujoSettingRow.qml`** — a row: name and description left, control
  right, a hover band that bleeds past the column so it reads as a row of the
  page. Both live in `components/` but are used only by the settings app.
- **Five shared shapes**, also in `components/`, so a group never draws its own.
  The groups used to hand-roll these some sixty times, at heights of 15/16/20/22
  and paddings of 8/10/14, half with a border and half without:
  - **`StatusTag.qml`** — the one badge: `text` + `tone` (neutral / accent /
    success / warning / error), or a `toneColor` the caller computes. `MujoCard`
    and `MujoSettingRow` use it for their own badges.
  - **`InfoRow.qml`** — a read-only fact, value right-aligned into the same
    column a `SettingRow` puts its control in, with a `trailing` slot. Exactly
    one item in it fills; a spacer plus a width-capped value gives two things a
    claim on the slack and the value lands nowhere in particular.
  - **`InsetPanel.qml`** — a recessed area inside a section: a log stream, a
    canvas, a form. Sunk (`bg`), a step *below* the page, which is what
    separates it from a control (raised, on `surface`).
  - **`ListRow.qml`** — one item in a list of real objects (a generation, a VM, a
    credential, a registered application). These are the one thing on a settings
    page that still gets a surface, because they are things you act on rather
    than settings.
  - **`EmptyState.qml`** — icon, line, hint, optional action. An empty screen is
    an invitation to act, never an apology. Its outer item is what fills; a
    nested Layout takes its own maximumWidth from its widest-constrained child,
    so a wrapped hint would otherwise cap the whole block and park it left of
    centre.
- **`<Domain>Group.qml`** — the sections of one domain: a plain `ColumnLayout` at
  `spacing: 14`, no
  scroll and no hero of its own, dropped into a page.
- **`SearchIndex.js`** — the omni-search rows, in their own `.pragma library` so
  `test-settings-ui.qml` asserts against the data the app ships. Every `card:`
  value must match a `MujoCard` title on the destination page verbatim; the test
  checks that.

A new domain adds a group, lists it under one of that page's `sections`, and adds
its card titles to `cardMap`. Every sub-category `id` in `settings.qml` must be a
section id or an alias on that page — `test-settings-ui.qml` asserts that
correspondence, and drift makes a sidebar row look like it does nothing.

Pages **stay alive once visited** so scroll position survives switching category.
Anything that polls must therefore bind `running: root.visible` rather than
`running: true` — an invisible parent propagates `visible: false` to its
children, so that stops the timer when the category is off screen.
