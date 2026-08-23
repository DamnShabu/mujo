//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "./modules/bar/modules"

// Standalone Settings application — a first-party control center for the shell.
// Top search bar + grouped, colorful navigation + per-section panels. Shares the
// Theme singleton and components with the bar (one design language). Launched as
// its own quickshell instance (`mujo settings [section]`, or Mod+,).
ShellRoot {
    FloatingWindow {
        id: win
        title: "mujō Settings"
        implicitWidth: 1040
        implicitHeight: 680
        color: Theme.bg

        // Quit whenever the window goes away (× button, Mod+Q, compositor close)
        // so no headless process lingers to jam the relaunch guard.
        property bool _shown: false
        onVisibleChanged: {
            if (visible) _shown = true
            else if (_shown) Qt.quit()
        }

        // ── Navigation model (grouped) ───────────────────────────────────────
        readonly property var groups: [
            { title: "",                items: [ { key: "overview",   label: "Overview",      brand: "overview",    icon: "dashboard" } ] },
            { title: "Personalization", items: [
                { key: "appearance",  label: "Appearance",   brand: "appearance",  icon: "palette" },
                { key: "wallpaper",   label: "Wallpaper",    brand: "wallpaper",   icon: "wallpaper" },
                { key: "desktop",     label: "Desktop",      brand: "desktop",     icon: "widgets" },
                { key: "island",      label: "Island",       brand: "desktop",     icon: "blur_on" },
                { key: "weather",     label: "Weather",      brand: "usage",       icon: "partly_cloudy_day" } ] },
            { title: "Intelligence",    items: [
                { key: "ai",            label: "AI",            brand: "usage",     icon: "neurology" },
                { key: "notifications", label: "Notifications", brand: "usage",     icon: "notifications" } ] },
            { title: "Hardware",        items: [
                { key: "display",     label: "Displays",     brand: "display",     icon: "monitor" },
                { key: "devices",     label: "Devices",      brand: "devices",     icon: "keyboard" } ] },
            { title: "Network",         items: [
                { key: "network",     label: "Network / VPN", brand: "network",    icon: "vpn_lock" } ] },
            { title: "Security",        items: [
                { key: "keyring",     label: "Keyring",      brand: "keyring",     icon: "key" } ] },
            { title: "System",          items: [
                { key: "persistence", label: "Persistence",  brand: "persistence", icon: "hard_drive" },
                { key: "shortcuts",   label: "Shortcuts",    brand: "shortcuts",   icon: "keyboard_command_key" },
                { key: "system",      label: "System / NixOS", brand: "system",    icon: "terminal" } ] },
            { title: "Apps",            items: [
                { key: "applications", label: "Applications", brand: "applications", icon: "apps" } ] }
        ]

        property string current: "overview"
        function selectPanel(key) {
            for (var g = 0; g < groups.length; g++)
                for (var i = 0; i < groups[g].items.length; i++)
                    if (groups[g].items[i].key === key) { win.current = key; return }
        }

        // ── Search index ─────────────────────────────────────────────────────
        readonly property var searchIndex: [
            { title: "Theme preset",        desc: "Catppuccin, Ayu, Dracula, Nord, Gruvbox…", cat: "Appearance", key: "appearance" },
            { title: "Accent color",        desc: "Override the theme accent",           cat: "Appearance", key: "appearance" },
            { title: "Surface opacity",     desc: "Transparency of panels and menus",    cat: "Appearance", key: "appearance" },
            { title: "Wallpaper library",   desc: "Apply from your local wallpapers",    cat: "Wallpaper",  key: "wallpaper" },
            { title: "Wallhaven browser",   desc: "Search and download wallpapers",      cat: "Wallpaper",  key: "wallpaper" },
            { title: "Cursor parallax",     desc: "Wallpaper zoom + pan effect",         cat: "Desktop",    key: "desktop" },
            { title: "Background color",    desc: "Letterbox fill around wallpapers",    cat: "Desktop",    key: "desktop" },
            { title: "Desktop widgets",     desc: "Add clock, weather, system widgets",  cat: "Desktop",    key: "desktop" },
            { title: "Island modules",      desc: "Clock, media, weather, cava-mini",     cat: "Island",     key: "island" },
            { title: "Island appearance",   desc: "Width, radius, opacity, offset",       cat: "Island",     key: "island" },
            { title: "Island behavior",     desc: "Auto-expand on track / notification",  cat: "Island",     key: "island" },
            { title: "Weather location",    desc: "City, auto-detect, units, interval",  cat: "Weather",    key: "weather" },
            { title: "Temperature units",   desc: "Celsius or Fahrenheit",               cat: "Weather",    key: "weather" },
            { title: "Resolution",          desc: "Per-monitor resolution",              cat: "Displays",   key: "display" },
            { title: "Refresh rate",        desc: "Per-monitor refresh rate",            cat: "Displays",   key: "display" },
            { title: "Display scale",       desc: "HiDPI scaling per monitor",           cat: "Displays",   key: "display" },
            { title: "Monitor layout",      desc: "Arrange monitors visually",           cat: "Displays",   key: "display" },
            { title: "Keyboard repeat rate",desc: "Key repeat speed and delay",          cat: "Devices",    key: "devices" },
            { title: "Keyboard layout",     desc: "xkb layout",                          cat: "Devices",    key: "devices" },
            { title: "Mouse acceleration",  desc: "Pointer accel profile and speed",     cat: "Devices",    key: "devices" },
            { title: "Natural scrolling",   desc: "Reverse scroll direction",            cat: "Devices",    key: "devices" },
            { title: "Tap to click",        desc: "Touchpad tap",                        cat: "Devices",    key: "devices" },
            { title: "Mullvad VPN",         desc: "Connect, disconnect, choose location",cat: "Network",    key: "network" },
            { title: "VPN auto-connect",    desc: "Connect at login",                    cat: "Network",    key: "network" },
            { title: "Mullvad account",     desc: "Account number in the keyring",       cat: "Network",    key: "network" },
            { title: "Credentials",         desc: "Store and reveal secrets",            cat: "Keyring",    key: "keyring" },
            { title: "Add credential",      desc: "Store a new secret",                  cat: "Keyring",    key: "keyring" },
            { title: "Persistent folders",  desc: "Survive the impermanence wipe",       cat: "Persistence",key: "persistence" },
            { title: "Keyboard shortcuts",  desc: "niri key bindings",                   cat: "Shortcuts",  key: "shortcuts" },
            { title: "NixOS rebuild",       desc: "Apply and switch configuration",      cat: "System",     key: "system" },
            { title: "Generation",          desc: "Current system generation",           cat: "System",     key: "system" },
            { title: "Integrations",        desc: "Discord, AI, media, apps",            cat: "Apps",       key: "applications" },
            { title: "AI provider",          desc: "Ollama local or OpenAI-compatible",    cat: "Intelligence", key: "ai" },
            { title: "AI model",             desc: "Model name and base URL",              cat: "Intelligence", key: "ai" },
            { title: "AI API key",           desc: "Store the provider key in the keyring", cat: "Intelligence", key: "ai" },
            { title: "AI privacy",           desc: "Shell context, crash data, confirm actions", cat: "Intelligence", key: "ai" },
            { title: "Do Not Disturb",      desc: "Silence notification toasts",         cat: "Intelligence", key: "notifications" },
            { title: "Notification position",desc: "Which corner toasts appear in",       cat: "Intelligence", key: "notifications" },
            { title: "Battery warnings",     desc: "Low-battery notification thresholds",  cat: "Intelligence", key: "notifications" },
            { title: "Mute apps",            desc: "Per-app notification mute list",       cat: "Intelligence", key: "notifications" }
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
            // fuzzy subsequence on title
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

        // ── Panel components ─────────────────────────────────────────────────
        function panelBrand(key) {
            for (var g = 0; g < groups.length; g++)
                for (var i = 0; i < groups[g].items.length; i++)
                    if (groups[g].items[i].key === key) return groups[g].items[i].brand
            return "overview"
        }

        Component { id: overviewComp;    OverviewPanel {} }
        Component { id: appearanceComp;  AppearancePanel {} }
        Component { id: wallpaperComp;   WallpaperPanel {} }
        Component { id: desktopComp;     DesktopPanel {} }
        Component { id: islandComp;      IslandPanel {} }
        Component { id: weatherComp;     WeatherPanel {} }
        Component { id: displayComp;     DisplayPanel {} }
        Component { id: devicesComp;     DevicesPanel {} }
        Component { id: networkComp;     NetworkPanel {} }
        Component { id: keyringComp;     KeyringPanel {} }
        Component { id: persistenceComp; PersistencePanel {} }
        Component { id: shortcutsComp;   ShortcutsPanel {} }
        Component { id: systemComp;      SystemPanel {} }
        Component { id: notificationsComp; NotificationsPanel {} }
        Component { id: aiComp;          AiPanel {} }
        Component { id: applicationsComp; IntegrationsPanel {} }

        function componentFor(key) {
            return key === "overview" ? overviewComp
                 : key === "appearance" ? appearanceComp
                 : key === "wallpaper" ? wallpaperComp
                 : key === "desktop" ? desktopComp
                 : key === "island" ? islandComp
                 : key === "weather" ? weatherComp
                 : key === "display" ? displayComp
                 : key === "devices" ? devicesComp
                 : key === "network" ? networkComp
                 : key === "keyring" ? keyringComp
                 : key === "persistence" ? persistenceComp
                 : key === "shortcuts" ? shortcutsComp
                 : key === "system" ? systemComp
                 : key === "notifications" ? notificationsComp
                 : key === "ai" ? aiComp
                 : applicationsComp
        }

        // Panel-routing target file (from `mujo settings <key>`).
        FileView {
            path: (Quickshell.env("HOME") || "/tmp") + "/.config/qsshell/settings-target"
            watchChanges: true
            onFileChanged: reload()
            onLoaded: win.selectPanel(text().trim())
        }

        // Signal bus so panels can request navigation (e.g. Overview cards,
        // "open wallpaper library"). Panels call SettingsBus.go(key).
        Connections {
            target: SettingsBus
            function onNavigate(key) { win.selectPanel(key) }
        }

        // ── Layout ───────────────────────────────────────────────────────────
        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            spacing: 0

            // Subtle open animation.
            opacity: 0
            Component.onCompleted: openAnim.start()
            NumberAnimation { id: openAnim; target: mainCol; property: "opacity"; from: 0; to: 1; duration: Theme.reduceMotion ? 0 : 220; easing.type: Easing.OutCubic }

            // Top bar: logo · search · close
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: Theme.surface
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 14

                    RowLayout {
                        spacing: 10
                        Layout.preferredWidth: 200
                        BrandIcon { brand: "overview"; size: 30 }
                        ColumnLayout {
                            spacing: -2
                            Text { text: "mujō"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle + 2; font.bold: true }
                            Text { text: "Settings"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                        }
                    }

                    // search
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 520
                        Layout.alignment: Qt.AlignHCenter
                        implicitHeight: 36
                        radius: Theme.radiusMd
                        color: Theme.bg
                        border.color: searchField.activeFocus ? Theme.accent : Theme.border
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 9
                            MaterialIcon { iconName: "search"; pixelSize: 18; color: Theme.textSecondary }
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
                                // Esc clears the search, or closes the app when already empty.
                                Keys.onEscapePressed: { if (text === "") Qt.quit(); else { text = ""; win.query = "" } }
                                focus: true
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: searchField.text === ""
                                    text: "Search settings…"
                                    color: Theme.textDim
                                    font: searchField.font
                                }
                            }
                            Text {
                                visible: searchField.text !== ""
                                text: "esc"
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    IconButton { iconName: "close"; onClicked: Qt.quit() }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Sidebar
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 236
                    color: Theme.surface
                    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 12
                        contentHeight: navCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: navCol
                            width: parent.width
                            spacing: 3

                            Repeater {
                                model: win.groups
                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 2
                                    SectionLabel {
                                        visible: modelData.title !== ""
                                        text: modelData.title
                                        Layout.topMargin: 10
                                        Layout.leftMargin: 8
                                        Layout.bottomMargin: 2
                                    }
                                    Repeater {
                                        model: parent.modelData.items
                                        delegate: Rectangle {
                                            id: navItem
                                            required property var modelData
                                            readonly property bool sel: win.current === modelData.key && !win.searching
                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            radius: Theme.radiusMd
                                            color: sel ? Theme.accentDim : (nav_hh.hovered ? Theme.surfaceHover : "transparent")
                                            border.color: sel ? Theme.accent : "transparent"
                                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                                            // Accent rail on the selected item.
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 3; height: navItem.sel ? 18 : 0
                                                radius: 1.5
                                                color: Theme.accent
                                                Behavior on height { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutQuad } }
                                            }
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 14
                                                anchors.rightMargin: 12
                                                spacing: 12
                                                MaterialIcon {
                                                    iconName: navItem.modelData.icon
                                                    pixelSize: 19
                                                    color: navItem.sel ? Theme.accent : (nav_hh.hovered ? Theme.text : Theme.textSecondary)
                                                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: navItem.modelData.label
                                                    color: navItem.sel ? Theme.text : Theme.textSecondary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeBody
                                                    font.bold: navItem.sel
                                                }
                                            }
                                            HoverHandler { id: nav_hh; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: { win.query = ""; searchField.text = ""; win.current = navItem.modelData.key } }
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                // Content: search results or the active panel
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Panel — fade + 8px slide on section change (WP-03 standard
                    // transition via Anim; instant when reduceMotion is on).
                    Item {
                        id: panelHost
                        anchors.fill: parent
                        visible: !win.searching
                        opacity: 1
                        transform: Translate { id: panelShift; y: 0 }
                        Loader {
                            anchors.fill: parent
                            sourceComponent: win.componentFor(win.current)
                        }
                        Connections {
                            target: win
                            function onCurrentChanged() { panelIn.restart() }
                        }
                        ParallelAnimation {
                            id: panelIn
                            NumberAnimation { target: panelHost; property: "opacity"; from: 0; to: 1; duration: Anim.d(Anim.enter); easing.type: Anim.easeEnter }
                            NumberAnimation { target: panelShift; property: "y"; from: 8; to: 0; duration: Anim.d(Anim.enter); easing.type: Anim.easeEnter }
                        }
                    }

                    // Search results
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 26
                        visible: win.searching
                        contentHeight: resCol.implicitHeight
                        clip: true
                        ColumnLayout {
                            id: resCol
                            width: parent.width
                            spacing: 8
                            Text {
                                text: win.results.length + (win.results.length === 1 ? " result" : " results")
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                Layout.bottomMargin: 4
                            }
                            Repeater {
                                model: win.results
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool sel: index === win.searchSel
                                    Layout.fillWidth: true
                                    implicitHeight: 58
                                    radius: Theme.radiusMd
                                    color: sel ? Theme.accentDim : (res_hh.hovered ? Theme.surfaceHover : Theme.surface)
                                    border.color: sel ? Theme.accent : Theme.border
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 14
                                        spacing: 12
                                        BrandIcon { brand: win.panelBrand(modelData.key); size: 34 }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text {
                                                text: modelData.title
                                                color: Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeBody
                                                font.bold: true
                                            }
                                            Text {
                                                text: modelData.desc
                                                color: Theme.textSecondary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                        Rectangle {
                                            implicitWidth: catL.implicitWidth + 16; implicitHeight: 20
                                            radius: Theme.radiusSm
                                            color: Theme.bg
                                            border.color: Theme.border
                                            Text {
                                                id: catL
                                                anchors.centerIn: parent
                                                text: modelData.cat
                                                color: Theme.textSecondary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeLabel
                                            }
                                        }
                                    }
                                    HoverHandler { id: res_hh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: win.activateResult(index) }
                                }
                            }
                            Text {
                                visible: win.results.length === 0
                                text: "No settings match “" + win.query + "”."
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                Layout.topMargin: 20
                            }
                        }
                    }
                }
            }
        }
    }
}
