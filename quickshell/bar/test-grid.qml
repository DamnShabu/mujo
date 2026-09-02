import QtQuick
import Quickshell
import "services"

// Self-check for the shared desktop occupancy map. Run: qs -p ./test-grid.qml
ShellRoot {
    // Quickshell connects Qt.exit() only once the config has finished
    // loading, so a check that runs from Component.onCompleted prints its
    // verdict and then hangs. One deferred tick puts it after load.
    Timer {
        interval: 0
        running: true
        onTriggered: {
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
}
