import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Applications & Integrations Control Center — Mujo (無常).
// Manager for integrated desktop services, installed Flatpaks & sandboxing permissions,
// and launcher workflow preferences (favorites & recents).
Item {
    id: root

    // ── Tab navigation state ──────────────────────────────────────────────────
    property string activeTab: "integrations" // integrations | flatpaks | launcher
    readonly property var tabs: [
        { id: "integrations", label: "Integrations & Services", icon: "extension" },
        { id: "flatpaks",     label: "Flatpak Applications",    icon: "inventory_2" },
        { id: "launcher",     label: "Launcher & Workflow",     icon: "stars" }
    ]

    // ── Integrations registry ────────────────────────────────────────────────
    readonly property var registry: [
        { id: "vesktop",   name: "Discord (Vesktop)",    category: "Communication", brand: "discord",  icon: "chat",
          check: "command -v vesktop || flatpak info dev.vencord.Vesktop",
          launch: "command -v vesktop >/dev/null 2>&1 && vesktop || flatpak run dev.vencord.Vesktop",
          dataDir: ".var/app/dev.vencord.Vesktop", desc: "Vesktop client with rich presence" },
        { id: "telegram",  name: "Telegram",             category: "Communication", brand: "telegram", icon: "send",
          check: "command -v telegram-desktop || flatpak info org.telegram.desktop",
          launch: "command -v telegram-desktop >/dev/null 2>&1 && telegram-desktop || flatpak run org.telegram.desktop",
          dataDir: ".var/app/org.telegram.desktop", desc: "Native messaging client" },

        { id: "claude",    name: "Claude Code",          category: "AI & Development", brand: "claude",   icon: "smart_toy",
          check: "command -v claude", launch: "kitty -e claude",
          dataDir: ".claude", desc: "Terminal AI coding assistant" },
        { id: "opencode",  name: "OpenCode",             category: "AI & Development", brand: "opencode", icon: "code",
          check: "command -v opencode", launch: "kitty -e opencode",
          dataDir: ".config/opencode", desc: "Open-source AI coding agent" },
        // The rest of the agent CLIs `mujo ai agents` knows about, so anything
        // selectable as an Ask-AI backend is also launchable from here.
        { id: "antigravity", name: "Antigravity",        category: "AI & Development", brand: "ai",       icon: "auto_awesome",
          check: "command -v agy", launch: "kitty -e agy",
          dataDir: ".gemini", desc: "Google Antigravity agent CLI" },
        { id: "codex",     name: "Codex",                category: "AI & Development", brand: "ai",       icon: "terminal",
          check: "command -v codex", launch: "kitty -e codex",
          dataDir: ".codex", desc: "OpenAI Codex coding agent" },
        { id: "gemini",    name: "Gemini CLI",           category: "AI & Development", brand: "ai",       icon: "auto_awesome",
          check: "command -v gemini", launch: "kitty -e gemini",
          dataDir: ".gemini", desc: "Google Gemini command-line agent" },
        { id: "pi",        name: "Pi",                   category: "AI & Development", brand: "ai",       icon: "smart_toy",
          check: "command -v pi", launch: "kitty -e pi",
          dataDir: ".pi", desc: "Pi coding agent" },
        { id: "herdr",     name: "Herdr",                category: "AI & Development", brand: "herdr",    icon: "grid_view",
          check: "command -v herdr", launch: "kitty --app-id herdr -e herdr",
          dataDir: ".config/herdr", desc: "Agent-native terminal workspace runtime" },
        { id: "llm",       name: "LLM Usage Tracker",    category: "AI & Development", brand: "llm",      icon: "monitoring",
          builtin: true, launch: "kitty -e mujo llm show", desc: "Real-time token metrics in the bar" },
        { id: "vscode",    name: "Visual Studio Code",   category: "AI & Development", brand: "vscode",   icon: "terminal",
          check: "command -v code || flatpak info com.visualstudio.code",
          launch: "command -v code >/dev/null 2>&1 && code || flatpak run com.visualstudio.code",
          dataDir: ".var/app/com.visualstudio.code", desc: "Code editor and workspace" },
        { id: "zed",       name: "Zed Editor",           category: "AI & Development", brand: "zed",      icon: "code",
          check: "command -v zed || flatpak info dev.zed.Zed",
          launch: "command -v zed >/dev/null 2>&1 && zed || flatpak run dev.zed.Zed",
          dataDir: ".var/app/dev.zed.Zed", desc: "High-performance code editor" },

        { id: "obsidian",  name: "Obsidian",             category: "Productivity", brand: "obsidian", icon: "book",
          check: "command -v obsidian || flatpak info md.obsidian.Obsidian",
          launch: "command -v obsidian >/dev/null 2>&1 && obsidian || flatpak run md.obsidian.Obsidian",
          dataDir: ".var/app/md.obsidian.Obsidian", desc: "Markdown knowledge base and notes" },
        { id: "superprod", name: "Super Productivity",   category: "Productivity", brand: "superprod",icon: "checklist",
          check: "flatpak info com.super_productivity.SuperProductivity",
          launch: "flatpak run com.super_productivity.SuperProductivity",
          dataDir: ".var/app/com.super_productivity.SuperProductivity", desc: "Task, time, and project tracking" },

        { id: "zen",       name: "Zen Browser",          category: "Web Browsers", brand: "zen",      icon: "public",
          check: "flatpak info app.zen_browser.zen",
          launch: "flatpak run app.zen_browser.zen",
          dataDir: ".var/app/app.zen_browser.zen", desc: "Privacy-focused Firefox fork" },
        { id: "brave",     name: "Brave Browser",        category: "Web Browsers", brand: "brave",    icon: "shield",
          check: "flatpak info com.brave.Browser",
          launch: "flatpak run com.brave.Browser",
          dataDir: ".var/app/com.brave.Browser", desc: "Chromium browser with ad-blocking" },

        { id: "feishin",   name: "Feishin",              category: "Media & Audio", brand: "feishin",  icon: "library_music",
          check: "flatpak info org.jeffvli.feishin",
          launch: "flatpak run org.jeffvli.feishin",
          dataDir: ".var/app/org.jeffvli.feishin", desc: "Subsonic/Jellyfin music streaming client" },
        { id: "mpris",     name: "Now Playing (MPRIS)",  category: "Media & Audio", brand: "mpris",    icon: "play_circle",
          builtin: true, launch: "", desc: "Media controls in the bar and island" },

        { id: "steam",     name: "Steam",                category: "Gaming", brand: "steam",    icon: "sports_esports",
          check: "flatpak info com.valvesoftware.Steam",
          launch: "flatpak run com.valvesoftware.Steam",
          dataDir: ".var/app/com.valvesoftware.Steam", desc: "Steam gaming client and runtime" },
        { id: "bottles",   name: "Bottles",              category: "Gaming", brand: "desktop",  icon: "sports_esports",
          check: "flatpak info com.usebottles.bottles",
          launch: "flatpak run com.usebottles.bottles",
          dataDir: ".var/app/com.usebottles.bottles", desc: "Wine environment manager for software & games" }
    ]
    readonly property var categories: ["Communication", "AI & Development", "Productivity", "Web Browsers", "Media & Audio", "Gaming"]

    // ── Live state properties ────────────────────────────────────────────────
    property var detected: ({})
    property var running: ({})
    property var enabledMap: ({})
    property var flatpaksList: []
    property string searchQuery: ""

    function entriesFor(cat) { return registry.filter(function(e) { return e.category === cat }) }
    function isInstalled(e) { return e.builtin === true || root.detected[e.id] === true }
    function isRunning(e) { return root.running[e.id] === true }
    function isEnabled(e) { return root.enabledMap[e.id] !== false }

    // Through Launch.run, not a bare execDetached: these get their own transient
    // systemd scope, so a terminal opened here survives a qs-bar restart.
    function launch(e) {
        if (e.launch && e.launch !== "")
            Launch.run(["sh", "-lc", e.launch], e.name, e.icon)
    }

    function openDataFolder(relPath) {
        if (relPath && relPath !== "")
            Quickshell.execDetached(["sh", "-c", 'xdg-open "$HOME/' + relPath + '" || true'])
    }

    function setEnabled(e, on) {
        var m = root.enabledMap; m[e.id] = on; root.enabledMap = m
        Quickshell.execDetached(["mujo", "integrations", "set", e.id, on ? "on" : "off"])
    }

    // ── Data Fetching Processes ──────────────────────────────────────────────
    Process {
        id: detectProc
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {}
                var lines = this.text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t")
                    if (p.length >= 2) m[p[0]] = (p[1].trim() === "1")
                }
                root.detected = m
            }
        }
    }
    function refreshDetection() {
        var lines = []
        for (var i = 0; i < registry.length; i++) {
            var e = registry[i]
            if (e.builtin === true) continue
            lines.push('printf "%s\\t" ' + e.id + '; { ' + e.check + '; } >/dev/null 2>&1 && echo 1 || echo 0')
        }
        detectProc.command = ["sh", "-c", lines.join("\n")]
        detectProc.running = true
    }

    Process {
        id: runningProc
        command: ["mujo", "apps", "running"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.running = JSON.parse(this.text) } catch (e) { root.running = {} }
            }
        }
    }

    Process {
        id: enabledProc
        command: ["mujo", "integrations", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.enabledMap = JSON.parse(this.text) } catch (e) { root.enabledMap = {} }
            }
        }
    }

    Process {
        id: flatpaksProc
        command: ["mujo", "apps", "flatpaks"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.flatpaksList = JSON.parse(this.text) } catch (e) { root.flatpaksList = [] }
            }
        }
    }

    function refreshAll() {
        refreshDetection()
        runningProc.running = true
        enabledProc.running = true
        flatpaksProc.running = true
    }

    Component.onCompleted: refreshAll()

    MujoFlickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + 48

        ColumnLayout {
            id: mainCol
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 16

            // ── Hero Banner ───────────────────────────────────────────────────
            MujoHero {
                brand: "applications"
                title: "Applications & Integrations"
                subtitle: "Manage integrated companion services, Flatpak sandboxes, and launcher pinned favorites."
                badgeText: root.flatpaksList.length > 0 ? (root.flatpaksList.length + " FLATPAKS") : "INTEGRATED"
                badgeColor: Theme.accent

                IconButton {
                    iconName: "refresh"
                    onClicked: root.refreshAll()
                }
            }

            // ── Segmented Tab Selector ───────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    Repeater {
                        model: root.tabs
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: root.activeTab === modelData.id
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSm
                            color: active ? Theme.surfaceActive : (tab_hh.hovered ? Theme.surfaceHover : "transparent")
                            border.color: active ? Theme.borderStrong : "transparent"
                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                MaterialIcon {
                                    iconName: modelData.icon
                                    pixelSize: 16
                                    color: active ? Theme.accent : Theme.textSecondary
                                }
                                Text {
                                    text: modelData.label
                                    color: active ? Theme.text : Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: active
                                }
                            }
                            HoverHandler { id: tab_hh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.activeTab = modelData.id }
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // TAB 1: INTEGRATIONS & SERVICES
            // ═════════════════════════════════════════════════════════════════
            ColumnLayout {
                visible: root.activeTab === "integrations"
                Layout.fillWidth: true
                spacing: 16

                Repeater {
                    model: root.categories
                    delegate: MujoCard {
                        required property var modelData
                        readonly property var entries: root.entriesFor(modelData)
                        visible: entries.length > 0
                        title: modelData
                        iconName: "extension"

                        Repeater {
                            model: parent.entries
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool installed: root.isInstalled(modelData)
                                readonly property bool running: root.isRunning(modelData)
                                Layout.fillWidth: true
                                implicitHeight: 60
                                radius: Theme.radiusMd
                                color: int_hh.hovered ? Theme.surfaceHover : "transparent"
                                border.color: int_hh.hovered ? Theme.borderStrong : "transparent"
                                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                HoverHandler { id: int_hh }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 12

                                    BrandIcon {
                                        brand: modelData.brand || "desktop"
                                        size: 34
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Layout.alignment: Qt.AlignVCenter

                                        RowLayout {
                                            spacing: 8

                                            Text {
                                                text: modelData.name
                                                color: Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeBody
                                                font.bold: true
                                            }

                                            // Status pill
                                            Rectangle {
                                                implicitWidth: statText.implicitWidth + 10
                                                implicitHeight: 16
                                                radius: Theme.radiusSm
                                                color: running ? Theme.accentDim : "transparent"
                                                border.color: running ? Theme.accent : (modelData.builtin ? Theme.accent : (installed ? Theme.success : Theme.border))

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4
                                                    Rectangle {
                                                        visible: running
                                                        width: 5; height: 5; radius: 2.5; color: Theme.success
                                                    }
                                                    Text {
                                                        id: statText
                                                        text: running ? "Running" : (modelData.builtin ? "Built-in" : (installed ? "Installed" : "Not installed"))
                                                        color: running ? Theme.success : (modelData.builtin ? Theme.accent : (installed ? Theme.success : Theme.textDim))
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: Theme.fontSizeLabel - 1
                                                        font.bold: running
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: modelData.desc
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Open Data Folder button
                                    Rectangle {
                                        visible: modelData.dataDir !== undefined && installed
                                        implicitWidth: 30; implicitHeight: 30
                                        radius: Theme.radiusSm
                                        color: data_hh.hovered ? Theme.surfaceActive : "transparent"
                                        border.color: Theme.border
                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            iconName: "folder_open"
                                            pixelSize: 15
                                            color: Theme.textSecondary
                                        }
                                        HoverHandler { id: data_hh; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: root.openDataFolder(modelData.dataDir) }
                                    }

                                    // Launch action
                                    DialogButton {
                                        visible: modelData.launch !== ""
                                        text: "Launch"
                                        enabled: installed
                                        opacity: installed ? 1 : 0.4
                                        onClicked: root.launch(modelData)
                                    }

                                    // Enable toggle
                                    ToggleSwitch {
                                        checked: root.isEnabled(modelData)
                                        onToggled: function(c) { root.setEnabled(modelData, c) }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // TAB 2: INSTALLED APPLICATIONS & FLATPAKS
            // ═════════════════════════════════════════════════════════════════
            ColumnLayout {
                visible: root.activeTab === "flatpaks"
                Layout.fillWidth: true
                spacing: 14

                // Flatpak Summary Card
                MujoCard {
                    title: "Flatpak Environment"
                    iconName: "inventory_2"
                    badgeText: root.flatpaksList.length + " APPS"
                    badgeColor: Theme.accent

                    MujoSettingRow {
                        iconName: "security"
                        title: "Application Permissions & Sandbox"
                        description: "Fine-tune filesystem, network socket, and device permissions with Flatseal."

                        DialogButton {
                            text: "Open Flatseal"
                            onClicked: Quickshell.execDetached(["sh", "-c", "flatpak run com.github.tchx84.Flatseal || true"])
                        }
                    }
                }

                // Filter search bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.radiusMd
                    color: Theme.surface
                    border.color: Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        MaterialIcon { iconName: "search"; pixelSize: 17; color: Theme.textDim }
                        TextInput {
                            id: flatSearch
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            onTextChanged: root.searchQuery = text.trim().toLowerCase()
                            Text {
                                visible: flatSearch.text === ""
                                text: "Filter installed Flatpak packages…"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                            }
                        }
                    }
                }

                // Flatpak List Card
                MujoCard {
                    title: "Installed Flatpaks"
                    iconName: "apps"

                    Repeater {
                        model: root.flatpaksList.filter(function(f) {
                            if (root.searchQuery === "") return true
                            return (f.name && f.name.toLowerCase().indexOf(root.searchQuery) >= 0)
                                || (f.id && f.id.toLowerCase().indexOf(root.searchQuery) >= 0)
                        })
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 52
                            radius: Theme.radiusMd
                            color: fp_hh.hovered ? Theme.surfaceHover : "transparent"
                            border.color: fp_hh.hovered ? Theme.borderStrong : "transparent"

                            HoverHandler { id: fp_hh }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 12

                                Rectangle {
                                    width: 32; height: 32; radius: Theme.radiusSm
                                    color: Theme.surfaceActive
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        iconName: "inventory_2"
                                        pixelSize: 17
                                        color: Theme.accent
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: modelData.name
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeBody
                                            font.bold: true
                                        }
                                        Rectangle {
                                            visible: modelData.version !== ""
                                            implicitWidth: verText.implicitWidth + 8; implicitHeight: 15
                                            radius: Theme.radiusSm
                                            color: Theme.bg
                                            border.color: Theme.border
                                            Text {
                                                id: verText
                                                anchors.centerIn: parent
                                                text: modelData.version
                                                color: Theme.textDim
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontSizeLabel - 1
                                            }
                                        }
                                    }
                                    Text {
                                        text: modelData.id + (modelData.size ? " · " + modelData.size : "")
                                        color: Theme.textSecondary
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }

                                Rectangle {
                                    implicitWidth: 30; implicitHeight: 30
                                    radius: Theme.radiusSm
                                    color: fp_data_hh.hovered ? Theme.surfaceActive : "transparent"
                                    border.color: Theme.border
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        iconName: "folder_open"
                                        pixelSize: 15
                                        color: Theme.textSecondary
                                    }
                                    HoverHandler { id: fp_data_hh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.openDataFolder(".var/app/" + modelData.id) }
                                }

                                DialogButton {
                                    text: "Launch"
                                    onClicked: Quickshell.execDetached(["flatpak", "run", modelData.id])
                                }
                            }
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // TAB 3: LAUNCHER & WORKFLOW PREFERENCES
            // ═════════════════════════════════════════════════════════════════
            ColumnLayout {
                id: appsSec
                visible: root.activeTab === "launcher"
                Layout.fillWidth: true
                spacing: 14

                readonly property var favorites: SettingsBus.get("apps.favorites", [])
                readonly property var recents: SettingsBus.get("apps.recent", [])

                function nameFor(id) {
                    var a = (DesktopEntries.applications ? DesktopEntries.applications.values : []) || []
                    for (var i = 0; i < a.length; i++) if (a[i] && a[i].id === id) return a[i].name
                    return id
                }

                MujoCard {
                    title: "Launcher Actions"
                    iconName: "bolt"

                    MujoSettingRow {
                        iconName: "power_settings_new"
                        title: "Power Actions in Command Palette"
                        description: "Show Log out, Reboot, Shut down, and Suspend in the “/” command palette."

                        ToggleSwitch {
                            checked: SettingsBus.get("launcher.enableDangerousActions", false)
                            onToggled: function (c) { SettingsBus.set("launcher.enableDangerousActions", c) }
                        }
                    }
                }

                // Favourites Card
                MujoCard {
                    title: "Favourite Apps (Pinned to Launcher)"
                    iconName: "star"
                    badgeText: appsSec.favorites.length + " PINNED"

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: appsSec.favorites.length > 0

                        Repeater {
                            model: appsSec.favorites
                            delegate: Rectangle {
                                id: favChip
                                required property var modelData
                                implicitWidth: fl.implicitWidth + 20; implicitHeight: 30
                                radius: Theme.radiusMd
                                color: Theme.surface
                                border.color: Theme.borderStrong
                                RowLayout {
                                    id: fl; anchors.centerIn: parent; spacing: 6
                                    MaterialIcon { iconName: "star"; pixelSize: 14; color: Theme.warning }
                                    Text {
                                        text: appsSec.nameFor(favChip.modelData)
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                    MaterialIcon {
                                        iconName: "close"
                                        pixelSize: 14
                                        color: fh.hovered ? Theme.text : Theme.textDim
                                        HoverHandler { id: fh; cursorShape: Qt.PointingHandCursor }
                                        TapHandler {
                                            onTapped: SettingsBus.set("apps.favorites", appsSec.favorites.filter(function (x) { return x !== favChip.modelData }))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: appsSec.favorites.length === 0
                        text: "Star apps in the launcher's grid view to pin them here."
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                // Recents Card
                MujoCard {
                    title: "Recent Apps History"
                    iconName: "history"
                    badgeText: appsSec.recents.length + " RECENT"

                    actions: [
                        DialogButton {
                            visible: appsSec.recents.length > 0
                            text: "Clear History"
                            onClicked: SettingsBus.set("apps.recent", [])
                        }
                    ]

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: appsSec.recents.length > 0

                        Repeater {
                            model: appsSec.recents
                            delegate: Rectangle {
                                id: recChip
                                required property var modelData
                                implicitWidth: rl.implicitWidth + 18; implicitHeight: 28
                                radius: Theme.radiusMd
                                color: Theme.surface
                                border.color: Theme.border
                                Text {
                                    id: rl; anchors.centerIn: parent
                                    text: appsSec.nameFor(recChip.modelData)
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }
                    }

                    Text {
                        visible: appsSec.recents.length === 0
                        text: "No recently launched apps yet."
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Item { implicitHeight: 12 }
        }
    }
}
