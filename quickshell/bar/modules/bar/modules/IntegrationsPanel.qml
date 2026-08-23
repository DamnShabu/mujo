import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Application & service integrations. Registry-driven: each entry is a plain
// object below — adding an integration means adding one row to `registry`, no
// other changes. Each row is detected (installed?), can be enabled/disabled
// (persisted via `mujo integrations`), and launched. AI/media/comms hooks live
// here; the LLM tracker and now-playing are built-in.
Item {
    id: root

    // ── Registry ─────────────────────────────────────────────────────────────
    // id · name · category · icon · check(sh test) · launch(sh cmd) · desc.
    readonly property var registry: [
        { id: "vesktop",  name: "Discord",           category: "Communication", icon: "chat",
          check: "command -v vesktop || flatpak info dev.vencord.Vesktop",
          launch: "command -v vesktop >/dev/null 2>&1 && vesktop || flatpak run dev.vencord.Vesktop",
          desc: "Vesktop client" },
        { id: "telegram", name: "Telegram",          category: "Communication", icon: "send",
          check: "command -v telegram-desktop || command -v Telegram",
          launch: "telegram-desktop || Telegram", desc: "Messaging" },
        { id: "claude",   name: "Claude Code",        category: "AI", icon: "smart_toy",
          check: "command -v claude", launch: "kitty -e claude", desc: "Terminal AI coding agent" },
        { id: "opencode", name: "OpenCode",           category: "AI", icon: "code",
          check: "command -v opencode", launch: "kitty -e opencode", desc: "AI coding agent" },
        { id: "llm",      name: "LLM Usage Tracker",  category: "AI", icon: "monitoring",
          builtin: true, launch: "kitty -e mujo llm show", desc: "Token usage in the bar" },
        { id: "feishin",  name: "Feishin",            category: "Media", icon: "library_music",
          check: "flatpak info org.jeffvli.feishin",
          launch: "flatpak run org.jeffvli.feishin", desc: "Music streaming" },
        { id: "mpris",    name: "Now Playing",        category: "Media", icon: "play_circle",
          builtin: true, launch: "", desc: "Media controls in the bar" },
        { id: "superprod", name: "Super Productivity", category: "Productivity", icon: "checklist",
          check: "flatpak info com.super_productivity.SuperProductivity",
          launch: "flatpak run com.super_productivity.SuperProductivity", desc: "Tasks & time" },
        { id: "obsidian", name: "Obsidian",           category: "Productivity", icon: "book",
          check: "command -v obsidian || flatpak info md.obsidian.Obsidian",
          launch: "obsidian || flatpak run md.obsidian.Obsidian", desc: "Notes" },
        { id: "zen",      name: "Zen Browser",        category: "Browser", icon: "public",
          check: "flatpak info app.zen_browser.zen",
          launch: "flatpak run app.zen_browser.zen", desc: "Web browser" }
    ]
    readonly property var categories: ["Communication", "AI", "Media", "Productivity", "Browser"]

    property var detected: ({})
    property var enabled: ({})

    function entriesFor(cat) { return registry.filter(function(e) { return e.category === cat }) }
    function isInstalled(e) { return e.builtin === true || root.detected[e.id] === true }
    function isEnabled(e) { return root.enabled[e.id] !== false }   // default on
    function launch(e) { if (e.launch && e.launch !== "") Quickshell.execDetached(["sh", "-lc", e.launch]) }
    function setEnabled(e, on) {
        var m = root.enabled; m[e.id] = on; root.enabled = m
        Quickshell.execDetached(["mujo", "integrations", "set", e.id, on ? "on" : "off"])
    }

    // ── Detection (one shell pass over the registry) ─────────────────────────
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
    function detect() {
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
        id: enabledProc
        command: ["mujo", "integrations", "get"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.enabled = JSON.parse(this.text) } catch (e) { root.enabled = {} } }
        }
    }

    Component.onCompleted: { detect(); enabledProc.running = true }

    Flickable {
        anchors.fill: parent
        anchors.margins: 26
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 20

            ColumnLayout {
                spacing: 3
                Text {
                    text: "Integrations"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle + 7
                    font.bold: true
                }
                Text {
                    text: "Apps and services the shell hooks into. Toggle to enable, or launch directly."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            Repeater {
                model: root.categories
                delegate: ColumnLayout {
                    required property var modelData
                    readonly property var entries: root.entriesFor(modelData)
                    visible: entries.length > 0
                    Layout.fillWidth: true
                    spacing: 10

                    SectionLabel { text: parent.modelData }

                    Repeater {
                        model: parent.entries
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool installed: root.isInstalled(modelData)
                            Layout.fillWidth: true
                            implicitHeight: 60
                            radius: Theme.radiusMd
                            color: Theme.surface
                            border.color: Theme.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Rectangle {
                                    width: 40; height: 40; radius: Theme.radiusSm
                                    color: installed ? Theme.accentDim : Theme.surfaceActive
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        iconName: modelData.icon
                                        pixelSize: 21
                                        color: installed ? Theme.accent : Theme.textDim
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
                                            implicitWidth: stat.implicitWidth + 12; implicitHeight: 17
                                            radius: Theme.radiusSm
                                            color: "transparent"
                                            border.color: modelData.builtin ? Theme.accent : (installed ? Theme.success : Theme.border)
                                            Text {
                                                id: stat
                                                anchors.centerIn: parent
                                                text: modelData.builtin ? "Built-in" : (installed ? "Installed" : "Not found")
                                                color: modelData.builtin ? Theme.accent : (installed ? Theme.success : Theme.textDim)
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeLabel
                                            }
                                        }
                                    }
                                    Text {
                                        text: modelData.desc
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }

                                DialogButton {
                                    visible: modelData.launch !== ""
                                    text: "Launch"
                                    enabled: installed
                                    opacity: installed ? 1 : 0.4
                                    onClicked: root.launch(modelData)
                                }
                                ToggleSwitch {
                                    checked: root.isEnabled(modelData)
                                    onToggled: function(c) { root.setEnabled(modelData, c) }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Add an integration by appending one entry to the registry in "
                    + "IntegrationsPanel.qml — no other changes needed."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            Item { implicitHeight: 4 }
        }
    }
}
