import QtQuick
import Quickshell

// `/` command palette (WP-10). One flat registry of commands ranked by plain-JS
// fuzzy scoring over title+keywords. Keyboard-first: the launcher search field
// drives move()/activateSelected(). Dangerous session actions are gated behind
// launcher.enableDangerousActions and confirmed inline (activate twice). Ask AI
// and Web search are synthesized from the current query.
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

    // ── registry ─────────────────────────────────────────────────────────────
    readonly property var settingsSections: [
        { key: "appearance", label: "Appearance" }, { key: "wallpaper", label: "Wallpaper" },
        { key: "desktop", label: "Desktop" }, { key: "weather", label: "Weather" },
        { key: "ai", label: "AI" }, { key: "notifications", label: "Notifications" },
        { key: "display", label: "Displays" }, { key: "devices", label: "Devices" },
        { key: "network", label: "Network" }, { key: "keyring", label: "Keyring" },
        { key: "persistence", label: "Persistence" }, { key: "shortcuts", label: "Shortcuts" },
        { key: "system", label: "System" }, { key: "applications", label: "Applications" }
    ]

    function baseCommands() {
        var c = []
        // toggles
        c.push({ id: "dnd", title: (Notifications.dnd ? "Turn off Do Not Disturb" : "Turn on Do Not Disturb"), icon: "do_not_disturb_on", keywords: "dnd silence notifications", run: function () { Notifications.toggleDnd() } })
        c.push({ id: "widgetlock", title: "Toggle widget lock", icon: "lock", keywords: "widgets desktop lock unlock", run: function () { Quickshell.execDetached(["mujo", "widgets", "lock", "toggle"]) } })
        c.push({ id: "cava", title: (pal.bget("cava.enabled", false) ? "Disable audio visualizer" : "Enable audio visualizer"), icon: "graphic_eq", keywords: "cava visualizer audio spectrum", run: function () { SettingsBus.set("cava.enabled", !pal.bget("cava.enabled", false)) } })
        c.push({ id: "island", title: (pal.bget("island.enabled", true) ? "Hide island" : "Show island"), icon: "border_horizontal", keywords: "island notch pill media", run: function () { SettingsBus.set("island.enabled", !pal.bget("island.enabled", true)) } })

        // wallpaper
        c.push({ id: "wp-random", title: "Random wallpaper", icon: "shuffle", keywords: "wallpaper background random", run: function () { Quickshell.execDetached(["mujo", "wallpaper", "random"]) } })
        c.push({ id: "wp-change", title: "Change wallpaper…", icon: "wallpaper", keywords: "wallpaper background set library", run: function () { Quickshell.execDetached(["mujo", "settings", "wallpaper"]) } })

        // system / shell
        c.push({ id: "rebuild", title: "Rebuild system…", icon: "terminal", keywords: "nixos rebuild switch system", run: function () { Quickshell.execDetached(["mujo", "settings", "system"]) } })
        c.push({ id: "reload", title: "Reload shell", icon: "refresh", keywords: "reload restart quickshell", run: function () { Quickshell.reload(false) } })
        c.push({ id: "clip", title: "Clipboard history", icon: "content_paste", keywords: "clipboard paste history cliphist", close: false, run: function () { pal.requestClip() } })

        var backupOn = pal.bget("backup.enabled", false)
        c.push({ id: "backup", title: "Back up now", icon: "backup", keywords: "backup snapshot github", disabled: !backupOn, disabledReason: "Set up backup first", run: function () { Quickshell.execDetached(["mujo", "backup", "run"]) } })

        // settings sections
        for (var i = 0; i < pal.settingsSections.length; i++) {
            var s = pal.settingsSections[i]
            c.push({ id: "set-" + s.key, title: "Settings: " + s.label, icon: "tune", keywords: "settings " + s.label.toLowerCase(), run: (function (key) { return function () { Quickshell.execDetached(["mujo", "settings", key]) } })(s.key) })
        }

        // session actions (dangerous ones gated)
        var sa = Session.available()
        for (var j = 0; j < sa.length; j++) {
            var a = sa[j]
            c.push({ id: "sess-" + a.id, title: a.title, icon: a.icon, keywords: "power session " + a.title.toLowerCase(), danger: a.danger, run: (function (aid) { return function () { Session.run(aid) } })(a.id) })
        }
        return c
    }

    // dynamic query-driven entries (always shown when the query is non-empty)
    function dynamicCommands(q) {
        if (q === "") return []
        return [
            { id: "askai", title: "Ask AI: " + q, icon: "neurology", keywords: "", dyn: true, run: function () { AI.ask(q) } },
            { id: "web", title: "Web search: " + q, icon: "search", keywords: "", dyn: true, run: function () { Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(q)]) } }
        ]
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
            if (q === "") { e._s = 0; out.push(e); continue }
            var sc = pal.score(e, q)
            if (sc < 0) continue
            e._s = sc; out.push(e)
        }
        // dynamic entries first, then by score
        out.sort(function (a, b) {
            if (!!a.dyn !== !!b.dyn) return a.dyn ? -1 : 1
            return (b._s || 0) - (a._s || 0)
        })
        return out
    }

    // ── keyboard API (driven by the launcher search field) ─────────────────────
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
        if (e.close === false) return   // clipboard: stays open (switches mode)
        pal.requestClose()
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 3
        model: pal.entries
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool sel: index === pal.selectedIndex
            readonly property bool confirming: pal.confirmId === modelData.id
            width: list.width
            height: 44
            radius: Theme.radiusMd
            color: confirming ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                 : sel ? Theme.accentDim
                 : (rowHover.hovered ? Theme.surfaceHover : "transparent")
            border.color: confirming ? Theme.error : (sel ? Theme.accent : "transparent")
            opacity: modelData.disabled ? 0.45 : 1
            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            Row {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 12
                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: row.confirming ? "priority_high" : row.modelData.icon
                    pixelSize: 19
                    color: row.confirming ? Theme.error : (row.sel ? Theme.accent : Theme.textSecondary)
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.width - 90
                    Text {
                        width: parent.width
                        text: row.confirming ? "Confirm: " + row.modelData.title : row.modelData.title
                        color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: (row.modelData.disabled && row.modelData.disabledReason) || row.confirming
                        text: row.confirming ? "Press Enter again to run" : (row.modelData.disabledReason || "")
                        color: row.confirming ? Theme.error : Theme.textDim
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel
                        elide: Text.ElideRight
                    }
                }
            }
            HoverHandler { id: rowHover; onHoveredChanged: if (hovered) pal.selectedIndex = row.index }
            TapHandler { onTapped: pal.activate(row.index) }
        }
    }

    Column {
        anchors.centerIn: parent
        visible: pal.entries.length === 0
        spacing: 6
        MaterialIcon { anchors.horizontalCenter: parent.horizontalCenter; iconName: "bolt"; pixelSize: 34; color: Theme.textDim }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No commands match"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
    }
}
