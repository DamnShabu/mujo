import QtQuick
import Quickshell
import "modules/settings"
import "modules/settings/TagQuery.js" as TagQuery

// Self-check for the wallpaper panel and the tag-query parsing its two search
// boxes share. Run: qs -p ./test-wallpaper-panel.qml
//
// Read-only: instantiating the panel starts a `mujo wallpaper list` read and
// nothing else, and TagQuery is pure string handling.
ShellRoot {
    id: root

    property var fails: []
    function check(name, ok) { if (!ok) root.fails.push(name) }

    Item {
        id: host
        width: 1200
        height: 800

        // Held in a Loader so the checks can drop it again: the panel keeps a
        // watched FileView and a `mujo wallpaper list` Process alive, and the
        // engine will not exit while they are.
        Loader {
            id: panelLoader
            anchors.fill: parent
            sourceComponent: WallpaperPanel {}
        }
    }

    readonly property var panel: panelLoader.item

    // Quickshell connects Qt.exit() only once the config has finished
    // loading, so a check that runs from Component.onCompleted prints its
    // verdict and then hangs. One deferred tick puts it after load.
    Timer {
        interval: 0
        running: true
        onTriggered: {
            // 1. The panel and the components it was split into resolve and load.
            check("WallpaperPanel instantiated", root.panel !== null)
            check("panel defaults to the library tab", root.panel.tab === "library")
            for (const tab of ["library", "wallhaven", "wallpaperengine", "effects"]) {
                root.panel.tab = tab
                check("tab switches to " + tab, root.panel.tab === tab)
            }
            root.panel.tab = "library"

            // 2. Tag recognition: whole tokens only, decoration and case ignored.
            check("plain tag found", TagQuery.isInQuery("nature forest", "forest"))
            check("hash-prefixed tag found", TagQuery.isInQuery("#nature", "nature"))
            check("quoted multi-word tag found", TagQuery.isInQuery('"pixel art" sky', "pixel art"))
            check("case is ignored", TagQuery.isInQuery("Nature", "nature"))
            check("substring is not a match", !TagQuery.isInQuery("forestry", "forest"))
            check("empty query matches nothing", !TagQuery.isInQuery("", "forest"))
            check("empty tag matches nothing", !TagQuery.isInQuery("forest", ""))

            // 3. Appending: quote only when needed, never duplicate.
            check("append to empty", TagQuery.append("", "forest") === "forest")
            check("append to existing", TagQuery.append("nature", "forest") === "nature forest")
            check("append quotes a phrase", TagQuery.append("sky", "pixel art") === 'sky "pixel art"')
            check("append strips decoration", TagQuery.append("sky", "#forest") === "sky forest")
            check("append refuses a duplicate", TagQuery.append("nature forest", "forest") === null)
            check("append refuses an empty tag", TagQuery.append("nature", "  ") === null)

            // 4. Completion replaces the partial word the caret is in.
            check("completion replaces the last word", TagQuery.replaceLastToken("nature fore", "forest") === "nature forest")
            check("completion on a lone word", TagQuery.replaceLastToken("fore", "forest") === "forest")
            check("completion drops a duplicate", TagQuery.replaceLastToken("forest fore", "forest") === "forest")
            check("completion refuses an empty tag", TagQuery.replaceLastToken("nature", "") === null)

            // 5. The token a completion request is built from.
            check("last token of a phrase", TagQuery.lastToken("nature fore") === "fore")
            check("one-letter tail falls back to the query", TagQuery.lastToken("nature f") === "nature f")
            check("trailing space keeps the whole query", TagQuery.lastToken("nature ") === "nature")

            panelLoader.sourceComponent = null

            if (root.fails.length === 0) {
                console.log("PASS  wallpaper panel: components resolve, tag query parses")
            } else {
                console.log("FAIL  wallpaper panel: " + root.fails.length + " check(s) failed")
                for (const f of root.fails) console.log("        - " + f)
            }
            Qt.exit(root.fails.length === 0 ? 0 : 1)
        }
    }
}
