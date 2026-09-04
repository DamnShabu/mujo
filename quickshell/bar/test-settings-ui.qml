import QtQuick
import Quickshell
import "modules/settings"
import "modules/settings/SearchIndex.js" as SearchIndex
import "services"

// Self-check for the settings shell primitives and 5-category IA.
// Run: qs -p ./quickshell/bar/test-settings-ui.qml
//
// Read-only: asserts that SettingRow reads the live store and that
// SettingsLayout resolves all 5 category keys, alias routes, and deep links.
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

        // The five real category pages, so the search index can be checked
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
                HardwarePage { id: pHardware }
                SecurityPage { id: pSecurity }

                readonly property var byKey: ({
                    "system": pSystem, "appearance": pAppearance,
                    "workspace": pWorkspace, "hardware": pHardware,
                    "security": pSecurity
                })
            }
        }

        SettingsLayout {
            id: layout
            categories: [
                {
                    key: "system", label: "System", icon: "tune", brand: "system",
                    subtitle: "Host, rebuilds, health sentinel, storage cleaner, preferences & apps",
                    badge: 4,
                    keys: ["system", "overview", "health", "general", "applications", "host", "rebuild", "gc", "sentinel", "preferences", "apps"]
                },
                {
                    key: "appearance", label: "Appearance", icon: "palette", brand: "appearance",
                    subtitle: "Theme presets, accent colors, wallpaper catalog, live engines & motion dynamics",
                    badge: 4,
                    keys: ["appearance", "theme", "colors", "accent", "transparency", "motion", "animations", "wallpapers", "wallpaper", "wallhaven", "wallpaperengine", "effects", "parallax"]
                },
                {
                    key: "workspace", label: "Workspace", icon: "dock_to_bottom", brand: "desktop",
                    subtitle: "Desktop bar layout, dynamic island notch, overlay widgets & staging shelf",
                    badge: 4,
                    keys: ["workspace", "bar", "island", "widgets", "desktop", "shelf"]
                },
                {
                    key: "hardware", label: "Hardware", icon: "monitor", brand: "display",
                    subtitle: "Displays, input devices, keyboard shortcuts, network VPN, power & virtual machines",
                    badge: 5,
                    keys: ["hardware", "display", "displays", "devices", "input", "keyboard", "mouse", "touchpad", "shortcuts", "vm", "machines", "idle", "power", "screen", "network", "vpn", "mullvad", "weather"]
                },
                {
                    key: "security", label: "Security & AI", icon: "shield", brand: "security",
                    subtitle: "Verified boot, AI assistants, progressive trust sandbox, credentials, privacy & alerts",
                    badge: 5,
                    keys: ["security", "vault", "keyring", "trust", "persistence", "privacy", "tpm", "boot", "ai", "intelligence", "notifications", "dnd", "credentials", "integrity"]
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

            // 3. 5-Category Routing Assertions
            layout.route("system")
            check("route to system", layout.current === "system")
            layout.route("rebuild")
            check("route alias rebuild -> system", layout.current === "system")
            layout.route("sentinel")
            check("route alias sentinel -> system", layout.current === "system")
            layout.route("health")
            check("route alias health -> system", layout.current === "system")
            layout.route("preferences")
            check("route alias preferences -> system", layout.current === "system")
            layout.route("apps")
            check("route alias apps -> system", layout.current === "system")

            layout.route("appearance")
            check("route to appearance", layout.current === "appearance")
            layout.route("theme")
            check("route alias theme -> appearance", layout.current === "appearance")
            layout.route("motion")
            check("route alias motion -> appearance", layout.current === "appearance")
            layout.route("accent")
            check("route alias accent -> appearance", layout.current === "appearance")
            layout.route("wallpapers")
            check("route alias wallpapers -> appearance", layout.current === "appearance")
            layout.route("wallhaven")
            check("route alias wallhaven -> appearance", layout.current === "appearance")
            layout.route("wallpaperengine")
            check("route alias wallpaperengine -> appearance", layout.current === "appearance")
            layout.route("effects")
            check("route alias effects -> appearance", layout.current === "appearance")

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

            layout.route("hardware")
            check("route to hardware", layout.current === "hardware")
            layout.route("display")
            check("route alias display -> hardware", layout.current === "hardware")
            layout.route("shortcuts")
            check("route alias shortcuts -> hardware", layout.current === "hardware")
            layout.route("network")
            check("route alias network -> hardware", layout.current === "hardware")
            layout.route("vpn")
            check("route alias vpn -> hardware", layout.current === "hardware")
            layout.route("weather")
            check("route alias weather -> hardware", layout.current === "hardware")
            layout.route("vm")
            check("route alias vm -> hardware", layout.current === "hardware")
            layout.route("input")
            check("route alias input -> hardware", layout.current === "hardware")
            layout.route("power")
            check("route alias power -> hardware", layout.current === "hardware")

            layout.route("security")
            check("route to security", layout.current === "security")
            layout.route("vault")
            check("route alias vault -> security", layout.current === "security")
            layout.route("ai")
            check("route alias ai -> security", layout.current === "security")
            layout.route("trust")
            check("route alias trust -> security", layout.current === "security")
            layout.route("keyring")
            check("route alias keyring -> security", layout.current === "security")
            layout.route("persistence")
            check("route alias persistence -> security", layout.current === "security")
            layout.route("privacy")
            check("route alias privacy -> security", layout.current === "security")
            layout.route("dnd")
            check("route alias dnd -> security", layout.current === "security")
            layout.route("notifications")
            check("route alias notifications -> security", layout.current === "security")
            layout.route("integrity")
            check("route alias integrity -> security", layout.current === "security")

            // 4. Sub-category Tab & Deep-Linking Resolution on Pages
            var pages = pagesLoader.item.byKey
            check("pSystem revealCard sub-tab rebuild", pages["system"].revealCard("rebuild"))
            check("pSystem revealCard sub-tab health", pages["system"].revealCard("health"))
            check("pSystem revealCard sub-tab preferences", pages["system"].revealCard("preferences"))
            check("pSystem revealCard sub-tab apps", pages["system"].revealCard("apps"))

            check("pAppearance revealCard sub-tab themes", pages["appearance"].revealCard("themes"))
            check("pAppearance revealCard sub-tab wallpapers", pages["appearance"].revealCard("wallpapers"))
            check("pAppearance revealCard sub-tab wallhaven", pages["appearance"].revealCard("wallhaven"))
            check("pAppearance revealCard sub-tab effects", pages["appearance"].revealCard("effects"))
            check("pAppearance revealCard sub-tab motion", pages["appearance"].revealCard("motion"))

            check("pWorkspace revealCard sub-tab bar", pages["workspace"].revealCard("bar"))
            check("pWorkspace revealCard sub-tab island", pages["workspace"].revealCard("island"))
            check("pWorkspace revealCard sub-tab widgets", pages["workspace"].revealCard("widgets"))
            check("pWorkspace revealCard sub-tab shelf", pages["workspace"].revealCard("shelf"))

            check("pHardware revealCard sub-tab displays", pages["hardware"].revealCard("displays"))
            check("pHardware revealCard sub-tab input", pages["hardware"].revealCard("input"))
            check("pHardware revealCard alias shortcuts", pages["hardware"].revealCard("shortcuts"))
            check("pHardware revealCard sub-tab network", pages["hardware"].revealCard("network"))
            check("pHardware revealCard alias vpn", pages["hardware"].revealCard("vpn"))
            check("pHardware revealCard alias weather", pages["hardware"].revealCard("weather"))
            check("pHardware revealCard sub-tab power", pages["hardware"].revealCard("power"))
            check("pHardware revealCard sub-tab vm", pages["hardware"].revealCard("vm"))

            check("pSecurity revealCard sub-tab integrity", pages["security"].revealCard("integrity"))
            check("pSecurity revealCard alias vault", pages["security"].revealCard("vault"))
            check("pSecurity revealCard sub-tab ai", pages["security"].revealCard("ai"))
            check("pSecurity revealCard sub-tab trust", pages["security"].revealCard("trust"))
            check("pSecurity revealCard sub-tab keyring", pages["security"].revealCard("keyring"))
            check("pSecurity revealCard sub-tab privacy", pages["security"].revealCard("privacy"))
            check("pSecurity revealCard alias notifications", pages["security"].revealCard("notifications"))
            check("pSecurity revealCard alias dnd", pages["security"].revealCard("dnd"))
            check("pSecurity revealCard alias persistence", pages["security"].revealCard("persistence"))

            // 5. Every search index entry routes, and every `card` anchor names
            //    a MujoCard or sub-view that actually exists on the page it routes to. A
            //    renamed card would otherwise silently degrade search to
            //    "lands on the right page, at the top".
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

            // 6. A card anchor is optional, and a bogus one fails loudly rather
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
