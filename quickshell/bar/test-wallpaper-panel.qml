import QtQuick
import Quickshell
import "modules/settings"
import "modules/settings/TagQuery.js" as TagQuery
import "services"

// Self-check for the wallpaper UI and the tag-query parsing its two search
// boxes share. Run: qs -p ./test-wallpaper-panel.qml
//
// The 5-category redesign moved WallpaperBrowseGroup and WallpaperEffectsGroup
// onto AppearancePage and left WallpapersPage reachable from nothing but this
// check. A test that is the only thing keeping a page alive is not testing the
// product, so the page is gone and this points at the live host.
//
// Read-only: instantiating the page starts a `mujo wallpaper list` read and
// nothing else, and TagQuery is pure string handling.
ShellRoot {
    id: root

    property var fails: []
    function check(name, ok) { if (!ok) root.fails.push(name) }

    Item {
        id: host
        width: 1200
        height: 800

        // Held in a Loader so the checks can drop it again: the page keeps a
        // watched FileView and a `mujo wallpaper list` Process alive, and the
        // engine will not exit while they are.
        Loader {
            id: panelLoader
            anchors.fill: parent
            sourceComponent: AppearancePage {}
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
            // 1. The host page and the two wallpaper groups resolve and load.
            check("AppearancePage instantiated", root.panel !== null)
            check("page defaults to the themes tab", root.panel.tab === "themes")
            for (const tab of ["wallpapers", "library", "wallhaven", "wallpaperengine", "effects"]) {
                root.panel.tab = tab
                check("tab switches to " + tab, root.panel.tab === tab)
            }
            root.panel.tab = "themes"

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

            // 6. Wallhaven error state & properties
            check("Wallhaven service has error property", Wallhaven.error !== undefined)
            check("Wallhaven service has errorType property", Wallhaven.errorType !== undefined)
            Wallhaven.error = "Connection timed out"
            Wallhaven.errorType = "timeout"
            check("Wallhaven error set", Wallhaven.error === "Connection timed out")
            check("Wallhaven errorType set", Wallhaven.errorType === "timeout")
            Wallhaven.error = ""
            Wallhaven.errorType = ""
            check("Wallhaven error cleared", Wallhaven.error === "" && Wallhaven.errorType === "")

            panelLoader.sourceComponent = null

            if (root.fails.length === 0) {
                console.log("PASS  wallpaper UI: components resolve, tag query parses, error pill handling verified")
            } else {
                console.log("FAIL  wallpaper UI: " + root.fails.length + " check(s) failed")
                for (const f of root.fails) console.log("        - " + f)
            }
            Qt.exit(root.fails.length === 0 ? 0 : 1)
        }
    }
}
