# Modular Topbar Architecture & Interchangeable Module System

## 1. Overview & Architectural Goals

The mujō desktop topbar is being re-architected from a semi-hardcoded, cluster-bound implementation into a **Universal Modular Canvas**. 

### Primary Goals:
- **Universal Interchangeability:** No module is locked to a specific section (Left, Center, Right) or bar style. Every module is a self-contained, first-class citizen that can be moved, reordered, or duplicated in any zone.
- **Multiple Bar Styles:** First-class support for 5 distinct bar presentations:
  1. **`Floating`** (Default): Three detached pill clusters with floating margin and subtle luminescence.
  2. **`Full-Width`**: Continuous edge-to-edge panel spanning 100% monitor width with zero screen margin.
  3. **`Island`**: Floating compact wings + center dynamic morphing/interactive status notch.
  4. **`Dock`**: Single centered floating capsule grouping all active modules with elevated dock styling.
  5. **`Compact`**: Ultra-slim low-profile bar (26–28px height) with condensed inter-widget spacing.
- **Zero Module Duplication:** Adding a new bar style does not require creating separate versions of existing modules; modules adapt their density and presentation automatically.
- **Frictionless Extensibility:** New modules register in a central registry and immediately become available across all bar styles and within the Settings customizer.
- **Visual 3-Zone Canvas Builder:** An intuitive Settings customizer to configure, reorder, and drag modules between Left, Center, and Right zones.
- **Resilient & Backward-Compatible:** Safe fallback for invalid/missing modules, with automatic migration from legacy `bar.rightModules` settings.

---

## 2. Architecture & Data Flow

```
ShellRoot (shell.qml)
└── Variants (per screen)
    └── PanelWindow (anchored to top/bottom edge)
        └── Bar.qml (Style Orchestrator)
            └── Loader { sourceComponent: activeStylePresenter }
                ├── FloatingStyle.qml / FullWidthStyle.qml / IslandStyle.qml / DockStyle.qml / CompactStyle.qml
                │   ├── Left Zone   ──> BarSlot.qml (Repeater over `bar.slots.left`)
                │   ├── Center Zone ──> BarSlot.qml (Repeater over `bar.slots.center`)
                │   └── Right Zone  ──> BarSlot.qml (Repeater over `bar.slots.right`)
                │       └── BarModuleLoader.qml (Dynamic factory from BarModuleRegistry)
```

### Reactive Configuration Model (`SettingsBus`)
Stored in `~/.config/qsshell/settings.json`:
* **`bar.style`** (`string`, default: `"floating"`): `"floating"` | `"full"` | `"island"` | `"dock"` | `"compact"`
* **`bar.slots.left`** (`string[]`, default: `["launcher", "workspaces", "activeWindow"]`): Ordered module IDs in Left zone.
* **`bar.slots.center`** (`string[]`, default: `["clock", "weather"]`): Ordered module IDs in Center zone.
* **`bar.slots.right`** (`string[]`, default: `["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"]`): Ordered module IDs in Right zone.
* **`bar.density`** (`string`, default: `"auto"`): `"auto"` | `"normal"` | `"compact"` | `"dense"`
* **`bar.position`** (`string`, default: `"top"`): `"top"` | `"bottom"`
* **`bar.height`** (`int`, default: `34`): Vertical height in pixels.
* **`bar.margin`** (`int`, default: `7`): Outer screen margin.
* **`bar.spacing`** (`int`, default: `6`): Gap spacing between modules/clusters.
* **`bar.opacity`** (`real`, default: `1.0`): Surface background translucency.
* **`bar.autoHide`** (`bool`, default: `false`): Slide off-screen until hovered.

---

## 3. Universal Module Registry (`BarModuleRegistry.qml`)

A singleton catalog (`quickshell/bar/modules/bar/BarModuleRegistry.qml`) declaring all supported modules, metadata, and component factory bindings:

| Module ID | Component File | Description | Default Slot | Key Capabilities |
|---|---|---|---|---|
| **`launcher`** | `LauncherPill.qml` | App launcher & search trigger | `left` | Custom icon (Search/Grid/NixOS/Mujō), optional text label. |
| **`workspaces`** | `Workspaces.qml` | Multi-workspace pager | `left` | Morphic gliders, Number/Dot/Roman/Kanji styles, window presence dots. |
| **`activeWindow`**| `ActiveWindowPill.qml` | Focused window icon & title | `left` | Live desktop icon, elided title with max width slider, pill/glass/plain styles. |
| **`clock`** | `ClockPill.qml` | Time & Date pill | `center` | 12/24h formats, live seconds, custom date patterns, opens Calendar flyout. |
| **`media`** | `MediaPill.qml` | MPRIS media player | `center` | Track ticker, album art, play/pause & skip controls, opens full media popup. |
| **`weather`** | `WeatherPill.qml` | Live weather status | `center` | Weather glyph + temperature, condition badge, opens weather card. |
| **`cava`** | `CavaPill.qml` | Mini audio visualizer | `center` | Real-time audio spectrum bars driven by `CavaService`. |
| **`volume`** | `VolumeMenu.qml` | PipeWire audio volume | `right` | Mouse scroll volume step, mute indicator, opens audio mixer popup. |
| **`battery`** | `BatteryMenu.qml` | Battery & power level | `right` | Charge state icon, percentage modes, low battery alert tint. |
| **`network`** | `NetworkMenu.qml` | Wi-Fi / Ethernet state | `right` | Signal strength, SSID pill display, opens Network manager menu. |
| **`bluetooth`** | `BluetoothMenu.qml` | Bluetooth accessories | `right` | Connected device badge, discovery toggle, opens Bluetooth menu. |
| **`notifications`**| `NotificationMenu.qml`| Notification center | `right` | Unread count badge, DND toggle, opens notification center. |
| **`tray`** | `SystemTray.qml` | SNI / AppIndicator Tray | `right` | Inline/collapsed tray delegates with DBus context menus & icon recoloring. |
| **`llm`** | `LlmTrackerMenu.qml` | AI Tokens & Agent tracker | `right` | Real-time token consumption meter & agent selector. |
| **`session`** | `SessionMenu.qml` | Power & Session controls | `right` | Power/Lock/Avatar icons, opens system power dialog. |
| **`divider`** | `DividerPill.qml` | Visual hairline separator | `none` | Subtle 1px vertical hairline divider. |
| **`spacer`** | `SpacerPill.qml` | Flexible layout expander | `none` | `Layout.fillWidth: true` for custom alignment gaps. |

---

## 4. Bar Style Presenters (`modules/bar/styles/`)

Every style presenter implements a standardized component interface receiving:
`{ niri, screenName, focusedOutput, panelWindow, launcherOpen }`

### 1. `FloatingStyle.qml` (Default)
- **Layout:** Three detached `BarCluster` instances (Left, Center, Right).
- **Styling:** Floating margin (`Theme.barMargin`), rounded pill corners (`Theme.groupRadius`), ambient `BarAura` edge luminescence, animated width transitions as modules change.

### 2. `FullWidthStyle.qml`
- **Layout:** One continuous edge-to-edge bar spanning 100% monitor width.
- **Styling:** Zero edge margin, single unifying surface fill with subtle border divider, hosting Left, Center, and Right layout groups internally.

### 3. `IslandStyle.qml`
- **Layout:** Floating Left & Right wings + Interactive Center Notch.
- **Styling:** Left and Right wings render as compact floating clusters; Center slot is hosted inside the morphing `Island` notch with dynamic alert expansion, media progress ring, and weather badges.

### 4. `DockStyle.qml`
- **Layout:** Single centered floating capsule combining all enabled slots.
- **Styling:** macOS/iPadOS-style floating dock pill with elevated shadow, glass blur, and larger icon-centric spacing.

### 5. `CompactStyle.qml`
- **Layout:** Three slim, condensed clusters or full strip.
- **Styling:** Low-profile vertical footprint (26–28px height), reduced inter-module padding, tight typography for space efficiency.

---

## 5. Universal Slot & Module Factory Engine

### `BarSlot.qml`
A shared slot manager used across all styles:
```qml
Item {
    id: slotRoot
    property var modules: []            // Array of module IDs
    property int alignment: Qt.AlignLeft
    property int spacing: Theme.groupPadding
    property bool wrapInCluster: true
    
    implicitWidth: row.implicitWidth + (wrapInCluster ? (Theme.groupPadding + 3) * 2 : 0)
    implicitHeight: Theme.barHeight
    visible: modules.length > 0
    
    RowLayout {
        id: row
        spacing: slotRoot.spacing
        Repeater {
            model: slotRoot.modules
            delegate: BarModuleLoader {
                required property var modelData
                moduleId: modelData
                panelWindow: root.panelWindow
                screenName: root.screenName
                niri: root.niri
                focusedOutput: root.focusedOutput
            }
        }
    }
}
```

### `BarModuleLoader.qml`
Dynamically instantiates and injects context into the corresponding module component:
```qml
Loader {
    id: loader
    required property string moduleId
    property var panelWindow
    property string screenName: ""
    property var niri
    property string focusedOutput: ""
    property bool launcherOpen: false

    Layout.alignment: Qt.AlignVCenter
    sourceComponent: BarModuleRegistry.getComponent(moduleId)

    onLoaded: {
        if (item) {
            if (item.panelWindow !== undefined) item.panelWindow = loader.panelWindow
            if (item.screenName !== undefined) item.screenName = loader.screenName
            if (item.niri !== undefined) item.niri = loader.niri
            if (item.focusedOutput !== undefined) item.focusedOutput = loader.focusedOutput
            if (item.launcherOpen !== undefined) item.launcherOpen = loader.launcherOpen
        }
    }
}
```

---

## 6. Settings Customizer & Interactive 3-Zone Builder (`BarGroup.qml`)

### 1. Bar Style Preset Selector
Visual card with 1-click preset switching:
- `Floating` (Detached pill clusters)
- `Full-Width` (Edge-to-edge bar)
- `Island` (Dynamic status notch + wings)
- `Dock` (Centered floating dock)
- `Compact` (Ultra-slim low profile)

### 2. Interactive 3-Zone Canvas Builder
- **Zone Managers:** Visual cards for **Left Zone**, **Center Zone**, and **Right Zone**.
- **Module Reordering:** Drag-and-drop or directional reordering via `MujoReorderList`.
- **Module Addition & Removal:** One-click removal (`✕`) and addition from the **Available Modules Pool**.
- **Layout Presets:**
  - *Default Mujō:* Left: `["launcher", "workspaces", "activeWindow"]` | Center: `["clock", "weather"]` | Right: `["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"]`
  - *Media Hub:* Left: `["workspaces"]` | Center: `["media", "cava", "clock"]` | Right: `["volume", "system"]`
  - *Minimalist Dock:* Center: `["launcher", "workspaces", "clock", "volume", "battery"]` | Left: `[]` | Right: `[]`

### 3. Deep Per-Widget Customizer
Retains the horizontal chip selector (`Workspaces`, `Clock`, `Launcher`, `Active Window`, `Media`, `Weather`, `Volume`, `Battery`, `Network`, `Bluetooth`, `Notifications`, `LLM`, `Session`) allowing deep tuning of each individual widget's options.

---

## 7. Migration, Resilience & Error Handling

1. **Automatic Schema Migration:**
   - On startup, if `bar.slots.left` / `center` / `right` are undefined in `settings.json`, default arrays are populated.
   - If legacy `bar.rightModules` exists, its ordering is preserved directly into `bar.slots.right`.
2. **Safe Module Loader Fallback:**
   - If an unrecognized module ID is passed, `BarModuleLoader` renders nothing (`null`), logs a console warning, and ensures the rest of the bar renders uninterrupted.
3. **Empty Slot Resilience:**
   - If any slot has zero modules, its container cleanly collapses to 0 width with smooth width animation.

---

## 8. Verification & Test Plan

1. **Offline QML Self-Check Suite (`quickshell/bar/test-bar-modular.qml`):**
   - Run headlessly with `qs -p ./quickshell/bar/test-bar-modular.qml`.
   - Assert all registered modules in `BarModuleRegistry` instantiate without errors.
   - Assert all 5 style presenters load and render their slot containers properly.
   - Assert empty slot collapse and dynamic module additions/removals at runtime.
2. **Shellcheck Verification:**
   - Run `nix shell nixpkgs#shellcheck -c shellcheck $(git ls-files '*.sh')` to ensure all shell scripts remain silent.
3. **Interactive Graphical Sandbox VM Testing:**
   - Boot sandbox VM (`nix run .#sandbox`).
   - Visually test all 5 bar styles across top and bottom screen positions.
   - Verify popup menus (Volume, Calendar, Media, Weather, Tray, LLM) anchor cleanly in all slot positions.
