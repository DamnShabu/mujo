import QtQuick
import Quickshell
import "components"
import "theme"

ShellRoot {
    id: root

    property var fails: []
    function check(name, ok) { if (!ok) root.fails.push(name) }

    Item {
        id: host
        width: 500
        height: 400

        MujoReorderList {
            id: reorderList
            width: 400
            model: ["notifications", "volume", "tray", "session", "llm"]
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            check("model loaded", reorderList.model.length === 5)
            check("itemHeight default", reorderList.itemHeight === 38)
            check("step calculation", reorderList.step === 46)
            check("initial implicitHeight", reorderList.implicitHeight === (5 * 38 + 4 * 8))

            // Test programmatic move
            reorderList.move(0, 1)
            check("move index 0 down", reorderList.model[0] === "volume" && reorderList.model[1] === "notifications")

            // Test programmatic remove
            reorderList.remove(0)
            check("remove index 0", reorderList.model.length === 4 && reorderList.model[0] === "notifications")

            if (root.fails.length === 0) {
                console.log("PASS  MujoReorderList tests passed")
            } else {
                console.log("FAIL  MujoReorderList: " + root.fails.length + " check(s) failed")
                for (var i = 0; i < root.fails.length; i++) console.log("        - " + root.fails[i])
            }
            Qt.exit(root.fails.length === 0 ? 0 : 1)
        }
    }
}
