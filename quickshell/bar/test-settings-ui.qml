import QtQuick
import Quickshell
import "modules/settings"
import "modules/settings/SearchIndex.js" as SearchIndex
import "services"

// Self-check for the settings shell primitives and 7-category IA.
// Run: qs -p ./quickshell/bar/test-settings-ui.qml
//
// Read-only: asserts that SettingRow reads the live store and that
// SettingsLayout resolves all category keys, alias routes, and deep links.
ShellRoot {
    id: root

    property var fails: []
    function check(name, ok) { if (!ok) root.fails.push(name) }

    Item {
        id: host
        width: 400
        height: 300

        SettingRow { id: rToggle; path: "bar.autoHide"; kind: "toggle"; def: false; title: "t" }
        SettingRow { id: rSlider; path: "bar.height"; kind: "slider"; def: 34; from: 20; to: 60; title: "s" }
        SettingRow { id: rSeg; path: "bar.position"; kind: "segment"; def: "top"; options: ["top", "bottom"]; title: "g" }
        SettingRow { id: rText; path: "general.hostname"; kind: "text"; def: "main"; title: "x" }

        SettingsPage { id: page; title: "Probe"; brand: "system" }

        // The seven real category pages, so the search index can be checked
        // against the cards the app actually ships. Held in a Loader for the
        // same reason as test-wallpaper-panel: several groups keep watched
        // FileViews and Processes alive, and the engine will not exit while
        // they are.
        Loader {
            id: pagesLoader
            width: 900
            height: 700
            sourceComponent: Column {
                SystemPage { id: pSystem }
                AppearancePage { id: pAppearance }
                WorkspacePage { id: pWorkspace }
                WallpapersPage { id: pWallpapers }
                IntelligencePage { id: pIntelligence }
                HardwarePage { id: pHardware }
                SecurityPage { id: pSecurity }

                readonly property var byKey: ({
                    "system": pSystem, "appearance": pAppearance,
                    "workspace": pWorkspace, "wallpapers": pWallpapers,
                    "intelligence": pIntelligence, "hardware": pHardware,
                    "security": pSecurity
                })
            }
        }

        SettingsLayout {
            id: layout
            categories: [
                {
                    key: "system", label: "System", icon: "tune", brand: "system",
                    keys: ["system", "overview", "health", "general", "applications", "host", "rebuild", "gc", "sentinel"]
                },
                {
                    key: "appearance", label: "Appearance", icon: "palette", brand: "appearance",
                    keys: ["appearance", "theme", "colors", "accent", "transparency", "motion", "animations"]
                },
                {
                    key: "workspace", label: "Workspace", icon: "dock_to_bottom", brand: "desktop",
                    keys: ["workspace", "bar", "island", "widgets", "desktop", "shelf"]
                },
                {
                    key: "wallpapers", label: "Wallpapers", icon: "wallpaper", brand: "wallpaper",
                    keys: ["wallpapers", "wallpaper", "wallhaven", "wallpaperengine", "effects", "parallax"]
                },
                {
                    key: "intelligence", label: "Intelligence", icon: "psychology", brand: "ai",
                    keys: ["intelligence", "ai", "notifications", "weather", "network", "vpn", "mullvad", "dnd"]
                },
                {
                    key: "hardware", label: "Hardware", icon: "monitor", brand: "display",
                    keys: ["hardware", "display", "displays", "devices", "input", "keyboard", "mouse", "touchpad", "shortcuts", "vm", "machines", "idle", "power", "screen"]
                },
                {
                    key: "security", label: "Security", icon: "shield", brand: "security",
                    keys: ["security", "vault", "keyring", "trust", "persistence", "privacy", "tpm", "boot"]
                }
            ]
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            // 1. Store binding assertions
            check("toggle reads store", rToggle.value === SettingsBus.get("bar.autoHide", false))
            check("slider reads store", Number(rSlider.value) === Number(SettingsBus.get("bar.height", 34)))
            check("segment reads store", rSeg.value === SettingsBus.get("bar.position", "top"))
            check("text reads store", String(rText.value) === String(SettingsBus.get("general.hostname", "main")))

            // 2. Page starts unscrolled
            check("page starts unscrolled", page.contentY === 0)

            // 3. 7-Category Routing Assertions
            layout.route("system")
            check("route to system", layout.current === "system")
            layout.route("rebuild")
            check("route alias rebuild -> system", layout.current === "system")
            layout.route("sentinel")
            check("route alias sentinel -> system", layout.current === "system")

            layout.route("appearance")
            check("route to appearance", layout.current === "appearance")
            layout.route("motion")
            check("route alias motion -> appearance", layout.current === "appearance")
            layout.route("accent")
            check("route alias accent -> appearance", layout.current === "appearance")

            layout.route("workspace")
            check("route to workspace", layout.current === "workspace")
            layout.route("bar")
            check("route alias bar -> workspace", layout.current === "workspace")
            layout.route("island")
            check("route alias island -> workspace", layout.current === "workspace")
            layout.route("widgets")
            check("route alias widgets -> workspace", layout.current === "workspace")
            layout.route("shelf")
            check("route alias shelf -> workspace", layout.current === "workspace")

            layout.route("wallpapers")
            check("route to wallpapers", layout.current === "wallpapers")
            layout.route("wallhaven")
            check("route alias wallhaven -> wallpapers", layout.current === "wallpapers")

            layout.route("intelligence")
            check("route to intelligence", layout.current === "intelligence")
            layout.route("ai")
            check("route alias ai -> intelligence", layout.current === "intelligence")
            layout.route("vpn")
            check("route alias vpn -> intelligence", layout.current === "intelligence")
            layout.route("weather")
            check("route alias weather -> intelligence", layout.current === "intelligence")

            layout.route("hardware")
            check("route to hardware", layout.current === "hardware")
            layout.route("vm")
            check("route alias vm -> hardware", layout.current === "hardware")
            layout.route("shortcuts")
            check("route alias shortcuts -> hardware", layout.current === "hardware")

            layout.route("security")
            check("route to security", layout.current === "security")
            layout.route("vault")
            check("route alias vault -> security", layout.current === "security")
            layout.route("keyring")
            check("route alias keyring -> security", layout.current === "security")
            layout.route("trust")
            check("route alias trust -> security", layout.current === "security")
            layout.route("persistence")
            check("route alias persistence -> security", layout.current === "security")
            layout.route("privacy")
            check("route alias privacy -> security", layout.current === "security")


            // 4. Every search index entry routes, and every `card` anchor names
            //    a MujoCard that actually exists on the page it routes to. A
            //    renamed card would otherwise silently degrade search to
            //    "lands on the right page, at the top".
            var pages = pagesLoader.item.byKey
            var badRoute = []
            var badCard = []
            for (var e = 0; e < SearchIndex.entries.length; e++) {
                var entry = SearchIndex.entries[e]
                layout.route(entry.key)
                var cat = layout.current
                if (!pages[cat]) { badRoute.push(entry.title + " → " + entry.key); continue }
                if (entry.card === undefined) continue
                if (!pages[cat].revealCard(entry.card)) badCard.push(entry.title + " → " + entry.card)
            }
            check("every search entry routes to a real category", badRoute.length === 0)
            check("every search card anchor resolves", badCard.length === 0)
            for (var b = 0; b < badRoute.length; b++) root.fails.push("  unroutable: " + badRoute[b])
            for (var d = 0; d < badCard.length; d++) root.fails.push("  no such card: " + badCard[d])

            // 5. A card anchor is optional, and a bogus one fails loudly rather
            //    than throwing.
            check("unknown card anchor returns false", page.revealCard("No Such Card") === false)

            pagesLoader.sourceComponent = null

            if (root.fails.length === 0) {
                console.log("PASS  settings UI: IA routing, aliases, store bindings, and search card anchors verified")
            } else {
                console.log("FAIL  settings UI: " + root.fails.length + " check(s) failed")
                for (var i = 0; i < root.fails.length; i++) console.log("        - " + root.fails[i])
            }
            Qt.exit(root.fails.length === 0 ? 0 : 1)
        }
    }
}
