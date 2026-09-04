import QtQuick
import Quickshell
import "theme"

// Self-check for system icon theme resolution: MIME types and file icons in
// theme/Icons.qml must exist in the installed theme, or it is a typo.
// Run: qs -p ./test-icons.qml
ShellRoot {
    // Quickshell connects Qt.exit() only once the config has finished
    // loading, so a check that runs from Component.onCompleted prints its
    // verdict and then hangs. One deferred tick puts it after load.
    Timer {
        interval: 0
        running: true
        onTriggered: {
            var fails = []
            var types = 0
            for (var ext in Icons.fileTypes) {
                types++
                if (!Quickshell.hasThemeIcon(Icons.fileTypes[ext]))
                    fails.push("filetype ." + ext + " -> " + Icons.fileTypes[ext])
            }
            if (Icons.fileIcon("x", true) === "") fails.push("folder icon missing")
            if (Icons.fileIcon("x.unknownext", false) === "") fails.push("generic document icon missing")

            // The extension parse itself, not just the table: a real name must land
            // on the right icon, and a dotfile must not be read as an extension.
            var cases = [["shot.png", "image-x-generic"], ["notes.md", "text-x-markdown"],
                         ["build.sh", "application-x-shellscript"], [".bashrc", "text-x-generic"]]
            for (var c = 0; c < cases.length; c++) {
                var want = Quickshell.iconPath(cases[c][1])
                if (Icons.fileIcon(cases[c][0], false) !== want)
                    fails.push(cases[c][0] + " did not resolve to " + cases[c][1])
            }

            if (fails.length === 0) {
                console.log("PASS  Icons: " + types + " file types resolve")
            } else {
                console.log("FAIL  Icons: " + fails.length + " unresolved of " + types)
                for (var i = 0; i < fails.length; i++) console.log("        - " + fails[i])
            }
            Qt.exit(fails.length === 0 ? 0 : 1)
        }
    }
}
