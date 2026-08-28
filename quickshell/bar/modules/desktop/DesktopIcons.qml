import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// The ~/Desktop icon layer.
//
// Lives inside the DesktopWidgets PanelWindow rather than owning a surface of
// its own: sharing the window means icons and widgets share one coordinate
// space for free, and there is no second layer-shell surface competing for the
// same clicks. Both register into DesktopGrid, which is what actually keeps a
// widget off a file and a file out of a widget.
//
// Declared BEFORE the widget Repeater in that window on purpose — the widget
// drag areas must stay above this layer's full-bleed background handler, or
// they would never see a press.
Item {
    id: root

    required property string screenName
    property bool active: true          // false on secondary screens
    property bool suspendInput: false   // the desktop context menu is open

    readonly property int cell: DesktopGrid.cell
    readonly property int span: DesktopGrid.iconSpan
    readonly property int cellPx: root.cell * root.span

    // The window this layer sits in is already inset past the bar (Theme
    // .desktopInsetTop), so auto-placement can start at the very first row.
    readonly property int firstRow: 0

    property var selection: []          // names
    property string renamingName: ""
    property string hoveredName: ""
    property var draggingDropSlot: null   // where a release would land; null while nothing legal is in reach

    // Live rect of the icon under the cursor, and the slot a release would land
    // in — both in this layer's pixel space. The desktop window reads them to
    // drive the one shared snap overlay, so a dragged file and a dragged widget
    // show the same grid and the same white box instead of two dialects.
    property var dragRect: null
    readonly property var dropBox: (root.draggingDropSlot && root.dropFolder === "")
        ? ({ x: root.draggingDropSlot.col * root.cell, y: root.draggingDropSlot.row * root.cell,
             w: root.cellPx, h: root.cellPx })
        : null

    signal itemMenuRequested(real mx, real my, string name)

    function _id(name) { return "file:" + name }
    function isSelected(name) { return root.selection.indexOf(name) >= 0 }

    // name → item, so drag targeting can ask "is that a folder?" without a scan.
    readonly property var byName: {
        var m = {}
        for (var i = 0; i < DesktopFiles.items.length; i++) m[DesktopFiles.items[i].name] = DesktopFiles.items[i]
        return m
    }

    // ─── Placement ────────────────────────────────────────────────────────────
    // slots: { name: {col, row} } — the resolved grid position of every item
    // currently on screen, which may differ from the remembered one when a
    // widget has since taken that spot.
    property var slots: ({})
    property bool _laying: false

    // Honour a remembered slot when it is still free, otherwise find the first
    // free one scanning from the top-left, the order a classic desktop uses.
    // Anything relocated is written back so the desktop is stable next login.
    function relayout() {
        if (!root.active || root._laying) return
        if (root.width <= 0 || root.height <= 0) return
        root._laying = true

        DesktopGrid.setBounds(root.screenName, root.width, root.height)
        DesktopGrid.clearScreen(root.screenName, "file")
        DesktopGrid.clearScreen(root.screenName, "folder")

        var items = DesktopFiles.items
        var pos = DesktopFiles.positions
        var next = {}
        var unplaced = []

        // Pass 1: everything with a remembered slot that is still free.
        for (var i = 0; i < items.length; i++) {
            var it = items[i]
            var p = pos[it.name]
            if (p && DesktopGrid.isFree(p.col, p.row, root.span, root.span, root.screenName, "")) {
                DesktopGrid.register(root._id(it.name), it.isDir ? "folder" : "file",
                                     p.col, p.row, root.span, root.span, root.screenName)
                next[it.name] = { col: p.col, row: p.row }
            } else {
                unplaced.push(it)
            }
        }

        // Pass 2: whatever is left goes to the first free slot, so a newly
        // created file cannot land on a widget.
        var placed = {}
        for (var j = 0; j < unplaced.length; j++) {
            var u = unplaced[j]
            var f = DesktopGrid.findFree(root.span, root.span, root.screenName,
                                         root.span, 0, root.firstRow)
            if (!f) continue                      // desktop full: item stays hidden
            DesktopGrid.register(root._id(u.name), u.isDir ? "folder" : "file",
                                 f.col, f.row, root.span, root.span, root.screenName)
            next[u.name] = { col: f.col, row: f.row }
            placed[u.name] = { col: f.col, row: f.row }
        }

        root.slots = next
        root._laying = false
        // One write for the whole pass, after _laying is clear so the refresh it
        // triggers finds a settled layout.
        DesktopFiles.setPositions(placed)
    }

    // ─── Sort / arrange ───────────────────────────────────────────────────────
    // Re-packs every icon from the top-left in the requested order, discarding
    // the remembered slots — the "Sort by" a file manager offers, which is a
    // one-shot rearrange rather than a mode the desktop stays in.
    function _compare(key) {
        switch (key) {
        case "type":
            return function (a, b) {
                if (a.isDir !== b.isDir) return a.isDir ? -1 : 1
                var ea = a.name.lastIndexOf("."), eb = b.name.lastIndexOf(".")
                var ta = ea > 0 ? a.name.substring(ea + 1).toLowerCase() : ""
                var tb = eb > 0 ? b.name.substring(eb + 1).toLowerCase() : ""
                if (ta !== tb) return ta < tb ? -1 : 1
                return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1
            }
        case "size":
            return function (a, b) {
                if (a.isDir !== b.isDir) return a.isDir ? -1 : 1
                if (a.size !== b.size) return b.size - a.size        // largest first
                return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1
            }
        case "date":
            return function (a, b) {
                if (a.mtime !== b.mtime) return b.mtime - a.mtime    // newest first
                return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1
            }
        default:
            return function (a, b) {
                if (a.isDir !== b.isDir) return a.isDir ? -1 : 1
                var na = a.name.toLowerCase(), nb = b.name.toLowerCase()
                return na === nb ? 0 : (na < nb ? -1 : 1)
            }
        }
    }

    function arrange(key) {
        if (!root.active || root.width <= 0 || root.height <= 0) return
        root._laying = true

        DesktopGrid.setBounds(root.screenName, root.width, root.height)
        DesktopGrid.clearScreen(root.screenName, "file")
        DesktopGrid.clearScreen(root.screenName, "folder")

        var items = DesktopFiles.items.slice()
        items.sort(root._compare(key))

        var next = {}
        var write = {}
        for (var i = 0; i < items.length; i++) {
            var it = items[i]
            var f = DesktopGrid.findFree(root.span, root.span, root.screenName,
                                         root.span, 0, root.firstRow)
            if (!f) break                          // desktop full: the rest stay put
            DesktopGrid.register(root._id(it.name), it.isDir ? "folder" : "file",
                                 f.col, f.row, root.span, root.span, root.screenName)
            next[it.name] = { col: f.col, row: f.row }
            write[it.name] = { col: f.col, row: f.row }
        }
        root.slots = next
        root._laying = false
        DesktopFiles.setPositions(write)
    }

    onWidthChanged: relayout()
    onHeightChanged: relayout()
    onActiveChanged: {
        if (!root.active) DesktopGrid.clearScreen(root.screenName, "")
        else relayout()
    }
    // An icon-size change resizes every footprint, so the whole desktop has to
    // be laid out again on the new span.
    onSpanChanged: relayout()

    Connections {
        target: DesktopFiles
        function onReloaded() {
            // Drop selection entries for items that no longer exist.
            var live = {}
            for (var i = 0; i < DesktopFiles.items.length; i++) live[DesktopFiles.items[i].name] = true
            var sel = root.selection.filter(function (n) { return live[n] === true })
            if (sel.length !== root.selection.length) root.selection = sel
            if (root.renamingName !== "" && !live[root.renamingName]) root.renamingName = ""
            root.relayout()
        }
    }

    Component.onCompleted: relayout()

    // ─── Selection helpers ────────────────────────────────────────────────────
    function selectOnly(name) { root.selection = name === "" ? [] : [name] }
    function toggle(name) {
        var s = root.selection.slice()
        var i = s.indexOf(name)
        if (i >= 0) s.splice(i, 1); else s.push(name)
        root.selection = s
    }
    function selectAll() {
        var s = []
        for (var i = 0; i < DesktopFiles.items.length; i++) s.push(DesktopFiles.items[i].name)
        root.selection = s
    }

    // Shift-click extends from the last plainly-clicked icon, over the listing
    // order — the same span a file manager gives you.
    property string anchorName: ""
    function selectRange(name) {
        var items = DesktopFiles.items
        var a = -1, b = -1
        for (var i = 0; i < items.length; i++) {
            if (items[i].name === root.anchorName) a = i
            if (items[i].name === name) b = i
        }
        if (b < 0) return
        if (a < 0) { root.selectOnly(name); root.anchorName = name; return }
        var lo = Math.min(a, b), hi = Math.max(a, b)
        var s = []
        for (var j = lo; j <= hi; j++) s.push(items[j].name)
        root.selection = s
    }

    function openSelection() {
        for (var i = 0; i < root.selection.length; i++) DesktopFiles.open(root.selection[i])
    }
    function trashSelection() {
        if (root.selection.length === 0) return
        var names = root.selection.slice()
        root.selection = []
        for (var i = 0; i < names.length; i++) DesktopGrid.unregister(root._id(names[i]))
        DesktopFiles.trash(names)
    }
    function beginRename(name) {
        if (!name) return
        root.selectOnly(name)
        root.renamingName = name
    }
    function copySelection() { DesktopFiles.copyToClipboard(root.selection) }
    function cutSelection() { DesktopFiles.cutToClipboard(root.selection) }

    // ─── Group drag ───────────────────────────────────────────────────────────
    // Dragging one icon of a multi-selection moves the whole selection, keeping
    // the shape it had. State lives here rather than on the delegate because
    // every follower has to read the lead's offset.
    property var dragNames: []
    property string dragLead: ""
    property real dragOffX: 0             // lead's free position minus its slot, in px
    property real dragOffY: 0
    property string dropFolder: ""        // a folder the release would move into

    function isDragged(name) { return root.dragNames.indexOf(name) >= 0 }

    // Every dragged icon has to fit at the same cell delta, or the drop is
    // refused whole — a partial group move would silently scatter the selection.
    function _groupFits(dCol, dRow) {
        var mc = DesktopGrid.cols(root.screenName)
        var mr = DesktopGrid.rows(root.screenName)
        for (var i = 0; i < root.dragNames.length; i++) {
            var s = root.slots[root.dragNames[i]]
            if (!s) return false
            var c = s.col + dCol, r = s.row + dRow
            if (c < 0 || r < 0) return false
            if (mc > 0 && c + root.span > mc) return false
            if (mr > 0 && r + root.span > mr) return false
            // isFree can only ignore one id, and a group vacates several, so the
            // occupancy check is done cell by cell here instead.
            for (var cc = 0; cc < root.span; cc++) {
                for (var rr = 0; rr < root.span; rr++) {
                    var occ = DesktopGrid.occupantAt(c + cc, r + rr, root.screenName, "")
                    if (occ === "") continue
                    if (occ.indexOf("file:") === 0 && root.isDragged(occ.substring(5))) continue
                    return false
                }
            }
        }
        return true
    }

    // ─── Background: deselect and marquee ─────────────────────────────────────
    property bool marqueeActive: false
    property real mqX0: 0
    property real mqY0: 0
    property real mqX1: 0
    property real mqY1: 0
    readonly property rect marqueeRect: Qt.rect(Math.min(root.mqX0, root.mqX1),
                                                Math.min(root.mqY0, root.mqY1),
                                                Math.abs(root.mqX1 - root.mqX0),
                                                Math.abs(root.mqY1 - root.mqY0))

    // Files dragged in from another application. Quickshell surfaces get the
    // Wayland drag like any other window, so this is the same drop a file
    // manager accepts; anything that cannot be read is simply skipped by the CLI.
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: function (drop) {
            if (!drop.hasUrls) { drop.accepted = false; return }
            var uris = []
            for (var i = 0; i < drop.urls.length; i++) uris.push(String(drop.urls[i]))
            var mode = (drop.proposedAction === Qt.MoveAction) ? "cut" : "copy"
            drop.acceptProposedAction()
            DesktopFiles.importUris(mode, uris)
        }
    }

    MouseArea {
        id: background
        anchors.fill: parent
        enabled: root.active && !root.suspendInput
        acceptedButtons: Qt.LeftButton
        // Right-clicks stay with the widget layer's own background handler,
        // which already owns the desktop context menu.
        propagateComposedEvents: true

        onPressed: function (mouse) {
            root.renamingName = ""
            if (!(mouse.modifiers & Qt.ControlModifier)) root.selectOnly("")
            root.mqX0 = mouse.x; root.mqY0 = mouse.y
            root.mqX1 = mouse.x; root.mqY1 = mouse.y
            root.marqueeActive = true
            root.forceActiveFocus()
        }
        onPositionChanged: function (mouse) {
            if (!root.marqueeActive) return
            root.mqX1 = mouse.x; root.mqY1 = mouse.y
            var r = root.marqueeRect
            var s = []
            for (var name in root.slots) {
                var sl = root.slots[name]
                var ix = sl.col * root.cell
                var iy = sl.row * root.cell
                if (ix < r.x + r.width && ix + root.cellPx > r.x &&
                    iy < r.y + r.height && iy + root.cellPx > r.y) s.push(name)
            }
            root.selection = s
        }
        onReleased: root.marqueeActive = false
        onCanceled: root.marqueeActive = false
    }

    Rectangle {
        visible: root.marqueeActive && root.marqueeRect.width > 2 && root.marqueeRect.height > 2
        x: root.marqueeRect.x
        y: root.marqueeRect.y
        width: root.marqueeRect.width
        height: root.marqueeRect.height
        radius: Theme.radiusSm
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
        border.width: 1
    }

    // ─── Icons ────────────────────────────────────────────────────────────────
    Repeater {
        model: root.active ? DesktopFiles.items : []

        delegate: Item {
            id: host
            required property var modelData
            required property int index

            readonly property string name: modelData.name
            readonly property bool isDir: modelData.isDir === true
            readonly property var slot: root.slots[host.name]
            readonly property bool placed: host.slot !== undefined

            visible: host.placed
            width: root.cellPx
            height: root.cellPx

            readonly property bool moving: root.isDragged(host.name)
            property real grabOffX: 0
            property real grabOffY: 0

            readonly property real slotX: host.placed ? host.slot.col * root.cell : 0
            readonly property real slotY: host.placed ? host.slot.row * root.cell : 0

            // The lead follows the cursor; the rest of the selection follows the
            // lead by the same offset, so the group keeps its shape.
            x: host.moving ? host.slotX + root.dragOffX : host.slotX
            y: host.moving ? host.slotY + root.dragOffY : host.slotY
            z: host.moving ? 2000 : (root.isSelected(host.name) ? 20 : 10)

            Behavior on x { enabled: !host.moving; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
            Behavior on y { enabled: !host.moving; NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }

            DesktopIcon {
                anchors.fill: parent
                name: host.name
                isDir: host.isDir
                selected: root.isSelected(host.name)
                hovered: root.hoveredName === host.name && root.dragLead === ""
                renaming: root.renamingName === host.name
                cut: DesktopFiles.cutNames.indexOf(host.name) >= 0
                dropInvalid: host.moving && root.draggingDropSlot === null && root.dropFolder === ""
                dropTarget: root.dropFolder === host.name
                onRenameAccepted: function (text) {
                    root.renamingName = ""
                    if (text !== "" && text !== host.name) DesktopFiles.rename(host.name, text)
                }
                onRenameCancelled: root.renamingName = ""
            }

            HoverHandler {
                enabled: root.active && !root.suspendInput
                onHoveredChanged: {
                    if (hovered) root.hoveredName = host.name
                    else if (root.hoveredName === host.name) root.hoveredName = ""
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.active && !root.suspendInput && root.renamingName !== host.name
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: host.moving ? Qt.ClosedHandCursor : Qt.ArrowCursor

                onPressed: function (mouse) {
                    root.forceActiveFocus()
                    root.renamingName = ""
                    if (mouse.button === Qt.RightButton) {
                        if (!root.isSelected(host.name)) { root.selectOnly(host.name); root.anchorName = host.name }
                        var g = mapToItem(root, mouse.x, mouse.y)
                        root.itemMenuRequested(g.x, g.y, host.name)
                        return
                    }
                    if (mouse.modifiers & Qt.ShiftModifier) {
                        root.selectRange(host.name)
                    } else if (mouse.modifiers & Qt.ControlModifier) {
                        root.toggle(host.name)
                        root.anchorName = host.name
                    } else if (!root.isSelected(host.name)) {
                        root.selectOnly(host.name)
                        root.anchorName = host.name
                    }

                    host.grabOffX = mouse.x
                    host.grabOffY = mouse.y
                }

                onPositionChanged: function (mouse) {
                    if (mouse.buttons !== Qt.LeftButton) return
                    var g = mapToItem(root, mouse.x, mouse.y)
                    if (root.dragLead !== host.name) {
                        // Don't start a drag on the jitter of an ordinary click.
                        if (root.dragLead !== "") return
                        if (Math.abs(g.x - host.slotX - host.grabOffX) < 4 &&
                            Math.abs(g.y - host.slotY - host.grabOffY) < 4) return
                        root.dragLead = host.name
                        root.dragNames = root.isSelected(host.name) && root.selection.length > 1
                            ? root.selection.slice() : [host.name]
                    }

                    var freeX = Math.max(0, Math.min(g.x - host.grabOffX, root.width - root.cellPx))
                    var freeY = Math.max(0, Math.min(g.y - host.grabOffY, root.height - root.cellPx))
                    root.dragOffX = freeX - host.slotX
                    root.dragOffY = freeY - host.slotY
                    root.dragRect = ({ x: freeX, y: freeY, w: root.cellPx, h: root.cellPx })

                    // A folder under the cursor wins over any snap: releasing
                    // there moves the drag into it, the way a file manager does.
                    var occ = DesktopGrid.occupantAt(Math.floor(g.x / root.cell), Math.floor(g.y / root.cell),
                                                     root.screenName, "")
                    var overName = occ.indexOf("file:") === 0 ? occ.substring(5) : ""
                    var overItem = overName !== "" ? root.byName[overName] : undefined
                    root.dropFolder = (overItem && overItem.isDir === true && !root.isDragged(overName))
                        ? overName : ""
                    if (root.dropFolder !== "") { root.draggingDropSlot = null; return }

                    // Snap to the nearest cell on the shared lattice that is
                    // free of BOTH other icons and any widget. Same cell, same
                    // search a dragged widget gets — an icon simply occupies a
                    // span x span block of it rather than being confined to
                    // every span-th cell, which is what used to give the two a
                    // grid each.
                    var wantCol = Math.round(freeX / root.cell)
                    var wantRow = Math.round(freeY / root.cell)
                    if (root.dragNames.length > 1) {
                        // A group snaps on the lead and moves as a rigid shape,
                        // so the only question is whether that delta fits.
                        var dCol = wantCol - host.slot.col
                        var dRow = wantRow - host.slot.row
                        root.draggingDropSlot = root._groupFits(dCol, dRow)
                            ? { col: wantCol, row: wantRow } : null
                    } else {
                        root.draggingDropSlot = DesktopGrid.nearestFree(wantCol, wantRow, root.span, root.span,
                                                                        root.screenName, root._id(host.name))
                    }
                }

                onReleased: function (mouse) {
                    if (root.dragLead !== host.name) return
                    var names = root.dragNames.slice()
                    var folder = root.dropFolder
                    var d = root.draggingDropSlot

                    root.dragLead = ""
                    root.dragNames = []
                    root.dragOffX = 0
                    root.dragOffY = 0
                    root.draggingDropSlot = null
                    root.dragRect = null
                    root.dropFolder = ""

                    if (folder !== "") {
                        for (var i = 0; i < names.length; i++) DesktopGrid.unregister(root._id(names[i]))
                        root.selection = []
                        DesktopFiles.moveInto(folder, names)
                        return
                    }
                    // No legal slot within reach: the icons spring back, which is
                    // the rejection feedback. Nothing is written.
                    if (!d) return

                    var dCol = d.col - host.slot.col
                    var dRow = d.row - host.slot.row
                    var next = {}
                    for (var k in root.slots) next[k] = root.slots[k]
                    var write = {}
                    for (var j = 0; j < names.length; j++) {
                        var s = root.slots[names[j]]
                        if (!s) continue
                        var nc = s.col + dCol, nr = s.row + dRow
                        var item = root.byName[names[j]]
                        DesktopGrid.register(root._id(names[j]), (item && item.isDir) ? "folder" : "file",
                                             nc, nr, root.span, root.span, root.screenName)
                        next[names[j]] = { col: nc, row: nr }
                        write[names[j]] = { col: nc, row: nr }
                    }
                    root.slots = next
                    DesktopFiles.setPositions(write)
                }
                onCanceled: {
                    if (root.dragLead !== host.name) return
                    root.dragLead = ""
                    root.dragNames = []
                    root.dragOffX = 0
                    root.dragOffY = 0
                    root.draggingDropSlot = null
                    root.dragRect = null
                    root.dropFolder = ""
                }

                onDoubleClicked: function (mouse) {
                    if (mouse.button !== Qt.LeftButton) return
                    DesktopFiles.open(host.name)
                }
            }
        }
    }

    // ─── Keyboard ─────────────────────────────────────────────────────────────
    // Only meaningful while this layer holds focus, which the window grants on
    // demand once something is selected.
    Keys.onPressed: function (event) {
        if (!root.active || root.renamingName !== "") return
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        switch (event.key) {
        case Qt.Key_Delete:
            root.trashSelection(); event.accepted = true; break
        case Qt.Key_F2:
            if (root.selection.length === 1) root.beginRename(root.selection[0])
            event.accepted = true; break
        case Qt.Key_F5:
            DesktopFiles.refresh(); event.accepted = true; break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.openSelection(); event.accepted = true; break
        case Qt.Key_Escape:
            // Escape abandons a pending cut as well as the selection, the way it
            // does everywhere else — otherwise the faded icons never come back.
            root.selectOnly(""); DesktopFiles.cutNames = []; event.accepted = true; break
        case Qt.Key_A:
            if (ctrl) { root.selectAll(); event.accepted = true }
            break
        case Qt.Key_C:
            if (ctrl) { root.copySelection(); event.accepted = true }
            break
        case Qt.Key_X:
            if (ctrl) { root.cutSelection(); event.accepted = true }
            break
        case Qt.Key_V:
            if (ctrl) { DesktopFiles.paste(); event.accepted = true }
            break
        case Qt.Key_Left:  root._step(-1, 0); event.accepted = true; break
        case Qt.Key_Right: root._step(1, 0);  event.accepted = true; break
        case Qt.Key_Up:    root._step(0, -1); event.accepted = true; break
        case Qt.Key_Down:  root._step(0, 1);  event.accepted = true; break
        }
    }

    // Move the selection cursor to the nearest icon in a direction, so arrow
    // keys walk the visible layout rather than the alphabetical model order.
    function _step(dCol, dRow) {
        var from = root.selection.length > 0 ? root.slots[root.selection[root.selection.length - 1]] : null
        if (!from) {
            for (var first in root.slots) { root.selectOnly(first); root.anchorName = first; return }
            return
        }
        var best = ""
        var bestScore = Infinity
        for (var name in root.slots) {
            var s = root.slots[name]
            var dc = s.col - from.col
            var dr = s.row - from.row
            if (dCol !== 0 && (dc === 0 || (dc > 0) !== (dCol > 0))) continue
            if (dRow !== 0 && (dr === 0 || (dr > 0) !== (dRow > 0))) continue
            // Along-axis distance dominates; off-axis drift only breaks ties.
            var score = dCol !== 0 ? Math.abs(dc) * 100 + Math.abs(dr)
                                   : Math.abs(dr) * 100 + Math.abs(dc)
            if (score < bestScore) { bestScore = score; best = name }
        }
        if (best !== "") { root.selectOnly(best); root.anchorName = best }
    }
}
