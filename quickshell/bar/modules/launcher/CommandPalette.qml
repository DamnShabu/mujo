import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// CommandPalette: `/` quick actions & command palette for Mujo (無常).
// Provides instant fuzzy command access, categorized system tools, AI and Web search integration,
// and safety confirmations for dangerous session operations.
Item {
    id: pal

    property string screenName: ""
    property string query: ""          // text after the leading "/"
    property int selectedIndex: 0
    property string confirmId: ""       // dangerous action awaiting a 2nd activate
    signal requestClose
    signal requestClip                  // switch launcher into clipboard mode

    onQueryChanged: { pal.selectedIndex = 0; pal.confirmId = "" }

    function bget(k, d) { return SettingsBus.get(k, d) }
    function toast(msg) { Notifications.notify(msg, "", "check", "low", { transient: true }) }

    // Settings sections
    readonly property var settingsSections: [
        { key: "overview", label: "Overview" }, { key: "appearance", label: "Appearance" },
        { key: "animations", label: "Animations" }, { key: "wallpaper", label: "Wallpaper" },
        { key: "island", label: "Dynamic Island" }, { key: "general", label: "General" },
        { key: "desktop", label: "Desktop" }, { key: "weather", label: "Weather" },
        { key: "ai", label: "AI & Assistants" }, { key: "notifications", label: "Notifications" },
        { key: "display", label: "Displays" }, { key: "devices", label: "Devices" },
        { key: "network", label: "Network" }, { key: "keyring", label: "Keyring & Vault" },
        { key: "persistence", label: "Persistence" }, { key: "shortcuts", label: "Shortcuts" },
        { key: "system", label: "System & Updates" }, { key: "applications", label: "Applications" }
    ]

    function baseCommands() {
        var c = []
        // System Toggles & Tools
        c.push({ id: "dnd", cat: "Toggle", title: (Notifications.dnd ? "Turn off Do Not Disturb" : "Turn on Do Not Disturb"), icon: "do_not_disturb_on", keywords: "dnd silence notifications", run: function () { Notifications.toggleDnd() } })
        c.push({ id: "widgetlock", cat: "Toggle", title: "Toggle desktop widget lock", icon: "lock", keywords: "widgets desktop lock unlock", run: function () { Quickshell.execDetached(["mujo", "widgets", "lock", "toggle"]) } })
        c.push({ id: "cava", cat: "Toggle", title: "Toggle audio visualizer widget", icon: "graphic_eq", keywords: "cava visualizer audio spectrum widget", run: function () { Quickshell.execDetached(["mujo", "widgets", "toggle-type", "cava"]) } })
        c.push({ id: "island", cat: "Toggle", title: (pal.bget("island.enabled", true) ? "Hide Dynamic Island" : "Show Dynamic Island"), icon: "border_horizontal", keywords: "island notch pill media", run: function () { SettingsBus.set("island.enabled", !pal.bget("island.enabled", true)) } })
        if (pal.bget("shelf.enabled", true)) {
            c.push({ id: "shelf-toggle", cat: "Tool", title: "Toggle Drag Shelf", icon: "inventory_2", keywords: "shelf staging tray drop files", run: function () { Shelf.toggle() } })
            c.push({ id: "shelf-clear", cat: "Tool", title: "Clear Drag Shelf", icon: "delete_sweep", keywords: "shelf clear staging empty", danger: true, disabled: Shelf.count === 0, disabledReason: "Shelf is empty", run: function () { Shelf.clear() } })
        }

        // Wallpaper & Theme
        c.push({ id: "wp-random", cat: "Theme", title: "Switch to Random Wallpaper", icon: "shuffle", keywords: "wallpaper background random", run: function () { Quickshell.execDetached(["mujo", "wallpaper", "random"]) } })
        c.push({ id: "wp-change", cat: "Theme", title: "Change Wallpaper…", icon: "wallpaper", keywords: "wallpaper background set library", run: function () { Quickshell.execDetached(["mujo", "settings", "wallpaper"]) } })

        // System & Shell Management
        c.push({ id: "rebuild", cat: "System", title: "Rebuild NixOS System…", icon: "terminal", keywords: "nixos rebuild switch system update", run: function () { Quickshell.execDetached(["mujo", "settings", "system"]) } })
        c.push({ id: "reload", cat: "System", title: "Reload Mujo Shell", icon: "refresh", keywords: "reload restart quickshell", run: function () { Quickshell.reload(false) } })
        c.push({ id: "clip", cat: "Tool", title: "Open Clipboard History", icon: "content_paste", keywords: "clipboard paste history cliphist", close: false, run: function () { pal.requestClip() } })

        var backupOn = pal.bget("backup.enabled", false)
        c.push({ id: "backup", cat: "System", title: "Trigger System Backup", icon: "backup", keywords: "backup snapshot github", disabled: !backupOn, disabledReason: "Backup not configured", run: function () { Quickshell.execDetached(["mujo", "backup", "run"]) } })

        // Settings Sections
        for (var i = 0; i < pal.settingsSections.length; i++) {
            var s = pal.settingsSections[i]
            c.push({
                id: "set-" + s.key,
                cat: "Settings",
                title: "Settings: " + s.label,
                icon: "tune",
                keywords: "settings " + s.label.toLowerCase() + " " + s.key,
                run: (function (key) { return function () { Quickshell.execDetached(["mujo", "settings", key]) } })(s.key)
            })
        }

        // Session Actions
        var sa = Session.available()
        for (var j = 0; j < sa.length; j++) {
            var a = sa[j]
            c.push({
                id: "sess-" + a.id,
                cat: "Power",
                title: a.title,
                icon: a.icon,
                keywords: "power session " + a.title.toLowerCase() + " " + a.id,
                danger: a.danger,
                run: (function (aid) { return function () { Session.run(aid) } })(a.id)
            })
        }
        return c
    }

    // Dynamic query-driven commands (Ask AI, Open <agent>, Web Search)
    function dynamicCommands(q) {
        if (q === "") return []
        var c = [
            { id: "askai", cat: "AI", title: "Ask AI Assistant: " + q, icon: "neurology", keywords: "", dyn: true, run: function () { AI.ask(q) } }
        ]
        // Hand the same query to the active agent CLI in a terminal, for the
        // follow-up conversation the one-shot notification cannot carry.
        var agent = AI.activeAgent
        if (agent && agent.available)
            c.push({ id: "askai-term", cat: "AI", title: "Open " + agent.name + ": " + q, icon: "terminal", keywords: "", dyn: true, run: function () { AI.openInTerminal(q) } })
        c.push({ id: "web", cat: "Web", title: "Web Search: " + q, icon: "search", keywords: "", dyn: true, run: function () { Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(q)]) } })
        return c
    }

    function score(e, q) {
        var t = e.title.toLowerCase(), k = (e.keywords || "")
        if (t.indexOf(q) === 0) return 100
        if (t.indexOf(q) >= 0) return 80
        if (k.indexOf(q) >= 0) return 60
        var s = t + " " + k, j = 0
        for (var i = 0; i < s.length && j < q.length; i++) if (s[i] === q[j]) j++
        return j === q.length ? 30 : -1
    }

    readonly property var entries: {
        var q = pal.query.trim().toLowerCase()
        var out = pal.dynamicCommands(q)
        var base = pal.baseCommands()
        for (var i = 0; i < base.length; i++) {
            var e = base[i]
            e._i = i                      // stable tiebreak: equal scores keep declaration order
            if (q === "") { e._s = 0; out.push(e); continue }
            var sc = pal.score(e, q)
            if (sc < 0) continue
            e._s = sc
            out.push(e)
        }
        out.sort(function (a, b) {
            if (!!a.dyn !== !!b.dyn) return a.dyn ? -1 : 1
            return ((b._s || 0) - (a._s || 0)) || ((a._i || 0) - (b._i || 0))
        })
        return out
    }

    // Keyboard API
    function move(dx, dy) {
        var n = pal.entries.length
        if (n === 0) return
        pal.confirmId = ""
        pal.selectedIndex = Math.max(0, Math.min(n - 1, pal.selectedIndex + dy))
        list.positionViewAtIndex(pal.selectedIndex, ListView.Contain)
    }
    function activateSelected() { pal.activate(pal.selectedIndex) }
    function activate(i) {
        var e = pal.entries[i]
        if (!e || e.disabled) return
        if (e.danger && pal.confirmId !== e.id) { pal.confirmId = e.id; return }
        e.run()
        if (e.close === false) return
        pal.requestClose()
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 4
        model: pal.entries
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool sel: index === pal.selectedIndex
            readonly property bool confirming: pal.confirmId === modelData.id

            width: list.width
            implicitHeight: 46
            radius: Theme.radiusMd

            color: confirming
                   ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22)
                   : (sel ? (Anim.ambient ? Theme.withAlpha(Theme.accent, 0.16) : Theme.accentDim) : (rowHover.hovered ? Theme.surfaceHover : "transparent"))
            border.color: confirming
                          ? Theme.error
                          : (sel ? Theme.accent : (rowHover.hovered ? Theme.border : "transparent"))
            border.width: 1
            opacity: modelData.disabled ? 0.45 : 1.0

            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            scale: Anim.microInteractions ? (sel ? 1.008 : (rowHover.hovered ? 1.004 : 1.0)) : 1.0
            Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }

            // Active indicator bar
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 3.5
                height: row.sel || row.confirming ? 24 : 0
                radius: 2
                color: row.confirming ? Theme.error : Theme.accent

                Behavior on height { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                // Icon Tile
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.radiusSm
                    color: row.confirming
                           ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3)
                           : (row.sel ? Theme.withAlpha(Theme.accent, 0.22) : Theme.surface)
                    border.color: row.confirming ? Theme.error : (row.sel ? Theme.withAlpha(Theme.accent, 0.4) : Theme.border)

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: row.confirming ? "priority_high" : row.modelData.icon
                        pixelSize: 17
                        color: row.confirming ? Theme.error : (row.sel ? Theme.accent : Theme.textSecondary)
                    }
                }

                // Title + Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: row.confirming ? "Confirm: " + row.modelData.title : row.modelData.title
                            color: row.confirming ? Theme.error : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: row.sel || row.confirming
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Category Tag
                        Rectangle {
                            visible: row.modelData.cat !== undefined && !row.confirming
                            implicitWidth: catT.implicitWidth + 10
                            implicitHeight: 18
                            radius: Theme.radiusSm
                            color: row.sel ? Theme.withAlpha(Theme.accent, 0.22) : Theme.surfaceActive
                            border.color: row.sel ? Theme.withAlpha(Theme.accent, 0.4) : Theme.borderStrong

                            Text {
                                id: catT
                                anchors.centerIn: parent
                                text: row.modelData.cat || ""
                                color: row.sel ? Theme.accent : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        visible: (row.modelData.disabled && row.modelData.disabledReason) || row.confirming
                        text: row.confirming ? "Press Enter again to execute dangerous action" : (row.modelData.disabledReason || "")
                        color: row.confirming ? Theme.error : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Enter Keycap (shown when selected)
                Rectangle {
                    visible: row.sel
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 20
                    radius: Theme.radiusSm
                    color: row.confirming ? Theme.error : Theme.withAlpha(Theme.accent, 0.22)
                    border.color: row.confirming ? Theme.error : Theme.withAlpha(Theme.accent, 0.5)

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "keyboard_return"
                        pixelSize: 12
                        color: row.confirming ? "#ffffff" : Theme.accent
                    }
                }
            }

            HoverHandler { id: rowHover; onHoveredChanged: if (hovered) pal.selectedIndex = row.index }
            TapHandler { onTapped: pal.activate(row.index) }
        }
    }

    LauncherEmptyState {
        anchors.centerIn: parent
        visible: pal.entries.length === 0
        mode: "no-results"
        query: pal.query
        subject: "commands"
        subjectHint: "Type a command name, or try dnd, wallpaper, rebuild"
    }
}
