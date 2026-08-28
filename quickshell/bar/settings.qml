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

// mujō (無常) — Desktop Settings.
// Clean, high-readability split-view architecture with fluid animations,
// categorized sidebar navigation, omni-search, and direct live settings fidelity.
ShellRoot {
    FloatingWindow {
        id: win
        title: "mujō — Settings"
        implicitWidth: 1120
        implicitHeight: 740
        color: Theme.bg

        // Quit whenever the window closes so no headless process lingers
        property bool _shown: false
        onVisibleChanged: {
            if (visible) _shown = true
            else if (_shown) Qt.quit()
        }

        // ── Categorized Navigation Architecture ──────────────────────────────
        readonly property var sections: [
            {
                category: "SYSTEM",
                items: [
                    { key: "overview",     label: "Overview",            icon: "dashboard",           brand: "overview" },
                    { key: "system",       label: "NixOS & Rebuild",     icon: "terminal",            brand: "system" },
                    { key: "health",       label: "Health & Sentinel",   icon: "health_and_safety",   brand: "health" },
                    { key: "general",      label: "General Preferences", icon: "tune",                brand: "general" }
                ]
            },
            {
                category: "PERSONALIZATION",
                items: [
                    { key: "appearance",   label: "Appearance & Theme",  icon: "palette",             brand: "appearance" },
                    { key: "animations",   label: "Animations & Motion", icon: "motion_photos_on",    brand: "animations" },
                    { key: "wallpaper",    label: "Wallpaper & Parallax",icon: "wallpaper",           brand: "wallpaper" },
                    { key: "desktop",      label: "Desktop & Cava",      icon: "widgets",             brand: "desktop" },
                    { key: "island",       label: "Dynamic Island",      icon: "blur_on",             brand: "island" }
                ]
            },
            {
                category: "INTELLIGENCE & NETWORK",
                items: [
                    { key: "ai",            label: "AI Assistant",        icon: "psychology",          brand: "ai" },
                    { key: "notifications", label: "Notifications & Focus",icon: "notifications",      brand: "notifications" },
                    { key: "weather",       label: "Weather & Climate",   icon: "partly_cloudy_day",   brand: "weather" },
                    { key: "network",       label: "Network & VPN",       icon: "vpn_lock",            brand: "network" }
                ]
            },
            {
                category: "HARDWARE",
                items: [
                    { key: "display",      label: "Displays & Power",    icon: "monitor",             brand: "display" },
                    { key: "devices",      label: "Keyboard & Pointer",  icon: "keyboard",            brand: "devices" },
                    { key: "shortcuts",    label: "Keyboard Shortcuts",  icon: "keyboard_command_key",brand: "shortcuts" },
                    { key: "vm",           label: "Virtual Machines",    icon: "terminal",            brand: "vm" }
                ]
            },
            {
                category: "STORAGE & SECURITY",
                items: [
                    { key: "keyring",      label: "Keyring Vault",       icon: "key",                 brand: "keyring" },
                    { key: "persistence",  label: "Persistence Map",     icon: "hard_drive",          brand: "persistence" },
                    { key: "applications", label: "Applications",        icon: "apps",                brand: "applications" }
                ]
            }
        ]

        // Flat lookup list
        readonly property var allItems: {
            var list = []
            for (var s = 0; s < sections.length; s++) {
                for (var i = 0; i < sections[s].items.length; i++) {
                    var it = sections[s].items[i]
                    list.push({
                        key: it.key,
                        label: it.label,
                        icon: it.icon,
                        brand: it.brand,
                        category: sections[s].category
                    })
                }
            }
            return list
        }

        // Active Navigation State
        property string currentPanel: "overview"

        readonly property var currentItem: {
            for (var i = 0; i < allItems.length; i++) {
                if (allItems[i].key === currentPanel) return allItems[i]
            }
            return allItems[0]
        }

        function selectPanel(panelKey) {
            for (var i = 0; i < allItems.length; i++) {
                if (allItems[i].key === panelKey) {
                    currentPanel = panelKey
                    return
                }
            }
        }

        // ── Omni-Search Index ────────────────────────────────────────────────
        readonly property var searchIndex: [
            // System
            { title: "System status overview", desc: "Live vitals, system metrics, hardware telemetry", cat: "System", key: "overview" },
            { title: "Quick controls",      desc: "Live toggles for Wi-Fi, Bluetooth, DND, VPN", cat: "System", key: "overview" },
            { title: "Active media playback",desc: "Currently playing track and MPRIS controls", cat: "System", key: "overview" },
            { title: "NixOS rebuild switch",desc: "Apply and switch host configuration with pkexec escalation", cat: "System", key: "system" },
            { title: "Generation history",  desc: "Inspect current and past bootable system generations", cat: "System", key: "system" },
            { title: "System overrides",    desc: "Local module drop-in overrides and flake inspect", cat: "System", key: "system" },
            { title: "System health & optimizer", desc: "Live process sentinel, runaway killer, storage cleaner", cat: "System", key: "health" },
            { title: "Problematic processes", desc: "View and manage runaway tasks, memory hogs, zombies, and terminated processes", cat: "System", key: "health" },
            { title: "Process sentinel & killer", desc: "Freeze, renice, or terminate runaway CPU/RAM tasks and zombies", cat: "System", key: "health" },
            { title: "Storage & cache cleaner", desc: "Vacuum journal logs, clean Nix store, purge thumbnails and trash", cat: "System", key: "health" },
            { title: "General preferences", desc: "Hostname, timezone, locale, store hardlinking", cat: "System", key: "general" },
            { title: "Default applications",desc: "MIME handlers for browser, editor, terminal, file manager", cat: "System", key: "general" },
            { title: "Clipboard history",   desc: "Max clipboard clips, sensitive filter, image cache", cat: "System", key: "general" },

            // Personalization
            { title: "Theme preset",        desc: "Crimson, Blood Moon, Catppuccin, Ayu, Dracula, Nord, Gruvbox…", cat: "Personalization", key: "appearance" },
            { title: "Accent color override",desc: "Custom hex or curated palette accent color", cat: "Personalization", key: "appearance" },
            { title: "Surface opacity",     desc: "Translucent glass alpha and blur controls", cat: "Personalization", key: "appearance" },
            { title: "Bar layout & modules",desc: "Bar position, height, margin, and right cluster ordering", cat: "Personalization", key: "appearance" },
            { title: "Bar widget styles",   desc: "Workspaces numerals, gliders, clock format, volume percent, battery modes", cat: "Personalization", key: "appearance" },
            { title: "Workspaces glider & numerals", desc: "Morphic glider, roman numerals, dots, window presence dots", cat: "Personalization", key: "appearance" },
            { title: "Animation intensity", desc: "Minimal, Balanced, or Expressive motion profile", cat: "Personalization", key: "animations" },
            { title: "Ambient motion & breathing", desc: "Living background flow, breathing, particle fields", cat: "Personalization", key: "animations" },
            { title: "Live motion preview", desc: "Interactive showcase demonstrating physics and spring curves", cat: "Personalization", key: "animations" },
            { title: "Page transitions",    desc: "Fluid crossfade and spatial transitions between pages", cat: "Personalization", key: "animations" },
            { title: "Reduced motion override", desc: "Accessibility preference eliminating spatial and continuous motion", cat: "Personalization", key: "animations" },
            { title: "Performance mode",    desc: "Reduce GPU/rendering load on low-power hardware", cat: "Personalization", key: "animations" },
            { title: "Wallpaper library",   desc: "Apply from local curated wallpaper collection", cat: "Personalization", key: "wallpaper" },
            { title: "Wallhaven browser",   desc: "Search, preview, and download wallpapers online", cat: "Personalization", key: "wallpaper" },
            { title: "Wallpaper Engine browser", desc: "Browse Steam Workshop Wallpaper Engine (431960) and installed live projects", cat: "Personalization", key: "wallpaper" },
            { title: "Wallpaper Engine performance", desc: "Live wallpaper FPS limit, audio automute, and sound volume", cat: "Personalization", key: "wallpaper" },
            { title: "Cursor parallax",     desc: "Dynamic wallpaper pan and depth motion on mouse move", cat: "Personalization", key: "wallpaper" },
            { title: "Desktop widgets",     desc: "Clock, system telemetry, weather, notes, photo, media desktop overlays", cat: "Personalization", key: "desktop" },
            { title: "Widget styles & glassmorphism", desc: "Glass opacity, corner radius, drop shadows, border glow", cat: "Personalization", key: "desktop" },
            { title: "Sticky notes colors", desc: "Slate, yellow, rose, emerald, dark color themes and font sizes", cat: "Personalization", key: "desktop" },
            { title: "Now playing vinyl style", desc: "Rotating vinyl record player, album art, playback controls", cat: "Personalization", key: "desktop" },
            { title: "Audio visualizer",    desc: "Cava spectrum visualizer style, color, and responsiveness", cat: "Personalization", key: "desktop" },
            { title: "Shelf drop zone",     desc: "Staging drawer for files and dragging items", cat: "Personalization", key: "desktop" },
            { title: "Dynamic Island",      desc: "Status notch: modules, geometry, animations, and auto-expand", cat: "Personalization", key: "island" },

            // Intelligence & Network
            { title: "AI provider & model", desc: "Ollama local, OpenAI, Claude, model name and base URL", cat: "Intelligence", key: "ai" },
            { title: "AI API credentials",  desc: "Keyring token storage and endpoint authentication", cat: "Intelligence", key: "ai" },
            { title: "AI privacy guards",   desc: "Context sharing, crash data opt-in, action confirmation", cat: "Intelligence", key: "ai" },
            { title: "Do Not Disturb",      desc: "Silence notification banners and toast alerts", cat: "Intelligence", key: "notifications" },
            { title: "Notification position",desc: "Screen corner gravity and toast timeout", cat: "Intelligence", key: "notifications" },
            { title: "Per-app notification muting", desc: "Selectively mute applications", cat: "Intelligence", key: "notifications" },
            { title: "Weather location",    desc: "City auto-detect, temperature units (°C/°F), refresh rate", cat: "Intelligence", key: "weather" },
            { title: "Mullvad VPN",         desc: "WireGuard connection, relay location, and boot auto-connect", cat: "Intelligence", key: "network" },
            { title: "Network interfaces",  desc: "Wi-Fi, Ethernet, IP address, gateway telemetry", cat: "Intelligence", key: "network" },

            // Hardware
            { title: "Display resolution & Hz", desc: "Resolution, refresh rate, and HiDPI scaling per screen", cat: "Hardware", key: "display" },
            { title: "Visual monitor layout", desc: "Arrangement, orientation, and primary screen setup", cat: "Hardware", key: "display" },
            { title: "Idle & power timers", desc: "Dim screen, display turn-off, lock screen, and suspend", cat: "Hardware", key: "display" },
            { title: "Keyboard repeat & delay", desc: "Key repeat rate and initial delay sensitivity", cat: "Hardware", key: "devices" },
            { title: "Keyboard layout",     desc: "XKB keymap layout and language variants", cat: "Hardware", key: "devices" },
            { title: "Pointer & Touchpad",  desc: "Mouse acceleration profile, natural scrolling, tap-to-click", cat: "Hardware", key: "devices" },
            { title: "Keyboard shortcuts",  desc: "Interactive searchable matrix of Niri window bindings", cat: "Hardware", key: "shortcuts" },
            { title: "Virtual machines & lab", desc: "Launch Windows, Ubuntu, Fedora, Arch in KVM with SPICE visual display", cat: "Hardware", key: "vm" },
            { title: "Deploy operating system", desc: "One-click download and launch Windows 11, macOS, Alpine, Debian", cat: "Hardware", key: "vm" },
            { title: "SPICE visual server", desc: "Zero-latency remote-viewer display with shared clipboard and auto-resizing", cat: "Hardware", key: "vm" },
            { title: "Custom ISO virtual machine", desc: "Create accelerated QEMU virtual machine from local ISO file", cat: "Hardware", key: "vm" },

            // Storage & Security
            { title: "Keyring vault",       desc: "Secure credentials, secret specs, and reveal tokens", cat: "Security", key: "keyring" },
            { title: "Impermanence storage",desc: "Persistent directories and files surviving btrfs boot wipe", cat: "Security", key: "persistence" },
            { title: "Integrations & Apps", desc: "Discord, Obsidian, Claude, Steam, Flatpaks, sandboxing", cat: "Security", key: "applications" }
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
        Component { id: healthComp;        HealthPanel {} }
        Component { id: systemComp;        SystemPanel {} }
        Component { id: vmComp;            VmPanel {} }
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
                 : key === "health"       ? healthComp
                 : key === "system"       ? systemComp
                 : key === "vm"           ? vmComp
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

        // ── Main UI Split-View Layout ────────────────────────────────────────
        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ═════════════════════════════════════════════════════════════════
            // LEFT SIDEBAR (260px)
            // ═════════════════════════════════════════════════════════════════
            Rectangle {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                color: Theme.surface
                border.color: "transparent"

                // Subtle right divider line
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.border
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    // 1. Sidebar Brand Header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                        spacing: 10

                        BrandIcon {
                            brand: "mujo"
                            size: 28
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "Settings"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle + 3
                            font.bold: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: mujoBadge.implicitWidth + 8
                            implicitHeight: 18
                            radius: Theme.radiusSm
                            color: Theme.accentDim
                            border.color: Theme.withAlpha(Theme.accent, 0.35)
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: mujoBadge
                                anchors.centerIn: parent
                                text: "mujō"
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }
                    }

                    // 2. Omni-Search Input Field
                    Rectangle {
                        id: searchBox
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Theme.radiusMd
                        color: Theme.withAlpha(Theme.bg, 0.85)
                        border.color: searchField.activeFocus ? Theme.accent : Theme.border
                        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                        Shortcut {
                            sequence: "/"
                            onActivated: searchField.forceActiveFocus()
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: searchField.forceActiveFocus()
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 8

                            MaterialIcon {
                                iconName: "search"
                                pixelSize: 17
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
                                activeFocusOnTab: true
                                cursorVisible: activeFocus
                                onTextChanged: { win.query = text; win.searchSel = 0 }
                                Keys.onDownPressed: if (win.searching) win.searchSel = Math.min(win.searchSel + 1, win.results.length - 1)
                                Keys.onUpPressed: if (win.searching) win.searchSel = Math.max(win.searchSel - 1, 0)
                                Keys.onReturnPressed: win.activateResult(win.searchSel)
                                Keys.onEscapePressed: { if (text === "") Qt.quit(); else { text = ""; win.query = "" } }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: searchField.text === ""
                                    text: "Search settings…"
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
                                implicitWidth: 32; implicitHeight: 18
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
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { searchField.text = ""; win.query = "" }
                                }
                            }
                        }
                    }

                    // 3. Scrollable Categorized Navigation List
                    Flickable {
                        id: navFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: navCol.implicitHeight + 10
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: navCol
                            width: navFlick.width
                            spacing: 14

                            Repeater {
                                model: win.sections
                                delegate: ColumnLayout {
                                    id: secCol
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 3

                                    // Section Category Header
                                    Text {
                                        text: secCol.modelData.category
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel
                                        font.bold: true
                                        font.letterSpacing: Theme.labelSpacing
                                        Layout.leftMargin: 8
                                        Layout.bottomMargin: 2
                                    }

                                    // Items within Category
                                    Repeater {
                                        model: secCol.modelData.items
                                        delegate: Rectangle {
                                            id: navItem
                                            required property var modelData
                                            readonly property bool isSelected: win.currentPanel === modelData.key && !win.searching
                                            Layout.fillWidth: true
                                            implicitHeight: 34
                                            radius: Theme.radiusMd
                                            color: isSelected ? Theme.accentDim : (navItemHh.hovered ? Theme.surfaceHover : "transparent")
                                            border.color: isSelected ? Theme.withAlpha(Theme.accent, 0.45) : "transparent"
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 10

                                                MaterialIcon {
                                                    iconName: navItem.modelData.icon
                                                    pixelSize: 16
                                                    color: navItem.isSelected ? Theme.accent : (navItemHh.hovered ? Theme.text : Theme.textSecondary)
                                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                                }

                                                Text {
                                                    text: navItem.modelData.label
                                                    color: navItem.isSelected ? Theme.text : (navItemHh.hovered ? Theme.text : Theme.textSecondary)
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeBody
                                                    font.bold: navItem.isSelected
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                                }
                                            }

                                            HoverHandler { id: navItemHh; cursorShape: Qt.PointingHandCursor }
                                            TapHandler {
                                                onTapped: {
                                                    win.query = ""
                                                    searchField.text = ""
                                                    win.selectPanel(navItem.modelData.key)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 4. Sidebar Footer (Theme Indicator & Close)
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.border
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Active Theme Pill
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: Theme.radiusSm
                            color: Theme.withAlpha(Theme.accent, 0.1)
                            border.color: thHh.hovered ? Theme.accent : Theme.withAlpha(Theme.accent, 0.3)
                            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: Theme.accent
                                }
                                Text {
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

            // ═════════════════════════════════════════════════════════════════
            // RIGHT MAIN CONTENT VIEWPORT (860px)
            // ═════════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.bg

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // 1. Top Header Bar
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
                            anchors.leftMargin: 24
                            anchors.rightMargin: 24
                            spacing: 12

                            ColumnLayout {
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        visible: !win.searching
                                        text: win.currentItem.category
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel
                                        font.bold: true
                                        font.letterSpacing: Theme.labelSpacing
                                    }
                                    Text {
                                        visible: !win.searching
                                        text: "•"
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontSizeLabel
                                    }
                                    Text {
                                        text: win.searching ? "Search Results" : win.currentItem.label
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeTitle + 1
                                        font.bold: true
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Quick Navigation Pill Indicator
                            Rectangle {
                                visible: !win.searching
                                implicitWidth: curBrandRow.implicitWidth + 14
                                implicitHeight: 24
                                radius: Theme.radiusSm
                                color: Theme.withAlpha(Theme.accent, 0.12)
                                border.color: Theme.withAlpha(Theme.accent, 0.3)

                                RowLayout {
                                    id: curBrandRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    MaterialIcon {
                                        iconName: win.currentItem.icon
                                        pixelSize: 14
                                        color: Theme.accent
                                    }
                                    Text {
                                        text: win.currentItem.key
                                        color: Theme.accent
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    // 2. Content Viewport / Search Overlay Host
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        // Panel Host (when not searching)
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
                                function onCurrentPanelChanged() {
                                    if (Anim.pageTransitions) panelIn.restart()
                                }
                            }

                            ParallelAnimation {
                                id: panelIn
                                NumberAnimation {
                                    target: panelHost
                                    property: "opacity"
                                    from: 0; to: 1
                                    duration: Anim.d(Anim.enter)
                                    easing.type: Anim.easeEnter
                                }
                                NumberAnimation {
                                    target: panelShift
                                    property: "y"
                                    from: 8; to: 0
                                    duration: Anim.d(Anim.enter)
                                    easing.type: Anim.easeStandard
                                }
                            }
                        }

                        // Omni-Search Results Overlay (when searching)
                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 24
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
                                        text: win.results.length + (win.results.length === 1 ? " setting found" : " settings found")
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
                                        implicitHeight: 56
                                        radius: Theme.radiusMd
                                        color: sel ? Theme.accentDim : (resHh.hovered ? Theme.surfaceHover : Theme.surface)
                                        border.color: sel ? Theme.accent : Theme.border
                                        border.width: sel ? 1.5 : 1
                                        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 16
                                            spacing: 14

                                            BrandIcon {
                                                brand: resCard.modelData.key
                                                size: 30
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    text: resCard.modelData.title
                                                    color: Theme.text
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeBody
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
}

