//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "./theme"
import "./components"
import "./services"
import "./modules/settings"
import "./modules/bar"

// Mujo (無常) Living Control Sanctuary.
// A redesigned, animated settings experience embodying impermanence, continuous flow, and transformation.
// Features 5 atmospheric Zen Domains (Sanctuary, Environment, Intelligence, Vessels, Sovereign),
// generative living canvas waveforms, omni-search command palette, and full live settings fidelity.
ShellRoot {
    FloatingWindow {
        id: win
        title: "mujō — 無常"
        implicitWidth: 1100
        implicitHeight: 740
        color: Theme.bg

        // Quit whenever the window closes so no headless process lingers
        property bool _shown: false
        onVisibleChanged: {
            if (visible) _shown = true
            else if (_shown) Qt.quit()
        }

        // ── Zen Domains Architecture ─────────────────────────────────────────
        readonly property var domains: [
            {
                id: "sanctuary",
                label: "Sanctuary",
                kanji: "透",
                icon: "dashboard",
                color: "#38BDF8",
                defaultSub: "overview",
                subSections: [
                    { key: "overview", label: "Overview Pulse", icon: "dashboard", brand: "overview" }
                ]
            },
            {
                id: "environment",
                label: "Environment",
                kanji: "景",
                icon: "palette",
                color: "#E879C7",
                defaultSub: "appearance",
                subSections: [
                    { key: "appearance", label: "Appearance & Theme", icon: "palette", brand: "appearance" },
                    { key: "animations", label: "Animations & Motion", icon: "motion_photos_on", brand: "animations" },
                    { key: "wallpaper",  label: "Wallpaper & Parallax", icon: "wallpaper", brand: "wallpaper" },
                    { key: "desktop",    label: "Desktop & Cava",     icon: "widgets", brand: "desktop" },
                    { key: "island",     label: "Dynamic Island",     icon: "blur_on", brand: "island" }
                ]
            },
            {
                id: "intelligence",
                label: "Intelligence",
                kanji: "流",
                icon: "psychology",
                color: "#8B5CF6",
                defaultSub: "ai",
                subSections: [
                    { key: "ai",            label: "AI & Neural Assistant", icon: "psychology", brand: "ai" },
                    { key: "notifications", label: "Notifications & Focus", icon: "notifications", brand: "notifications" },
                    { key: "weather",       label: "Weather & Climate",     icon: "partly_cloudy_day", brand: "weather" }
                ]
            },
            {
                id: "vessels",
                label: "Vessels",
                kanji: "器",
                icon: "monitor",
                color: "#22D3EE",
                defaultSub: "display",
                subSections: [
                    { key: "display", label: "Displays & Power",    icon: "monitor", brand: "display" },
                    { key: "devices", label: "Keyboard & Pointer",  icon: "keyboard", brand: "devices" }
                ]
            },
            {
                id: "sovereign",
                label: "Sovereign",
                kanji: "核",
                icon: "terminal",
                color: "#5277C3",
                defaultSub: "system",
                subSections: [
                    { key: "system",       label: "NixOS & Rebuild",       icon: "terminal", brand: "system" },
                    { key: "general",      label: "General & Defaults",    icon: "tune", brand: "general" },
                    { key: "network",      label: "Network & Mullvad VPN", icon: "vpn_lock", brand: "network" },
                    { key: "keyring",      label: "Keyring Vault",         icon: "key", brand: "keyring" },
                    { key: "persistence",  label: "Persistence Map",       icon: "hard_drive", brand: "persistence" },
                    { key: "shortcuts",    label: "Keyboard Matrix",       icon: "keyboard_command_key", brand: "shortcuts" },
                    { key: "applications", label: "Integrations & Apps",   icon: "apps", brand: "applications" }
                ]
            }
        ]

        // ── Active Navigation State ──────────────────────────────────────────
        property string activeDomainId: "sanctuary"
        property string currentPanel: "overview"

        readonly property var activeDomain: {
            for (var d = 0; d < domains.length; d++) {
                if (domains[d].id === activeDomainId) return domains[d]
            }
            return domains[0]
        }

        function selectDomain(dId) {
            for (var d = 0; d < domains.length; d++) {
                if (domains[d].id === dId) {
                    activeDomainId = dId
                    var subs = domains[d].subSections
                    var hasCurrent = false
                    for (var s = 0; s < subs.length; s++) {
                        if (subs[s].key === currentPanel) { hasCurrent = true; break }
                    }
                    if (!hasCurrent) {
                        currentPanel = domains[d].defaultSub || subs[0].key
                    }
                    return
                }
            }
        }

        function selectPanel(panelKey) {
            for (var d = 0; d < domains.length; d++) {
                var subs = domains[d].subSections
                for (var s = 0; s < subs.length; s++) {
                    if (subs[s].key === panelKey) {
                        activeDomainId = domains[d].id
                        currentPanel = panelKey
                        return
                    }
                }
            }
        }

        // ── Search Index (Comprehensive mapping) ─────────────────────────────
        readonly property var searchIndex: [
            // Sanctuary / Overview
            { title: "System status overview", desc: "Live vitals, system metrics, hardware telemetry", cat: "Sanctuary", key: "overview" },
            { title: "Quick controls",      desc: "Live toggles for Wi-Fi, Bluetooth, DND, VPN", cat: "Sanctuary", key: "overview" },
            { title: "Active media playback",desc: "Currently playing track and MPRIS controls", cat: "Sanctuary", key: "overview" },

            // Environment
            { title: "Theme preset",        desc: "Catppuccin, Ayu, Dracula, Nord, Gruvbox…", cat: "Environment", key: "appearance" },
            { title: "Accent color override",desc: "Custom hex or curated palette accent color", cat: "Environment", key: "appearance" },
            { title: "Animation intensity", desc: "Minimal, Balanced, or Expressive motion profile", cat: "Environment", key: "animations" },
            { title: "Ambient motion & breathing", desc: "Living background flow, Ensō breathing, particle fields", cat: "Environment", key: "animations" },
            { title: "Live motion preview", desc: "Interactive canvas showcase demonstrating Mujo physics and spring loops", cat: "Environment", key: "animations" },
            { title: "Page & domain transitions", desc: "Kinematic spatial transitions when switching between Zen domains", cat: "Environment", key: "animations" },
            { title: "Reduced motion override", desc: "Accessibility preference eliminating spatial and continuous motion", cat: "Environment", key: "animations" },
            { title: "Performance mode", desc: "Reduce GPU/rendering load on low-power hardware", cat: "Environment", key: "animations" },
            { title: "Surface opacity",     desc: "Translucent glass alpha and blur controls", cat: "Environment", key: "appearance" },
            { title: "Bar layout & modules",desc: "Bar position, height, margin, and right cluster ordering", cat: "Environment", key: "appearance" },
            { title: "Wallpaper library",   desc: "Apply from local curated wallpaper collection", cat: "Environment", key: "wallpaper" },
            { title: "Wallhaven browser",   desc: "Search, preview, and download wallpapers online", cat: "Environment", key: "wallpaper" },
            { title: "Wallpaper Engine browser", desc: "Browse Steam Workshop Wallpaper Engine (431960) and installed live projects", cat: "Environment", key: "wallpaper" },
            { title: "Wallpaper Engine performance", desc: "Live wallpaper FPS limit, audio automute, and sound volume", cat: "Environment", key: "wallpaper" },
            { title: "Cursor parallax",     desc: "Dynamic wallpaper pan and depth motion on mouse move", cat: "Environment", key: "wallpaper" },
            { title: "Desktop widgets",     desc: "Clock, system telemetry, and weather desktop overlays", cat: "Environment", key: "desktop" },
            { title: "Audio visualizer",    desc: "Cava spectrum visualizer style, color, and responsiveness", cat: "Environment", key: "desktop" },
            { title: "Shelf drop zone",     desc: "Staging drawer for files and dragging items", cat: "Environment", key: "desktop" },
            { title: "Dynamic Island",      desc: "Status notch: modules, geometry, animations, and auto-expand", cat: "Environment", key: "island" },

            // Intelligence
            { title: "AI provider & model", desc: "Ollama local, OpenAI, Claude, model name and base URL", cat: "Intelligence", key: "ai" },
            { title: "AI API credentials",  desc: "Keyring token storage and endpoint authentication", cat: "Intelligence", key: "ai" },
            { title: "AI privacy guards",   desc: "Context sharing, crash data opt-in, action confirmation", cat: "Intelligence", key: "ai" },
            { title: "Do Not Disturb",      desc: "Silence notification banners and toast alerts", cat: "Intelligence", key: "notifications" },
            { title: "Notification position",desc: "Screen corner gravity and toast timeout", cat: "Intelligence", key: "notifications" },
            { title: "Per-app notification muting", desc: "Selectively mute applications", cat: "Intelligence", key: "notifications" },
            { title: "Weather location",    desc: "City auto-detect, temperature units (°C/°F), refresh rate", cat: "Intelligence", key: "weather" },

            // Vessels (Hardware)
            { title: "Display resolution & Hz", desc: "Resolution, refresh rate, and HiDPI scaling per screen", cat: "Vessels", key: "display" },
            { title: "Visual monitor layout", desc: "Arrangement, orientation, and primary screen setup", cat: "Vessels", key: "display" },
            { title: "Idle & power timers", desc: "Dim screen, display turn-off, lock screen, and suspend", cat: "Vessels", key: "display" },
            { title: "Keyboard repeat & delay", desc: "Key repeat rate and initial delay sensitivity", cat: "Vessels", key: "devices" },
            { title: "Keyboard layout",     desc: "XKB keymap layout and language variants", cat: "Vessels", key: "devices" },
            { title: "Pointer & Touchpad",  desc: "Mouse acceleration profile, natural scrolling, tap-to-click", cat: "Vessels", key: "devices" },

            // Sovereign (System)
            { title: "NixOS rebuild switch",desc: "Apply and switch host configuration with pkexec escalation", cat: "Sovereign", key: "system" },
            { title: "Generation history",  desc: "Inspect current and past bootable system generations", cat: "Sovereign", key: "system" },
            { title: "System overrides",    desc: "Local module drop-in overrides and flake inspect", cat: "Sovereign", key: "system" },
            { title: "General preferences", desc: "Hostname, timezone, locale, store hardlinking", cat: "Sovereign", key: "general" },
            { title: "Default applications",desc: "MIME handlers for browser, editor, terminal, file manager", cat: "Sovereign", key: "general" },
            { title: "Clipboard history",   desc: "Max clipboard clips, sensitive filter, image cache", cat: "Sovereign", key: "general" },
            { title: "Mullvad VPN",         desc: "WireGuard connection, relay location, and boot auto-connect", cat: "Sovereign", key: "network" },
            { title: "Keyring vault",       desc: "Secure credentials, secret specs, and reveal tokens", cat: "Sovereign", key: "keyring" },
            { title: "Impermanence storage",desc: "Persistent directories and files surviving btrfs boot wipe", cat: "Sovereign", key: "persistence" },
            { title: "Keyboard shortcuts",  desc: "Interactive searchable matrix of Niri window bindings", cat: "Sovereign", key: "shortcuts" },
            { title: "Integrations & Apps", desc: "Discord, Obsidian, Claude, Steam, Flatpaks, sandboxing", cat: "Sovereign", key: "applications" }
        ]

        property string query: ""
        property int searchSel: 0
        readonly property bool searching: query.trim() !== ""

        function score(e, q) {
            var t = e.title.toLowerCase(), d = e.desc.toLowerCase(), c = e.cat.toLowerCase()
            if (t.indexOf(q) === 0) return 100
            if (t.indexOf(q) >= 0) return 80
            if (c.indexOf(q) >= 0) return 60
            if (d.indexOf(q) >= 0) return 40
            var j = 0
            for (var i = 0; i < t.length && j < q.length; i++) if (t[i] === q[j]) j++
            return j === q.length ? 20 : -1
        }
        readonly property var results: {
            var q = query.trim().toLowerCase()
            if (q === "") return []
            var scored = []
            for (var i = 0; i < searchIndex.length; i++) {
                var s = score(searchIndex[i], q)
                if (s >= 0) scored.push({ e: searchIndex[i], s: s })
            }
            scored.sort(function(a, b) { return b.s - a.s })
            return scored.map(function(x) { return x.e })
        }
        function activateResult(i) {
            if (i < 0 || i >= results.length) return
            selectPanel(results[i].key)
            query = ""
            searchField.text = ""
        }

        // ── Panel Components ─────────────────────────────────────────────────
        Component { id: overviewComp;      OverviewPanel {} }
        Component { id: generalComp;       GeneralPanel {} }
        Component { id: appearanceComp;    AppearancePanel {} }
        Component { id: animationsComp;    AnimationsPanel {} }
        Component { id: wallpaperComp;     WallpaperPanel {} }
        Component { id: desktopComp;       DesktopPanel {} }
        Component { id: islandComp;        IslandPanel {} }
        Component { id: weatherComp;       WeatherPanel {} }
        Component { id: aiComp;            AiPanel {} }
        Component { id: notificationsComp; NotificationsPanel {} }
        Component { id: displayComp;       DisplayPanel {} }
        Component { id: devicesComp;       DevicesPanel {} }
        Component { id: networkComp;       NetworkPanel {} }
        Component { id: keyringComp;       KeyringPanel {} }
        Component { id: persistenceComp;   PersistencePanel {} }
        Component { id: shortcutsComp;     ShortcutsPanel {} }
        Component { id: systemComp;        SystemPanel {} }
        Component { id: applicationsComp;  ApplicationsPanel {} }

        function componentFor(key) {
            return key === "overview"     ? overviewComp
                 : key === "general"      ? generalComp
                 : key === "appearance"   ? appearanceComp
                 : key === "animations"   ? animationsComp
                 : key === "wallpaper"    ? wallpaperComp
                 : key === "desktop"      ? desktopComp
                 : key === "island"       ? islandComp
                 : key === "weather"      ? weatherComp
                 : key === "ai"           ? aiComp
                 : key === "notifications"? notificationsComp
                 : key === "display"      ? displayComp
                 : key === "devices"      ? devicesComp
                 : key === "network"      ? networkComp
                 : key === "keyring"      ? keyringComp
                 : key === "persistence"  ? persistenceComp
                 : key === "shortcuts"    ? shortcutsComp
                 : key === "system"       ? systemComp
                 : applicationsComp
        }

        // Panel-routing target file (from `mujo settings <key>`)
        FileView {
            path: (Quickshell.env("HOME") || "/tmp") + "/.config/qsshell/settings-target"
            watchChanges: true
            onFileChanged: reload()
            onLoaded: win.selectPanel(text().trim())
        }

        // Signal bus so panels can request navigation (e.g. Overview cards)
        Connections {
            target: SettingsBus
            function onNavigate(key) { win.selectPanel(key) }
        }

        // ── Main UI Layout ───────────────────────────────────────────────────
        Item {
            id: mainContainer
            anchors.fill: parent

            // Ambient background glow from living canvas
            MujoLivingCanvas {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -60
                anchors.topMargin: -40
                width: 480
                height: 300
                opacity: 0.08
                accentColor: win.activeDomain.color || Theme.accent
                flowSpeed: 0.4
                showEnso: true
                showWaves: true
                showParticles: false
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── 1. Top Zen Header: Brand · Kanji Seal · Omni-Search · Status ─────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: Theme.surface
                    border.color: "transparent"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 18
                        spacing: 16

                        // Brand Capsule: Icon + "mujō" + living "無常" kanji seal
                        RowLayout {
                            spacing: 12
                            Layout.alignment: Qt.AlignVCenter

                            BrandIcon {
                                brand: "mujo"
                                size: 34
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: "mujō"
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeTitle + 3
                                        font.bold: true
                                    }

                                    // Living Kanji Seal
                                    Rectangle {
                                        implicitWidth: kSeal.implicitWidth + 8
                                        implicitHeight: 18
                                        radius: Theme.radiusSm
                                        color: Theme.withAlpha(win.activeDomain.color || Theme.accent, 0.14)
                                        border.color: Theme.withAlpha(win.activeDomain.color || Theme.accent, 0.4)
                                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.standard) } }
                                        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.standard) } }

                                        Text {
                                            id: kSeal
                                            anchors.centerIn: parent
                                            text: "無常"
                                            color: win.activeDomain.color || Theme.accent
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeLabel - 1
                                            font.bold: true
                                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.standard) } }
                                        }
                                    }
                                }

                                Text {
                                    text: "Living Sanctuary"
                                    color: Theme.textDim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel - 1
                                }
                            }
                        }

                        // Omni-Search Input Field
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 460
                            Layout.alignment: Qt.AlignHCenter
                            implicitHeight: 38
                            radius: Theme.radiusMd
                            color: Theme.withAlpha(Theme.bg, 0.85)
                            border.color: searchField.activeFocus ? Theme.accent : Theme.border
                            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 8

                                MaterialIcon {
                                    iconName: "search"
                                    pixelSize: 18
                                    color: searchField.activeFocus ? Theme.accent : Theme.textSecondary
                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                }

                                TextInput {
                                    id: searchField
                                    Layout.fillWidth: true
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    selectByMouse: true
                                    onTextChanged: { win.query = text; win.searchSel = 0 }
                                    Keys.onDownPressed: if (win.searching) win.searchSel = Math.min(win.searchSel + 1, win.results.length - 1)
                                    Keys.onUpPressed: if (win.searching) win.searchSel = Math.max(win.searchSel - 1, 0)
                                    Keys.onReturnPressed: win.activateResult(win.searchSel)
                                    Keys.onEscapePressed: { if (text === "") Qt.quit(); else { text = ""; win.query = "" } }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: searchField.text === ""
                                        text: "Omni-search settings, preferences, controls…"
                                        color: Theme.textDim
                                        font: searchField.font
                                    }
                                }

                                Rectangle {
                                    visible: searchField.text === ""
                                    implicitWidth: slashTxt.implicitWidth + 8
                                    implicitHeight: 18
                                    radius: Theme.radiusSm
                                    color: Theme.withAlpha(Theme.surfaceActive, 0.7)
                                    border.color: Theme.border

                                    Text {
                                        id: slashTxt
                                        anchors.centerIn: parent
                                        text: "/"
                                        color: Theme.textDim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                    }
                                }

                                Rectangle {
                                    visible: searchField.text !== ""
                                    implicitWidth: 34; implicitHeight: 18
                                    radius: Theme.radiusSm
                                    color: Theme.surface
                                    border.color: Theme.border
                                    Text {
                                        anchors.centerIn: parent
                                        text: "esc"
                                        color: Theme.textDim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                    }
                                }
                            }
                        }

                        // Right Glance Capsules
                        RowLayout {
                            spacing: 8
                            Layout.alignment: Qt.AlignVCenter

                            // Active Theme Pill
                            Rectangle {
                                implicitWidth: themeLbl.implicitWidth + 16
                                implicitHeight: 28
                                radius: Theme.radiusSm
                                color: Theme.withAlpha(Theme.accent, 0.1)
                                border.color: Theme.withAlpha(Theme.accent, 0.3)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: Theme.accent
                                    }
                                    Text {
                                        id: themeLbl
                                        text: Theme.presetLabels[Theme.presetName] || Theme.presetName
                                        color: Theme.text
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel
                                        font.bold: true
                                    }
                                }
                                HoverHandler { id: thHh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: win.selectPanel("appearance") }
                            }

                            // Close Window Button
                            IconButton {
                                iconName: "close"
                                onClicked: Qt.quit()
                            }
                        }
                    }
                }

                // ── 2. Zen Domain Navigation Ribbon ──────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    color: Theme.surface
                    border.color: "transparent"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 8

                        Repeater {
                            model: win.domains
                            delegate: Rectangle {
                                id: dTab
                                required property var modelData
                                readonly property bool isSelected: win.activeDomainId === modelData.id && !win.searching
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: Theme.radiusMd
                                color: isSelected ? Theme.withAlpha(modelData.color, 0.14) : (dTabHh.hovered ? Theme.surfaceHover : "transparent")
                                border.color: isSelected ? Theme.withAlpha(modelData.color, 0.45) : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    // Kanji seal stamp
                                    Text {
                                        text: dTab.modelData.kanji
                                        color: dTab.isSelected ? dTab.modelData.color : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                    }

                                    MaterialIcon {
                                        iconName: dTab.modelData.icon
                                        pixelSize: 17
                                        color: dTab.isSelected ? dTab.modelData.color : (dTabHh.hovered ? Theme.text : Theme.textSecondary)
                                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                    }

                                    Text {
                                        text: dTab.modelData.label
                                        color: dTab.isSelected ? Theme.text : (dTabHh.hovered ? Theme.text : Theme.textSecondary)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeBody
                                        font.bold: dTab.isSelected
                                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                    }
                                }

                                HoverHandler { id: dTabHh; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        win.query = ""
                                        searchField.text = ""
                                        win.selectDomain(dTab.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 3. Contextual Sub-Navigation Ribbon (if domain has >1 sub) ───────
                Rectangle {
                    visible: win.activeDomain.subSections.length > 1 && !win.searching
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Theme.withAlpha(Theme.surface, 0.6)
                    border.color: "transparent"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    Flickable {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        contentWidth: subRow.implicitWidth + 20
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        RowLayout {
                            id: subRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Repeater {
                                model: win.activeDomain.subSections
                                delegate: Rectangle {
                                    id: subTab
                                    required property var modelData
                                    readonly property bool isSubSelected: win.currentPanel === modelData.key
                                    implicitHeight: 28
                                    implicitWidth: subTabContent.implicitWidth + 20
                                    radius: Theme.radiusSm
                                    color: isSubSelected ? Theme.accentDim : (subHh.hovered ? Theme.surfaceHover : "transparent")
                                    border.color: isSubSelected ? Theme.withAlpha(Theme.accent, 0.4) : "transparent"
                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                    RowLayout {
                                        id: subTabContent
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialIcon {
                                            iconName: subTab.modelData.icon
                                            pixelSize: 15
                                            color: subTab.isSubSelected ? Theme.accent : (subHh.hovered ? Theme.text : Theme.textSecondary)
                                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                        }

                                        Text {
                                            text: subTab.modelData.label
                                            color: subTab.isSubSelected ? Theme.text : (subHh.hovered ? Theme.text : Theme.textSecondary)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.bold: subTab.isSubSelected
                                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                        }
                                    }

                                    HoverHandler { id: subHh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            win.currentPanel = subTab.modelData.key
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 4. Main Living Content / Search Results Host ─────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // Panel Host
                    Item {
                        id: panelHost
                        anchors.fill: parent
                        visible: !win.searching
                        opacity: 1
                        clip: true
                        transform: Translate { id: panelShift; y: 0 }

                        Loader {
                            anchors.fill: parent
                            sourceComponent: win.componentFor(win.currentPanel)
                        }

                        Connections {
                            target: win
                            function onCurrentPanelChanged() { if (Anim.pageTransitions) panelIn.restart() }
                            function onActiveDomainIdChanged() { if (Anim.pageTransitions) panelIn.restart() }
                        }

                        ParallelAnimation {
                            id: panelIn
                            NumberAnimation { target: panelHost; property: "opacity"; from: 0; to: 1; duration: Anim.d(Anim.enter); easing.type: Anim.easeEnter }
                            NumberAnimation { target: panelShift; property: "y"; from: 10; to: 0; duration: Anim.d(Anim.enter); easing.type: Anim.easeStandard }
                        }
                    }

                    // Omni-Search Results Overlay
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 28
                        visible: win.searching
                        contentHeight: resCol.implicitHeight + 30
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: resCol
                            width: parent.width
                            spacing: 10

                            RowLayout {
                                spacing: 8
                                Layout.bottomMargin: 4

                                Text {
                                    text: win.results.length + (win.results.length === 1 ? " setting discovered" : " settings discovered")
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Text {
                                    text: "• Use ↑↓ arrows to navigate, Enter to select"
                                    color: Theme.textDim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                }
                            }

                            Repeater {
                                model: win.results
                                delegate: Rectangle {
                                    id: resCard
                                    required property var modelData
                                    required property int index
                                    readonly property bool sel: index === win.searchSel
                                    Layout.fillWidth: true
                                    implicitHeight: 60
                                    radius: Theme.radiusMd
                                    color: sel ? Theme.accentDim : (resHh.hovered ? Theme.surfaceHover : Theme.surface)
                                    border.color: sel ? Theme.accent : Theme.border
                                    border.width: sel ? 1.5 : 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 16
                                        spacing: 14

                                        BrandIcon {
                                            brand: resCard.modelData.key
                                            size: 34
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: resCard.modelData.title
                                                color: Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeBody + 1
                                                font.bold: true
                                            }

                                            Text {
                                                text: resCard.modelData.desc
                                                color: Theme.textSecondary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Rectangle {
                                            implicitWidth: catBadge.implicitWidth + 14
                                            implicitHeight: 22
                                            radius: Theme.radiusSm
                                            color: Theme.bg
                                            border.color: Theme.border

                                            Text {
                                                id: catBadge
                                                anchors.centerIn: parent
                                                text: resCard.modelData.cat
                                                color: Theme.accent
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontSizeLabel
                                                font.bold: true
                                            }
                                        }
                                    }

                                    HoverHandler { id: resHh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: win.activateResult(index) }
                                }
                            }

                            Text {
                                visible: win.results.length === 0
                                text: "No settings match “" + win.query + "”. Try searching for display, theme, nixos, or ai."
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                Layout.topMargin: 24
                            }
                        }
                    }
                }
            }
        }
    }
}
