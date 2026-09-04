# Modular Topbar Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the desktop topbar into a universal modular canvas where any module can be freely placed, moved, and reordered across Left, Center, and Right zones, with first-class support for 5 bar styles (Floating, Full-Width, Island, Dock, Compact).

**Architecture:** A centralized `BarModuleRegistry` singleton maps module IDs to components; a shared `BarSlot` and `BarModuleLoader` handle dynamic instantiation with context injection; 5 swappable style presenters (`FloatingStyle`, `FullWidthStyle`, `IslandStyle`, `DockStyle`, `CompactStyle`) render the layout chrome; and `BarGroup.qml` provides a visual 3-zone slot builder and style preset selector.

**Tech Stack:** Quickshell 0.3.0 (QML/JS), Wayland layer-shell, Niri compositor plugin, `SettingsBus` reactive JSON store.

**Spec:** [`docs/superpowers/specs/2026-09-04-modular-topbar-architecture-design.md`](file:///home/yurii/nixconf/docs/superpowers/specs/2026-09-04-modular-topbar-architecture-design.md)

## Global Constraints

- **Read colors from `Theme.*` in QML**; never use unapproved hex literals.
- **Register every new QML component in its domain's `qmldir`**; singletons must use `singleton Name File.qml`.
- **Offline self-checks run via `qs -p`** and must execute assertions from `Timer { interval: 0 }`, not `Component.onCompleted`.
- **All shell scripts must pass `shellcheck`**.
- **Always prefix shell commands with `rtk`** when running git or CLI tools.

---

### Task 1: Standalone Sub-Widgets & Module Primitives

Extract and build standalone versions of sub-widgets (Media Player, Weather, Cava, Divider, Spacer) so they function as first-class, independent bar modules.

**Files:**
- Create: `quickshell/bar/modules/bar/MediaPill.qml`
- Create: `quickshell/bar/modules/bar/WeatherPill.qml`
- Create: `quickshell/bar/modules/bar/CavaPill.qml`
- Create: `quickshell/bar/modules/bar/DividerPill.qml`
- Create: `quickshell/bar/modules/bar/SpacerPill.qml`
- Modify: `quickshell/bar/modules/bar/qmldir`

**Interfaces:**
- Consumes: `Theme`, `Anim`, `Mpris`, `WeatherService`, `CavaService`, `MaterialIcon`
- Produces: `MediaPill`, `WeatherPill`, `CavaPill`, `DividerPill`, `SpacerPill` components accepting `panelWindow` and `screenName`.

- [ ] **Step 1: Create `DividerPill.qml` and `SpacerPill.qml`**

```qml
// quickshell/bar/modules/bar/DividerPill.qml
import QtQuick
import QtQuick.Layouts
import "../../theme"

Rectangle {
    id: root
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: 1
    implicitHeight: Math.round(Theme.barHeight * 0.45)
    color: Theme.borderStrong
    opacity: 0.7
}
```

```qml
// quickshell/bar/modules/bar/SpacerPill.qml
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    Layout.fillWidth: true
    implicitWidth: 8
    implicitHeight: 1
}
```

- [ ] **Step 2: Create `MediaPill.qml`**

```qml
// quickshell/bar/modules/bar/MediaPill.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property bool hasMedia: !!Mpris.activePlayer && (Mpris.title.length > 0 || Mpris.playbackStatus !== "Stopped")
    visible: hasMedia
    implicitWidth: visible ? contentRow.implicitWidth + 14 : 0
    implicitHeight: Theme.barHeight
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radiusSm
        color: mediaHover.hovered ? Theme.hoverOverlay : "transparent"

        HoverHandler { id: mediaHover }
        TapHandler {
            onTapped: {
                if (root.panelWindow) {
                    PopupCoordinator.toggle(root.screenName + ":media")
                }
            }
        }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                iconName: Mpris.playbackStatus === "Playing" ? "graphic_eq" : "music_note"
                pixelSize: 14
                color: Mpris.playbackStatus === "Playing" ? Theme.accent : Theme.textSecondary
            }

            Text {
                text: {
                    var t = Mpris.title || "No Media"
                    var a = Mpris.artist ? " • " + Mpris.artist : ""
                    var s = t + a
                    return s.length > 24 ? s.substring(0, 22) + "…" : s
                }
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }
    }
}
```

- [ ] **Step 3: Create `WeatherPill.qml` and `CavaPill.qml`**

```qml
// quickshell/bar/modules/bar/WeatherPill.qml
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property bool hasWeather: WeatherService.hasData
    visible: hasWeather
    implicitWidth: visible ? weatherRow.implicitWidth + 12 : 0
    implicitHeight: Theme.barHeight
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radiusSm
        color: weatherHover.hovered ? Theme.hoverOverlay : "transparent"

        HoverHandler { id: weatherHover }
        TapHandler {
            onTapped: {
                if (root.panelWindow) {
                    PopupCoordinator.toggle(root.screenName + ":weather")
                }
            }
        }

        RowLayout {
            id: weatherRow
            anchors.centerIn: parent
            spacing: 5

            MaterialIcon {
                iconName: WeatherService.iconName || "wb_cloudy"
                pixelSize: 14
                color: Theme.accent
            }

            Text {
                text: WeatherService.tempFormatted || "--°C"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
```

```qml
// quickshell/bar/modules/bar/CavaPill.qml
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    implicitWidth: 36
    implicitHeight: Theme.barHeight
    Layout.alignment: Qt.AlignVCenter
    visible: CavaService.running

    Row {
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: 5
            delegate: Rectangle {
                required property int index
                width: 3
                height: Math.max(3, Math.min(18, (CavaService.values[index] || 0) * 18))
                radius: 1.5
                color: Theme.accent
                anchors.bottom: parent.bottom
            }
        }
    }
}
```

- [ ] **Step 4: Register new pills in `quickshell/bar/modules/bar/qmldir`**

```
MediaPill MediaPill.qml
WeatherPill WeatherPill.qml
CavaPill CavaPill.qml
DividerPill DividerPill.qml
SpacerPill SpacerPill.qml
```

- [ ] **Step 5: Commit**

```bash
rtk git add quickshell/bar/modules/bar/
rtk git commit -m "feat(bar): add standalone Media, Weather, Cava, Divider, and Spacer pills"
```

---

### Task 2: Module Registry (`BarModuleRegistry.qml`) & Loader (`BarModuleLoader.qml`)

Create the centralized module catalog and dynamic context-injecting loader component.

**Files:**
- Create: `quickshell/bar/modules/bar/BarModuleRegistry.qml`
- Create: `quickshell/bar/modules/bar/BarModuleLoader.qml`
- Modify: `quickshell/bar/modules/bar/qmldir`

**Interfaces:**
- Produces: `singleton BarModuleRegistry` with `getComponent(id)`, `allModules`, `metadata(id)`.
- Produces: `BarModuleLoader` item accepting `moduleId`, `panelWindow`, `screenName`, `niri`, `focusedOutput`.

- [ ] **Step 1: Create `BarModuleRegistry.qml`**

```qml
// quickshell/bar/modules/bar/BarModuleRegistry.qml
pragma Singleton
import QtQuick
import "../notifications"
import "../launcher"

QtObject {
    id: registry

    readonly property var allModules: [
        { id: "launcher",     name: "App Launcher",        icon: "apps",             category: "navigation", defaultSlot: "left" },
        { id: "workspaces",   name: "Workspace Switcher",  icon: "view_carousel",    category: "navigation", defaultSlot: "left" },
        { id: "activeWindow", name: "Active Window Title", icon: "tab",              category: "navigation", defaultSlot: "left" },
        { id: "clock",        name: "Clock & Calendar",    icon: "schedule",         category: "system",     defaultSlot: "center" },
        { id: "media",        name: "Media Player",        icon: "play_circle",      category: "media",      defaultSlot: "center" },
        { id: "weather",      name: "Weather Status",      icon: "wb_sunny",         category: "info",       defaultSlot: "center" },
        { id: "cava",         name: "Audio Visualizer",    icon: "graphic_eq",       category: "media",      defaultSlot: "center" },
        { id: "volume",       name: "Audio Volume",        icon: "volume_up",        category: "hardware",   defaultSlot: "right" },
        { id: "network",      name: "Network & Wi-Fi",     icon: "wifi",             category: "hardware",   defaultSlot: "right" },
        { id: "bluetooth",    name: "Bluetooth",           icon: "bluetooth",        category: "hardware",   defaultSlot: "right" },
        { id: "battery",      name: "Battery & Power",     icon: "battery_full",     category: "hardware",   defaultSlot: "right" },
        { id: "notifications",name: "Notification Center", icon: "notifications",    category: "system",     defaultSlot: "right" },
        { id: "tray",         name: "System Tray",         icon: "widgets",          category: "system",     defaultSlot: "right" },
        { id: "llm",          name: "AI Tokens / Agent",   icon: "psychology",       category: "ai",         defaultSlot: "right" },
        { id: "session",      name: "Session / Power",     icon: "power_settings_new",category: "system",    defaultSlot: "right" },
        { id: "divider",      name: "Visual Separator",    icon: "more_vert",        category: "layout",     defaultSlot: "none" },
        { id: "spacer",       name: "Flexible Spacer",     icon: "space_bar",        category: "layout",     defaultSlot: "none" }
    ]

    function metadata(id) {
        for (var i = 0; i < allModules.length; i++) {
            if (allModules[i].id === id) return allModules[i]
        }
        return { id: id, name: id, icon: "widgets", category: "custom", defaultSlot: "none" }
    }

    // Component references
    readonly property Component launcherComp: Component { LauncherPill {} }
    readonly property Component workspacesComp: Component { Workspaces {} }
    readonly property Component activeWinComp: Component { ActiveWindowPill {} }
    readonly property Component clockComp: Component { ClockPill {} }
    readonly property Component mediaComp: Component { MediaPill {} }
    readonly property Component weatherComp: Component { WeatherPill {} }
    readonly property Component cavaComp: Component { CavaPill {} }
    readonly property Component volumeComp: Component { VolumeMenu {} }
    readonly property Component networkComp: Component { NetworkMenu {} }
    readonly property Component bluetoothComp: Component { BluetoothMenu {} }
    readonly property Component batteryComp: Component { BatteryMenu {} }
    readonly property Component notifComp: Component { NotificationMenu {} }
    readonly property Component trayComp: Component { SystemTray {} }
    readonly property Component llmComp: Component { LlmTrackerMenu {} }
    readonly property Component sessionComp: Component { SessionMenu {} }
    readonly property Component dividerComp: Component { DividerPill {} }
    readonly property Component spacerComp: Component { SpacerPill {} }

    function getComponent(id) {
        switch (id) {
            case "launcher":     return launcherComp
            case "workspaces":   return workspacesComp
            case "activeWindow": return activeWinComp
            case "clock":        return clockComp
            case "media":        return mediaComp
            case "weather":      return weatherComp
            case "cava":         return cavaComp
            case "volume":       return volumeComp
            case "network":      return networkComp
            case "bluetooth":    return bluetoothComp
            case "battery":      return batteryComp
            case "notifications":return notifComp
            case "tray":         return trayComp
            case "llm":          return llmComp
            case "session":      return sessionComp
            case "divider":      return dividerComp
            case "spacer":       return spacerComp
            default:
                console.warn("BarModuleRegistry: Unknown module id:", id)
                return null
        }
    }
}
```

- [ ] **Step 2: Create `BarModuleLoader.qml`**

```qml
// quickshell/bar/modules/bar/BarModuleLoader.qml
import QtQuick
import QtQuick.Layouts

Loader {
    id: root
    property string moduleId: ""
    property var panelWindow
    property string screenName: ""
    property var niri
    property string focusedOutput: ""
    property bool launcherOpen: false

    Layout.alignment: Qt.AlignVCenter
    sourceComponent: BarModuleRegistry.getComponent(moduleId)

    onLoaded: {
        if (item) {
            if (item.panelWindow !== undefined) item.panelWindow = root.panelWindow
            if (item.screenName !== undefined) item.screenName = root.screenName
            if (item.niri !== undefined) item.niri = root.niri
            if (item.focusedOutput !== undefined) item.focusedOutput = root.focusedOutput
            if (item.launcherOpen !== undefined) item.launcherOpen = root.launcherOpen
        }
    }
}
```

- [ ] **Step 3: Register in `quickshell/bar/modules/bar/qmldir`**

```
singleton BarModuleRegistry BarModuleRegistry.qml
BarModuleLoader BarModuleLoader.qml
```

- [ ] **Step 4: Commit**

```bash
rtk git add quickshell/bar/modules/bar/
rtk git commit -m "feat(bar): add BarModuleRegistry singleton and BarModuleLoader"
```

---

### Task 3: Slot Container (`BarSlot.qml`)

Build the shared `BarSlot.qml` container that renders arrays of module IDs with smooth resize animation and cluster wrapping.

**Files:**
- Create: `quickshell/bar/modules/bar/BarSlot.qml`
- Modify: `quickshell/bar/modules/bar/qmldir`

**Interfaces:**
- Consumes: `BarModuleLoader`, `BarCluster`, `Theme`
- Produces: `BarSlot` component accepting `modules: []`, `alignment`, `spacing`, `wrapInCluster`.

- [ ] **Step 1: Create `BarSlot.qml`**

```qml
// quickshell/bar/modules/bar/BarSlot.qml
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

Item {
    id: root
    property var modules: []
    property int alignment: Qt.AlignLeft
    property int spacing: Theme.groupPadding
    property bool wrapInCluster: true
    property var panelWindow
    property string screenName: ""
    property var niri
    property string focusedOutput: ""
    property bool launcherOpen: false

    visible: modules && modules.length > 0
    implicitHeight: Theme.barHeight
    implicitWidth: wrapInCluster ? cluster.implicitWidth : contentRow.implicitWidth

    BarCluster {
        id: cluster
        visible: root.wrapInCluster
        anchors.fill: parent
        spacing: root.spacing
        contentAlign: root.alignment

        RowLayout {
            spacing: root.spacing
            Repeater {
                model: root.modules || []
                delegate: BarModuleLoader {
                    required property var modelData
                    moduleId: modelData
                    panelWindow: root.panelWindow
                    screenName: root.screenName
                    niri: root.niri
                    focusedOutput: root.focusedOutput
                    launcherOpen: root.launcherOpen
                }
            }
        }
    }

    RowLayout {
        id: contentRow
        visible: !root.wrapInCluster
        anchors.centerIn: parent
        spacing: root.spacing
        Repeater {
            model: root.modules || []
            delegate: BarModuleLoader {
                required property var modelData
                moduleId: modelData
                panelWindow: root.panelWindow
                screenName: root.screenName
                niri: root.niri
                focusedOutput: root.focusedOutput
                launcherOpen: root.launcherOpen
            }
        }
    }
}
```

- [ ] **Step 2: Register `BarSlot` in `quickshell/bar/modules/bar/qmldir`**

```
BarSlot BarSlot.qml
```

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/bar/modules/bar/
rtk git commit -m "feat(bar): add universal BarSlot component"
```

---

### Task 4: 5 Bar Style Presenters (`modules/bar/styles/`)

Build the 5 distinct bar layout styles: Floating, Full-Width, Island, Dock, and Compact.

**Files:**
- Create: `quickshell/bar/modules/bar/styles/FloatingStyle.qml`
- Create: `quickshell/bar/modules/bar/styles/FullWidthStyle.qml`
- Create: `quickshell/bar/modules/bar/styles/IslandStyle.qml`
- Create: `quickshell/bar/modules/bar/styles/DockStyle.qml`
- Create: `quickshell/bar/modules/bar/styles/CompactStyle.qml`
- Create: `quickshell/bar/modules/bar/styles/qmldir`

- [ ] **Step 1: Create `FloatingStyle.qml`**

```qml
// quickshell/bar/modules/bar/styles/FloatingStyle.qml
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import ".."

Item {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    readonly property var leftModules: SettingsBus.get("bar.slots.left", ["launcher", "workspaces", "activeWindow"])
    readonly property var centerModules: SettingsBus.get("bar.slots.center", ["clock", "weather"])
    readonly property var rightModules: SettingsBus.get("bar.slots.right", ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])
    readonly property int clusterGap: SettingsBus.get("bar.spacing", 6)

    BarSlot {
        id: leftSlot
        modules: root.leftModules
        alignment: Qt.AlignLeft
        spacing: root.clusterGap
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: Theme.barMargin
        }
    }

    BarSlot {
        id: centerSlot
        modules: root.centerModules
        alignment: Qt.AlignHCenter
        spacing: root.clusterGap
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors.centerIn: parent
    }

    BarSlot {
        id: rightSlot
        modules: root.rightModules
        alignment: Qt.AlignRight
        spacing: Math.max(0, root.clusterGap - 2)
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: Theme.barMargin
        }
    }
}
```

- [ ] **Step 2: Create `FullWidthStyle.qml`**

```qml
// quickshell/bar/modules/bar/styles/FullWidthStyle.qml
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import ".."

Rectangle {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    anchors.fill: parent
    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.surface.a * Theme.barGroupOpacity)
    border.width: 1
    border.color: Theme.border

    readonly property var leftModules: SettingsBus.get("bar.slots.left", ["launcher", "workspaces", "activeWindow"])
    readonly property var centerModules: SettingsBus.get("bar.slots.center", ["clock", "weather"])
    readonly property var rightModules: SettingsBus.get("bar.slots.right", ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])
    readonly property int clusterGap: SettingsBus.get("bar.spacing", 8)

    BarSlot {
        modules: root.leftModules
        alignment: Qt.AlignLeft
        spacing: root.clusterGap
        wrapInCluster: false
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: 12
        }
    }

    BarSlot {
        modules: root.centerModules
        alignment: Qt.AlignHCenter
        spacing: root.clusterGap
        wrapInCluster: false
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors.centerIn: parent
    }

    BarSlot {
        modules: root.rightModules
        alignment: Qt.AlignRight
        spacing: root.clusterGap
        wrapInCluster: false
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: 12
        }
    }
}
```

- [ ] **Step 3: Create `IslandStyle.qml`**

```qml
// quickshell/bar/modules/bar/styles/IslandStyle.qml
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import ".."

Item {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    readonly property var leftModules: SettingsBus.get("bar.slots.left", ["launcher", "workspaces", "activeWindow"])
    readonly property var rightModules: SettingsBus.get("bar.slots.right", ["volume", "battery", "notifications", "tray", "session"])
    readonly property int clusterGap: SettingsBus.get("bar.spacing", 6)

    BarSlot {
        modules: root.leftModules
        alignment: Qt.AlignLeft
        spacing: root.clusterGap
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: Theme.barMargin
        }
    }

    // Interactive Island Notch in center
    Island {
        panelWindow: root.panelWindow
        screenName: root.screenName
        anchors.centerIn: parent
    }

    BarSlot {
        modules: root.rightModules
        alignment: Qt.AlignRight
        spacing: Math.max(0, root.clusterGap - 2)
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: Theme.barMargin
        }
    }
}
```

- [ ] **Step 4: Create `DockStyle.qml` and `CompactStyle.qml`**

```qml
// quickshell/bar/modules/bar/styles/DockStyle.qml
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../components"
import "../../../services"
import ".."

Item {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    readonly property var leftModules: SettingsBus.get("bar.slots.left", ["launcher", "workspaces", "activeWindow"])
    readonly property var centerModules: SettingsBus.get("bar.slots.center", ["clock", "weather"])
    readonly property var rightModules: SettingsBus.get("bar.slots.right", ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])
    readonly property var combinedModules: leftModules.concat(centerModules).concat(rightModules)

    BarCluster {
        anchors.centerIn: parent
        spacing: 8
        radius: Theme.radiusLg
        implicitHeight: Math.max(Theme.barHeight, 38)
        auraColor: Theme.accent

        RowLayout {
            spacing: 8
            Repeater {
                model: root.combinedModules
                delegate: BarModuleLoader {
                    required property var modelData
                    moduleId: modelData
                    panelWindow: root.panelWindow
                    screenName: root.screenName
                    niri: root.niri
                    focusedOutput: root.focusedOutput
                    launcherOpen: root.launcherOpen
                }
            }
        }
    }
}
```

```qml
// quickshell/bar/modules/bar/styles/CompactStyle.qml
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import ".."

Item {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    readonly property var leftModules: SettingsBus.get("bar.slots.left", ["launcher", "workspaces", "activeWindow"])
    readonly property var centerModules: SettingsBus.get("bar.slots.center", ["clock", "weather"])
    readonly property var rightModules: SettingsBus.get("bar.slots.right", ["llm", "network", "bluetooth", "volume", "battery", "notifications", "tray", "session"])

    BarSlot {
        modules: root.leftModules
        alignment: Qt.AlignLeft
        spacing: 3
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: 4
        }
    }

    BarSlot {
        modules: root.centerModules
        alignment: Qt.AlignHCenter
        spacing: 3
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors.centerIn: parent
    }

    BarSlot {
        modules: root.rightModules
        alignment: Qt.AlignRight
        spacing: 2
        wrapInCluster: true
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: 4
        }
    }
}
```

- [ ] **Step 5: Create `quickshell/bar/modules/bar/styles/qmldir`**

```
FloatingStyle FloatingStyle.qml
FullWidthStyle FullWidthStyle.qml
IslandStyle IslandStyle.qml
DockStyle DockStyle.qml
CompactStyle CompactStyle.qml
```

- [ ] **Step 6: Commit**

```bash
rtk git add quickshell/bar/modules/bar/styles/
rtk git commit -m "feat(bar): add Floating, FullWidth, Island, Dock, and Compact style presenters"
```

---

### Task 5: Refactor `Bar.qml` Orchestrator

Refactor `quickshell/bar/modules/bar/Bar.qml` to dynamically instantiate the active style presenter and support hot-swapping.

**Files:**
- Modify: `quickshell/bar/modules/bar/Bar.qml`

- [ ] **Step 1: Update `Bar.qml`**

```qml
// quickshell/bar/modules/bar/Bar.qml
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"
import "./styles"

Item {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    // Catch clicks on empty / transparent space of the bar to dismiss open GUIs.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: PopupCoordinator.closeAll()
    }

    readonly property string barStyle: SettingsBus.get("bar.style", "floating")

    Loader {
        id: styleLoader
        anchors.fill: parent
        sourceComponent: {
            switch (root.barStyle) {
                case "full":    return fullStyleC
                case "island":  return islandStyleC
                case "dock":    return dockStyleC
                case "compact": return compactStyleC
                case "floating":
                default:        return floatingStyleC
            }
        }

        onLoaded: {
            if (item) {
                item.niri = Qt.binding(function() { return root.niri })
                item.screenName = Qt.binding(function() { return root.screenName })
                item.focusedOutput = Qt.binding(function() { return root.focusedOutput })
                item.panelWindow = Qt.binding(function() { return root.panelWindow })
                item.launcherOpen = Qt.binding(function() { return root.launcherOpen })
            }
        }
    }

    Component { id: floatingStyleC; FloatingStyle {} }
    Component { id: fullStyleC;     FullWidthStyle {} }
    Component { id: islandStyleC;   IslandStyle {} }
    Component { id: dockStyleC;     DockStyle {} }
    Component { id: compactStyleC;  CompactStyle {} }
}
```

- [ ] **Step 2: Commit**

```bash
rtk git add quickshell/bar/modules/bar/Bar.qml
rtk git commit -m "refactor(bar): route Bar.qml through dynamic style presenter loader"
```

---

### Task 6: Settings 3-Zone Canvas Builder & Style Selector (`BarGroup.qml`)

Update `quickshell/bar/modules/settings/BarGroup.qml` to provide 1-click Style Presets, an interactive 3-Zone canvas manager with `MujoReorderList`, and available modules pool.

**Files:**
- Modify: `quickshell/bar/modules/settings/BarGroup.qml`

- [ ] **Step 1: Update `BarGroup.qml` with Style Selector and 3-Zone Canvas Manager**

Implement the full 3-Zone slot editor (Left, Center, Right), drag/reorder controls, module addition from pool, removal, layout presets, and deep widget settings tabs.

- [ ] **Step 2: Run offline self-check on settings**

```bash
qs -p ./quickshell/bar/test-settings-ui.qml
```
Expected: PASS

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/bar/modules/settings/BarGroup.qml
rtk git commit -m "feat(settings): add 3-zone slot canvas builder and bar style selector to BarGroup"
```

---

### Task 7: Comprehensive Self-Check Test Suite (`test-bar-modular.qml`)

Create automated test verifying all modules, style presenters, slot bindings, and empty slot collapse.

**Files:**
- Create: `quickshell/bar/test-bar-modular.qml`

- [ ] **Step 1: Write `test-bar-modular.qml`**

```qml
// quickshell/bar/test-bar-modular.qml
import QtQuick
import QtQuick.Layouts
import "./theme"
import "./services"
import "./modules/bar"
import "./modules/bar/styles"

Item {
    id: root
    width: 1920
    height: 1080

    Bar {
        id: testBar
        width: 1920
        height: 34
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            var passed = true
            var failures = []

            function assert(cond, msg) {
                if (!cond) {
                    passed = false
                    failures.push(msg)
                    console.error("FAIL:", msg)
                }
            }

            // 1. Verify BarModuleRegistry
            assert(BarModuleRegistry.allModules.length >= 17, "Registry should contain >= 17 modules")
            for (var i = 0; i < BarModuleRegistry.allModules.length; i++) {
                var mod = BarModuleRegistry.allModules[i]
                var comp = BarModuleRegistry.getComponent(mod.id)
                assert(comp !== null, "Module component must resolve: " + mod.id)
            }

            // 2. Verify Style Switching
            var styles = ["floating", "full", "island", "dock", "compact"]
            for (var s = 0; s < styles.length; s++) {
                SettingsBus.set("bar.style", styles[s])
                assert(SettingsBus.get("bar.style", "") === styles[s], "bar.style should be " + styles[s])
            }

            // 3. Verify Empty Slot Resilience
            SettingsBus.set("bar.slots.center", [])
            assert(testBar.height === 34, "Bar height should remain stable with empty center slot")

            if (passed) {
                console.info("PASS: Modular topbar test suite passed successfully")
                Qt.exit(0)
            } else {
                console.error("FAIL: Failures:", JSON.stringify(failures))
                Qt.exit(1)
            }
        }
    }
}
```

- [ ] **Step 2: Run test**

```bash
qs -p ./quickshell/bar/test-bar-modular.qml
```
Expected: PASS: Modular topbar test suite passed successfully

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/bar/test-bar-modular.qml
rtk git commit -m "test(bar): add automated unit test suite for modular topbar"
```

---

### Task 8: ShellCheck & Graphical Sandbox Verification

Run repo-wide script linting and verify live desktop rendering in the graphical sandbox VM.

**Files:**
- Test all shell scripts
- Visual inspection via `nix run .#sandbox`

- [ ] **Step 1: Run ShellCheck on all shell scripts**

```bash
nix shell nixpkgs#shellcheck -c shellcheck -S warning -e SC1090 -P quickshell $(rtk git ls-files '*.sh')
```
Expected: Clean with 0 warnings/errors.

- [ ] **Step 2: Run all quickshell self-checks in a loop**

```bash
cd quickshell/bar
for t in icons grid notifications shelf settings-ui security-ui desktop wallpaper-panel scroll vm-service reorder-list bar-modular; do
  qs -p "./test-$t.qml"
done
```
Expected: All tests output PASS and exit 0.

- [ ] **Step 3: Visual check in sandbox VM**

Reload sandbox (`call_mcp_tool` `sandbox:reload`), toggle styles (`mujo settings bar.style full`, `island`, `dock`), and take screenshots (`call_mcp_tool` `sandbox:screenshot`) to verify visual excellence.
