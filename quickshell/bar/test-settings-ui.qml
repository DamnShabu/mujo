import QtQuick
import Quickshell
import "modules/settings"
import "modules/settings/SearchIndex.js" as SearchIndex
import "services"
import "theme"

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
            searchIndex: SearchIndex.entries
            categories: [
                {
                    key: "system", label: "System", icon: "tune", brand: "system",
                    subtitle: "Host, rebuilds, health sentinel, storage cleaner, preferences & apps",
                    subs: [
                        { id: "rebuild",     label: "Host & Rebuild",   icon: "autorenew" },
                        { id: "health",      label: "Health & Storage", icon: "health_and_safety" },
                        { id: "preferences", label: "Preferences",      icon: "tune" },
                        { id: "apps",        label: "Applications",     icon: "apps" }
                    ],
                    keys: ["system", "overview", "health", "general", "applications", "host", "rebuild", "gc", "sentinel", "preferences", "apps"]
                },
                {
                    key: "appearance", label: "Appearance", icon: "palette", brand: "appearance",
                    subtitle: "Theme presets, accent colors, wallpaper catalog, live engines & motion dynamics",
                    subs: [
                        { id: "themes",     label: "Themes & Colors",   icon: "palette" },
                        { id: "wallpapers", label: "Wallpapers",        icon: "photo_library" },
                        { id: "effects",    label: "Wallpaper Effects", icon: "tune" },
                        { id: "motion",     label: "Motion Dynamics",   icon: "animation" }
                    ],
                    keys: ["appearance", "theme", "colors", "accent", "transparency", "motion", "animations", "wallpapers", "wallpaper", "wallhaven", "wallpaperengine", "effects", "parallax"]
                },
                {
                    key: "workspace", label: "Workspace", icon: "dock_to_bottom", brand: "desktop",
                    subtitle: "Desktop bar layout, dynamic island notch, overlay widgets, notifications, weather & staging shelf",
                    subs: [
                        { id: "bar",           label: "Desktop Bar",          icon: "dock_to_bottom" },
                        { id: "island",        label: "Dynamic Island",       icon: "dynamic_form" },
                        { id: "widgets",       label: "Overlay Widgets",      icon: "widgets" },
                        { id: "notifications", label: "Notifications & DND",  icon: "notifications" },
                        { id: "weather",       label: "Weather",              icon: "wb_sunny" },
                        { id: "shelf",         label: "Shelf",                icon: "inventory_2" }
                    ],
                    keys: ["workspace", "bar", "island", "widgets", "desktop", "shelf", "notifications", "dnd", "weather"]
                },
                {
                    key: "hardware", label: "Hardware", icon: "monitor", brand: "display",
                    subtitle: "Displays, input devices, keyboard shortcuts, power & virtual machines",
                    subs: [
                        { id: "displays", label: "Displays",         icon: "monitor" },
                        { id: "input",    label: "Input & Keys",     icon: "keyboard" },
                        { id: "power",    label: "Power & Sleep",    icon: "power_settings_new" },
                        { id: "network",  label: "Network & VPN",    icon: "vpn_key" },
                        { id: "vm",       label: "Virtual Machines", icon: "dns" }
                    ],
                    keys: ["hardware", "display", "displays", "devices", "input", "keyboard", "mouse", "touchpad", "shortcuts", "vm", "machines", "idle", "power", "screen", "network", "vpn", "mullvad"]
                },
                {
                    key: "security", label: "Security & Privacy", icon: "shield", brand: "security",
                    subtitle: "Verified boot, progressive trust sandbox, credentials, AI assistants & persistence",
                    subs: [
                        { id: "integrity",   label: "System Integrity",      icon: "verified_user" },
                        { id: "trust",       label: "Trust & Sandbox",       icon: "shield" },
                        { id: "keyring",     label: "Credentials",           icon: "password" },
                        { id: "ai",          label: "AI Assistants",         icon: "psychology" },
                        { id: "persistence", label: "Persistence & Privacy", icon: "security" }
                    ],
                    keys: ["security", "vault", "keyring", "trust", "persistence", "privacy", "tpm", "boot", "ai", "intelligence", "credentials", "integrity"]
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
            layout.route("notifications")
            check("route alias notifications -> workspace", layout.current === "workspace")
            layout.route("dnd")
            check("route alias dnd -> workspace", layout.current === "workspace")
            layout.route("weather")
            check("route alias weather -> workspace", layout.current === "workspace")
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
            layout.route("integrity")
            check("route alias integrity -> security", layout.current === "security")

            // 4. Sub-category Tab & Deep-Linking Resolution on Pages
            var pages = pagesLoader.item.byKey
            check("pSystem revealCard sub-tab rebuild", pages["system"].revealCard("rebuild"))
            check("pSystem revealCard sub-tab health", pages["system"].revealCard("health"))
            check("pSystem revealCard sub-tab preferences", pages["system"].revealCard("preferences"))
            check("pSystem revealCard sub-tab apps", pages["system"].revealCard("apps"))

            check("pAppearance revealCard sub-tab themes", pages["appearance"].revealCard("themes"))
            check("pAppearance revealCard card Appearance Mode", pages["appearance"].revealCard("Appearance Mode"))
            check("pAppearance revealCard card Automated Day & Night Schedule", pages["appearance"].revealCard("Automated Day & Night Schedule"))
            check("pAppearance revealCard sub-tab wallpapers", pages["appearance"].revealCard("wallpapers"))
            check("pAppearance revealCard sub-tab wallhaven", pages["appearance"].revealCard("wallhaven"))
            check("pAppearance revealCard sub-tab effects", pages["appearance"].revealCard("effects"))
            check("pAppearance revealCard sub-tab motion", pages["appearance"].revealCard("motion"))

            check("pWorkspace revealCard sub-tab bar", pages["workspace"].revealCard("bar"))
            check("pWorkspace revealCard sub-tab island", pages["workspace"].revealCard("island"))
            check("pWorkspace revealCard sub-tab widgets", pages["workspace"].revealCard("widgets"))
            check("pWorkspace revealCard sub-tab notifications", pages["workspace"].revealCard("notifications"))
            check("pWorkspace revealCard alias dnd", pages["workspace"].revealCard("dnd"))
            check("pWorkspace revealCard sub-tab weather", pages["workspace"].revealCard("weather"))
            check("pWorkspace revealCard sub-tab shelf", pages["workspace"].revealCard("shelf"))

            check("pHardware revealCard sub-tab displays", pages["hardware"].revealCard("displays"))
            check("pHardware revealCard sub-tab input", pages["hardware"].revealCard("input"))
            check("pHardware revealCard alias shortcuts", pages["hardware"].revealCard("shortcuts"))
            check("pHardware revealCard sub-tab network", pages["hardware"].revealCard("network"))
            check("pHardware revealCard alias vpn", pages["hardware"].revealCard("vpn"))
            check("pHardware revealCard sub-tab power", pages["hardware"].revealCard("power"))
            check("pHardware revealCard sub-tab vm", pages["hardware"].revealCard("vm"))

            check("pSecurity revealCard sub-tab integrity", pages["security"].revealCard("integrity"))
            check("pSecurity revealCard alias vault", pages["security"].revealCard("vault"))
            check("pSecurity revealCard sub-tab trust", pages["security"].revealCard("trust"))
            check("pSecurity revealCard sub-tab keyring", pages["security"].revealCard("keyring"))
            check("pSecurity revealCard sub-tab ai", pages["security"].revealCard("ai"))
            check("pSecurity revealCard sub-tab persistence", pages["security"].revealCard("persistence"))
            check("pSecurity revealCard alias privacy", pages["security"].revealCard("privacy"))

            // 4b. Sidebar hierarchy. Every sub-category the rail offers must be
            //     a tab its page actually has: an id that drifts out of step
            //     with `tabIds` selects the category and then silently lands on
            //     whichever tab happened to be open, which looks like the click
            //     was ignored.
            var badSub = []
            for (var ci = 0; ci < layout.categories.length; ci++) {
                var cdef = layout.categories[ci]
                var cpage = pages[cdef.key]
                var csubs = cdef.subs || []
                check("category declares sub-categories: " + cdef.key, csubs.length > 0)
                for (var si = 0; si < csubs.length; si++) {
                    if (!cpage || cpage.tabIds.indexOf(csubs[si].id) < 0)
                        badSub.push(cdef.key + "/" + csubs[si].id)
                }
            }
            check("every sidebar sub-category is a real page tab", badSub.length === 0)
            for (var bs = 0; bs < badSub.length; bs++) root.fails.push("  no such tab: " + badSub[bs])

            // The rail is one flat list: the parents, plus the children of the
            // single open branch. An accordion, so opening one closes the rest.
            layout.select("workspace")
            var wsSubs = 6
            check("rail shows every category", layout.railRows.length === layout.categories.length + wsSubs)
            check("rail opens the selected category", layout.expandedKey === "workspace")
            layout.select("security")
            check("rail closes the previous branch", layout.expandedKey === "security")
            check("rail row count follows the open branch",
                  layout.railRows.length === layout.categories.length + 5)

            // Selecting a sub-category drives the page's own tab, which is what
            // replaced the per-page segmented control. The two halves of that
            // chain are checked separately: the layout parks the sub id for the
            // page host to flush (route() defers via Qt.callLater, and this
            // harness has no live page behind the layout), and the page's own
            // revealCard turns that id into a tab.
            layout.route("workspace", "island")
            check("sub-category is handed to the page", layout.pendingCard === "island")
            check("page turns the sub id into a tab",
                  pages["workspace"].revealCard("island") && pages["workspace"].tab === "island")
            check("page switches tab again",
                  pages["workspace"].revealCard("shelf") && pages["workspace"].tab === "shelf")

            // Arrow keys walk into an open branch rather than skipping it, and
            // never collapse it on the way past.
            layout.select("system")
            layout.step(1)
            check("Down enters the open branch", layout.current === "system" && layout.expandedKey === "system")
            layout.step(-1)
            check("Up leaves the branch to the row above", layout.current === "system")

            // 5. Every search index entry routes, adheres to schema (title, desc, cat, key, card, tags),
            //    and every `card` anchor names a MujoCard or sub-view that actually exists on the page it routes to.
            var validCats = ["System", "Appearance", "Workspace", "Hardware", "Security & Privacy"]
            var badRoute = []
            var badCard = []
            var badSchema = []
            var badCat = []
            for (var e = 0; e < SearchIndex.entries.length; e++) {
                var entry = SearchIndex.entries[e]
                if (!entry.title || !entry.desc || !entry.cat || !entry.key || !entry.card || !Array.isArray(entry.tags) || entry.tags.length === 0) {
                    badSchema.push(entry.title || ("entry #" + e))
                }
                if (validCats.indexOf(entry.cat) < 0) badCat.push(entry.title + " (cat: " + entry.cat + ")")
                layout.route(entry.key)
                var cat = layout.current
                if (!pages[cat]) { badRoute.push(entry.title + " → " + entry.key); continue }
                if (entry.card === undefined) continue
                if (!pages[cat].revealCard(entry.card)) badCard.push(entry.title + " → " + entry.card)
            }
            check("every search entry satisfies schema (title, desc, cat, key, card, tags)", badSchema.length === 0)
            check("every search entry has valid category enum", badCat.length === 0)
            check("every search entry routes to a real category", badRoute.length === 0)
            check("every search card anchor resolves", badCard.length === 0)
            for (var bs0 = 0; bs0 < badSchema.length; bs0++) root.fails.push("  invalid schema: " + badSchema[bs0])
            for (var bc0 = 0; bc0 < badCat.length; bc0++) root.fails.push("  invalid category: " + badCat[bc0])
            for (var b = 0; b < badRoute.length; b++) root.fails.push("  unroutable: " + badRoute[b])
            for (var d = 0; d < badCard.length; d++) root.fails.push("  no such card: " + badCard[d])

            // 5b. Search scoring and tags match verification
            layout.setQuery("wireguard")
            check("search query 'wireguard' finds VPN tunnel via tags/desc", layout.results.length > 0)
            layout.setQuery("zombies")
            check("search query 'zombies' finds sentinel via tags/desc", layout.results.length > 0)
            layout.setQuery("dark")
            check("search query 'dark' finds appearance mode", layout.results.length > 0)
            layout.clearSearch()
            check("clearSearch resets query and results", layout.results.length === 0 && layout.query === "")

            // 6. A card anchor is optional, and a bogus one fails loudly rather
            //    than throwing.
            check("unknown card anchor returns false", page.revealCard("No Such Card") === false)

            // 7. Theme color resolution & dynamic reactivity
            var origPreset = Theme.presetName
            var origMode = Theme.mode
            Theme.mode = "dark"
            Theme.presetName = "nord"
            check("Theme.bg resolves preset bg on Nord", Theme.bg.toString() === Theme.withAlpha(Theme.presets.nord.bg, Theme.transparency).toString())
            check("Theme.surface resolves preset surface on Nord", Theme.surface.toString() === Theme.withAlpha(Theme.presets.nord.surface, Theme.transparency).toString())
            check("Theme.isDark is true for Nord", Theme.isDark === true)
            check("Theme.isLight is false for Nord", Theme.isLight === false)

            Theme.presetName = "dracula"
            check("Theme.bg updates dynamically on Dracula", Theme.bg.toString() === Theme.withAlpha(Theme.presets.dracula.bg, Theme.transparency).toString())
            check("Theme.surface updates dynamically on Dracula", Theme.surface.toString() === Theme.withAlpha(Theme.presets.dracula.surface, Theme.transparency).toString())

            // 8. Light / Dark mode switching & counterpart pairing assertions
            Theme.mode = "light"
            check("Theme.effectivePreset resolves light counterpart on light mode", Theme.effectivePreset === "dracula_light")
            check("Theme.isLight is true in light mode", Theme.isLight === true)
            check("Theme.isDark is false in light mode", Theme.isDark === false)
            check("Theme.bg resolves light bg", Theme.bg.toString() === Theme.withAlpha(Theme.presets.dracula_light.bg, Theme.transparency).toString())

            Theme.presetName = "catppuccin"
            check("Catppuccin resolves to catppuccin_latte in light mode", Theme.effectivePreset === "catppuccin_latte")
            Theme.mode = "dark"
            check("Catppuccin resolves to dark catppuccin in dark mode", Theme.effectivePreset === "catppuccin")

            // 9. Schedule assertions
            Theme.mode = "auto"
            Theme.scheduleType = "time"
            Theme.dayStart = "00:00"
            Theme.nightStart = "23:59"
            Theme.darkPreset = "catppuccin"
            Theme.lightPreset = "catppuccin_latte"
            Theme.updateSchedule()
            check("Auto mode daytime resolves lightPreset", Theme.effectivePreset === "catppuccin_latte")

            // Verify counterpart bidirectional mapping integrity across all presets
            var counterpartFails = 0
            for (var pi = 0; pi < Theme.presetOrder.length; pi++) {
                var dp = Theme.presetOrder[pi]
                var lp = Theme.darkToLight[dp]
                if (!lp || !Theme.presets[lp] || Theme.lightToDark[lp] !== dp) counterpartFails++
            }
            check("All 24 dark presets have valid bidirectional light counterparts", counterpartFails === 0)

            Theme.presetName = origPreset
            Theme.mode = origMode
            Theme.updateSchedule()

            pagesLoader.sourceComponent = null

            if (root.fails.length === 0) {
                console.log("PASS  settings UI: IA routing, aliases, store bindings, light/dark mode, schedule, and search card anchors verified")
            } else {
                console.log("FAIL  settings UI: " + root.fails.length + " check(s) failed")
                for (var i = 0; i < root.fails.length; i++) console.log("        - " + root.fails[i])
            }
            Qt.exit(root.fails.length === 0 ? 0 : 1)
        }
    }
}
