# Settings Information Architecture Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the mujō Settings app from a legacy 7-category vertically overflowing stack into a 5-category Information Architecture with horizontal segmented sub-category tabs (`MujoSegmented`) providing 1-click access to every subsystem.

**Architecture:** Each of the 5 top-level category pages (`SystemPage`, `AppearancePage`, `WorkspacePage`, `HardwarePage`, `SecurityPage`) hosts a horizontal `MujoSegmented` sub-tab switcher. Switching sub-tabs displays dedicated sub-pages/groups, and `revealCard(name)` supports deep-linking directly into sub-tabs and cards from search and CLI routing. `settings.qml`, `SettingsLayout.qml`, and `SearchIndex.js` are updated to align with the 5 categories.

**Tech Stack:** QML / Quickshell, JavaScript.

**Spec:** `docs/superpowers/specs/2026-09-04-settings-information-architecture-redesign.md`

## Global Constraints

- Never hardcode user `"yurii"`; use `config.preferences.user.name` or dynamic environment paths.
- Read colors from `Theme.*` in QML.
- Keep `test-settings-ui.qml` and all test harnesses passing at each step.
- Every new component must be registered in `qmldir`.

---

### Task 1: Sub-Category Navigation in System Page

**Files:**
- Modify: `quickshell/bar/modules/settings/SystemPage.qml`
- Test: `quickshell/bar/test-settings-ui.qml`

**Interfaces:**
- Consumes: `NixosHostGroup.qml`, `HealthGroup.qml`, `PreferencesGroup.qml`, `ApplicationsGroup.qml`, `MujoSegmented.qml`, `MujoFlickable.qml`
- Produces: `SystemPage` with `property string tab`, `function revealCard(name)`

- [ ] **Step 1: Write the updated `SystemPage.qml` implementation**

```qml
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// System Host & Operations — Sub-categorized into Host & Rebuild,
// Health & Storage, Preferences, and Applications.
Item {
    id: root

    property string brand: "system"
    property string title: "System"
    property string subtitle: "Host configuration, rebuilds, health sentinel, storage cleaner, preferences & apps."
    property bool isNixos: true

    property string tab: "rebuild"   // rebuild | health | preferences | apps

    readonly property var tabIds: ["rebuild", "health", "preferences", "apps"]

    // Card title to sub-tab mapping for omni-search deep linking
    readonly property var cardTabMap: ({
        "NixOS Generation & Store": "rebuild",
        "System Generation History": "rebuild",
        "Local Module Overrides": "rebuild",
        "System Health Sentinel": "health",
        "Sentinel Automation": "health",
        "Process Sentinel & Anomaly Tracker": "health",
        "Storage Reclamation & Cleaner": "health",
        "Default Applications": "preferences",
        "System Parameters & Host Config": "preferences",
        "Clipboard History (cliphist)": "preferences",
        "Applications & Integrations": "apps"
    })

    function revealCard(name) {
        if (root.tabIds.indexOf(name) >= 0) {
            root.tab = name
            return true
        }
        var targetTab = root.cardTabMap[name]
        if (targetTab) {
            root.tab = targetTab
            Qt.callLater(function() {
                var flick = _getActiveFlickable()
                if (flick) _scrollFlickToCard(flick, name)
            })
            return true
        }
        return false
    }

    function _getActiveFlickable() {
        if (root.tab === "rebuild") return flickRebuild
        if (root.tab === "health") return flickHealth
        if (root.tab === "preferences") return flickPref
        if (root.tab === "apps") return flickApps
        return null
    }

    function _scrollFlickToCard(flick, cardTitle) {
        var card = _findCard(flick.contentItem, cardTitle)
        if (!card) return
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var p = card.mapToItem(flick.contentItem, 0, 0)
        flick.contentY = Math.max(0, Math.min(p.y, maxY))
    }

    function _findCard(node, cardTitle) {
        if (!node) return null
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.collapsible !== undefined && c.title === cardTitle) return c
            var hit = _findCard(c, cardTitle)
            if (hit) return hit
        }
        return null
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        MujoSegmented {
            Layout.alignment: Qt.AlignLeft
            model: [
                { id: "rebuild",     label: "Host & Rebuild",  icon: "autorenew" },
                { id: "health",      label: "Health & Storage", icon: "health_and_safety" },
                { id: "preferences", label: "Preferences",     icon: "tune" },
                { id: "apps",        label: "Applications",    icon: "apps" }
            ]
            current: root.tab
            onSelected: function(id) { root.tab = id }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MujoFlickable {
                id: flickRebuild
                anchors.fill: parent
                visible: root.tab === "rebuild"
                contentHeight: colRebuild.implicitHeight + 20

                ColumnLayout {
                    id: colRebuild
                    width: parent.width
                    spacing: 14
                    NixosHostGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickHealth
                anchors.fill: parent
                visible: root.tab === "health"
                contentHeight: colHealth.implicitHeight + 20

                ColumnLayout {
                    id: colHealth
                    width: parent.width
                    spacing: 14
                    HealthGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickPref
                anchors.fill: parent
                visible: root.tab === "preferences"
                contentHeight: colPref.implicitHeight + 20

                ColumnLayout {
                    id: colPref
                    width: parent.width
                    spacing: 14
                    PreferencesGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickApps
                anchors.fill: parent
                visible: root.tab === "apps"
                contentHeight: colApps.implicitHeight + 20

                ColumnLayout {
                    id: colApps
                    width: parent.width
                    spacing: 14
                    ApplicationsGroup { Layout.fillWidth: true }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify `SystemPage.qml` loads with `qs -p`**

Run: `qs -p quickshell/bar/test-settings-ui.qml`
Expected: Evaluates cleanly without QML syntax errors.

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/bar/modules/settings/SystemPage.qml
rtk git commit -m "feat(settings): add segmented sub-category tabs to SystemPage"
```

---

### Task 2: Sub-Category Navigation in Appearance Page

**Files:**
- Modify: `quickshell/bar/modules/settings/AppearancePage.qml`
- Test: `quickshell/bar/test-settings-ui.qml`

**Interfaces:**
- Consumes: `ThemeGroup.qml`, `WallpaperBrowseGroup.qml`, `WallpaperEffectsGroup.qml`, `MotionGroup.qml`, `MujoSegmented.qml`
- Produces: `AppearancePage` with `property string tab`, `function revealCard(name)`

- [ ] **Step 1: Write the updated `AppearancePage.qml` implementation**

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Appearance & Personalization — Themes & Colors, Wallpaper Catalog,
// Wallpaper Effects, and Motion Dynamics.
Item {
    id: root

    property string brand: "appearance"
    property string title: "Appearance"
    property string subtitle: "Theme presets, accent colors, wallpaper catalog, live engines & motion dynamics."

    property string tab: "themes"   // themes | wallpapers | effects | motion
    readonly property var tabIds: ["themes", "wallpapers", "effects", "motion", "library", "wallhaven", "wallpaperengine"]

    // Wallpaper state
    property var localList: []
    property string currentImage: ""
    property string letterbox: Theme.active.bg
    property bool motionOn: false

    function runWp(args) { Quickshell.execDetached(["mujo", "wallpaper"].concat(args)) }
    function refreshLocal() { listProc.running = true }

    Component.onCompleted: root.refreshLocal()

    FileView {
        path: (Quickshell.env("HOME") || "/tmp") + "/.config/quickshell/wallpaper.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var c = JSON.parse(text())
                var d = c["default"] || {}
                root.currentImage = d.image || d.video || d.engine || ""
                root.letterbox = c.background || Theme.active.bg
                root.motionOn = !!(c.effects && c.effects.motion)
            } catch (e) {
                console.warn("AppearancePage: wallpaper.json parse error:", e)
            }
        }
    }

    Process {
        id: listProc
        command: ["mujo", "wallpaper", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.localList = JSON.parse(this.text) }
                catch (e) { root.localList = [] }
            }
        }
    }

    Connections {
        target: WallpaperDownloads
        function onDownloadFinished(url, destPath) { root.refreshLocal() }
    }

    readonly property var cardTabMap: ({
        "Theme Presets": "themes",
        "Accent Color & Surface Opacity": "themes",
        "Wallpaper Engine Performance": "effects",
        "Parallax & Background": "effects",
        "Motion Intensity Profile": "motion",
        "Interactive Motion Playground": "motion",
        "Granular Motion Domains": "motion",
        "Accessibility & Performance": "motion"
    })

    function revealCard(name) {
        if (name === "library" || name === "wallhaven" || name === "wallpaperengine" || name === "wallpapers") {
            root.tab = "wallpapers"
            if (browseGroup && (name === "library" || name === "wallhaven" || name === "wallpaperengine")) {
                browseGroup.tab = name
            }
            return true
        }
        if (root.tabIds.indexOf(name) >= 0) {
            root.tab = name
            return true
        }
        var targetTab = root.cardTabMap[name]
        if (targetTab) {
            root.tab = targetTab
            Qt.callLater(function() {
                var flick = _getActiveFlickable()
                if (flick) _scrollFlickToCard(flick, name)
            })
            return true
        }
        return false
    }

    function _getActiveFlickable() {
        if (root.tab === "themes") return flickThemes
        if (root.tab === "effects") return flickEffects
        if (root.tab === "motion") return flickMotion
        return null
    }

    function _scrollFlickToCard(flick, cardTitle) {
        var card = _findCard(flick.contentItem, cardTitle)
        if (!card) return
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var p = card.mapToItem(flick.contentItem, 0, 0)
        flick.contentY = Math.max(0, Math.min(p.y, maxY))
    }

    function _findCard(node, cardTitle) {
        if (!node) return null
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.collapsible !== undefined && c.title === cardTitle) return c
            var hit = _findCard(c, cardTitle)
            if (hit) return hit
        }
        return null
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        MujoSegmented {
            Layout.alignment: Qt.AlignLeft
            model: [
                { id: "themes",     label: "Themes & Colors",   icon: "palette" },
                { id: "wallpapers", label: "Wallpapers",        icon: "photo_library" },
                { id: "effects",    label: "Wallpaper Effects", icon: "tune" },
                { id: "motion",     label: "Motion Dynamics",   icon: "animation" }
            ]
            current: root.tab
            onSelected: function(id) { root.tab = id }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MujoFlickable {
                id: flickThemes
                anchors.fill: parent
                visible: root.tab === "themes"
                contentHeight: colThemes.implicitHeight + 20

                ColumnLayout {
                    id: colThemes
                    width: parent.width
                    spacing: 14
                    ThemeGroup { Layout.fillWidth: true }
                }
            }

            WallpaperBrowseGroup {
                id: browseGroup
                anchors.fill: parent
                visible: root.tab === "wallpapers"
                localList: root.localList
                currentImage: root.currentImage
                onWpRun: function(args) { root.runWp(args) }
            }

            MujoFlickable {
                id: flickEffects
                anchors.fill: parent
                visible: root.tab === "effects"
                contentHeight: colEffects.implicitHeight + 20

                ColumnLayout {
                    id: colEffects
                    width: parent.width
                    spacing: 14
                    WallpaperEffectsGroup {
                        Layout.fillWidth: true
                        motionOn: root.motionOn
                        letterbox: root.letterbox
                        onWpRun: function(args) { root.runWp(args) }
                    }
                }
            }

            MujoFlickable {
                id: flickMotion
                anchors.fill: parent
                visible: root.tab === "motion"
                contentHeight: colMotion.implicitHeight + 20

                ColumnLayout {
                    id: colMotion
                    width: parent.width
                    spacing: 14
                    MotionGroup { Layout.fillWidth: true }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify `AppearancePage.qml` loads with `qs -p`**

Run: `qs -p quickshell/bar/test-settings-ui.qml`
Expected: Evaluates cleanly without QML syntax errors.

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/bar/modules/settings/AppearancePage.qml
rtk git commit -m "feat(settings): add segmented sub-category tabs to AppearancePage"
```

---

### Task 3: Sub-Category Navigation in Workspace Page

**Files:**
- Modify: `quickshell/bar/modules/settings/WorkspacePage.qml`
- Test: `quickshell/bar/test-settings-ui.qml`

**Interfaces:**
- Consumes: `BarGroup.qml`, `IslandGroup.qml`, `WidgetsGroup.qml`, `ShelfGroup.qml`, `MujoSegmented.qml`
- Produces: `WorkspacePage` with `property string tab`, `function revealCard(name)`

- [ ] **Step 1: Write the updated `WorkspacePage.qml` implementation**

```qml
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Workspace & Desktop Chrome — Desktop Bar, Dynamic Island,
// Overlay Widgets, and Edge Staging Shelf.
Item {
    id: root

    property string brand: "desktop"
    property string title: "Workspace"
    property string subtitle: "Desktop bar layout, dynamic island notch, overlay widgets & staging shelf."

    property string tab: "bar"   // bar | island | widgets | shelf
    readonly property var tabIds: ["bar", "island", "widgets", "shelf"]

    readonly property var cardTabMap: ({
        "Desktop Bar Layout & Geometry": "bar",
        "Right Cluster Modules & Order": "bar",
        "Bar Widget Style Customizer": "bar",
        "Dynamic Island Notch": "island",
        "Island Geometry & Surface": "island",
        "Expansion & Alert Behavior": "island",
        "Desktop Overlay Widgets": "widgets",
        "Global Widget Styles & Glassmorphism": "widgets",
        "Widget Customization & Styles": "widgets",
        "Shelf File Staging Drop Zone": "shelf"
    })

    function revealCard(name) {
        if (root.tabIds.indexOf(name) >= 0) {
            root.tab = name
            return true
        }
        var targetTab = root.cardTabMap[name]
        if (targetTab) {
            root.tab = targetTab
            Qt.callLater(function() {
                var flick = _getActiveFlickable()
                if (flick) _scrollFlickToCard(flick, name)
            })
            return true
        }
        return false
    }

    function _getActiveFlickable() {
        if (root.tab === "bar") return flickBar
        if (root.tab === "island") return flickIsland
        if (root.tab === "widgets") return flickWidgets
        if (root.tab === "shelf") return flickShelf
        return null
    }

    function _scrollFlickToCard(flick, cardTitle) {
        var card = _findCard(flick.contentItem, cardTitle)
        if (!card) return
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var p = card.mapToItem(flick.contentItem, 0, 0)
        flick.contentY = Math.max(0, Math.min(p.y, maxY))
    }

    function _findCard(node, cardTitle) {
        if (!node) return null
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.collapsible !== undefined && c.title === cardTitle) return c
            var hit = _findCard(c, cardTitle)
            if (hit) return hit
        }
        return null
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        MujoSegmented {
            Layout.alignment: Qt.AlignLeft
            model: [
                { id: "bar",     label: "Desktop Bar",     icon: "dock_to_bottom" },
                { id: "island",  label: "Dynamic Island",  icon: "notifications_active" },
                { id: "widgets", label: "Overlay Widgets", icon: "widgets" },
                { id: "shelf",   label: "Shelf",           icon: "inventory_2" }
            ]
            current: root.tab
            onSelected: function(id) { root.tab = id }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MujoFlickable {
                id: flickBar
                anchors.fill: parent
                visible: root.tab === "bar"
                contentHeight: colBar.implicitHeight + 20

                ColumnLayout {
                    id: colBar
                    width: parent.width
                    spacing: 14
                    BarGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickIsland
                anchors.fill: parent
                visible: root.tab === "island"
                contentHeight: colIsland.implicitHeight + 20

                ColumnLayout {
                    id: colIsland
                    width: parent.width
                    spacing: 14
                    IslandGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickWidgets
                anchors.fill: parent
                visible: root.tab === "widgets"
                contentHeight: colWidgets.implicitHeight + 20

                ColumnLayout {
                    id: colWidgets
                    width: parent.width
                    spacing: 14
                    WidgetsGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickShelf
                anchors.fill: parent
                visible: root.tab === "shelf"
                contentHeight: colShelf.implicitHeight + 20

                ColumnLayout {
                    id: colShelf
                    width: parent.width
                    spacing: 14
                    ShelfGroup { Layout.fillWidth: true }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify `WorkspacePage.qml` loads with `qs -p`**

Run: `qs -p quickshell/bar/test-settings-ui.qml`
Expected: Evaluates cleanly without QML syntax errors.

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/bar/modules/settings/WorkspacePage.qml
rtk git commit -m "feat(settings): add segmented sub-category tabs to WorkspacePage"
```

---

### Task 4: Sub-Category Navigation in Hardware Page

**Files:**
- Modify: `quickshell/bar/modules/settings/HardwarePage.qml`
- Test: `quickshell/bar/test-settings-ui.qml`

**Interfaces:**
- Consumes: `DisplaysGroup.qml`, `InputGroup.qml`, `ShortcutsGroup.qml`, `NetworkGroup.qml`, `WeatherGroup.qml`, `IdlePowerGroup.qml`, `VmGroup.qml`, `MujoSegmented.qml`
- Produces: `HardwarePage` with `property string tab`, `function revealCard(name)`

- [ ] **Step 1: Write the updated `HardwarePage.qml` implementation**

```qml
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Hardware & Devices — Displays, Input & Keys, Network & VPN, Power & Sleep,
// and Virtual Machines.
Item {
    id: root

    property string brand: "display"
    property string title: "Hardware"
    property string subtitle: "Displays, input devices, keyboard shortcuts, network VPN, power & virtual machines."
    property bool isNixos: true

    property string tab: "displays"   // displays | input | network | power | vm
    readonly property var tabIds: ["displays", "input", "network", "power", "vm", "shortcuts", "vpn", "weather"]

    readonly property var cardTabMap: ({
        "Arrangement": "displays",
        "Keyboard": "input",
        "Pointer": "input",
        "Keyboard Shortcuts": "input",
        "Mullvad WireGuard Tunnel": "network",
        "Keyring Credentials & Login": "network",
        "Relay Locations & Exit Nodes": "network",
        "Current Atmospheric Conditions": "network",
        "Location & Geocoding": "network",
        "Idle & Power": "power",
        "Virtual Machines": "vm"
    })

    function revealCard(name) {
        if (name === "shortcuts") { root.tab = "input"; return true }
        if (name === "vpn" || name === "weather") { root.tab = "network"; return true }
        if (root.tabIds.indexOf(name) >= 0) {
            root.tab = name
            return true
        }
        var targetTab = root.cardTabMap[name]
        if (targetTab) {
            root.tab = targetTab
            Qt.callLater(function() {
                var flick = _getActiveFlickable()
                if (flick) _scrollFlickToCard(flick, name)
            })
            return true
        }
        return false
    }

    function _getActiveFlickable() {
        if (root.tab === "displays") return flickDisplays
        if (root.tab === "input") return flickInput
        if (root.tab === "network") return flickNetwork
        if (root.tab === "power") return flickPower
        if (root.tab === "vm") return flickVm
        return null
    }

    function _scrollFlickToCard(flick, cardTitle) {
        var card = _findCard(flick.contentItem, cardTitle)
        if (!card) return
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var p = card.mapToItem(flick.contentItem, 0, 0)
        flick.contentY = Math.max(0, Math.min(p.y, maxY))
    }

    function _findCard(node, cardTitle) {
        if (!node) return null
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.collapsible !== undefined && c.title === cardTitle) return c
            var hit = _findCard(c, cardTitle)
            if (hit) return hit
        }
        return null
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        MujoSegmented {
            Layout.alignment: Qt.AlignLeft
            model: [
                { id: "displays", label: "Displays",         icon: "monitor" },
                { id: "input",    label: "Input & Keys",     icon: "keyboard" },
                { id: "network",  label: "Network & VPN",    icon: "vpn_key" },
                { id: "power",    label: "Power & Sleep",    icon: "power_settings_new" },
                { id: "vm",       label: "Virtual Machines", icon: "dns" }
            ]
            current: root.tab
            onSelected: function(id) { root.tab = id }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MujoFlickable {
                id: flickDisplays
                anchors.fill: parent
                visible: root.tab === "displays"
                contentHeight: colDisplays.implicitHeight + 20

                ColumnLayout {
                    id: colDisplays
                    width: parent.width
                    spacing: 14
                    DisplaysGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickInput
                anchors.fill: parent
                visible: root.tab === "input"
                contentHeight: colInput.implicitHeight + 20

                ColumnLayout {
                    id: colInput
                    width: parent.width
                    spacing: 14
                    InputGroup { Layout.fillWidth: true }
                    ShortcutsGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickNetwork
                anchors.fill: parent
                visible: root.tab === "network"
                contentHeight: colNetwork.implicitHeight + 20

                ColumnLayout {
                    id: colNetwork
                    width: parent.width
                    spacing: 14
                    NetworkGroup { Layout.fillWidth: true }
                    WeatherGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickPower
                anchors.fill: parent
                visible: root.tab === "power"
                contentHeight: colPower.implicitHeight + 20

                ColumnLayout {
                    id: colPower
                    width: parent.width
                    spacing: 14
                    IdlePowerGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickVm
                anchors.fill: parent
                visible: root.tab === "vm"
                contentHeight: colVm.implicitHeight + 20

                ColumnLayout {
                    id: colVm
                    width: parent.width
                    spacing: 14
                    VmGroup { Layout.fillWidth: true }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify `HardwarePage.qml` loads with `qs -p`**

Run: `qs -p quickshell/bar/test-settings-ui.qml`
Expected: Evaluates cleanly without QML syntax errors.

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/bar/modules/settings/HardwarePage.qml
rtk git commit -m "feat(settings): add segmented sub-category tabs to HardwarePage"
```

---

### Task 5: Sub-Category Navigation in Security & AI Page

**Files:**
- Modify: `quickshell/bar/modules/settings/SecurityPage.qml`
- Test: `quickshell/bar/test-settings-ui.qml`

**Interfaces:**
- Consumes: `SecurityGroup.qml`, `AiGroup.qml`, `ApplicationsTrustTab.qml`, `KeyringGroup.qml`, `PrivacyGroup.qml`, `PersistenceGroup.qml`, `NotificationsGroup.qml`, `MujoSegmented.qml`
- Produces: `SecurityPage` with `property string tab`, `function revealCard(name)`

- [ ] **Step 1: Write the updated `SecurityPage.qml` implementation**

```qml
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Security & AI — Verified boot, AI assistants, progressive trust sandbox,
// credentials, privacy & alerts.
Item {
    id: root

    property string brand: "security"
    property string title: "Security & AI"
    property string subtitle: "Verified boot, AI assistants, progressive trust sandbox, credentials, privacy & alerts."
    property bool isNixos: true

    property string tab: "integrity"   // integrity | ai | trust | keyring | privacy
    readonly property var tabIds: ["integrity", "ai", "trust", "keyring", "privacy", "vault", "notifications", "dnd", "persistence"]

    readonly property var cardTabMap: ({
        "Verified Boot & System Integrity": "integrity",
        "LUKS2 Encrypted Storage Vault": "integrity",
        "Host Hardening & Memory Isolation": "integrity",
        "Coding Assistant CLI": "ai",
        "API Provider & Endpoint": "ai",
        "AI Privacy & Safety Guardrails": "ai",
        "Progressive Trust & Isolation Engine": "trust",
        "Stored credentials": "keyring",
        "Managed Persistence Paths": "privacy",
        "Local Activity Trail": "privacy",
        "Session Lock": "privacy",
        "Behavior & Do Not Disturb": "privacy",
        "Sound Alerts & Placement": "privacy",
        "Per-App Mute Rules": "privacy"
    })

    function revealCard(name) {
        if (name === "vault") { root.tab = "integrity"; return true }
        if (name === "ai") { root.tab = "ai"; return true }
        if (name === "trust") { root.tab = "trust"; return true }
        if (name === "keyring") { root.tab = "keyring"; return true }
        if (name === "privacy" || name === "notifications" || name === "dnd" || name === "persistence") { root.tab = "privacy"; return true }
        if (root.tabIds.indexOf(name) >= 0) {
            root.tab = name
            return true
        }
        var targetTab = root.cardTabMap[name]
        if (targetTab) {
            root.tab = targetTab
            Qt.callLater(function() {
                var flick = _getActiveFlickable()
                if (flick) _scrollFlickToCard(flick, name)
            })
            return true
        }
        return false
    }

    function _getActiveFlickable() {
        if (root.tab === "integrity") return flickIntegrity
        if (root.tab === "ai") return flickAi
        if (root.tab === "trust") return flickTrust
        if (root.tab === "keyring") return flickKeyring
        if (root.tab === "privacy") return flickPrivacy
        return null
    }

    function _scrollFlickToCard(flick, cardTitle) {
        var card = _findCard(flick.contentItem, cardTitle)
        if (!card) return
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var p = card.mapToItem(flick.contentItem, 0, 0)
        flick.contentY = Math.max(0, Math.min(p.y, maxY))
    }

    function _findCard(node, cardTitle) {
        if (!node) return null
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.collapsible !== undefined && c.title === cardTitle) return c
            var hit = _findCard(c, cardTitle)
            if (hit) return hit
        }
        return null
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        MujoSegmented {
            Layout.alignment: Qt.AlignLeft
            model: [
                { id: "integrity", label: "System Integrity",  icon: "verified_user" },
                { id: "ai",        label: "AI Assistants",     icon: "psychology" },
                { id: "trust",     label: "Trust & Sandbox",   icon: "shield" },
                { id: "keyring",   label: "Credentials",       icon: "password" },
                { id: "privacy",   label: "Privacy & Alerts",  icon: "security" }
            ]
            current: root.tab
            onSelected: function(id) { root.tab = id }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MujoFlickable {
                id: flickIntegrity
                anchors.fill: parent
                visible: root.tab === "integrity"
                contentHeight: colIntegrity.implicitHeight + 20

                ColumnLayout {
                    id: colIntegrity
                    width: parent.width
                    spacing: 14
                    SecurityGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickAi
                anchors.fill: parent
                visible: root.tab === "ai"
                contentHeight: colAi.implicitHeight + 20

                ColumnLayout {
                    id: colAi
                    width: parent.width
                    spacing: 14
                    AiGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickTrust
                anchors.fill: parent
                visible: root.tab === "trust"
                contentHeight: colTrust.implicitHeight + 20

                ColumnLayout {
                    id: colTrust
                    width: parent.width
                    spacing: 14
                    ApplicationsTrustTab { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickKeyring
                anchors.fill: parent
                visible: root.tab === "keyring"
                contentHeight: colKeyring.implicitHeight + 20

                ColumnLayout {
                    id: colKeyring
                    width: parent.width
                    spacing: 14
                    KeyringGroup { Layout.fillWidth: true }
                }
            }

            MujoFlickable {
                id: flickPrivacy
                anchors.fill: parent
                visible: root.tab === "privacy"
                contentHeight: colPrivacy.implicitHeight + 20

                ColumnLayout {
                    id: colPrivacy
                    width: parent.width
                    spacing: 14
                    PersistenceGroup { Layout.fillWidth: true }
                    PrivacyGroup { Layout.fillWidth: true }
                    NotificationsGroup { Layout.fillWidth: true }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify `SecurityPage.qml` loads with `qs -p`**

Run: `qs -p quickshell/bar/test-settings-ui.qml`
Expected: Evaluates cleanly without QML syntax errors.

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/bar/modules/settings/SecurityPage.qml
rtk git commit -m "feat(settings): add segmented sub-category tabs to SecurityPage"
```

---

### Task 6: 5-Category Shell Configuration & Routing

**Files:**
- Modify: `quickshell/bar/settings.qml`
- Modify: `quickshell/bar/modules/settings/SettingsLayout.qml`
- Test: `quickshell/bar/test-settings-ui.qml`

**Interfaces:**
- Consumes: `SystemPage`, `AppearancePage`, `WorkspacePage`, `HardwarePage`, `SecurityPage`
- Produces: 5-Category consolidated Settings shell with alias routing.

- [ ] **Step 1: Update `quickshell/bar/settings.qml`**

Configure the 5 consolidated categories with updated subtitles, badges, and routing alias keys:
```qml
//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import Quickshell
import "./theme"
import "./modules/settings"
import "./modules/settings/SearchIndex.js" as SearchIndex

// mujō (無常) — Desktop Settings.
// 5-Category Information Architecture: System, Appearance, Workspace, Hardware, Security & AI.
ShellRoot {
    FloatingWindow {
        id: win
        title: "mujō — Settings"
        implicitWidth: 1120
        implicitHeight: 740
        color: Theme.bg

        property bool _shown: false
        onVisibleChanged: {
            if (visible) _shown = true
            else if (_shown) Qt.quit()
        }

        Component { id: systemComp;       SystemPage {} }
        Component { id: appearanceComp;   AppearancePage {} }
        Component { id: workspaceComp;    WorkspacePage {} }
        Component { id: hardwareComp;     HardwarePage {} }
        Component { id: securityComp;     SecurityPage {} }

        SettingsLayout {
            anchors.fill: parent

            categories: [
                {
                    key: "system", label: "System", icon: "tune", brand: "system",
                    subtitle: "Host, rebuilds, health sentinel, storage cleaner, preferences & apps",
                    page: systemComp, badge: 4,
                    keys: ["system", "overview", "health", "general", "applications", "host", "rebuild", "gc", "sentinel", "preferences", "apps"]
                },
                {
                    key: "appearance", label: "Appearance", icon: "palette", brand: "appearance",
                    subtitle: "Theme presets, accent colors, wallpaper catalog, live engines & motion dynamics",
                    page: appearanceComp, badge: 4,
                    keys: ["appearance", "theme", "colors", "accent", "transparency", "motion", "animations", "wallpapers", "wallpaper", "wallhaven", "wallpaperengine", "effects", "parallax"]
                },
                {
                    key: "workspace", label: "Workspace", icon: "dock_to_bottom", brand: "desktop",
                    subtitle: "Desktop bar layout, dynamic island notch, overlay widgets & staging shelf",
                    page: workspaceComp, badge: 4,
                    keys: ["workspace", "bar", "island", "widgets", "desktop", "shelf"]
                },
                {
                    key: "hardware", label: "Hardware", icon: "monitor", brand: "display",
                    subtitle: "Displays, input devices, keyboard shortcuts, network VPN, power & virtual machines",
                    page: hardwareComp, badge: 5,
                    keys: ["hardware", "display", "displays", "devices", "input", "keyboard", "mouse", "touchpad", "shortcuts", "vm", "machines", "idle", "power", "screen", "network", "vpn", "mullvad", "weather"]
                },
                {
                    key: "security", label: "Security & AI", icon: "shield", brand: "security",
                    subtitle: "Verified boot, AI assistants, progressive trust sandbox, credentials, privacy & alerts",
                    page: securityComp, badge: 5,
                    keys: ["security", "vault", "keyring", "trust", "persistence", "privacy", "tpm", "boot", "ai", "intelligence", "notifications", "dnd", "credentials", "integrity"]
                }
            ]

            searchIndex: SearchIndex.entries
        }
    }
}
```

- [ ] **Step 2: Update `quickshell/bar/modules/settings/SettingsLayout.qml`**

Ensure `flushPendingCard` and `route` pass the alias/key to `currentPage.revealCard(key)` or `currentPage.revealCard(card)`.

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/bar/settings.qml quickshell/bar/modules/settings/SettingsLayout.qml
rtk git commit -m "feat(settings): configure 5-category shell navigation and routing"
```

---

### Task 7: Omni-Search Index Synchronization

**Files:**
- Modify: `quickshell/bar/modules/settings/SearchIndex.js`
- Test: `quickshell/bar/test-settings-ui.qml`

**Interfaces:**
- Consumes: All `MujoCard` titles and tab IDs across the 5 pages
- Produces: `SearchIndex.entries` with accurate category names, keys, and card anchors.

- [ ] **Step 1: Update `quickshell/bar/modules/settings/SearchIndex.js`**

Map all search entries to the 5 categories (`System`, `Appearance`, `Workspace`, `Hardware`, `Security & AI`), ensuring exact card titles match the QML components:

```javascript
.pragma library

var entries = [
    // ── 1. System ──
    { title: "NixOS Rebuild & Switch", desc: "Apply and switch host configuration with pkexec escalation", cat: "System", key: "rebuild", card: "NixOS Generation & Store" },
    { title: "System Generation History", desc: "Inspect current and past bootable system generations", cat: "System", key: "rebuild", card: "System Generation History" },
    { title: "Nix Store Usage & Flake Status", desc: "View store disk consumption and flake.lock currency", cat: "System", key: "rebuild", card: "NixOS Generation & Store" },
    { title: "Local Module Overrides", desc: "Machine-local drop-in overrides and flake inspect", cat: "System", key: "rebuild", card: "Local Module Overrides" },
    { title: "System Health Sentinel", desc: "Real-time process anomaly tracker, zombie reaper & storage cleaner", cat: "System", key: "health", card: "System Health Sentinel" },
    { title: "Sentinel Automation", desc: "Enable the process sentinel, silent zombie reaping and runaway auto-kill", cat: "System", key: "health", card: "Sentinel Automation" },
    { title: "Problematic Processes", desc: "Terminate runaway CPU/RAM tasks and reap defunct zombies", cat: "System", key: "health", card: "Process Sentinel & Anomaly Tracker" },
    { title: "Storage Reclamation & Cleaner", desc: "Vacuum journal logs, clean Nix store, purge thumbnails and trash", cat: "System", key: "health", card: "Storage Reclamation & Cleaner" },
    { title: "Memory Compaction & ZRAM", desc: "Compact ZRAM swap buffers and drop inactive kernel page cache", cat: "System", key: "health", card: "Storage Reclamation & Cleaner" },
    { title: "Default Applications (XDG MIME)", desc: "MIME handlers for browser, editor, terminal, file manager, media", cat: "System", key: "preferences", card: "Default Applications" },
    { title: "System Hostname & Timezone", desc: "Declarative hostname and regional timezone clock mapping", cat: "System", key: "preferences", card: "System Parameters & Host Config" },
    { title: "Hardware Power Profile", desc: "CPU energy performance scaling governor (performance/balanced/eco)", cat: "System", key: "preferences", card: "System Parameters & Host Config" },
    { title: "System Sound Alerts", desc: "Play the system chime for alerts and completion events", cat: "System", key: "preferences", card: "System Parameters & Host Config" },
    { title: "Clipboard History (cliphist)", desc: "History depth, sensitive filter, image capture, and wipe", cat: "System", key: "preferences", card: "Clipboard History (cliphist)" },
    { title: "Companion App Integrations", desc: "Discord, Obsidian, Steam, VS Code, Spotify desktop integrations", cat: "System", key: "apps", card: "Applications & Integrations" },
    { title: "Flatpak Applications & Permissions", desc: "Installed Flatpaks, filesystem access, and socket permissions", cat: "System", key: "apps", card: "Applications & Integrations" },
    { title: "Launcher Pins & Workflows", desc: "Pinned favorite apps, recent launches, and search history", cat: "System", key: "apps", card: "Applications & Integrations" },

    // ── 2. Appearance ──
    { title: "Theme Presets", desc: "Crimson, Blood Moon, Catppuccin, Ayu, Dracula, Nord, Gruvbox…", cat: "Appearance", key: "appearance", card: "Theme Presets" },
    { title: "Accent Color Override", desc: "Custom hex or curated 34-color palette accent swatch", cat: "Appearance", key: "appearance", card: "Accent Color & Surface Opacity" },
    { title: "Surface Transparency", desc: "Translucent glass alpha and blur opacity across panels and bars", cat: "Appearance", key: "appearance", card: "Accent Color & Surface Opacity" },
    { title: "Wallpaper Library", desc: "Apply from local curated high-resolution wallpaper collection", cat: "Appearance", key: "wallpapers", card: "library" },
    { title: "Wallhaven Online Explorer", desc: "Search millions of wallpapers, purity filters, NVMe thumbnail cache", cat: "Appearance", key: "wallhaven", card: "wallhaven" },
    { title: "Wallpaper Engine Steam Workshop", desc: "Browse Steam Workshop (431960) and installed live animated wallpapers", cat: "Appearance", key: "wallpaperengine", card: "wallpaperengine" },
    { title: "Wallpaper Engine Performance", desc: "Live FPS limit, audio automute, and background volume", cat: "Appearance", key: "effects", card: "Wallpaper Engine Performance" },
    { title: "Cursor Parallax & Depth", desc: "Dynamic wallpaper pan and parallax depth motion on mouse move", cat: "Appearance", key: "effects", card: "Parallax & Background" },
    { title: "Letterbox Fill Colour", desc: "Background shown around wallpapers that do not fill the screen", cat: "Appearance", key: "effects", card: "Parallax & Background" },
    { title: "Motion Intensity Profile", desc: "Minimal, Balanced, or Expressive physics and kinetic curves", cat: "Appearance", key: "motion", card: "Motion Intensity Profile" },
    { title: "Interactive Motion Playground", desc: "Test real-time duration scaling, pulses, and spring feedback", cat: "Appearance", key: "motion", card: "Interactive Motion Playground" },
    { title: "Page & Tab Transitions", desc: "Fluid crossfade and spatial slide transitions between pages", cat: "Appearance", key: "motion", card: "Granular Motion Domains" },
    { title: "Tactile Micro-interactions", desc: "Fluid hover highlights, switch elasticity, and accordion physics", cat: "Appearance", key: "motion", card: "Granular Motion Domains" },
    { title: "Ambient Motion & Flow", desc: "Subtle continuous background dynamics and breathing loops", cat: "Appearance", key: "motion", card: "Granular Motion Domains" },
    { title: "Background Glow & Lighting", desc: "Backdrop radial lighting and interactive specular highlights", cat: "Appearance", key: "motion", card: "Granular Motion Domains" },
    { title: "Animated Illustrations", desc: "Looping empty-state and hero artwork across the shell", cat: "Appearance", key: "motion", card: "Granular Motion Domains" },
    { title: "Reduced Motion Mode", desc: "Accessibility preference eliminating spatial movement and transitions", cat: "Appearance", key: "motion", card: "Accessibility & Performance" },
    { title: "Low-Power Performance Mode", desc: "Disable background particle effects and continuous loops to save battery", cat: "Appearance", key: "motion", card: "Accessibility & Performance" },

    // ── 3. Workspace ──
    { title: "Desktop Bar Layout & Position", desc: "Attach floating bar to top or bottom edge of screen", cat: "Workspace", key: "workspace", card: "Desktop Bar Layout & Geometry" },
    { title: "Bar Height & Edge Margin", desc: "Vertical pill height, screen border margin, and cluster spacing", cat: "Workspace", key: "workspace", card: "Desktop Bar Layout & Geometry" },
    { title: "Bar Auto-Hide", desc: "Intelligent auto-hide when windows approach the screen edge", cat: "Workspace", key: "workspace", card: "Desktop Bar Layout & Geometry" },
    { title: "Right Cluster Modules & Order", desc: "Drag, reorder, add, and remove modules in the right cluster", cat: "Workspace", key: "workspace", card: "Right Cluster Modules & Order" },
    { title: "Workspaces Numeral Style", desc: "Numbers (1 2 3), Dots (•), Roman (I II), or Kanji (一 二)", cat: "Workspace", key: "workspace", card: "Bar Widget Style Customizer" },
    { title: "Workspaces Glider Indicator", desc: "Morphic glider, pill, underline, or outline active workspace indicator", cat: "Workspace", key: "workspace", card: "Bar Widget Style Customizer" },
    { title: "Clock Time Format & Seconds", desc: "24-hour format, live seconds counter, date pattern, monospace font", cat: "Workspace", key: "workspace", card: "Bar Widget Style Customizer" },
    { title: "Launcher Trigger Icon & Label", desc: "Search glass, Mujō logo, app grid, or custom text label", cat: "Workspace", key: "workspace", card: "Bar Widget Style Customizer" },
    { title: "Active Window Pill Style", desc: "App icon, window title text, max width elision, pill or glass style", cat: "Workspace", key: "workspace", card: "Bar Widget Style Customizer" },
    { title: "Dynamic Island Notch", desc: "Floating status notch: modules, geometry, animations, and auto-expand", cat: "Workspace", key: "island", card: "Dynamic Island Notch" },
    { title: "Island Geometry & Surface", desc: "Island max width, corner radius, vertical offset and opacity", cat: "Workspace", key: "island", card: "Island Geometry & Surface" },
    { title: "Island Auto-Expand & Alerts", desc: "Expansion duration and expand-on-notification banners", cat: "Workspace", key: "island", card: "Expansion & Alert Behavior" },
    { title: "Desktop Overlay Widgets", desc: "Freely place, drag, resize, and lock widgets across monitors", cat: "Workspace", key: "widgets", card: "Desktop Overlay Widgets" },
    { title: "Widget Glassmorphism & Shadows", desc: "Glass opacity, corner radius, drop shadows, and specular border glow", cat: "Workspace", key: "widgets", card: "Global Widget Styles & Glassmorphism" },
    { title: "Sticky Notes Widget Theme", desc: "Slate, yellow, rose, emerald, dark color themes and font sizes", cat: "Workspace", key: "widgets", card: "Widget Customization & Styles" },
    { title: "Cava Spectrum Visualizer", desc: "Equalizer bars, wave, dots, opacity, and mirror reflection", cat: "Workspace", key: "widgets", card: "Widget Customization & Styles" },
    { title: "Shelf File Staging Drop Zone", desc: "Screen-edge staging strip for collecting dragged files across folders", cat: "Workspace", key: "shelf", card: "Shelf File Staging Drop Zone" },

    // ── 4. Hardware ──
    { title: "Display Resolution & Refresh Rate", desc: "Resolution, Hz, and HiDPI scaling per connected monitor", cat: "Hardware", key: "hardware", card: "Arrangement" },
    { title: "Visual Monitor Arrangement", desc: "Spatial drag-and-drop monitor layout and primary screen setup", cat: "Hardware", key: "hardware", card: "Arrangement" },
    { title: "Keyboard Repeat & Sensitivity", desc: "Key repeat rate, delay, and XKB keymap layout variants", cat: "Hardware", key: "input", card: "Keyboard" },
    { title: "Pointer & Touchpad Dynamics", desc: "Mouse acceleration profile, natural scrolling, tap-to-click", cat: "Hardware", key: "input", card: "Pointer" },
    { title: "Keyboard Shortcuts Matrix", desc: "Interactive searchable matrix of Niri window manager bindings", cat: "Hardware", key: "shortcuts", card: "Keyboard Shortcuts" },
    { title: "Mullvad WireGuard VPN", desc: "Connection status, relay country picker, and boot auto-connect", cat: "Hardware", key: "vpn", card: "Mullvad WireGuard Tunnel" },
    { title: "Mullvad Keyring Account", desc: "Keyring-stored 16-digit account number and instant login", cat: "Hardware", key: "vpn", card: "Keyring Credentials & Login" },
    { title: "VPN Relay Locations", desc: "Pick an exit node country and relay for the WireGuard tunnel", cat: "Hardware", key: "vpn", card: "Relay Locations & Exit Nodes" },
    { title: "Weather Telemetry & Forecast", desc: "Open-Meteo current conditions, 5-day forecast, and auto-IP geolocation", cat: "Hardware", key: "weather", card: "Current Atmospheric Conditions" },
    { title: "Weather Location & Units", desc: "Geocoded city search, metric or imperial units, refresh interval", cat: "Hardware", key: "weather", card: "Location & Geocoding" },
    { title: "Idle & Power Sleep Timers", desc: "Dim screen, display turn-off, lock screen, and suspend timers", cat: "Hardware", key: "power", card: "Idle & Power" },
    { title: "Lock Screen", desc: "Lock on suspend and the grace period before the session locks", cat: "Hardware", key: "power", card: "Idle & Power" },
    { title: "Virtual Machines & Lab", desc: "Launch Windows, Ubuntu, Fedora, Arch in KVM with SPICE display", cat: "Hardware", key: "vm", card: "Virtual Machines" },
    { title: "Provision a Virtual Machine", desc: "Create a new guest from the image catalogue", cat: "Hardware", key: "vm", card: "Virtual Machines" },

    // ── 5. Security & AI ──
    { title: "Verified Boot & Security Architecture", desc: "UEFI Secure Boot, TPM 2.0 PCR state, kernel lockdown, and sudo policies", cat: "Security & AI", key: "security", card: "Verified Boot & System Integrity" },
    { title: "Encrypted Storage Vault", desc: "Unlock and lock /persist/secure/mujo-vault.luks container", cat: "Security & AI", key: "vault", card: "LUKS2 Encrypted Storage Vault" },
    { title: "Host Hardening & Memory Isolation", desc: "Kernel lockdown, memory isolation and sudo policy", cat: "Security & AI", key: "security", card: "Host Hardening & Memory Isolation" },
    { title: "Assistant CLI Engine", desc: "Claude Code, opencode, Antigravity, Codex, Gemini CLI, Pi, custom argv", cat: "Security & AI", key: "ai", card: "Coding Assistant CLI" },
    { title: "API Provider & Endpoint", desc: "Local Ollama model, OpenAI-compatible API base URL, model name", cat: "Security & AI", key: "ai", card: "API Provider & Endpoint" },
    { title: "Keyring API Credentials", desc: "Secure keyring storage for AI provider tokens", cat: "Security & AI", key: "ai", card: "API Provider & Endpoint" },
    { title: "AI Privacy & Guardrails", desc: "Shell context, crash data opt-in, and interactive action confirmation", cat: "Security & AI", key: "ai", card: "AI Privacy & Safety Guardrails" },
    { title: "Progressive Trust & Isolation Engine", desc: "Tier statistics, app sandbox policies (Native, Sandbox, MicroVM, Blocked)", cat: "Security & AI", key: "trust", card: "Progressive Trust & Isolation Engine" },
    { title: "Keyring Credentials Manager", desc: "Secret Service credentials, API keys, reveal tokens, and deletions", cat: "Security & AI", key: "keyring", card: "Stored credentials" },
    { title: "Impermanence Persistence Paths", desc: "Managed directories and files surviving btrfs root wipe on boot", cat: "Security & AI", key: "persistence", card: "Managed Persistence Paths" },
    { title: "Recent Files & Location Privacy", desc: "Launcher recent-apps trail and the weather IP geolocation fallback", cat: "Security & AI", key: "privacy", card: "Local Activity Trail" },
    { title: "Lock Before Suspend", desc: "Lock the session in swayidle's before-sleep hook", cat: "Security & AI", key: "privacy", card: "Session Lock" },
    { title: "Do Not Disturb (DND)", desc: "Suppress notification toasts; alerts are still recorded in history", cat: "Security & AI", key: "dnd", card: "Behavior & Do Not Disturb" },
    { title: "Fullscreen Toast Suppression", desc: "Hold notification banners while focused window is fullscreen", cat: "Security & AI", key: "notifications", card: "Behavior & Do Not Disturb" },
    { title: "Notification Audio Chimes", desc: "Sound alerts, urgency threshold filter, and chime preview", cat: "Security & AI", key: "notifications", card: "Sound Alerts & Placement" },
    { title: "Notification Screen Gravity Corner", desc: "Screen corner placement (bottom-right, top-right, etc.) and auto-dismiss", cat: "Security & AI", key: "notifications", card: "Sound Alerts & Placement" },
    { title: "Per-App Notification Rules", desc: "Selectively mute noisy applications while keeping history", cat: "Security & AI", key: "notifications", card: "Per-App Mute Rules" }
]
```

- [ ] **Step 2: Commit**

```bash
rtk git add quickshell/bar/modules/settings/SearchIndex.js
rtk git commit -m "feat(settings): synchronize search index for 5-category IA"
```

---

### Task 8: Comprehensive Self-Check Test Suite Update & Verification

**Files:**
- Modify: `quickshell/bar/test-settings-ui.qml`
- Test: `quickshell/bar/test-settings-ui.qml`

**Interfaces:**
- Consumes: All 5 pages, `SettingsLayout`, `SearchIndex.js`
- Produces: Verified test output.

- [ ] **Step 1: Update `quickshell/bar/test-settings-ui.qml`**

Instantiate the 5 category pages (`SystemPage`, `AppearancePage`, `WorkspacePage`, `HardwarePage`, `SecurityPage`) and test all 5 categories, all routing aliases, and every single search index item and card anchor.

- [ ] **Step 2: Execute `test-settings-ui.qml`**

Run: `qs -p quickshell/bar/test-settings-ui.qml`
Expected: `PASS  settings UI: IA routing, aliases, store bindings, and search card anchors verified`

- [ ] **Step 3: Run all shell self-checks**

Run:
```bash
cd quickshell/bar
for t in icons grid notifications shelf settings-ui desktop wallpaper-panel scroll vm-service reorder-list; do
  qs -p "./test-$t.qml"
done
```
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
rtk git add quickshell/bar/test-settings-ui.qml
rtk git commit -m "test(settings): update self-check test suite for 5-category architecture"
```
