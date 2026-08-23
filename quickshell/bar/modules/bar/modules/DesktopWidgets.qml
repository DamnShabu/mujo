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

                // The continuous snapped target values
                property real targetX: modelData.x
                property real targetY: modelData.y
                property real targetW: modelData.w || defaultW
                property real targetH: modelData.h || defaultH

                // Allow external edits from widgets.json to apply ONLY when idle
                Binding on targetX { value: modelData.x; when: !host.dragging }
                Binding on targetY { value: modelData.y; when: !host.dragging }
                Binding on targetW { value: modelData.w || host.defaultW; when: !host.resizing }
                Binding on targetH { value: modelData.h || host.defaultH; when: !host.resizing }

                // The actual physical positions that smoothly glide to catch up with targets
                x: targetX
                y: targetY
                width: targetW
                height: targetH

                Behavior on x { NumberAnimation { duration: host.dragging ? 150 : 0; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: host.dragging ? 150 : 0; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: host.resizing ? 150 : 0; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: host.resizing ? 150 : 0; easing.type: Easing.OutCubic } }

                property bool dragging: false
                property bool resizing: false

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

                    // The widget implementation logic
                    Loader {
                        id: loader
                        anchors.fill: parent
                        anchors.margins: 4
                        sourceComponent: host.modelData.type === "clock" ? clockComp
                                       : host.modelData.type === "weather" ? weatherComp
                                       : host.modelData.type === "sysmon" ? sysmonComp
                                       : clockComp
                        property var wcfg: host.modelData.config || ({})
                    }
                }

                // ── Drag Handle (Body) ────────────────────────────────────────
                // We use an invisible item as the raw drag target so the mouse can
                // move freely while the actual widget snaps and glides behind it.
                Item {
                    id: rawDragTarget
                    x: host.targetX
                    y: host.targetY
                    width: host.targetW
                    height: host.targetH
                }
                
                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 12
                    anchors.bottomMargin: 12
                    enabled: !cfg.locked
                    cursorShape: cfg.locked ? Qt.ArrowCursor : Qt.SizeAllCursor
                    drag.target: cfg.locked ? undefined : rawDragTarget
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: -1000 // Handled strictly by snapping
                    drag.minimumY: -1000

                    onPressed: {
                        if (!cfg.locked) {
                            rawDragTarget.x = host.targetX
                            rawDragTarget.y = host.targetY
                            host.dragging = true
                            win.anyDragging = true
                            win.activeWidget = host
                        }
                    }
                    onPositionChanged: {
                        if (host.dragging) {
                            host.targetX = win.snapX(rawDragTarget.x, host.targetW)
                            host.targetY = win.snapY(rawDragTarget.y, host.targetH)
                        }
                    }
                    onReleased: {
                        if (!cfg.locked) {
                            host.dragging = false
                            win.anyDragging = false
                            win.activeWidget = null
                            win.persistGeometry(host.modelData.id, host.targetX, host.targetY, host.targetW, host.targetH)
                        }
                    }
                }

                // ── Resize Handle: Bottom-Right ───────────────────────────────
                MouseArea {
                    width: 20
                    height: 20
                    anchors { right: parent.right; bottom: parent.bottom }
                    cursorShape: Qt.SizeFDiagCursor
                    enabled: !cfg.locked
                    visible: !cfg.locked
                    property real startMouseX
                    property real startMouseY
                    property real startW
                    property real startH
                    onPressed: (mouse) => {
                        var pt = mapToItem(win.contentItem, mouse.x, mouse.y)
                        startMouseX = pt.x
                        startMouseY = pt.y
                        startW = host.targetW
                        startH = host.targetH
                        host.resizing = true
                        win.anyResizing = true
                        win.activeWidget = host
                    }
                    onPositionChanged: (mouse) => {
                        var pt = mapToItem(win.contentItem, mouse.x, mouse.y)
                        var maxW = win.width - host.targetX
                        var maxH = win.height - host.targetY
                        host.targetW = Math.min(maxW, win.snapW(startW + (pt.x - startMouseX)))
                        host.targetH = Math.min(maxH, win.snapH(startH + (pt.y - startMouseY)))
                    }
                    onReleased: {
                        host.resizing = false
                        win.anyResizing = false
                        win.activeWidget = null
                        win.persistGeometry(host.modelData.id, host.targetX, host.targetY, host.targetW, host.targetH)
                    }
                }

                // ── Resize Handle: Right ──────────────────────────────────────
                MouseArea {
                    width: 12
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom; bottomMargin: 20; topMargin: 12 }
                    cursorShape: Qt.SizeHorCursor
                    enabled: !cfg.locked
                    visible: !cfg.locked
                    property real startMouseX
                    property real startW
                    onPressed: (mouse) => {
                        startMouseX = mapToItem(win.contentItem, mouse.x, mouse.y).x
                        startW = host.targetW
                        host.resizing = true
                        win.anyResizing = true
                        win.activeWidget = host
                    }
                    onPositionChanged: (mouse) => {
                        var pt = mapToItem(win.contentItem, mouse.x, mouse.y)
                        var maxW = win.width - host.targetX
                        host.targetW = Math.min(maxW, win.snapW(startW + (pt.x - startMouseX)))
                    }
                    onReleased: {
                        host.resizing = false
                        win.anyResizing = false
                        win.activeWidget = null
                        win.persistGeometry(host.modelData.id, host.targetX, host.targetY, host.targetW, host.targetH)
                    }
                }

                // ── Resize Handle: Bottom ─────────────────────────────────────
                MouseArea {
                    height: 12
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right; rightMargin: 20; leftMargin: 12 }
                    cursorShape: Qt.SizeVerCursor
                    enabled: !cfg.locked
                    visible: !cfg.locked
                    property real startMouseY
                    property real startH
                    onPressed: (mouse) => {
                        startMouseY = mapToItem(win.contentItem, mouse.x, mouse.y).y
                        startH = host.targetH
                        host.resizing = true
                        win.anyResizing = true
                        win.activeWidget = host
                    }
                    onPositionChanged: (mouse) => {
                        var pt = mapToItem(win.contentItem, mouse.x, mouse.y)
                        var maxH = win.height - host.targetY
                        host.targetH = Math.min(maxH, win.snapH(startH + (pt.y - startMouseY)))
                    }
                    onReleased: {
                        host.resizing = false
                        win.anyResizing = false
                        win.activeWidget = null
                        win.persistGeometry(host.modelData.id, host.targetX, host.targetY, host.targetW, host.targetH)
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
                Item { Layout.fillWidth: true }
                MaterialIcon { iconName: Weather.data ? Weather.iconFor(Weather.data.code) : "cloud"; pixelSize: 52; color: Theme.accent }
                ColumnLayout {
                    spacing: -2
                    RowLayout {
                        spacing: 2
                        Text { text: Weather.data ? Weather.data.temp : "–"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 34; font.bold: true }
                        Text { text: Weather.unitSymbol(); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 15; Layout.topMargin: 6 }
                    }
                    Text { text: Weather.data ? Weather.descFor(Weather.data.code) : "Loading…"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    Text { text: Weather.data ? Weather.data.city : ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel }
                }
                Item { Layout.fillWidth: true }
            }
        }

        Component {
            id: sysmonComp
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                property int cpu: 0
                property int mem: 0
                property string memText: ""
                Process {
                    id: smProc
                    command: ["mujo", "sysmon"]
                    stdout: StdioCollector { onStreamFinished: { try { var d = JSON.parse(this.text); parent.cpu = d.cpu; parent.mem = d.mem; parent.memText = d.memUsedGb + " / " + d.memTotalGb + " GB" } catch (e) {} } }
                }
                Timer { interval: 3000; running: true; repeat: true; onTriggered: smProc.running = true; Component.onCompleted: smProc.running = true }
                Item { Layout.fillHeight: true }
                SysBar {
                    Layout.alignment: Qt.AlignHCenter
                    width: Math.min(190, parent.width - 24)
                    label: "CPU"; value: parent.cpu; caption: parent.cpu + "%" 
                }
                SysBar {
                    Layout.alignment: Qt.AlignHCenter
                    width: Math.min(190, parent.width - 24)
                    label: "RAM"; value: parent.mem; caption: parent.memText 
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
