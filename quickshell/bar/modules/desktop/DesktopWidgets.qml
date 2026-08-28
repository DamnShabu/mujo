import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme"
import "../../components"
import "../../services"

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
        // Take keyboard focus only while something on the desktop actually wants
        // keys: the context menu, or a selected/renaming icon. Holding focus on a
        // Bottom layer any longer than that is what causes focus-loss trouble
        // under Niri, so the grant stays as narrow as the interaction.
        WlrLayershell.keyboardFocus: (win.menuOpen || win.propsOpen || icons.selection.length > 0
                                      || icons.renamingName !== "" || win.focusedWidgetId !== "")
                                     ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        // Inset to exactly where a niri window starts: its struts plus a gap on
        // every side, and the band the bar reserves on top of that. Everything
        // on the desktop therefore lives inside the rectangle an open window
        // covers, instead of a widget edge or an icon label poking out through
        // the gap niri leaves around it. The wallpaper is a separate surface and
        // still runs edge to edge.
        margins {
            left: Theme.desktopInset
            right: Theme.desktopInset
            top: Theme.desktopInsetTop
            bottom: Theme.desktopInsetBottom
        }

        // We accept all input to this surface. Clicks on empty desktop spaces will be
        // caught by our background MouseArea. Because this layer is below 'Normal'
        // windows, this does not block application interaction.
        mask: null

        readonly property string screenName: modelData.name
        readonly property bool isFirst: Quickshell.screens.length > 0 && Quickshell.screens[0].name === screenName

        property var activeWidget: null
        property string focusedWidgetId: ""

        // ── Shared snap overlay source ────────────────────────────────────────
        // One overlay serves both object types, because there is one grid.
        // `dragFocus` is the rect the grid fades out from — a widget or a
        // ~/Desktop icon, whichever is moving. `dropBox` is where a release
        // lands. Both are already snapped, so the white box always sits on the
        // lines drawn under it.
        readonly property var dragFocus:
            win.activeWidget !== null
                ? ({ x: win.activeWidget.x, y: win.activeWidget.y,
                     w: win.activeWidget.width, h: win.activeWidget.height })
                : icons.dragRect

        readonly property var dropBox:
            win.activeWidget !== null
                ? ({ x: win.activeWidget.targetX, y: win.activeWidget.targetY,
                     w: win.activeWidget.targetW, h: win.activeWidget.targetH,
                     invalid: win.activeWidget.dropInvalid === true })
                : (icons.dropBox
                    ? ({ x: icons.dropBox.x, y: icons.dropBox.y,
                         w: icons.dropBox.w, h: icons.dropBox.h, invalid: false })
                    : null)

        // ── Grid & Geometry Constants ─────────────────────────────────────────
        // The 24px snap now comes from DesktopGrid, the occupancy map this layer
        // shares with the ~/Desktop icons. Same granularity as before, so every
        // existing widget geometry stayed exactly where it was — what changed is
        // that a placement is now checked against what else is on the desktop.
        // Default size per widget type. One map instead of a ternary chain that
        // would need two more branches per new widget kind.
        readonly property var widgetDefs: ({
            "clock":    { w: 216, h: 144 },
            "weather":  { w: 240, h: 96  },
            "sysmon":   { w: 216, h: 144 },
            "cava":     { w: 336, h: 120 },
            "calendar": { w: 264, h: 264 },
            "media":    { w: 336, h: 120 },
            "notes":    { w: 240, h: 216 },
            "photo":    { w: 288, h: 216 },
            "vpn":      { w: 288, h: 96  },
            "aiusage":  { w: 312, h: 168 }
        })

        readonly property int gridSize: DesktopGrid.cell
        readonly property int minGridW: 120
        readonly property int minGridH: 72

        // Every snap goes through DesktopGrid.snapPx, so the widget lattice, the
        // icon lattice and the grid the overlay draws can never drift apart.
        function snapX(x, w) { return DesktopGrid.snapPx(x, gridSize, win.width - w) }
        function snapY(y, h) { return DesktopGrid.snapPx(y, gridSize, win.height - h) }
        function snapW(w) { return Math.max(minGridW, DesktopGrid.snapPx(w, gridSize, win.width)) }
        function snapH(h) { return Math.max(minGridH, DesktopGrid.snapPx(h, gridSize, win.height)) }

        onWidthChanged: DesktopGrid.setBounds(win.screenName, win.width, win.height)
        onHeightChanged: DesktopGrid.setBounds(win.screenName, win.width, win.height)

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

        function persistRotation(id, deg) {
            Quickshell.execDetached(["mujo", "widgets", "rotate", id, String(Math.round(deg))])
        }

        function removeWidget(id) {
            Quickshell.execDetached(["mujo", "widgets", "remove", id])
        }

        // ── Background Click Handler ──────────────────────────────────────────
        // Catches right clicks for the context menu. Left clicks when the menu is
        // closed are ignored by this MouseArea and vanish silently, safely preventing
        // Niri focus loss bugs while doing nothing.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: (win.menuOpen || win.propsOpen) ? (Qt.LeftButton | Qt.RightButton) : Qt.RightButton
            onPressed: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    win.mx = mouse.x
                    win.my = mouse.y
                    win.menuTarget = ""
                    win.confirmingReset = false
                    win.subActions = null
                    win.menuOpen = true
                } else {
                    win.closeMenu()
                    win.propsOpen = false
                }
            }
            onClicked: {
                // Clicking on empty desktop clears widget focus
                win.focusedWidgetId = ""
            }
        }

        // ── Radial White Grid Effect ──────────────────────────────────────────
        // Hardware-accelerated grid that fades outwards from whatever is being
        // dragged or resized. Only draws lines near it to stay lightweight. One
        // lattice for the whole desktop, so every cell it shows is a cell the
        // drop can actually land in, whether that is a widget or a file.
        Canvas {
            id: gridCanvas
            anchors.fill: parent
            opacity: win.dragFocus !== null ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Anim.d(Anim.standard)
                    easing.type: Easing.OutCubic
                }
            }

            // Repaint as the dragged object glides or stretches. The binding
            // rebuilds dragFocus on every move, so one handler covers widgets,
            // icons, drags and resizes alike.
            property var dragFocus: win.dragFocus
            onDragFocusChanged: gridCanvas.requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var f = gridCanvas.dragFocus
                if (!f) return

                var cx = f.x + f.w / 2
                var cy = f.y + f.h / 2
                var r = 600 // Fade radius

                var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                grad.addColorStop(0, "rgba(255, 255, 255, 0.30)")
                grad.addColorStop(0.3, "rgba(255, 255, 255, 0.12)")
                grad.addColorStop(1, "rgba(255, 255, 255, 0.0)")

                ctx.lineWidth = 1
                ctx.strokeStyle = grad
                ctx.beginPath()

                // Lines sit at absolute multiples of the one cell — the same
                // arithmetic snapPx uses, so every line is a real landing edge
                // for a widget and for an icon alike.
                var gs = win.gridSize
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
        // The white box: the exact cells the drop will occupy, for a widget or a
        // ~/Desktop icon alike. It always sits on the grid lines drawn above,
        // because both come from the same snapped geometry.
        Rectangle {
            id: footprint
            readonly property var b: win.dropBox
            opacity: footprint.b !== null ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

            x: footprint.b ? footprint.b.x : 0
            y: footprint.b ? footprint.b.y : 0
            width: footprint.b ? footprint.b.w : 0
            height: footprint.b ? footprint.b.h : 0

            Behavior on x { NumberAnimation { duration: Anim.d(70); easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: Anim.d(70); easing.type: Easing.OutQuad } }
            Behavior on width { NumberAnimation { duration: Anim.d(70); easing.type: Easing.OutQuad } }
            Behavior on height { NumberAnimation { duration: Anim.d(70); easing.type: Easing.OutQuad } }

            // Turns red the moment the shared grid has nowhere legal to put this
            // widget — the "rejected drop" feedback, in the same place the user
            // is already looking for the snap preview. An icon with nowhere to go
            // has no box at all; the icon itself carries the rejection instead.
            readonly property bool invalid: footprint.b !== null && footprint.b.invalid === true
            color: footprint.invalid ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
                                     : Qt.rgba(1, 1, 1, 0.08)
            border.color: footprint.invalid ? Theme.error : Qt.rgba(1, 1, 1, 0.25)
            border.width: 1.5
            radius: Theme.radiusLg
            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        }

        // ── Desktop icons (~/Desktop) ─────────────────────────────────────────
        // Declared before the widget Repeater so the widget drag areas stay above
        // this layer's background handler and keep receiving their presses.
        DesktopIcons {
            id: icons
            anchors.fill: parent
            screenName: win.screenName
            active: win.isFirst
            suspendInput: win.menuOpen || win.propsOpen
            onItemMenuRequested: function (mx, my, name) {
                win.mx = mx
                win.my = my
                win.menuTarget = name
                win.confirmingReset = false
                win.menuOpen = true
            }
        }

        // ── Widgets ───────────────────────────────────────────────────────────
        Repeater {
            model: cfg.widgets
            delegate: Item {
                id: host
                required property var modelData
                required property int index

                readonly property string widgetId: modelData.id || ""
                readonly property string widgetType: modelData.type || "clock"

                // Standardized fallbacks for initial width/height
                readonly property var wdef: win.widgetDefs[host.widgetType] || win.widgetDefs["clock"]
                property real defaultW: wdef.w
                property real defaultH: wdef.h

                // Snapped, committed geometry (what persists to widgets.json).
                property real targetX: modelData.x
                property real targetY: modelData.y
                property real targetW: modelData.w || defaultW
                property real targetH: modelData.h || defaultH
                property real targetRot: modelData.rot || 0

                // Continuous, UNSNAPPED geometry during active drag/resize
                property real freeX: modelData.x
                property real freeY: modelData.y
                property real freeW: modelData.w || defaultW
                property real freeH: modelData.h || defaultH
                property real freeRot: modelData.rot || 0
                property real grabOffX: 0
                property real grabOffY: 0
                property bool dragging: false
                property bool resizing: false
                property bool rotating: false
                readonly property bool active: host.dragging || host.resizing || host.rotating
                readonly property bool isFocused: win.focusedWidgetId === host.widgetId

                // Elevated z-order
                z: host.dragging ? 1000 : (host.resizing ? 900 : (host.isFocused ? 200 : 10 + index))

                // Dynamic coordinate binding without rigid anchors
                x: host.active ? host.freeX : host.targetX
                y: host.active ? host.freeY : host.targetY
                width: host.active ? host.freeW : host.targetW
                height: host.active ? host.freeH : host.targetH
                rotation: host.active ? host.freeRot : host.targetRot
                transformOrigin: Item.Center

                Behavior on x { enabled: !host.active; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !host.active; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }
                Behavior on width { enabled: !host.active; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }
                Behavior on height { enabled: !host.active; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }
                Behavior on rotation { enabled: !host.active; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }

                // 8 resize zones (corners + edges)
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

                // ── Shared-grid footprint ────────────────────────────────────
                // A widget occupies whole cells, rounded up, so a widget that
                // covers even part of a cell blocks a file from landing there.
                readonly property int cw: Math.max(1, Math.ceil(host.targetW / DesktopGrid.cell))
                readonly property int ch: Math.max(1, Math.ceil(host.targetH / DesktopGrid.cell))
                property bool dropInvalid: false

                // Committed geometry is registered as-is, never auto-moved: a
                // widget the user placed stays where they put it, even if the
                // icon layer would rather have that spot.
                // ponytail: a rotated widget still books its unrotated,
                // axis-aligned cells. Compute the OBB hull only if overlap with
                // desktop icons actually becomes visible in practice.
                function syncGrid() {
                    DesktopGrid.register(host.widgetId, "widget",
                                         Math.round(host.targetX / DesktopGrid.cell),
                                         Math.round(host.targetY / DesktopGrid.cell),
                                         host.cw, host.ch, win.screenName)
                }
                Component.onCompleted: host.syncGrid()
                Component.onDestruction: DesktopGrid.unregister(host.widgetId)

                function endDrag() {
                    if (!host.dragging) return
                    host.dragging = false
                    win.activeWidget = null
                    if (host.dropInvalid) {
                        // Nowhere legal within reach — snap back to the last
                        // committed slot and write nothing.
                        host.dropInvalid = false
                        var o = DesktopGrid.objects[host.widgetId]
                        if (o) {
                            host.targetX = o.col * DesktopGrid.cell
                            host.targetY = o.row * DesktopGrid.cell
                        }
                        return
                    }
                    host.syncGrid()
                    win.persistGeometry(host.widgetId, host.targetX, host.targetY, host.targetW, host.targetH)
                }

                function endResize() {
                    if (!host.resizing) return
                    host.resizing = false
                    win.activeWidget = null
                    if (host.dropInvalid) {
                        host.dropInvalid = false
                        var o = DesktopGrid.objects[host.widgetId]
                        if (o) {
                            host.targetX = o.col * DesktopGrid.cell
                            host.targetY = o.row * DesktopGrid.cell
                            host.targetW = o.cw * DesktopGrid.cell
                            host.targetH = o.ch * DesktopGrid.cell
                        }
                        return
                    }
                    host.syncGrid()
                    win.persistGeometry(host.widgetId, host.targetX, host.targetY, host.targetW, host.targetH)
                }

                function endRotate() {
                    if (!host.rotating) return
                    host.rotating = false
                    win.activeWidget = null
                    host.targetRot = host.freeRot
                    win.persistRotation(host.widgetId, host.targetRot)
                }

                // ── Widget Instance Loader ───────────────────────────────────
                Loader {
                    id: widgetLoader
                    anchors.fill: parent
                    // Above dragArea/resize grips so the widget's own controls (delete, retry)
                    // receive presses; non-interactive card area falls through to the drag.
                    z: 1
                    sourceComponent: host.comps[host.widgetType] || clockComp
                }

                Component {
                    id: cavaComp
                    CavaWidget {
                        wcfg: host.modelData.config || ({})
                        locked: cfg.locked
                        dragging: host.dragging
                        resizing: host.resizing
                        focused: host.isFocused
                        onCloseClicked: win.removeWidget(host.widgetId)
                    }
                }

                Component {
                    id: calendarComp
                    CalendarWidget {
                        wcfg: host.modelData.config || ({})
                        locked: cfg.locked
                        dragging: host.dragging
                        resizing: host.resizing
                        focused: host.isFocused
                        onCloseClicked: win.removeWidget(host.widgetId)
                    }
                }

                Component {
                    id: mediaComp
                    MediaWidget {
                        wcfg: host.modelData.config || ({})
                        locked: cfg.locked
                        dragging: host.dragging
                        resizing: host.resizing
                        focused: host.isFocused
                        onCloseClicked: win.removeWidget(host.widgetId)
                    }
                }

                Component {
                    id: notesComp
                    NotesWidget {
                        wcfg: host.modelData.config || ({})
                        widgetId: host.widgetId
                        locked: cfg.locked
                        dragging: host.dragging
                        resizing: host.resizing
                        focused: host.isFocused
                        onCloseClicked: win.removeWidget(host.widgetId)
                    }
                }

                Component {
                    id: photoComp
                    PhotoWidget {
                        wcfg: host.modelData.config || ({})
                        locked: cfg.locked
                        dragging: host.dragging
                        resizing: host.resizing
                        focused: host.isFocused
                        onCloseClicked: win.removeWidget(host.widgetId)
                    }
                }

                Component {
                    id: vpnComp
                    VpnWidget {
                        wcfg: host.modelData.config || ({})
                        locked: cfg.locked
                        dragging: host.dragging
                        resizing: host.resizing
                        focused: host.isFocused
                        onCloseClicked: win.removeWidget(host.widgetId)
                    }
                }

                Component {
                    id: aiUsageComp
                    AiUsageWidget {
                        wcfg: host.modelData.config || ({})
                        locked: cfg.locked
                        dragging: host.dragging
                        resizing: host.resizing
                        focused: host.isFocused
                        onCloseClicked: win.removeWidget(host.widgetId)
                    }
                }

                readonly property var comps: ({
                    "clock": clockComp, "weather": weatherComp, "sysmon": sysmonComp,
                    "cava": cavaComp, "calendar": calendarComp, "media": mediaComp,
                    "notes": notesComp, "photo": photoComp, "vpn": vpnComp,
                    "aiusage": aiUsageComp
                })

                Component {
                    id: clockComp
                    ClockWidget {
                        wcfg: host.modelData.config || ({})
                        locked: cfg.locked
                        dragging: host.dragging
                        resizing: host.resizing
                        focused: host.isFocused
                        onCloseClicked: win.removeWidget(host.widgetId)
                    }
                }

                Component {
                    id: weatherComp
                    WeatherWidget {
                        wcfg: host.modelData.config || ({})
                        locked: cfg.locked
                        dragging: host.dragging
                        resizing: host.resizing
                        focused: host.isFocused
                        onCloseClicked: win.removeWidget(host.widgetId)
                    }
                }

                Component {
                    id: sysmonComp
                    SysmonWidget {
                        wcfg: host.modelData.config || ({})
                        locked: cfg.locked
                        dragging: host.dragging
                        resizing: host.resizing
                        focused: host.isFocused
                        onCloseClicked: win.removeWidget(host.widgetId)
                    }
                }

                // Focus tap handler when locked
                TapHandler {
                    enabled: cfg.locked
                    onTapped: win.focusedWidgetId = host.widgetId
                }

                // ── Drag Body MouseArea ──────────────────────────────────────
                // Free cursor-tracked placement with strict boundary constraints
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    enabled: !cfg.locked
                    cursorShape: cfg.locked ? Qt.ArrowCursor
                              : host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: (mouse) => {
                        win.focusedWidgetId = host.widgetId
                        var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                        host.grabOffX = p.x - host.targetX
                        host.grabOffY = p.y - host.targetY
                        host.freeX = host.targetX
                        host.freeY = host.targetY
                        host.freeW = host.targetW
                        host.freeH = host.targetH
                        host.dragging = true
                        win.activeWidget = host
                    }
                    onPositionChanged: (mouse) => {
                        if (!host.dragging) return
                        var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                        // Clamp free coordinates to visible desktop bounds
                        host.freeX = Math.max(0, Math.min(p.x - host.grabOffX, win.width - host.targetW))
                        host.freeY = Math.max(0, Math.min(p.y - host.grabOffY, win.height - host.targetH))
                        // Snap to the nearest cell the shared map says is free of
                        // both other widgets and any ~/Desktop icon.
                        var d = DesktopGrid.nearestFree(Math.round(host.freeX / DesktopGrid.cell),
                                                        Math.round(host.freeY / DesktopGrid.cell),
                                                        host.cw, host.ch, win.screenName,
                                                        host.widgetId)
                        host.dropInvalid = (d === null)
                        if (d) {
                            host.targetX = d.col * DesktopGrid.cell
                            host.targetY = d.row * DesktopGrid.cell
                        }
                    }
                    onReleased: host.endDrag()
                    onCanceled: host.endDrag()
                }

                // ── Resize Grips ─────────────────────────────────────────────
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

                        property real sMx: 0
                        property real sMy: 0
                        property real sX: 0
                        property real sY: 0
                        property real sW: 0
                        property real sH: 0

                        onPressed: (mouse) => {
                            win.focusedWidgetId = host.widgetId
                            var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                            sMx = p.x
                            sMy = p.y
                            sX = host.targetX
                            sY = host.targetY
                            sW = host.targetW
                            sH = host.targetH
                            host.freeX = sX
                            host.freeY = sY
                            host.freeW = sW
                            host.freeH = sH
                            host.resizing = true
                            win.activeWidget = host
                        }
                        onPositionChanged: (mouse) => {
                            if (!host.resizing) return
                            var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                            var dx = p.x - sMx
                            var dy = p.y - sMy
                            var nx = sX
                            var ny = sY
                            var nw = sW
                            var nh = sH

                            if (modelData.l) {
                                nx = Math.max(0, sX + dx)
                                nw = sW - (nx - sX)
                                if (nw < win.minGridW) {
                                    nx = sX + sW - win.minGridW
                                    nw = win.minGridW
                                }
                            }
                            if (modelData.r) {
                                nw = Math.max(win.minGridW, Math.min(sW + dx, win.width - sX))
                            }
                            if (modelData.t) {
                                ny = Math.max(0, sY + dy)
                                nh = sH - (ny - sY)
                                if (nh < win.minGridH) {
                                    ny = sY + sH - win.minGridH
                                    nh = win.minGridH
                                }
                            }
                            if (modelData.b) {
                                nh = Math.max(win.minGridH, Math.min(sH + dy, win.height - sY))
                            }

                            host.freeX = nx
                            host.freeY = ny
                            host.freeW = nw
                            host.freeH = nh
                            var tw = win.snapW(nw)
                            var th = win.snapH(nh)
                            var tx = win.snapX(nx, tw)
                            var ty = win.snapY(ny, th)
                            // A resize is a placement too: growing over a file is
                            // refused the same way moving onto one is, and the
                            // widget keeps its last legal size.
                            var col = Math.round(tx / DesktopGrid.cell)
                            var row = Math.round(ty / DesktopGrid.cell)
                            var cwN = Math.max(1, Math.ceil(tw / DesktopGrid.cell))
                            var chN = Math.max(1, Math.ceil(th / DesktopGrid.cell))
                            host.dropInvalid = !DesktopGrid.isFree(col, row, cwN, chN,
                                                                   win.screenName, host.widgetId)
                            if (host.dropInvalid) return
                            host.targetW = tw
                            host.targetH = th
                            host.targetX = tx
                            host.targetY = ty
                        }
                        onReleased: host.endResize()
                        onCanceled: host.endResize()
                    }
                }

                // -- Rotate Grip ----------------------------------------------
                // One handle above the top edge. The angle comes from the pointer
                // position relative to the widget centre in surface coordinates,
                // so it stays stable while the handle itself rotates under it.
                Item {
                    id: rotHandle
                    visible: !cfg.locked
                    width: 22
                    height: 22
                    x: (host.width - width) / 2
                    y: -30

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: host.rotating ? Theme.accent
                             : (rotHh.hovered ? Theme.surfaceHover : Theme.withAlpha(Theme.surface, 0.9))
                        border.color: host.rotating ? Theme.accent : Theme.borderStrong
                        border.width: 1

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "rotate_right"
                            pixelSize: 14
                            color: host.rotating ? Theme.accentText : Theme.textSecondary
                        }
                    }

                    HoverHandler { id: rotHh; cursorShape: Qt.PointingHandCursor }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !cfg.locked
                        cursorShape: Qt.PointingHandCursor

                        function angleTo(mouse) {
                            var c = host.mapToItem(win.contentItem, host.width / 2, host.height / 2)
                            var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                            var deg = Math.atan2(p.y - c.y, p.x - c.x) * 180 / Math.PI + 90
                            // Snap to 5 degrees, and hard-snap near the quarter turns
                            // so upright and sideways are easy to hit exactly.
                            deg = Math.round(deg / 5) * 5
                            deg = ((deg % 360) + 360) % 360
                            for (var q = 0; q <= 360; q += 90)
                                if (Math.abs(deg - q) <= 4) deg = q % 360
                            return deg
                        }

                        onPressed: (mouse) => {
                            win.focusedWidgetId = host.widgetId
                            host.freeX = host.targetX
                            host.freeY = host.targetY
                            host.freeW = host.targetW
                            host.freeH = host.targetH
                            host.freeRot = host.targetRot
                            host.rotating = true
                            win.activeWidget = host
                        }
                        onPositionChanged: (mouse) => {
                            if (!host.rotating) return
                            host.freeRot = angleTo(mouse)
                        }
                        onReleased: host.endRotate()
                        onCanceled: host.endRotate()
                    }
                }
            }
        }

        // ── Desktop Right-Click Context Menu ──────────────────────────────────
        property bool menuOpen: false
        property real mx: 0
        property real my: 0
        property bool confirmingReset: false
        // Non-empty when the menu was opened on a ~/Desktop icon rather than on
        // empty desktop. One menu renderer, two content sets.
        property string menuTarget: ""
        // The entry whose submenu is showing, and where its row sits in the card.
        property var subActions: null
        property real subY: 0
        readonly property bool hasWidgets: cfg.widgets.length > 0

        function closeMenu() {
            win.menuOpen = false
            win.confirmingReset = false
            win.menuTarget = ""
            win.subActions = null
        }

        // Menu content. The item set is what a file manager offers for a
        // selection; the empty-desktop set is the desktop's own, with everything
        // that would otherwise make the card twenty rows tall folded into
        // submenus the way a desktop context menu normally does it.
        readonly property var actions: {
            var items = []
            if (win.menuTarget !== "") {
                var n = icons.selection.length
                var many = n > 1
                items.push({ icon: "open_in_new", label: many ? "Open " + n + " items" : "Open", action: "openItem" })
                items.push({ divider: true })
                items.push({ icon: "content_cut", label: "Cut", action: "cutItem" })
                items.push({ icon: "content_copy", label: "Copy", action: "copyItem" })
                if (!many) items.push({ icon: "edit", label: "Rename", action: "renameItem" })
                items.push({ icon: "delete", label: "Move to trash", action: "trashItem" })
                items.push({ divider: true })
                items.push({ icon: "info", label: "Properties", action: "propsItem", disabled: many })
                return items
            }
            items.push({ icon: "add", label: "New", sub: [
                { icon: "create_new_folder", label: "Folder", action: "newFolder" },
                { icon: "description", label: "Text document", action: "newFile" }
            ] })
            items.push({ icon: "content_paste", label: "Paste", action: "paste" })
            items.push({ divider: true })
            items.push({ icon: "sort", label: "Sort by", sub: [
                { icon: "sort_by_alpha", label: "Name", action: "sortName" },
                { icon: "category", label: "Type", action: "sortType" },
                { icon: "straighten", label: "Size", action: "sortSize" },
                { icon: "schedule", label: "Date modified", action: "sortDate" }
            ] })
            items.push({ icon: "photo_size_select_large", label: "Icon size", sub: [
                { icon: "photo_size_select_small", label: "Small", action: "iconSmall" },
                { icon: "photo_size_select_large", label: "Medium", action: "iconMedium" },
                { icon: "crop_free", label: "Large", action: "iconLarge" }
            ] })
            items.push({ icon: "refresh", label: "Refresh", action: "refresh" })
            items.push({ icon: "select_all", label: "Select all", action: "selectAll" })
            items.push({ divider: true })
            items.push({ icon: "terminal", label: "Open terminal here", action: "terminal" })
            items.push({ divider: true })
            var widgetSub = [{ icon: "widgets", label: "Add widget", cmd: ["mujo", "settings", "desktop"] }]
            if (win.hasWidgets) {
                widgetSub.push(cfg.locked
                    ? { icon: "lock_open", label: "Unlock widgets", cmd: ["mujo", "widgets", "lock", "off"] }
                    : { icon: "lock", label: "Lock widgets", cmd: ["mujo", "widgets", "lock", "on"] })
                widgetSub.push({ icon: "restart_alt", label: "Restore positions", action: "confirmReset" })
            }
            items.push({ icon: "widgets", label: "Widgets", sub: widgetSub })
            items.push({ icon: "wallpaper", label: "Wallpaper", sub: [
                { icon: "wallpaper", label: "Change wallpaper", cmd: ["mujo", "settings", "wallpaper"] },
                { icon: "shuffle", label: "Random wallpaper", cmd: ["mujo", "wallpaper", "random"] }
            ] })
            items.push({ divider: true })
            items.push({ icon: "palette", label: "Appearance", cmd: ["mujo", "settings", "appearance"] })
            items.push({ icon: "desktop_windows", label: "Display settings", cmd: ["mujo", "settings", "display"] })
            items.push({ icon: "tune", label: "Open settings", cmd: ["mujo", "settings"] })
            return items
        }

        function runAction(act) {
            if (act.action === "confirmReset") {
                win.subActions = null
                win.confirmingReset = true
                return
            }
            var target = win.menuTarget
            win.closeMenu()
            switch (act.action) {
            case "openItem":   icons.openSelection(); return
            case "renameItem": icons.beginRename(target); return
            case "trashItem":  icons.trashSelection(); return
            case "copyItem":   icons.copySelection(); return
            case "cutItem":    icons.cutSelection(); return
            case "propsItem":  win.showProperties(target); return
            case "newFolder":  DesktopFiles.createFolder(); return
            case "newFile":    DesktopFiles.createFile(); return
            case "paste":      DesktopFiles.paste(); return
            case "refresh":    DesktopFiles.refresh(); return
            case "selectAll":  icons.selectAll(); return
            case "terminal":   DesktopFiles.openTerminal(); return
            case "sortName":   icons.arrange("name"); return
            case "sortType":   icons.arrange("type"); return
            case "sortSize":   icons.arrange("size"); return
            case "sortDate":   icons.arrange("date"); return
            case "iconSmall":  SettingsBus.set("desktop.iconSize", 72); return
            case "iconMedium": SettingsBus.set("desktop.iconSize", 96); return
            case "iconLarge":  SettingsBus.set("desktop.iconSize", 120); return
            }
            if (act.cmd) Quickshell.execDetached(act.cmd)
        }

        function executeReset() {
            Quickshell.execDetached(["mujo", "widgets", "reset"])
            win.closeMenu()
        }
        function cancelReset() { win.confirmingReset = false }

        // ── Properties sheet ──────────────────────────────────────────────────
        property bool propsOpen: false
        property var propsInfo: null

        function showProperties(name) {
            if (!name) return
            win.propsInfo = null
            win.propsOpen = true
            DesktopFiles.requestInfo(name)
        }

        Connections {
            target: DesktopFiles
            function onInfoReady(info) { if (win.propsOpen) win.propsInfo = info }
        }

        // ── Menu surfaces ─────────────────────────────────────────────────────
        Item {
            id: menuHost
            anchors.fill: parent
            visible: win.menuOpen || mainMenu.visible || confirmCard.visible

            readonly property int cardW: 248
            readonly property real menuX: Math.max(8, Math.min(win.mx, win.width - menuHost.cardW - 8))
            readonly property real menuY: Math.max(8, Math.min(win.my, win.height - mainMenu.height - 8))

            DesktopMenu {
                id: mainMenu
                actions: win.actions
                open: win.menuOpen && !win.confirmingReset
                cardWidth: menuHost.cardW
                x: menuHost.menuX
                y: menuHost.menuY
                onTriggered: function (act) { win.runAction(act) }
                onRowHovered: function (act, rowY) {
                    win.subActions = act ? act.sub : null
                    win.subY = rowY
                }
            }

            // The submenu opens beside its row, and flips to the other side when
            // there is no room — a menu that runs off the screen is a menu with
            // items you cannot reach.
            DesktopMenu {
                id: subMenu
                actions: win.subActions || []
                open: win.menuOpen && !win.confirmingReset && win.subActions !== null
                cardWidth: 200
                x: (menuHost.menuX + menuHost.cardW + 4 + cardWidth < win.width)
                    ? menuHost.menuX + menuHost.cardW + 4
                    : Math.max(8, menuHost.menuX - cardWidth - 4)
                y: Math.max(8, Math.min(menuHost.menuY + win.subY - 6, win.height - height - 8))
                onTriggered: function (act) { win.runAction(act) }
            }

            // Reset confirmation replaces the card in place, so the question is
            // asked where the answer was requested.
            Item {
                id: confirmCard
                width: menuHost.cardW
                height: confirmCol.implicitHeight + 24
                x: menuHost.menuX
                y: menuHost.menuY
                opacity: win.confirmingReset ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bg
                    radius: Theme.radiusLg
                    border.color: Theme.border

                    Column {
                        id: confirmCol
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
                                TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: win.cancelReset() }
                            }
                            Rectangle {
                                width: resetLabel.implicitWidth + 20; height: 30; radius: Theme.radiusSm
                                color: reset_hh.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.25) : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15); border.color: Theme.error
                                Text { id: resetLabel; anchors.centerIn: parent; text: "Reset"; color: Theme.error; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                                HoverHandler { id: reset_hh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: win.executeReset() }
                            }
                        }
                    }
                }
            }

            Keys.onEscapePressed: win.closeMenu()
            focus: win.menuOpen
        }

        DesktopProperties {
            id: propsSheet
            info: win.propsInfo
            open: win.propsOpen && win.propsInfo !== null
            x: Math.round((win.width - width) / 2)
            y: Math.round((win.height - height) / 2)
            onClosed: win.propsOpen = false
            Keys.onEscapePressed: win.propsOpen = false
            focus: win.propsOpen
        }
    }
}
