pragma Singleton
import QtQuick

// Shared desktop occupancy map — the single coordinate space that desktop icons
// (DesktopIcons.qml) and desktop widgets (DesktopWidgets.qml) both live in.
//
// Both object types register their footprint here, so a widget can never be
// dropped onto a file and a file can never be dropped onto a widget, without
// either layer knowing anything about the other. `type` is carried through so
// they stay distinct objects sharing one grid, not one merged object type.
//
// Units are CELLS, not pixels, and there is exactly ONE lattice: the 24px cell.
// Icons and widgets snap on it, the drag overlay draws it, and every snap goes
// through snapPx, so nothing can drift onto a grid of its own. `iconSpan` is an
// icon's SIZE — a 4x4 block, 96px square — not a coarser lattice it snaps to; an
// icon can sit on any cell, it just occupies sixteen of them.
QtObject {
    id: grid

    readonly property int cell: 24        // px per atomic cell — the only lattice
    // Cells per icon SIDE. 4 → the default 96px square footprint; desktop.iconSize
    // moves it in whole cells so small/medium/large stay on the one lattice.
    readonly property int iconSpan: Math.max(2, Math.round(SettingsBus.get("desktop.iconSize", 96) / grid.cell))

    // id → { type: "file"|"folder"|"widget", col, row, cw, ch, screen }
    property var objects: ({})

    // "screen|col,row" → id. Derived from `objects`; never written directly.
    property var _cells: ({})

    // screen → { cols, rows }. Callers own their screen's extent.
    property var _bounds: ({})

    signal changed()

    // ─── Pixel ↔ cell ─────────────────────────────────────────────────────────
    function toCell(px) { return Math.round(px / grid.cell) }
    function toPx(c) { return c * grid.cell }

    // Snap a pixel coordinate to `step`, clamped into [0, maxPx] — and clamped
    // ON the lattice, at the last whole step that fits. Clamping to a raw pixel
    // edge is what parks an object between grid lines, so the snap preview stops
    // matching the drawn grid and the cell it registers stops matching where it
    // actually sits. Every snap in the desktop goes through here.
    function snapPx(px, step, maxPx) {
        return Math.max(0, Math.min(Math.round(px / step) * step, Math.floor(maxPx / step) * step))
    }

    function setBounds(screen, widthPx, heightPx) {
        var b = {}
        for (var k in grid._bounds) b[k] = grid._bounds[k]
        b[screen] = { cols: Math.floor(widthPx / grid.cell), rows: Math.floor(heightPx / grid.cell) }
        grid._bounds = b
    }
    function cols(screen) { return grid._bounds[screen] ? grid._bounds[screen].cols : 0 }
    function rows(screen) { return grid._bounds[screen] ? grid._bounds[screen].rows : 0 }

    // ─── Registry ─────────────────────────────────────────────────────────────
    function _key(screen, col, row) { return screen + "|" + col + "," + row }

    // ponytail: full rebuild per mutation is O(objects × footprint). A desktop
    // holds tens of objects, so this is microseconds. Go incremental only if a
    // profile ever says so.
    function _rebuild() {
        var m = {}
        for (var id in grid.objects) {
            var o = grid.objects[id]
            for (var c = 0; c < o.cw; c++)
                for (var r = 0; r < o.ch; r++)
                    m[grid._key(o.screen, o.col + c, o.row + r)] = id
        }
        grid._cells = m
        grid.changed()
    }

    function register(id, type, col, row, cw, ch, screen) {
        if (!id) return
        var next = {}
        for (var k in grid.objects) next[k] = grid.objects[k]
        next[id] = { type: type, col: col, row: row, cw: cw, ch: ch, screen: screen }
        grid.objects = next
        grid._rebuild()
    }

    function unregister(id) {
        if (!grid.objects[id]) return
        var next = {}
        for (var k in grid.objects) if (k !== id) next[k] = grid.objects[k]
        grid.objects = next
        grid._rebuild()
    }

    function clearScreen(screen, type) {
        var next = {}
        var hit = false
        for (var k in grid.objects) {
            var o = grid.objects[k]
            if (o.screen === screen && (!type || o.type === type)) { hit = true; continue }
            next[k] = o
        }
        if (!hit) return
        grid.objects = next
        grid._rebuild()
    }

    // ─── Occupancy queries ────────────────────────────────────────────────────
    // Who sits on this cell? "" when free. exceptId lets a dragging object ignore
    // the footprint it is about to vacate.
    function occupantAt(col, row, screen, exceptId) {
        var id = grid._cells[grid._key(screen, col, row)]
        if (!id || id === exceptId) return ""
        return id
    }

    function isFree(col, row, cw, ch, screen, exceptId) {
        if (col < 0 || row < 0) return false
        var mc = grid.cols(screen)
        var mr = grid.rows(screen)
        if (mc > 0 && col + cw > mc) return false
        if (mr > 0 && row + ch > mr) return false
        for (var c = 0; c < cw; c++)
            for (var r = 0; r < ch; r++)
                if (grid.occupantAt(col + c, row + r, screen, exceptId) !== "") return false
        return true
    }

    // What type is blocking this placement? "" when nothing is. Drives the
    // "can't drop a widget on a file" messaging without the caller inspecting
    // the registry itself.
    function blockerType(col, row, cw, ch, screen, exceptId) {
        for (var c = 0; c < cw; c++) {
            for (var r = 0; r < ch; r++) {
                var id = grid.occupantAt(col + c, row + r, screen, exceptId)
                if (id !== "" && grid.objects[id]) return grid.objects[id].type
            }
        }
        return ""
    }

    // First free slot scanning column-major from the top-left, the placement
    // order a classic desktop uses for a newly appeared item. `step` is a
    // PACKING STRIDE, not a lattice: auto-placement walks it so a fresh desktop
    // comes out in tidy icon-width columns, while a drag may still put that same
    // icon on any cell. minCol / minRow let a caller keep auto-placement clear of
    // a reserved strip, such as the band the floating bar sits in.
    function findFree(cw, ch, screen, step, minCol, minRow) {
        var s = step || 1
        var c0 = minCol || 0
        var r0 = minRow || 0
        var mc = grid.cols(screen)
        var mr = grid.rows(screen)
        if (mc <= 0 || mr <= 0) return null
        for (var col = c0; col + cw <= mc; col += s)
            for (var row = r0; row + ch <= mr; row += s)
                if (grid.isFree(col, row, cw, ch, screen, "")) return { col: col, row: row }
        return null
    }

    // Closest free placement to a desired cell, searched as expanding rings on
    // the one shared lattice — the same search for an icon and for a widget, so
    // a rejected drop means the same thing either way. Returns null past
    // maxRadius, so a crowded desktop rejects the drop instead of flinging the
    // object across the screen; the caller shows that rejection to the user.
    function nearestFree(col, row, cw, ch, screen, exceptId, maxRadius) {
        var cap = maxRadius || 12
        if (grid.isFree(col, row, cw, ch, screen, exceptId)) return { col: col, row: row }
        for (var rad = 1; rad <= cap; rad++) {
            // Walk the ring's four sides rather than scanning the whole square
            // and discarding its interior: same result, O(rad) probes instead of
            // O(rad²), which is what lets the cap be generous enough to feel
            // forgiving without costing anything on a mouse move.
            for (var d = -rad; d <= rad; d++) {
                var probes = [[d, -rad], [d, rad], [-rad, d], [rad, d]]
                for (var i = 0; i < 4; i++) {
                    var nc = col + probes[i][0]
                    var nr = row + probes[i][1]
                    if (grid.isFree(nc, nr, cw, ch, screen, exceptId)) return { col: nc, row: nr }
                }
            }
        }
        return null
    }

    // ─── Self-check ───────────────────────────────────────────────────────────
    // Run with: qs -p ./test-grid.qml
    function selfTest() {
        var fails = []
        function ok(cond, what) { if (!cond) fails.push(what) }

        var saveObjects = grid.objects
        var saveCells = grid._cells
        var saveBounds = grid._bounds
        grid.objects = ({}); grid._cells = ({}); grid._bounds = ({})
        grid.setBounds("T", 24 * 20, 24 * 10)          // 20 x 10 cells

        ok(grid.cols("T") === 20 && grid.rows("T") === 10, "bounds")
        ok(grid.toCell(96) === 4 && grid.toPx(4) === 96, "px↔cell")

        // snapPx: results must land ON the lattice for every input, including
        // the clamped ones. A clamp to a raw pixel edge is what used to park a
        // widget between grid lines, where the drawn grid and the white drop box
        // stopped agreeing with the cell the object registered itself in.
        var step = grid.cell
        var maxPx = 1911                       // deliberately not a multiple of 24
        for (var px = -60; px <= 2000; px += 7) {
            var v = grid.snapPx(px, step, maxPx)
            if (v % step !== 0) { ok(false, "snapPx(" + px + ") off-lattice: " + v); break }
            if (v < 0 || v > maxPx) { ok(false, "snapPx(" + px + ") out of range: " + v); break }
        }
        ok(grid.snapPx(5000, step, maxPx) === 1896, "snapPx clamps to the last whole cell")
        ok(grid.snapPx(-99, step, maxPx) === 0, "snapPx floors at zero")
        ok(grid.snapPx(100, step, maxPx) === 96, "snapPx rounds to nearest")

        // One lattice: an icon must be placeable on ANY cell, not only every
        // fourth one. Seeding nearestFree on a blocked cell has to return an
        // adjacent free cell, the same way it does for a widget.
        grid.setBounds("L", 24 * 40, 24 * 40)
        grid.register("blocker", "file", 8, 8, 4, 4, "L")
        var near = grid.nearestFree(8, 8, 4, 4, "L", "")
        ok(near !== null, "nearestFree finds a slot beside a blocked seed")
        ok(near !== null && grid.isFree(near.col, near.row, 4, 4, "L", ""),
           "nearestFree returns a genuinely free slot")
        // The heart of it: an icon-sized block asked for a cell that is not a
        // multiple of four must get exactly that cell back. Under the old split
        // lattice this position was unreachable for a file.
        var odd = grid.nearestFree(9, 13, 4, 4, "L", "")
        ok(odd !== null && odd.col === 9 && odd.row === 13,
           "an icon can sit on any cell, not only every fourth one")
        // A widget seeded on the same blocked cell must be offered the same
        // lattice — proof the two layers no longer search different grids.
        var wNear = grid.nearestFree(8, 8, 2, 2, "L", "")
        ok(wNear !== null && grid.isFree(wNear.col, wNear.row, 2, 2, "L", ""),
           "widgets and icons search the same lattice")
        grid.unregister("blocker")

        // a 4x4 icon at origin
        grid.register("file:a", "file", 0, 0, 4, 4, "T")
        ok(!grid.isFree(0, 0, 4, 4, "T", ""), "occupied cell reads occupied")
        ok(grid.isFree(0, 0, 4, 4, "T", "file:a"), "exceptId ignores own footprint")
        ok(grid.isFree(4, 0, 4, 4, "T", ""), "neighbouring cell free")
        ok(grid.occupantAt(2, 2, "T", "") === "file:a", "occupantAt finds the owner")

        // a widget must not be placeable over that file, and vice versa
        ok(!grid.isFree(2, 2, 6, 3, "T", ""), "widget overlapping a file is rejected")
        ok(grid.blockerType(2, 2, 6, 3, "T", "") === "file", "blocker is reported as a file")
        grid.register("w:1", "widget", 8, 0, 6, 3, "T")
        ok(!grid.isFree(6, 0, 4, 4, "T", ""), "file overlapping a widget is rejected")
        ok(grid.blockerType(6, 0, 4, 4, "T", "") === "widget", "blocker is reported as a widget")

        // bounds are hard edges
        ok(!grid.isFree(18, 0, 4, 4, "T", ""), "past right edge is rejected")
        ok(!grid.isFree(0, 8, 4, 4, "T", ""), "past bottom edge is rejected")
        ok(!grid.isFree(-1, 0, 4, 4, "T", ""), "negative cell is rejected")

        // nearestFree slides a colliding drop to an adjacent slot on the icon lattice
        var n = grid.nearestFree(0, 0, 4, 4, "T", "", 4, 8)
        ok(n !== null && !(n.col === 0 && n.row === 0), "nearestFree moves off a taken cell")
        ok(n !== null && grid.isFree(n.col, n.row, 4, 4, "T", ""), "nearestFree returns a free cell")

        // findFree is column-major from the top-left, and skips the taken origin
        var f = grid.findFree(4, 4, "T", 4)
        ok(f !== null && f.col === 0 && f.row === 4, "findFree scans column-major")

        // a full screen rejects rather than scanning forever
        grid.objects = ({}); grid._cells = ({}); grid._bounds = ({})
        grid.setBounds("F", 24 * 4, 24 * 4)
        grid.register("only", "file", 0, 0, 4, 4, "F")
        ok(grid.nearestFree(0, 0, 4, 4, "F", "", 4, 6) === null, "full desktop rejects the drop")
        ok(grid.findFree(4, 4, "F", 4) === null, "full desktop has no free slot")

        // unregister frees the cells again
        grid.unregister("only")
        ok(grid.isFree(0, 0, 4, 4, "F", ""), "unregister frees the footprint")

        grid.objects = saveObjects; grid._cells = saveCells; grid._bounds = saveBounds
        return fails
    }
}
