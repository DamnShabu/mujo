import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../theme"
import "../../components"
import "../../services"

// Overview (WP-19) — a glanceable dashboard of live status cards built on
// DashboardCard. Every card reads a real service; anything unavailable renders
// disabled with a reason (LAW 10 — no fake controls).
//
// Parking (performance law): the whole panel is instantiated by settings.qml's
// Loader, which destroys it on navigation away, and the Settings app Qt.quit()s
// on close — so timers/processes cease when the window closes or you leave the
// section. `active` additionally falls false while the search overlay hides the
// panel (item visibility propagates from the hidden panelHost), stopping every
// poll. Each card gates its Timer on `root.active` (and its own expanded state),
// so a collapsed/hidden card costs nothing.
Item {
    id: root

    // Parking signal — false while destroyed (navigate away) or hidden (search).
    property bool active: visible

    // ── Persisted card layout (overview.cards[] in settings.json) ─────────────
    // Each entry: {id, visible, expanded}. Unknown ids are dropped; missing
    // default ids are appended. There is no drag-reorder UI yet, so the stored
    // order equals the default order — the schema already supports reordering.
    readonly property var defOrder: ["clock", "health", "system", "weather", "battery", "recent", "notifications", "media", "toggles", "backup", "machines", "update", "ai"]
    readonly property var defExpanded: ({
        clock: true, health: true, weather: true, system: true, battery: true, recent: true,
        notifications: true, media: true, toggles: true,
        backup: false, machines: false, update: false, ai: false
    })

    function layoutCfg() {
        var stored = SettingsBus.get("overview.cards", [])
        var out = [], seen = ({})
        for (var i = 0; i < stored.length; i++) {
            var s = stored[i]
            if (s && root.defOrder.indexOf(s.id) >= 0 && !seen[s.id]) {
                out.push({ id: s.id, visible: s.visible !== false, expanded: s.expanded !== false })
                seen[s.id] = true
            }
        }
        for (var j = 0; j < root.defOrder.length; j++) {
            var id = root.defOrder[j]
            if (!seen[id]) out.push({ id: id, visible: true, expanded: root.defExpanded[id] })
        }
        return out
    }
    property var cfg: layoutCfg()
    Connections { target: SettingsBus; function onLoaded() { root.cfg = root.layoutCfg() } }
    function _persist() { SettingsBus.set("overview.cards", root.cfg) }

    function _find(id) { for (var i = 0; i < root.cfg.length; i++) if (root.cfg[i].id === id) return root.cfg[i]; return null }
    function isExpanded(id) { var e = _find(id); return e ? e.expanded : true }
    // No-op when nothing actually changed. cfg is bound to the persisted value,
    // so an unconditional write re-entered the `expanded` binding through
    // SettingsBus and Qt reported a binding loop.
    function setExpanded(id, v) {
        var cur = root._find(id)
        if (cur && cur.expanded === v) return
        var c = root.cfg.slice()
        for (var i = 0; i < c.length; i++) if (c[i].id === id) c[i] = { id: id, visible: c[i].visible, expanded: v }
        root.cfg = c; root._persist()
    }
    function setVisible(id, v) {
        var curv = root._find(id)
        if (curv && curv.visible === v) return
        var c = root.cfg.slice()
        for (var i = 0; i < c.length; i++) if (c[i].id === id) c[i] = { id: id, visible: v, expanded: c[i].expanded }
        root.cfg = c; root._persist()
    }

    readonly property var visibleIds: { var o = []; for (var i = 0; i < cfg.length; i++) if (cfg[i].visible) o.push(cfg[i].id); return o }
    readonly property var hiddenIds: { var o = []; for (var i = 0; i < cfg.length; i++) if (!cfg[i].visible) o.push(cfg[i].id); return o }

    // Layout guard: only the first two rows show; the rest hide behind "more".
    property bool showAll: false
    readonly property var shownIds: showAll ? visibleIds : visibleIds.slice(0, Math.max(1, grid.columns) * 2)

    function titleFor(id) {
        return ({ clock: "Clock", health: "Health & Care", weather: "Weather", system: "System", battery: "Battery",
                  recent: "Recent apps", notifications: "Notifications", media: "Media",
                  toggles: "Quick toggles", backup: "Backup", machines: "Machines",
                  update: "System updates", ai: "AI" })[id] || id
    }
    function compFor(id) {
        return id === "clock" ? clockCard : id === "health" ? healthCard
             : id === "weather" ? weatherCard : id === "system" ? systemCard
             : id === "battery" ? batteryCard : id === "recent" ? recentCard
             : id === "notifications" ? notifsCard : id === "media" ? mediaCard
             : id === "toggles" ? togglesCard : id === "backup" ? backupCard
             : id === "machines" ? machinesCard : id === "update" ? updateCard
             : id === "ai" ? aiCard : null
    }

    // Width of the System card's reading column. Fixed so every row's value is
    // right-aligned on the same edge and the sparklines all end together; sized
    // for the longest reading ("100% · 31.2/31.4G").
    readonly property int metricValueW: 116

    // ── Shared inline components (must be declared at file-root level) ────────
    component CountPill: Rectangle {
        property string label: ""
        property color tint: Theme.accent
        implicitWidth: pl.implicitWidth + 12; implicitHeight: 17
        radius: height / 2; color: Theme.withAlpha(tint, 0.16)
        Text { id: pl; anchors.centerIn: parent; text: parent.label; color: parent.tint; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel; font.bold: true }
    }
    component Muted: Text {
        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap; Layout.fillWidth: true
    }
    component Spark: Canvas {
        property var series: []
        property color stroke: Theme.accent
        property real maxVal: 100
        implicitHeight: 18
        onSeriesChanged: requestPaint()
        // A resize clears the backing store, so the line vanished whenever the
        // grid relaid out (e.g. on "Show more") until the next 2s poll.
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
            var n = series.length; if (n < 2) return
            var mx = maxVal; for (var k = 0; k < n; k++) if (series[k] > mx) mx = series[k]
            ctx.strokeStyle = stroke; ctx.lineWidth = 1.5; ctx.beginPath()
            for (var i = 0; i < n; i++) {
                var x = (i / (n - 1)) * width
                var y = height - (Math.max(0, series[i]) / mx) * height
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }
    component MetricRow: RowLayout {
        id: mrow
        property string label: ""
        property string value: ""
        property var series: []
        property color tint: Theme.accent
        property real maxVal: 100
        property bool available: true
        property string naReason: ""
        Layout.fillWidth: true; spacing: 10
        Text { text: mrow.label; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; Layout.preferredWidth: 42 }
        Spark { visible: mrow.available; series: mrow.series; stroke: mrow.tint; maxVal: mrow.maxVal; Layout.fillWidth: true; Layout.preferredHeight: 18 }
        Text { visible: !mrow.available; text: mrow.naReason; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel; Layout.fillWidth: true }
        Text { text: mrow.value; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; Layout.preferredWidth: root.metricValueW; Layout.minimumWidth: root.metricValueW; Layout.maximumWidth: root.metricValueW }
    }
    component ToggleRow: RowLayout {
        id: trow
        property string label: ""
        property string sub: ""
        property bool on: false
        signal toggled(bool v)
        Layout.fillWidth: true; spacing: 10
        ColumnLayout {
            spacing: 0
            Text { text: trow.label; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
            Text { visible: trow.sub !== ""; text: trow.sub; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel }
        }
        // Flexible spacer, not fillWidth on the label column: a nested layout
        // will not stretch here, which left every switch parked right after its
        // own label instead of aligned down the card's right edge.
        Item { Layout.fillWidth: true }
        ToggleSwitch {
            id: sw
            Layout.alignment: Qt.AlignVCenter
            checked: trow.on
            onToggled: function (v) { trow.toggled(v) }
            // Keep the switch slaved to real state (a self-click breaks the binding).
            Binding { target: sw; property: "checked"; value: trow.on }
        }
    }
    component StatusRow: RowLayout {
        id: srow
        property string label: ""
        property string status: ""   // not `state`: that shadows Item.state
        property bool ok: false
        Layout.fillWidth: true; spacing: 8
        Rectangle { width: 8; height: 8; radius: 4; color: srow.ok ? Theme.success : Theme.textDim; Layout.alignment: Qt.AlignVCenter }
        Text { text: srow.label; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; Layout.fillWidth: true }
        Text { text: srow.status; color: Theme.textSecondary; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel }
    }

    MujoFlickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48

        ColumnLayout {
            id: col
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 16

            // Header
            MujoHero {
                brand: "mujo"
                title: "Overview"
                subtitle: "A live glance at your desktop vitals, active media, and quick controls."
                badgeText: "LIVE TELEMETRY"
                badgeColor: Theme.accent
            }

            // GridLayout, not Grid: it sizes each row to the tallest card in
            // that row and `fillHeight` stretches the rest of the row to match,
            // so card bottoms line up. Grid leaves every card at its own
            // implicit height, which left ragged rows.
            GridLayout {
                id: grid
                Layout.fillWidth: true
                columns: Math.max(1, Math.floor(width / 330))
                columnSpacing: 14
                rowSpacing: 14

                Repeater {
                    model: root.shownIds
                    delegate: Loader {
                        id: cell
                        required property var modelData
                        // A card that hides itself (Battery on a desktop) drops
                        // out of the layout entirely rather than leaving a hole
                        // in the grid. `shown` is the card's declared intent —
                        // reading `visible` here would latch the cell off, since
                        // an item reports its parent's effective visibility.
                        visible: !item || item.shown
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: item ? item.implicitHeight : 0
                        sourceComponent: root.compFor(modelData)
                    }
                }
            }

            // "More" expander — reveals cards past the first two rows.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: root.visibleIds.length > Math.max(1, grid.columns) * 2
                implicitWidth: moreRow.implicitWidth + 24; implicitHeight: 30
                radius: Theme.radiusMd
                color: moreHh.hovered ? Theme.surfaceHover : Theme.surface
                border.color: Theme.border
                RowLayout {
                    id: moreRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIcon { iconName: root.showAll ? "expand_less" : "expand_more"; pixelSize: 16; color: Theme.textSecondary }
                    Text {
                        text: root.showAll ? "Show less" : ("Show " + (root.visibleIds.length - Math.max(1, grid.columns) * 2) + " more")
                        color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                    }
                }
                HoverHandler { id: moreHh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.showAll = !root.showAll }
            }

            // Hidden cards — restore chips.
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.hiddenIds.length > 0
                spacing: 7
                SectionLabel { text: "Hidden cards" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 7
                    Repeater {
                        model: root.hiddenIds
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: hl.implicitWidth + 26; implicitHeight: 26
                            radius: Theme.radiusMd; color: Theme.surface; border.color: Theme.border
                            RowLayout {
                                anchors.centerIn: parent; spacing: 6
                                MaterialIcon { iconName: "add"; pixelSize: 14; color: hch.hovered ? Theme.accent : Theme.textDim }
                                Text { id: hl; text: root.titleFor(modelData); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                            }
                            HoverHandler { id: hch; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.setVisible(modelData, true) }
                        }
                    }
                }
            }

            Item { implicitHeight: 4 }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Cards
    // ═══════════════════════════════════════════════════════════════════════════

    // 1 — Clock / date. No calendar-event source exists in the shell yet, so the
    // "next event" line is honestly rendered as an empty state.
    Component {
        id: clockCard
        DashboardCard {
            width: parent ? parent.width : implicitWidth
            title: "Clock"; icon: "schedule"
            expanded: root.isExpanded("clock"); onExpandedChanged: root.setExpanded("clock", expanded)
            onHideRequested: root.setVisible("clock", false)

            QtObject { id: clk; property date now: new Date() }
            Timer { interval: 1000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: clk.now = new Date() }

            Text { text: Qt.formatDateTime(clk.now, "HH:mm"); color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 40; font.bold: true }
            Text { text: Qt.formatDateTime(clk.now, "dddd, d MMMM yyyy"); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 4; spacing: 7
                MaterialIcon { iconName: "event_upcoming"; pixelSize: 15; color: Theme.textDim }
                Muted { text: "No calendar connected" }
            }
        }
    }

    // 2 — Weather (compact). Shares the Weather singleton; inherits error/stale.
    Component {
        id: weatherCard
        DashboardCard {
            width: parent ? parent.width : implicitWidth
            title: "Weather"; icon: "partly_cloudy_day"
            expanded: root.isExpanded("weather"); onExpandedChanged: root.setExpanded("weather", expanded)
            onHideRequested: root.setVisible("weather", false)

            badge: CountPill { visible: Weather.stale; label: "STALE"; tint: Theme.warning }

            RowLayout {
                Layout.fillWidth: true
                visible: Weather.data !== null
                spacing: 14
                MaterialIcon { iconName: Weather.data ? Weather.iconFor(Weather.data.code) : "cloud"; pixelSize: 40; color: Weather.stale ? Theme.textDim : Theme.text }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: Weather.data ? Math.round(Weather.data.temp) + Weather.unitSymbol() : "—"; color: Weather.stale ? Theme.textSecondary : Theme.text; font.family: Theme.fontMono; font.pixelSize: 26; font.bold: true }
                    Text { text: Weather.data ? Weather.descFor(Weather.data.code) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    Text { text: Weather.data && Weather.data.city ? Weather.data.city : ""; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel }
                }
            }
            Muted { visible: Weather.data === null; text: Weather.error !== "" ? ("Weather unavailable: " + Weather.error) : "Loading weather…" }
        }
    }

    // 3 — System. Polls `mujo sysmon` every 2s ONLY while active and expanded;
    // keeps a small per-metric sparkline history. temp degrades to a reason.
    Component {
        id: systemCard
        DashboardCard {
            id: sysc
            width: parent ? parent.width : implicitWidth
            title: "System"; icon: "monitor_heart"
            expanded: root.isExpanded("system"); onExpandedChanged: root.setExpanded("system", expanded)
            onHideRequested: root.setVisible("system", false)

            property var cpuH: []
            property var memH: []
            property var tempH: []
            property var netH: []
            property var d: null

            function push(arr, v, cap) { var a = arr.slice(); a.push(v); if (a.length > cap) a = a.slice(a.length - cap); return a }

            Process {
                id: sysProc
                command: ["mujo", "sysmon"]
                stdout: StdioCollector { onStreamFinished: {
                    try {
                        var j = JSON.parse(this.text); sysc.d = j
                        sysc.cpuH = sysc.push(sysc.cpuH, j.cpu, 40)
                        sysc.memH = sysc.push(sysc.memH, j.mem, 40)
                        if (typeof j.temp === "number") sysc.tempH = sysc.push(sysc.tempH, j.temp, 40)
                        sysc.netH = sysc.push(sysc.netH, (j.netRxKbps || 0) + (j.netTxKbps || 0), 40)
                    } catch (e) {}
                } }
            }
            Timer { interval: 2000; running: root.active && sysc.expanded; repeat: true; triggeredOnStart: true; onTriggered: if (!sysProc.running) sysProc.running = true }

            MetricRow { label: "CPU"; series: sysc.cpuH; tint: Theme.accent; value: sysc.d ? (sysc.d.cpu + "%") : "…" }
            MetricRow { label: "RAM"; series: sysc.memH; tint: "#22D3EE"; value: sysc.d ? (sysc.d.mem + "% · " + sysc.d.memUsedGb.toFixed(1) + "/" + sysc.d.memTotalGb.toFixed(1) + "G") : "…" }
            MetricRow {
                label: "Temp"; series: sysc.tempH; tint: Theme.warning; maxVal: 100
                available: sysc.d !== null && typeof sysc.d.temp === "number"
                naReason: "no sensor"
                value: (sysc.d && typeof sysc.d.temp === "number") ? (sysc.d.temp + "°C") : "—"
            }
            MetricRow {
                label: "Net"; series: sysc.netH; tint: "#F472B6"; maxVal: 64
                available: sysc.d !== null && typeof sysc.d.netRxKbps === "number"
                naReason: "n/a"
                value: (sysc.d && typeof sysc.d.netRxKbps === "number") ? (Math.round(sysc.d.netRxKbps) + "↓ " + Math.round(sysc.d.netTxKbps) + "↑ KB/s") : "…"
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                readonly property bool has: sysc.d !== null && typeof sysc.d.diskPct === "number"
                Text { text: "Disk"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; Layout.preferredWidth: 42 }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 8; radius: 4; color: Theme.surfaceActive
                    Rectangle { width: parent.width * (parent.parent.has ? sysc.d.diskPct / 100 : 0); height: parent.height; radius: parent.radius; color: (parent.parent.has && sysc.d.diskPct > 90) ? Theme.error : Theme.success }
                }
                Text { text: parent.has ? (sysc.d.diskPct + "% · " + sysc.d.diskUsedGb.toFixed(0) + "/" + sysc.d.diskTotalGb.toFixed(0) + "G") : "…"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; Layout.preferredWidth: root.metricValueW; Layout.minimumWidth: root.metricValueW; Layout.maximumWidth: root.metricValueW }
            }
        }
    }

    // 4 — Battery. Reads `mujo battery` (which normalizes /sys/class/power_supply
    // /BAT*) every 30s; the whole card hides on desktops with no battery.
    Component {
        id: batteryCard
        DashboardCard {
            id: batc
            width: parent ? parent.width : implicitWidth
            title: "Battery"; icon: "battery_full"
            shown: batc.present
            expanded: root.isExpanded("battery"); onExpandedChanged: root.setExpanded("battery", expanded)
            onHideRequested: root.setVisible("battery", false)

            property bool present: false
            property int level: 0
            property string status: ""

            Process {
                id: batProc; command: ["mujo", "battery"]
                stdout: StdioCollector { onStreamFinished: { try { var b = JSON.parse(this.text); batc.present = !!b.present; batc.level = b.level || 0; batc.status = b.status || "" } catch (e) {} } }
            }
            Timer { interval: 30000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: if (!batProc.running) batProc.running = true }

            RowLayout {
                Layout.fillWidth: true; spacing: 12
                MaterialIcon { iconName: batc.status === "Charging" ? "battery_charging_full" : "battery_full"; pixelSize: 30; color: batc.level <= 15 ? Theme.error : Theme.success }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: batc.level + "%"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 22; font.bold: true }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 8; radius: 4; color: Theme.surfaceActive
                        Rectangle { width: parent.width * batc.level / 100; height: parent.height; radius: parent.radius; color: batc.level <= 15 ? Theme.error : (batc.status === "Charging" ? Theme.warning : Theme.success) }
                    }
                    Text { text: batc.status; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }
            }
        }
    }

    // 5 — Recent apps. From apps.recent[]; click a chip to launch it.
    Component {
        id: recentCard
        DashboardCard {
            id: recc
            width: parent ? parent.width : implicitWidth
            title: "Recent apps"; icon: "apps"
            expanded: root.isExpanded("recent"); onExpandedChanged: root.setExpanded("recent", expanded)
            onHideRequested: root.setVisible("recent", false)

            readonly property var recents: SettingsBus.get("apps.recent", [])
            function entryFor(id) { var a = (DesktopEntries.applications ? DesktopEntries.applications.values : []) || []; for (var i = 0; i < a.length; i++) if (a[i] && a[i].id === id) return a[i]; return null }

            Flow {
                Layout.fillWidth: true; spacing: 7
                visible: recc.recents.length > 0
                Repeater {
                    model: recc.recents
                    delegate: Rectangle {
                        required property var modelData
                        readonly property var entry: recc.entryFor(modelData)
                        implicitWidth: rl.implicitWidth + 18; implicitHeight: 28
                        radius: Theme.radiusMd; color: rhh.hovered ? Theme.surfaceHover : Theme.surface; border.color: Theme.border
                        Text { id: rl; anchors.centerIn: parent; text: parent.entry ? parent.entry.name : modelData; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                        HoverHandler { id: rhh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (parent.entry) parent.entry.execute() }
                    }
                }
            }
            Muted { visible: recc.recents.length === 0; text: "No recent apps yet — launch something from the app launcher." }
        }
    }

    // 6 — Notifications digest. Reads the persisted history file directly (the
    // settings process must not spin up a second NotificationServer). Grouped by
    // app for today. Opening the history lives on the bar's bell, so it is shown
    // disabled with a reason here.
    Component {
        id: notifsCard
        DashboardCard {
            id: notc
            width: parent ? parent.width : implicitWidth
            title: "Notifications"; icon: "notifications"
            expanded: root.isExpanded("notifications"); onExpandedChanged: root.setExpanded("notifications", expanded)
            onHideRequested: root.setVisible("notifications", false)

            property var groups: []
            property int todayCount: 0
            function recompute(txt) {
                var start = new Date(); start.setHours(0, 0, 0, 0); var t0 = start.getTime()
                var g = [], byApp = ({}), n = 0
                try {
                    var d = JSON.parse(txt || "{}"); var h = (d && d.history) || []
                    for (var i = 0; i < h.length; i++) {
                        if (!h[i].time || h[i].time < t0) continue
                        n++
                        var k = h[i].appName || "Notification"
                        if (byApp[k] === undefined) { byApp[k] = g.length; g.push({ appName: k, count: 0 }) }
                        g[byApp[k]].count++
                    }
                } catch (e) {}
                notc.groups = g; notc.todayCount = n
            }
            FileView {
                path: (Quickshell.env("HOME") || "/tmp") + "/.local/state/qsshell/notifications.json"
                watchChanges: true
                onFileChanged: reload()
                onLoaded: notc.recompute(text())
                onLoadFailed: function (e) { notc.recompute("{}") }
            }

            badge: CountPill { visible: notc.todayCount > 0; label: String(notc.todayCount) }

            Muted { visible: notc.todayCount === 0; text: "No notifications today." }
            Repeater {
                model: notc.groups
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 8
                    Text { text: modelData.appName; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: modelData.count; color: Theme.textSecondary; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall }
                }
            }
            actions: DialogButton { text: "Open history"; enabled: false; opacity: 0.5 }
            Text { text: "History opens from the bar's bell menu."; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }
    }

    // 7 — Media mini controls (MPRIS).
    Component {
        id: mediaCard
        DashboardCard {
            id: medc
            width: parent ? parent.width : implicitWidth
            title: "Media"; icon: "music_note"
            expanded: root.isExpanded("media"); onExpandedChanged: root.setExpanded("media", expanded)
            onHideRequested: root.setVisible("media", false)

            readonly property var player: {
                var ps = Mpris.players ? Mpris.players.values : []
                if (!ps.length) return null
                for (var i = 0; i < ps.length; i++) if (ps[i] && ps[i].isPlaying) return ps[i]
                return ps[0]
            }

            RowLayout {
                Layout.fillWidth: true; visible: medc.player !== null; spacing: 12
                Rectangle {
                    Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: Theme.radiusMd; color: Theme.surfaceHover; clip: true
                    Image { anchors.fill: parent; source: medc.player && medc.player.trackArtUrl ? medc.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; sourceSize.width: 88; sourceSize.height: 88; smooth: true; visible: status === Image.Ready }
                    MaterialIcon { anchors.centerIn: parent; visible: !medc.player || !medc.player.trackArtUrl; iconName: "music_note"; pixelSize: 20; color: Theme.textDim }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { Layout.fillWidth: true; text: medc.player ? medc.player.trackTitle : ""; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: medc.player ? medc.player.trackArtist : ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
                }
                RowLayout {
                    spacing: 4
                    MaterialIcon {
                        iconName: "skip_previous"; pixelSize: 22; color: prevHh.hovered ? Theme.text : Theme.textSecondary
                        visible: medc.player && medc.player.canGoPrevious
                        HoverHandler { id: prevHh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (medc.player) medc.player.previous() }
                    }
                    MaterialIcon {
                        iconName: medc.player && medc.player.isPlaying ? "pause_circle" : "play_circle"; pixelSize: 30; color: Theme.text
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (medc.player) medc.player.togglePlaying() }
                    }
                    MaterialIcon {
                        iconName: "skip_next"; pixelSize: 22; color: nextHh.hovered ? Theme.text : Theme.textSecondary
                        visible: medc.player && medc.player.canGoNext
                        HoverHandler { id: nextHh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (medc.player) medc.player.next() }
                    }
                }
            }
            Muted { visible: medc.player === null; text: "Nothing playing." }
        }
    }

    // 8 — Quick toggles: DND, CAVA overlay, widget lock (all local state), plus a
    // Mullvad control that reflects live `mullvad status` (polled only while
    // expanded) and connects/disconnects via the mullvad CLI.
    Component {
        id: togglesCard
        DashboardCard {
            id: togc
            width: parent ? parent.width : implicitWidth
            title: "Quick toggles"; icon: "tune"
            expanded: root.isExpanded("toggles"); onExpandedChanged: root.setExpanded("toggles", expanded)
            onHideRequested: root.setVisible("toggles", false)

            // widget lock lives in widgets.json (managed by `mujo widgets`).
            property bool widgetsLocked: false
            property bool cavaPresent: false
            FileView {
                path: (Quickshell.env("HOME") || "/tmp") + "/.config/qsshell/widgets.json"
                watchChanges: true
                onFileChanged: reload()
                onLoaded: {
                    try {
                        var c = JSON.parse(text())
                        togc.widgetsLocked = !!c.locked
                        togc.cavaPresent = (c.widgets || []).some(function (w) { return w.type === "cava" })
                    } catch (e) {}
                }
                onLoadFailed: function (e) {}
            }

            // Mullvad live state.
            property string vpnState: "…"
            readonly property bool vpnConnected: vpnState === "Connected"
            readonly property bool vpnBusy: vpnState === "Connecting" || vpnState === "Disconnecting"
            readonly property bool vpnAvailable: togc.vpnState !== "…" && togc.vpnState !== "Not installed"
            Process {
                id: vpnProc; command: ["mullvad", "status"]
                stdout: StdioCollector { onStreamFinished: togc.vpnState = this.text.trim().split("\n")[0].trim() || "Disconnected" }
                // A missing binary produces no output, so without this the row
                // sits on "…" for ever and still offers a Connect button that
                // cannot work.
                onRunningChanged: if (!running && togc.vpnState === "…") togc.vpnState = "Not installed"
            }
            Timer { interval: 3000; running: root.active && togc.expanded; repeat: true; triggeredOnStart: true; onTriggered: if (!vpnProc.running) vpnProc.running = true }
            Timer { id: vpnRepoll; interval: 700; onTriggered: vpnProc.running = true }

            ToggleRow { label: "Do Not Disturb"; sub: "Silence notification toasts"; on: SettingsBus.get("notifications.dnd", false); onToggled: function (v) { SettingsBus.set("notifications.dnd", v) } }
            ToggleRow { label: "Audio visualizer"; sub: "Add or remove the desktop cava widget"; on: togc.cavaPresent; onToggled: function (v) { Quickshell.execDetached(["mujo", "widgets", "toggle-type", "cava"]) } }
            ToggleRow { label: "Widget lock"; sub: "Lock desktop widgets in place"; on: togc.widgetsLocked; onToggled: function (v) { Quickshell.execDetached(["mujo", "widgets", "lock", v ? "on" : "off"]) } }

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                ColumnLayout {
                    spacing: 0
                    Text { text: "Mullvad VPN"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                    Text { text: togc.vpnState; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel }
                }
                Item { Layout.fillWidth: true }
                // The status dot rides with the action rather than leading the
                // label: a leading dot pushed this row's text 19px right of the
                // toggle rows above it.
                Rectangle { Layout.alignment: Qt.AlignVCenter; width: 9; height: 9; radius: 4.5; color: togc.vpnConnected ? Theme.success : (togc.vpnBusy ? Theme.warning : Theme.textDim) }
                DialogButton { enabled: togc.vpnAvailable; text: togc.vpnConnected ? "Disconnect" : "Connect"; primary: !togc.vpnConnected; onClicked: { Quickshell.execDetached(["mullvad", togc.vpnConnected ? "disconnect" : "connect"]); vpnRepoll.restart() } }
            }
        }
    }

    // 9 — Backup status. Reads backup.json if present; absent ⇒ disabled card.
    Component {
        id: backupCard
        DashboardCard {
            id: bkc
            width: parent ? parent.width : implicitWidth
            title: "Backup"; icon: "backup"
            expanded: root.isExpanded("backup"); onExpandedChanged: root.setExpanded("backup", expanded)
            onHideRequested: root.setVisible("backup", false)

            property bool configured: false
            property var info: null
            FileView {
                path: (Quickshell.env("HOME") || "/tmp") + "/.local/state/qsshell/backup.json"
                watchChanges: true
                onFileChanged: reload()
                onLoaded: { try { bkc.info = JSON.parse(text()); bkc.configured = true } catch (e) { bkc.configured = false } }
                onLoadFailed: function (e) { bkc.configured = false }
            }

            disabled: !bkc.configured
            disabledReason: "Backup not configured."

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                MaterialIcon { iconName: (bkc.info && bkc.info.status === "ok") ? "cloud_done" : "cloud"; pixelSize: 24; color: (bkc.info && bkc.info.status === "ok") ? Theme.success : Theme.textSecondary }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text { text: bkc.info && bkc.info.status ? bkc.info.status : "Unknown"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                    Text { text: bkc.info && bkc.info.lastRun ? ("Last run " + bkc.info.lastRun) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }
            }
            actions: DialogButton { text: "Back up now"; onClicked: Quickshell.execDetached(["mujo", "backup", "run"]) }
        }
    }

    // 10 — Machines. LAZY: queries libvirtd/docker/virsh only once expanded.
    Component {
        id: machinesCard
        DashboardCard {
            id: mac
            width: parent ? parent.width : implicitWidth
            title: "Machines"; icon: "dns"
            expanded: root.isExpanded("machines")
            onHideRequested: root.setVisible("machines", false)

            property string libvirt: "…"
            property string docker: "…"
            property string vms: ""
            property bool virshMissing: false
            property bool queried: false

            function query() {
                mac.queried = true
                libvirtProc.running = true
                dockerProc.running = true
            }
            onExpandedChanged: { root.setExpanded("machines", expanded); if (expanded && !mac.queried) mac.query() }
            Component.onCompleted: if (mac.expanded) mac.query()

            Process { id: libvirtProc; command: ["systemctl", "is-active", "libvirtd"]
                stdout: StdioCollector { onStreamFinished: { mac.libvirt = this.text.trim() || "unknown"; if (mac.libvirt === "active") virshProc.running = true } } }
            Process { id: dockerProc; command: ["podman", "--version"]
                stdout: StdioCollector { onStreamFinished: mac.docker = this.text.split("\n")[0].trim() || "unknown" } }
            Process { id: virshProc; command: ["virsh", "-c", "qemu:///system", "list", "--all"]
                stdout: StdioCollector { onStreamFinished: mac.vms = this.text.trim() }
                onExited: function (code) { if (code !== 0) mac.virshMissing = true } }

            StatusRow { label: "libvirtd"; status: mac.libvirt; ok: mac.libvirt === "active" }
            StatusRow { label: "podman"; status: mac.docker; ok: mac.docker.toLowerCase().indexOf("podman") >= 0 || mac.docker === "active" }
            // VM list & quick access to Virtual Machines panel
            Text { visible: mac.libvirt === "active" && !mac.virshMissing && mac.vms !== ""; text: mac.vms; color: Theme.textSecondary; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            DialogButton {
                text: "Open Virtual Machines & Lab"
                Layout.topMargin: 4
                onClicked: SettingsBus.go("vm")
            }
        }
    }

    // 11 — Update badge. `mujo update-status` compares flake.lock freshness to the
    // running closure. Click opens the System panel (in-process nav bus).
    Component {
        id: updateCard
        DashboardCard {
            id: upc
            width: parent ? parent.width : implicitWidth
            title: "System updates"; icon: "system_update"
            expanded: root.isExpanded("update"); onExpandedChanged: root.setExpanded("update", expanded)
            onHideRequested: root.setVisible("update", false)

            property var s: null
            readonly property bool stale: s !== null && (s.updateSuggested || s.lockNewerThanSystem)
            Process { id: upProc; command: ["mujo", "update-status"]
                stdout: StdioCollector { onStreamFinished: { try { upc.s = JSON.parse(this.text) } catch (e) {} } } }
            Timer { interval: 120000; running: root.active && upc.expanded; repeat: true; triggeredOnStart: true; onTriggered: if (!upProc.running) upProc.running = true }

            badge: CountPill { visible: upc.stale; label: "UPDATE"; tint: Theme.warning }

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                MaterialIcon { iconName: upc.stale ? "update" : "check_circle"; pixelSize: 24; color: upc.stale ? Theme.warning : Theme.success }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text { text: upc.s === null ? "Checking…" : (upc.stale ? "Update available" : "Up to date"); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                    Text { visible: upc.s !== null; text: (upc.s && upc.s.lockAgeDays ? ("flake.lock " + upc.s.lockAgeDays + "d old") : "flake.lock current") + (upc.s && upc.s.rebootRequired ? " · reboot required" : ""); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                }
            }
            actions: DialogButton { text: "Open System"; onClicked: SettingsBus.go("system") }
        }
    }

    // 12 — AI entry. Probes `mujo ai test` on expand; disabled with the reason if
    // the provider is unreachable, otherwise a shortcut into the AI section.
    Component {
        id: aiCard
        DashboardCard {
            id: aic
            width: parent ? parent.width : implicitWidth
            title: "AI"; icon: "neurology"
            expanded: root.isExpanded("ai")
            onHideRequested: root.setVisible("ai", false)

            property bool tested: false
            property bool ok: false
            property string err: ""
            property bool testing: false
            function test() { aic.tested = true; aic.testing = true; aiProc.running = true }
            onExpandedChanged: { root.setExpanded("ai", expanded); if (expanded && !aic.tested) aic.test() }
            Component.onCompleted: if (aic.expanded) aic.test()

            Process { id: aiProc; command: ["mujo", "ai", "test"]
                stdout: StdioCollector { onStreamFinished: { aic.testing = false; try { var r = JSON.parse(this.text); aic.ok = !!r.ok; aic.err = r.error || "" } catch (e) { aic.ok = false; aic.err = "unexpected response" } } } }

            disabled: aic.tested && !aic.testing && !aic.ok
            disabledReason: "AI provider unreachable" + (aic.err !== "" ? (" — " + aic.err) : "") + "."

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                MaterialIcon { iconName: "neurology"; pixelSize: 24; color: Theme.accent }
                Text { text: aic.testing ? "Checking provider…" : "Ask AI about your desktop"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.fillWidth: true }
            }
            actions: DialogButton { text: "Open AI"; primary: true; onClicked: SettingsBus.go("ai") }
        }
    }

    // 13 — System Health & Optimizer. Live Sentinel telemetry, health score, and quick action.
    Component {
        id: healthCard
        DashboardCard {
            id: htc
            width: parent ? parent.width : implicitWidth
            title: "Health & Care"; icon: "health_and_safety"
            expanded: root.isExpanded("health"); onExpandedChanged: root.setExpanded("health", expanded)
            onHideRequested: root.setVisible("health", false)

            badge: CountPill {
                label: SentinelService.healthScore >= 85 ? "OPTIMAL" : (SentinelService.healthScore >= 60 ? "ATTENTION" : "CRITICAL")
                tint: SentinelService.healthScore >= 85 ? Theme.success : (SentinelService.healthScore >= 60 ? Theme.warning : Theme.error)
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 12
                MaterialIcon {
                    iconName: "monitor_heart"
                    pixelSize: 32
                    color: SentinelService.healthScore >= 85 ? Theme.success : (SentinelService.healthScore >= 60 ? Theme.warning : Theme.error)
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text {
                        text: SentinelService.healthScore + " / 100 Health Score"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeHeading
                        font.bold: true
                    }
                    Text {
                        text: (SentinelService.problematicProcesses.length > 0 ? (SentinelService.problematicProcesses.length + (SentinelService.problematicProcesses.length === 1 ? " problematic process · " : " problematic processes · ")) : "") +
                              (SentinelService.zombieCount > 0 ? (SentinelService.zombieCount + " zombie · ") : "") +
                              "Sentinel active"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            actions: RowLayout {
                spacing: 8
                DialogButton {
                    text: "Open Health"
                    primary: true
                    onClicked: SettingsBus.go("health")
                }
            }
        }
    }
}
