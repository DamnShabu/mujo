import QtQuick
import Quickshell
import "services"

// Self-check for the shared desktop occupancy map. Run: qs -p ./test-grid.qml
ShellRoot {
    Component.onCompleted: {
        var fails = DesktopGrid.selfTest()
        if (fails.length === 0) {
            console.log("PASS  DesktopGrid: all occupancy checks green")
        } else {
            console.log("FAIL  DesktopGrid: " + fails.length + " check(s) failed")
            for (var i = 0; i < fails.length; i++) console.log("        - " + fails[i])
        }
        Qt.exit(fails.length === 0 ? 0 : 1)
    }
}
