import QtQuick
import Quickshell
import "services"
import "modules/desktop"

// Integration check for the shared grid: real ~/Desktop contents, laid out
// against a widget that is already sitting on the grid. Run: qs -p ./test-desktop.qml
//
// Back up ~/.local/state/qsshell/desktop-icons.json first — this writes slots
// for real, because that is what makes it a real check.
ShellRoot {
    id: harness

    property int cell: DesktopGrid.cell
    property int span: DesktopGrid.iconSpan

    // A widget parked over the top-left region, exactly where icon
    // auto-placement wants to start.
    // Quickshell connects Qt.exit() only once the config has finished
    // loading, so a check that runs from Component.onCompleted prints its
    // verdict and then hangs. One deferred tick puts it after load.
    Timer {
        interval: 0
        running: true
        onTriggered: {
            DesktopGrid.setBounds("TEST", 1920, 1080)
            DesktopGrid.register("w:fake", "widget", 0, 2, 10, 6, "TEST")
        }
    }

    DesktopIcons {
        id: icons
        screenName: "TEST"
        width: 1920
        height: 1080
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            var fails = []
            function ok(cond, what) { if (!cond) fails.push(what) }

            var names = Object.keys(icons.slots)
            ok(DesktopFiles.loaded, "DesktopFiles loaded a listing")
            ok(names.length === DesktopFiles.items.length,
               "every item got a slot (" + names.length + " of " + DesktopFiles.items.length + ")")

            // No icon may sit on the widget's cells.
            var w = DesktopGrid.objects["w:fake"]
            for (var i = 0; i < names.length; i++) {
                var s = icons.slots[names[i]]
                var hit = s.col < w.col + w.cw && s.col + harness.span > w.col &&
                          s.row < w.row + w.ch && s.row + harness.span > w.row
                ok(!hit, "icon '" + names[i] + "' overlaps the widget at " + s.col + "," + s.row)
            }

            // No two icons may share cells.
            for (var a = 0; a < names.length; a++) {
                for (var b = a + 1; b < names.length; b++) {
                    var p = icons.slots[names[a]]
                    var q = icons.slots[names[b]]
                    ok(!(p.col === q.col && p.row === q.row),
                       "'" + names[a] + "' and '" + names[b] + "' share a slot")
                }
            }

            // The grid must agree with what the layer thinks it placed.
            for (var k = 0; k < names.length; k++) {
                var sl = icons.slots[names[k]]
                var owner = DesktopGrid.occupantAt(sl.col, sl.row, "TEST", "")
                ok(owner === "file:" + names[k],
                   "grid owner at " + sl.col + "," + sl.row + " is '" + owner + "', expected '" + names[k] + "'")
            }

            // A widget must now be refused where an icon landed.
            if (names.length > 0) {
                var first = icons.slots[names[0]]
                ok(!DesktopGrid.isFree(first.col, first.row, 6, 3, "TEST", "w:fake"),
                   "a widget can still be placed on top of an icon")
                ok(DesktopGrid.blockerType(first.col, first.row, 6, 3, "TEST", "w:fake") !== "widget",
                   "blocker at an icon slot should not report as a widget")
            }

            if (fails.length === 0) {
                console.log("PASS  desktop layout: " + names.length + " items placed, no overlaps, grid agrees")
            } else {
                console.log("FAIL  desktop layout: " + fails.length + " check(s) failed")
                for (var f = 0; f < fails.length; f++) console.log("        - " + fails[f])
            }
            Qt.exit(fails.length === 0 ? 0 : 1)
        }
    }
}
