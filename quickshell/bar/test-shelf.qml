import QtQuick
import Quickshell
import "./services"
import "./theme"

// Self-check for Shelf singleton state management, path normalization, and icon mapping.
// Run: qs -p ./quickshell/bar/test-shelf.qml
ShellRoot {
    // Quickshell connects Qt.exit() only once the config has finished
    // loading, so a check that runs from Component.onCompleted prints its
    // verdict and then hangs. One deferred tick puts it after load.
    Timer {
        interval: 0
        running: true
        onTriggered: {
            var fails = []

            // 1. Initial State & Clearing
            Shelf.clear()
            if (Shelf.count !== 0 || Shelf.items.length !== 0) {
                fails.push("Shelf.clear() failed to empty items (count: " + Shelf.count + ")")
            }

            // 2. Adding normal paths
            Shelf.addPath("/tmp/mujo-test-file.txt")
            if (Shelf.count !== 1) fails.push("addPath failed, expected count 1, got " + Shelf.count)
            if (Shelf.items.length > 0 && Shelf.items[0].name !== "mujo-test-file.txt") {
                fails.push("Item name mismatch, got: " + (Shelf.items[0] ? Shelf.items[0].name : "undefined"))
            }

            // 3. Deduplication by path
            Shelf.addPath("/tmp/mujo-test-file.txt")
            if (Shelf.count !== 1) fails.push("Deduplication failed, count is " + Shelf.count)

            // 4. Adding file:// URI
            Shelf.addUri("file:///tmp/another%20test%20file.pdf")
            if (Shelf.count !== 2) fails.push("addUri failed, expected count 2, got " + Shelf.count)
            if (Shelf.items.length > 1 && Shelf.items[1].name !== "another test file.pdf") {
                fails.push("URI decode mismatch, got: " + (Shelf.items[1] ? Shelf.items[1].name : "undefined"))
            }

            // 5. Adding URI list with multiple lines
            var uriList = "file:///tmp/photo1.png\r\nfile:///tmp/photo2.jpg\n/tmp/plainpath.rs\n"
            Shelf.addUriList(uriList)
            if (Shelf.count !== 5) fails.push("addUriList failed, expected count 5, got " + Shelf.count)

            // 6. Removing specific path
            Shelf.remove("/tmp/mujo-test-file.txt")
            if (Shelf.count !== 4) fails.push("remove failed, expected count 4, got " + Shelf.count)

            // 7. Icon resolution check for staged file types
            var testIcons = [
                { name: "photo.png", isDir: false },
                { name: "doc.pdf", isDir: false },
                { name: "code.rs", isDir: false },
                { name: "folder", isDir: true }
            ]
            for (var i = 0; i < testIcons.length; i++) {
                var icon = Icons.fileIcon(testIcons[i].name, testIcons[i].isDir)
                if (!icon || icon === "") {
                    fails.push("Icons.fileIcon failed to resolve for " + testIcons[i].name)
                }
            }

            // 8. Clean up
            Shelf.clear()
            if (Shelf.count !== 0) fails.push("Final clear failed, count is " + Shelf.count)

            if (fails.length === 0) {
                console.log("PASS  Shelf: state management, URI/path normalization, deduplication, and icon resolution verified")
            } else {
                console.log("FAIL  Shelf: " + fails.length + " check(s) failed")
                for (var j = 0; j < fails.length; j++) console.log("        - " + fails[j])
            }
            Qt.exit(fails.length === 0 ? 0 : 1)
        }
    }
}
