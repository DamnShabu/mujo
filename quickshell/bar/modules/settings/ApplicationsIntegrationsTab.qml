import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// The integrated desktop applications mujō knows how to detect, launch and
// enable. The registry below is the whole of that knowledge, and detection runs
// straight off it, so both live here rather than in the panel.
ColumnLayout {
    id: section

    spacing: 16

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

    property var detected: ({})
    property var running: ({})
    property var enabledMap: ({})

    function entriesFor(cat) { return registry.filter(function(e) { return e.category === cat }) }
    function isInstalled(e) { return e.builtin === true || section.detected[e.id] === true }
    function isRunning(e) { return section.running[e.id] === true }
    function isEnabled(e) { return section.enabledMap[e.id] !== false }

    // Through Launch.run, not a bare execDetached: these get their own transient
    // systemd scope, so a terminal opened here survives a qs-bar restart.
    function launch(e) {
        if (e.launch && e.launch !== "")
            Launch.run(["sh", "-lc", e.launch], e.name, e.icon)
    }

    // xdg-open under `sh -c` so ~ expands in the guest's own shell; the path is
    // a fixed relative string from the registry, never user input.
    function openDataFolder(relPath) {
        if (relPath && relPath !== "")
            Quickshell.execDetached(["sh", "-c", 'xdg-open "$HOME/' + relPath + '" || true'])
    }

    function setEnabled(e, on) {
        var m = section.enabledMap; m[e.id] = on; section.enabledMap = m
        Quickshell.execDetached(["mujo", "integrations", "set", e.id, on ? "on" : "off"])
    }

    // One `sh -c` running every entry's own check, rather than a process each.
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
                section.detected = m
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
                try { section.running = JSON.parse(this.text) } catch (e) { section.running = {} }
            }
        }
    }

    Process {
        id: enabledProc
        command: ["mujo", "integrations", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { section.enabledMap = JSON.parse(this.text) } catch (e) { section.enabledMap = {} }
            }
        }
    }

    Component.onCompleted: {
        refreshDetection()
        runningProc.running = true
        enabledProc.running = true
    }


    Repeater {
        model: section.categories
        delegate: MujoCard {
            id: catCard
            required property var modelData
            readonly property var entries: section.entriesFor(modelData)
            visible: entries.length > 0
            title: modelData
            iconName: "extension"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: catCard.entries
                    delegate: Rectangle {
                        id: intRow
                        required property var modelData
                        readonly property bool installed: section.isInstalled(modelData)
                        readonly property bool running: section.isRunning(modelData)
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Theme.radiusMd
                        color: int_hh.hovered ? Theme.surfaceHover : "transparent"
                        border.color: int_hh.hovered ? Theme.borderStrong : "transparent"
                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                        HoverHandler { id: int_hh }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            BrandIcon {
                                brand: intRow.modelData.brand || "desktop"
                                size: 32
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                RowLayout {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Text {
                                        text: intRow.modelData.name
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
                                        color: intRow.running ? Theme.accentDim : "transparent"
                                        border.color: intRow.running ? Theme.accent : (intRow.modelData.builtin ? Theme.accent : (intRow.installed ? Theme.success : Theme.border))

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Rectangle {
                                                visible: intRow.running
                                                width: 5; height: 5; radius: 2.5; color: Theme.success
                                            }
                                            Text {
                                                id: statText
                                                text: intRow.running ? "Running" : (intRow.modelData.builtin ? "Built-in" : (intRow.installed ? "Installed" : "Not installed"))
                                                color: intRow.running ? Theme.success : (intRow.modelData.builtin ? Theme.accent : (intRow.installed ? Theme.success : Theme.textDim))
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeLabel - 1
                                                font.bold: intRow.running
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: intRow.modelData.desc
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Open Data Folder button
                            Rectangle {
                                visible: intRow.modelData.dataDir !== undefined && intRow.installed
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                Layout.alignment: Qt.AlignVCenter
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
                                TapHandler { onTapped: section.openDataFolder(intRow.modelData.dataDir) }
                            }

                            // Launch action
                            DialogButton {
                                visible: intRow.modelData.launch !== ""
                                Layout.alignment: Qt.AlignVCenter
                                text: "Launch"
                                enabled: intRow.installed
                                opacity: intRow.installed ? 1 : 0.4
                                onClicked: section.launch(intRow.modelData)
                            }

                            // Enable toggle
                            ToggleSwitch {
                                Layout.alignment: Qt.AlignVCenter
                                checked: section.isEnabled(intRow.modelData)
                                onToggled: function(c) { section.setEnabled(intRow.modelData, c) }
                            }
                        }
                    }
                }
            }
        }
    }
}
