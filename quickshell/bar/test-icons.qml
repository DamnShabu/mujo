import QtQuick
import Quickshell
import "theme"

// Self-check for system icon theme resolution: every name in theme/Icons.qml
// must exist in the installed theme, or it is a typo rather than a fallback.
// Run: qs -p ./test-icons.qml
ShellRoot {
    Component.onCompleted: {
        var fails = []
        var actions = 0
        for (var k in Icons.actions) {
            actions++
            if (Icons.path(k) === "") fails.push("action " + k + " -> " + Icons.actions[k] + "-symbolic")
        }
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
            console.log("PASS  Icons: " + actions + " actions + " + types + " file types resolve")
        } else {
            console.log("FAIL  Icons: " + fails.length + " unresolved of " + (actions + types))
            for (var i = 0; i < fails.length; i++) console.log("        - " + fails[i])
        }
        Qt.exit(fails.length === 0 ? 0 : 1)
    }
}
