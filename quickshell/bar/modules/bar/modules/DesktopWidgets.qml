import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Draggable, resizable, persistent desktop widgets and unified desktop context menu.
// Positioned on WlrLayer.Bottom. By managing both the context menu and the widgets
// on the exact same surface, we perfectly handle all background right-clicks
// without any compositor-level input blocking conflicts.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        WlrLayershell.namespace: "qs-widgets"
        WlrLayershell.layer: WlrLayer.Bottom
        // Only steal keyboard focus if the context menu is open
        WlrLayershell.keyboardFocus: win.menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        // We accept all input to this surface. Clicks on empty desktop spaces will be
        // caught by our background MouseArea. Because this layer is below 'Normal'
        // windows, this does not block application interaction.
        mask: null

        readonly property string screenName: modelData.name
        readonly property bool isFirst: Quickshell.screens.length > 0 && Quickshell.screens[0].name === screenName

        property bool anyDragging: false
        property bool anyResizing: false
        property var activeWidget: null

        // ── Grid & Geometry Constants ─────────────────────────────────────────
        readonly property int gridSize: 24
        readonly property int minGridW: 120
        readonly property int minGridH: 72

        function snapX(x, w) { return Math.max(0, Math.min(Math.round(x / gridSize) * gridSize, win.width - w)) }
        function snapY(y, h) { return Math.max(0, Math.min(Math.round(y / gridSize) * gridSize, win.height - h)) }
        function snapW(w) { return Math.max(minGridW, Math.round(w / gridSize) * gridSize) }
        function snapH(h) { return Math.max(minGridH, Math.round(h / gridSize) * gridSize) }

        // ── Config ────────────────────────────────────────────────────────────
        QtObject {
            id: cfg
            property bool locked: true
            property var widgets: []
        }
        FileView {
            path: (Quickshell.env("HOME") || "/tmp") + "/.config/qsshell/widgets.json"
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                try {
                    var c = JSON.parse(text())
                    cfg.locked = !!c.locked
                    var screens = {}
                    for (var i = 0; i < Quickshell.screens.length; i++)
                        screens[Quickshell.screens[i].name] = true
                    cfg.widgets = (c.widgets || []).filter(function(w) {
                        if (w.monitor === win.screenName) return true
                        if ((!w.monitor || w.monitor === "") && win.isFirst) return true
                        if (w.monitor && !screens[w.monitor] && win.isFirst) return true
                        return false
                    })
                } catch (e) { cfg.widgets = [] }
            }
        }

        function persistGeometry(id, x, y, w, h) {
            Quickshell.execDetached(["mujo", "widgets", "geometry", id,
                String(Math.round(x)), String(Math.round(y)),
                String(Math.round(w)), String(Math.round(h)), win.screenName])
        }

        // ── Background Click Handler ──────────────────────────────────────────
        // Catches right clicks for the context menu. Left clicks when the menu is
        // closed are ignored by this MouseArea and vanish silently, safely preventing
        // Niri focus loss bugs while doing nothing.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: win.menuOpen ? (Qt.LeftButton | Qt.RightButton) : Qt.RightButton
            onPressed: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    win.mx = mouse.x
                    win.my = mouse.y
                    win.confirmingReset = false
                    win.menuOpen = true
                } else {
                    win.menuOpen = false
                    win.confirmingReset = false
                }
            }
        }

        // ── Radial White Grid Effect ──────────────────────────────────────────
        // Highly optimized hardware-accelerated grid that fades outwards from the
        // active widget. Only draws grid lines near the widget to keep rendering lightweight.
        Canvas {
            id: gridCanvas
            anchors.fill: parent
            visible: win.anyDragging || win.anyResizing
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.reduceMotion ? 0 : Theme.durationSlow
                    easing.type: Easing.OutCubic
                }
            }

            // Repaint continuously as the active widget glides or stretches
            Connections {
                target: win.activeWidget
                ignoreUnknownSignals: true
                function onXChanged() { gridCanvas.requestPaint() }
                function onYChanged() { gridCanvas.requestPaint() }
                function onWidthChanged() { gridCanvas.requestPaint() }
                function onHeightChanged() { gridCanvas.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (!win.activeWidget) return

                var aw = win.activeWidget
                // Center the radial gradient on the actual visual bounds of the widget
                var cx = aw.x + aw.width / 2
                var cy = aw.y + aw.height / 2
                var r = 600 // Fade radius
                
                var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                grad.addColorStop(0, "rgba(255, 255, 255, 0.30)")
                grad.addColorStop(0.3, "rgba(255, 255, 255, 0.12)")
                grad.addColorStop(1, "rgba(255, 255, 255, 0.0)")

                ctx.lineWidth = 1
                ctx.strokeStyle = grad
                ctx.beginPath()

                var gs = win.gridSize
                // Culling: only draw lines within the gradient's radius bounds
                var startX = Math.max(0, Math.floor((cx - r) / gs) * gs)
                var endX = Math.min(width, cx + r)
                for (var x = startX; x <= endX; x += gs) {
                    ctx.moveTo(x, cy - r)
                    ctx.lineTo(x, cy + r)
                }

                var startY = Math.max(0, Math.floor((cy - r) / gs) * gs)
                var endY = Math.min(height, cy + r)
                for (var y = startY; y <= endY; y += gs) {
                    ctx.moveTo(cx - r, y)
                    ctx.lineTo(cx + r, y)
                }
                ctx.stroke()
            }
        }

        // ── Active Footprint Highlight ────────────────────────────────────────
        // Instantly highlights the exact grid cells the widget will snap into.
        Rectangle {
            id: footprint
            visible: win.activeWidget !== null
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }
            
            x: win.activeWidget ? win.activeWidget.targetX : 0
            y: win.activeWidget ? win.activeWidget.targetY : 0
            width: win.activeWidget ? win.activeWidget.targetW : 0
            height: win.activeWidget ? win.activeWidget.targetH : 0
            
            // A swift catch-up animation for dragging
            Behavior on x { NumberAnimation { duration: Theme.reduceMotion ? 0 : 70; easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: Theme.reduceMotion ? 0 : 70; easing.type: Easing.OutQuad } }
            Behavior on width { NumberAnimation { duration: Theme.reduceMotion ? 0 : 70; easing.type: Easing.OutQuad } }
            Behavior on height { NumberAnimation { duration: Theme.reduceMotion ? 0 : 70; easing.type: Easing.OutQuad } }
            
            color: Qt.rgba(1, 1, 1, 0.08)
            border.color: Qt.rgba(1, 1, 1, 0.25)
            border.width: 1.5
            radius: Theme.radiusLg
        }

        // ── Widgets ───────────────────────────────────────────────────────────
        Repeater {
            model: cfg.widgets
            delegate: Item {
                id: host
                required property var modelData

                // Standardized fallbacks for initial width/height
                property real defaultW: modelData.type === "clock" ? 216 : (modelData.type === "sysmon" ? 216 : 240)
                property real defaultH: modelData.type === "clock" ? 144 : (modelData.type === "weather" ? 96 : 96)

                // Snapped, committed geometry (what persists to widgets.json).
                property real targetX: modelData.x
                property real targetY: modelData.y
                property real targetW: modelData.w || defaultW
                property real targetH: modelData.h || defaultH

                // Continuous, UNSNAPPED geometry during an active drag/resize — the
                // widget tracks the cursor exactly (WP-07); the grid snap is shown
                // only as a ghost preview and committed on release.
                property real freeX: modelData.x
                property real freeY: modelData.y
                property real freeW: modelData.w || defaultW
                property real freeH: modelData.h || defaultH
                property real grabOffX: 0
                property real grabOffY: 0
                property bool dragging: false
                property bool resizing: false
                readonly property bool active: host.dragging || host.resizing

                // Allow external edits from widgets.json to apply ONLY when idle.
                Binding on targetX { value: modelData.x; when: !host.active }
                Binding on targetY { value: modelData.y; when: !host.active }
                Binding on targetW { value: modelData.w || host.defaultW; when: !host.active }
                Binding on targetH { value: modelData.h || host.defaultH; when: !host.active }

                // While active: exact cursor-tracked free geometry (no glide, no
                // detachment). Idle: the snapped target, glided into place.
                x: host.active ? host.freeX : host.targetX
                y: host.active ? host.freeY : host.targetY
                width: host.active ? host.freeW : host.targetW
                height: host.active ? host.freeH : host.targetH

                Behavior on x { enabled: !host.active; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !host.active; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }
                Behavior on width { enabled: !host.active; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }
                Behavior on height { enabled: !host.active; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }

                // 8 resize zones (corners + edges); each moves its edge(s) with the
                // opposite edge fixed.
                readonly property var resizeZones: [
                    { l: true, t: true, cur: Qt.SizeFDiagCursor },
                    { t: true, cur: Qt.SizeVerCursor },
                    { r: true, t: true, cur: Qt.SizeBDiagCursor },
                    { r: true, cur: Qt.SizeHorCursor },
                    { r: true, b: true, cur: Qt.SizeFDiagCursor },
                    { b: true, cur: Qt.SizeVerCursor },
                    { l: true, b: true, cur: Qt.SizeBDiagCursor },
                    { l: true, cur: Qt.SizeHorCursor }
                ]

                // Finalize an interaction from EITHER onReleased OR onCanceled.
                // On wlroots layer-shell the pointer grab is often *canceled*
                // (not released) when the widget slides out from under the cursor
                // mid-drag, so a release-only reset strands `dragging` true and
                // freezes the widget at its last free position.
                function endDrag() {
                    if (!host.dragging) return
                    host.dragging = false
                    win.anyDragging = false
                    win.activeWidget = null
                    win.persistGeometry(host.modelData.id, host.targetX, host.targetY, host.targetW, host.targetH)
                }
                function endResize() {
                    if (!host.resizing) return
                    host.resizing = false
                    win.anyResizing = false
                    win.activeWidget = null
                    win.persistGeometry(host.modelData.id, host.targetX, host.targetY, host.targetW, host.targetH)
                }

                // keep position synced if monitor shifts
                Connections { target: win; function onScreenNameChanged() {} }

                Rectangle {
                    id: content
                    anchors.fill: parent
                    radius: Theme.radiusLg
                    color: withA(Theme.surface, 0.72)
                    border.color: (host.dragging || host.resizing) ? Theme.accent
                               : !cfg.locked ? withA(Theme.accent, 0.5)
                               : withA(Theme.borderStrong, 0.6)
                    border.width: (host.dragging || host.resizing) ? 2 : (!cfg.locked ? 1.5 : 1)
                    function withA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
                    Behavior on border.color {
                        ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast }
                    }

                    // Active state visual lift
                    transform: Scale {
                        origin.x: content.width / 2
                        origin.y: content.height / 2
                        xScale: (host.dragging || host.resizing) ? 1.03 : 1.0
                        yScale: (host.dragging || host.resizing) ? 1.03 : 1.0
                        Behavior on xScale {
                            NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast; easing.type: Easing.OutCubic }
                        }
                        Behavior on yScale {
                            NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast; easing.type: Easing.OutCubic }
                        }
                    }

                    opacity: (host.dragging || host.resizing) ? 0.88 : 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast }
                    }

                    // The widget implementation logic. Widgets may expose
                    // `wReady` (false while loading) / `wError` (message) / `wRetry()`
                    // for the loading + error overlay below (WP-07).
                    readonly property bool wLoading: loader.item && loader.item.wReady === false && !(loader.item.wError)
                    readonly property string wErr: (loader.item && loader.item.wError) ? String(loader.item.wError) : ""

                    Loader {
                        id: loader
                        anchors.fill: parent
                        anchors.margins: 4
                        visible: !content.wLoading && content.wErr === ""
                        sourceComponent: host.modelData.type === "clock" ? clockComp
                                       : host.modelData.type === "weather" ? weatherComp
                                       : host.modelData.type === "sysmon" ? sysmonComp
                                       : clockComp
                        property var wcfg: host.modelData.config || ({})
                    }

                    Spinner {
                        anchors.centerIn: parent
                        visible: content.wLoading
                        size: 24
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        visible: content.wErr !== ""
                        spacing: 6
                        MaterialIcon { anchors.horizontalCenter: parent.horizontalCenter; iconName: "error_outline"; pixelSize: 26; color: Theme.error }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: content.wErr; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: retryLbl.implicitWidth + 22; height: 26; radius: Theme.radiusSm
                            color: retry_hh.hovered ? Theme.surfaceHover : Theme.surface; border.color: Theme.border
                            Text { id: retryLbl; anchors.centerIn: parent; text: "Retry"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                            HoverHandler { id: retry_hh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: if (loader.item && loader.item.wRetry) loader.item.wRetry() }
                        }
                    }
                }

                // ── Drag Body (WP-07) ─────────────────────────────────────────
                // Grab offset captured once on press; the widget follows
                // cursor − offset exactly and NEVER detaches. Only the ghost
                // footprint (targetX/Y) is snapped; snapped geometry commits on
                // release and the widget glides into it.
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    enabled: !cfg.locked
                    cursorShape: cfg.locked ? Qt.ArrowCursor
                              : host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: (mouse) => {
                        var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                        host.grabOffX = p.x - host.targetX
                        host.grabOffY = p.y - host.targetY
                        host.freeX = host.targetX; host.freeY = host.targetY
                        host.freeW = host.targetW; host.freeH = host.targetH
                        host.dragging = true
                        win.anyDragging = true
                        win.activeWidget = host
                    }
                    onPositionChanged: (mouse) => {
                        if (!host.dragging) return
                        var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                        host.freeX = p.x - host.grabOffX
                        host.freeY = p.y - host.grabOffY
                        host.targetX = win.snapX(host.freeX, host.targetW)
                        host.targetY = win.snapY(host.freeY, host.targetH)
                    }
                    onReleased: host.endDrag()
                    onCanceled: host.endDrag()
                }

                // ── Resize Grips (WP-07) ──────────────────────────────────────
                // 8 zones (4 edges + 4 corners) from resizeZones; each moves its
                // edge(s) with the opposite edge fixed. Geometry tracks the cursor
                // freely and snaps only on release. Placed after the drag body so
                // grips win the edge hit-test.
                Repeater {
                    model: host.resizeZones
                    delegate: MouseArea {
                        required property var modelData
                        readonly property int grip: 12
                        enabled: !cfg.locked
                        visible: !cfg.locked
                        cursorShape: modelData.cur
                        x: modelData.l ? 0 : (modelData.r ? host.width - grip : grip)
                        width: (modelData.l || modelData.r) ? grip : Math.max(0, host.width - 2 * grip)
                        y: modelData.t ? 0 : (modelData.b ? host.height - grip : grip)
                        height: (modelData.t || modelData.b) ? grip : Math.max(0, host.height - 2 * grip)

                        property real sMx
                        property real sMy
                        property real sX
                        property real sY
                        property real sW
                        property real sH
                        onPressed: (mouse) => {
                            var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                            sMx = p.x; sMy = p.y
                            sX = host.targetX; sY = host.targetY
                            sW = host.targetW; sH = host.targetH
                            host.freeX = sX; host.freeY = sY; host.freeW = sW; host.freeH = sH
                            host.resizing = true
                            win.anyResizing = true
                            win.activeWidget = host
                        }
                        onPositionChanged: (mouse) => {
                            if (!host.resizing) return
                            var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                            var dx = p.x - sMx, dy = p.y - sMy
                            var nx = sX, ny = sY, nw = sW, nh = sH
                            if (modelData.l) { nx = sX + dx; nw = sW - dx; if (nw < win.minGridW) { nx = sX + sW - win.minGridW; nw = win.minGridW } }
                            if (modelData.r) { nw = Math.max(win.minGridW, sW + dx) }
                            if (modelData.t) { ny = sY + dy; nh = sH - dy; if (nh < win.minGridH) { ny = sY + sH - win.minGridH; nh = win.minGridH } }
                            if (modelData.b) { nh = Math.max(win.minGridH, sH + dy) }
                            host.freeX = nx; host.freeY = ny; host.freeW = nw; host.freeH = nh
                            host.targetW = win.snapW(nw); host.targetH = win.snapH(nh)
                            host.targetX = win.snapX(nx, host.targetW)
                            host.targetY = win.snapY(ny, host.targetH)
                        }
                        onReleased: host.endResize()
                        onCanceled: host.endResize()
                    }
                }
            }
        }

        // ── Widget Content Components ─────────────────────────────────────────
        // Modified to fill their parent loader intelligently rather than hardcoding.
        Component {
            id: clockComp
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                property var c: parent && parent.wcfg ? parent.wcfg : ({})
                readonly property bool h24: c.format24 !== undefined ? c.format24 : true
                readonly property bool secs: !!c.showSeconds
                readonly property bool showDate: c.showDate !== undefined ? c.showDate : true
                
                Item { Layout.fillHeight: true }
                Text {
                    id: clk
                    Layout.alignment: Qt.AlignHCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    // Scale down the pixel size based on container size loosely if we wanted to,
                    // but rigid pixel size ensures clear legibility.
                    font.pixelSize: 46
                    font.bold: true
                    Timer { interval: 1000; running: true; repeat: true; onTriggered: clk.text = Qt.formatTime(new Date(), (parent.h24 ? "HH:mm" : "h:mm AP") + (parent.secs ? ":ss" : "")) }
                    Component.onCompleted: text = Qt.formatTime(new Date(), (parent.h24 ? "HH:mm" : "h:mm AP") + (parent.secs ? ":ss" : ""))
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: parent.showDate
                    text: Qt.formatDate(new Date(), "dddd, MMMM d")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
                Item { Layout.fillHeight: true }
            }
        }

        Component {
            id: weatherComp
            RowLayout {
                anchors.fill: parent
                spacing: 14
                // Loading/error surface for the widget overlay (WP-07).
                property bool wReady: Weather.data !== null || Weather.error !== ""
                property string wError: Weather.data === null ? Weather.error : ""
                function wRetry() { Weather.refresh(true) }
                // Honour the shared style + stale flags (WP-05): compact hides the
                // description/city; stale data renders muted.
                opacity: Weather.stale ? 0.55 : 1
                Item { Layout.fillWidth: true }
                MaterialIcon { iconName: Weather.data ? Weather.iconFor(Weather.data.code) : "cloud"; pixelSize: 52; color: Theme.accent }
                ColumnLayout {
                    spacing: -2
                    RowLayout {
                        spacing: 2
                        Text { text: Weather.data ? Weather.data.temp : "–"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 34; font.bold: true }
                        Text { text: Weather.unitSymbol(); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 15; Layout.topMargin: 6 }
                    }
                    Text { visible: Weather.style !== "compact"; text: Weather.data ? Weather.descFor(Weather.data.code) : "Loading…"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    Text { visible: Weather.style !== "compact"; text: Weather.data ? Weather.data.city : ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel }
                }
                Item { Layout.fillWidth: true }
            }
        }

        Component {
            id: sysmonComp
            ColumnLayout {
                id: sm
                anchors.fill: parent
                spacing: 10
                property int cpu: 0
                property int mem: 0
                property string memText: ""
                // Loading/error surface for the widget overlay (WP-07).
                property bool wReady: false
                property string wError: ""
                function wRetry() { sm.wError = ""; smProc.running = true }
                Process {
                    id: smProc
                    command: ["mujo", "sysmon"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                var d = JSON.parse(this.text)
                                sm.cpu = d.cpu; sm.mem = d.mem
                                sm.memText = d.memUsedGb + " / " + d.memTotalGb + " GB"
                                sm.wReady = true; sm.wError = ""
                            } catch (e) { if (!sm.wReady) sm.wError = "sysmon unavailable" }
                        }
                    }
                    onExited: (code) => { if (code !== 0 && !sm.wReady) sm.wError = "sysmon exited (" + code + ")" }
                }
                Timer { interval: 3000; running: true; repeat: true; onTriggered: smProc.running = true; Component.onCompleted: smProc.running = true }
                Item { Layout.fillHeight: true }
                SysBar {
                    Layout.alignment: Qt.AlignHCenter
                    width: Math.min(190, sm.width - 24)
                    label: "CPU"; value: sm.cpu; caption: sm.cpu + "%"
                }
                SysBar {
                    Layout.alignment: Qt.AlignHCenter
                    width: Math.min(190, sm.width - 24)
                    label: "RAM"; value: sm.mem; caption: sm.memText
                }
                Item { Layout.fillHeight: true }
            }
        }

        // ── Desktop Right-Click Context Menu ──────────────────────────────────
        // Seamlessly integrated to ensure precise layering interaction
        property bool menuOpen: false
        property real mx: 0
        property real my: 0
        property bool confirmingReset: false
        readonly property bool hasWidgets: cfg.widgets.length > 0
        
        readonly property var actions: {
            var items = []
            if (win.hasWidgets) {
                items.push({ icon: "widgets", label: "Add Widget", cmd: ["mujo", "settings", "desktop"] })
                if (cfg.locked) {
                    items.push({ icon: "lock_open", label: "Unlock Widgets", cmd: ["mujo", "widgets", "lock", "off"] })
                } else {
                    items.push({ icon: "lock", label: "Lock Widgets", cmd: ["mujo", "widgets", "lock", "on"] })
                }
                items.push({ icon: "restart_alt", label: "Restore Default Widget Positions", action: "confirmReset" })
                items.push({ divider: true })
            } else {
                items.push({ icon: "widgets", label: "Add Widget", cmd: ["mujo", "settings", "desktop"] })
                items.push({ divider: true })
            }
            items.push({ icon: "wallpaper", label: "Change Wallpaper", cmd: ["mujo", "settings", "wallpaper"] })
            items.push({ icon: "shuffle", label: "Random Wallpaper", cmd: ["mujo", "wallpaper", "random"] })
            items.push({ divider: true })
            items.push({ icon: "palette", label: "Appearance", cmd: ["mujo", "settings", "appearance"] })
            items.push({ icon: "desktop_windows", label: "Display Settings", cmd: ["mujo", "settings", "display"] })
            items.push({ icon: "tune", label: "Open Settings", cmd: ["mujo", "settings"] })
            return items
        }

        function runAction(act) {
            if (act.action === "confirmReset") {
                win.confirmingReset = true
                return
            }
            win.menuOpen = false
            win.confirmingReset = false
            if (act.cmd) Quickshell.execDetached(act.cmd)
        }

        function executeReset() {
            Quickshell.execDetached(["mujo", "widgets", "reset"])
            win.menuOpen = false
            win.confirmingReset = false
        }
        function cancelReset() { win.confirmingReset = false }

        Item {
            id: menu
            visible: win.menuOpen || cardOpacity > 0
            property real cardOpacity: win.menuOpen ? 1 : 0
            Behavior on cardOpacity { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }

            width: 248
            height: win.confirmingReset ? confirmCol.implicitHeight + 24 : col.implicitHeight + 12
            Behavior on height {
                NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast; easing.type: Easing.OutCubic }
            }
            x: Math.max(8, Math.min(win.mx, win.width - width - 8))
            y: Math.max(8, Math.min(win.my, win.height - height - 8))

            Rectangle {
                id: shadowSrc
                anchors.fill: card
                radius: card.radius
                color: "#000000"
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: shadowSrc
                source: shadowSrc
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: "#000000"
                shadowBlur: 1.0
                shadowVerticalOffset: 6
                shadowOpacity: 0.5
                opacity: menu.cardOpacity
            }

            Rectangle {
                id: card
                anchors.fill: parent
                color: Theme.bg
                radius: Theme.radiusLg
                border.color: Theme.border
                opacity: menu.cardOpacity
                scale: win.menuOpen ? 1 : 0.96
                transformOrigin: Item.TopLeft
                Behavior on scale { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast; easing.type: Easing.OutCubic } }
                clip: true

                Column {
                    id: col
                    visible: !win.confirmingReset
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    spacing: 0

                    Repeater {
                        model: win.actions
                        delegate: Loader {
                            required property var modelData
                            width: parent.width
                            sourceComponent: modelData.divider ? dividerComp : itemComp

                            Component {
                                id: dividerComp
                                Item {
                                    width: parent ? parent.width : 0
                                    height: 9
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors { left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6 }
                                        height: 1
                                        color: Theme.border
                                    }
                                }
                            }
                            Component {
                                id: itemComp
                                Rectangle {
                                    width: parent ? parent.width : 0
                                    height: 34
                                    radius: Theme.radiusSm
                                    color: item_hh.hovered ? Theme.surfaceHover : "transparent"
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        spacing: 11
                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            iconName: modelData.icon
                                            pixelSize: 18
                                            color: item_hh.hovered ? Theme.accent : Theme.textSecondary
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.label
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeBody
                                        }
                                    }
                                    HoverHandler { id: item_hh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: win.runAction(modelData) }
                                }
                            }
                        }
                    }
                }

                Column {
                    id: confirmCol
                    visible: win.confirmingReset
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 12
                    Text { text: "Reset widget positions?"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true }
                    Text { text: "All widgets will return to their default positions and sizes."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; width: parent.width; wrapMode: Text.WordWrap }
                    Row {
                        spacing: 8
                        anchors.right: parent.right
                        Rectangle {
                            width: cancelLabel.implicitWidth + 20; height: 30; radius: Theme.radiusSm
                            color: cancel_hh.hovered ? Theme.surfaceHover : Theme.surface; border.color: Theme.border
                            Text { id: cancelLabel; anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                            HoverHandler { id: cancel_hh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.cancelReset() }
                        }
                        Rectangle {
                            width: resetLabel.implicitWidth + 20; height: 30; radius: Theme.radiusSm
                            color: reset_hh.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.25) : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15); border.color: Theme.error
                            Text { id: resetLabel; anchors.centerIn: parent; text: "Reset"; color: Theme.error; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            HoverHandler { id: reset_hh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.executeReset() }
                        }
                    }
                }
            }

            Keys.onEscapePressed: { win.menuOpen = false; win.confirmingReset = false }
            focus: win.menuOpen
        }
    }
}
