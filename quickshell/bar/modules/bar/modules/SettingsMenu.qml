import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

FloatingWindow {
    id: root

    signal menuClosed

    property int currentCategory: 0
    property bool _saving: false
    property bool _loading: false
    property bool _dirty: false
    property string currentTheme: "Default"
    property var weather
    readonly property int sidebarWidth: 230
    readonly property int footerHeight: 44
    readonly property int contentWidth: width - sidebarWidth - 32

    visible: false
    color: Theme.bg
    implicitWidth: 1100
    implicitHeight: 720
    minimumSize: Qt.size(800, 500)

    onVisibleChanged: {
        if (visible) {
            openAnim.restart()
            loadFromTheme()
        }
    }

    onClosed: {
        if (visible) {
            visible = false
        }
        root.menuClosed()
    }

    ParallelAnimation {
        id: openAnim
        running: false
        NumberAnimation { target: menuBg; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutQuad }
    }

    SystemClock {
        id: menuClock
        precision: SystemClock.Minutes
    } // drives the static-text previews so they tick like the real bar

    function open() {
        visible = true
    }

    function close() {
        if (visible) {
            visible = false
        }
        root.menuClosed()
    }

    function loadFromTheme() {
        _loading = true
        currentTheme = Theme.themeName || "Default"
        accentField.text = Theme.accent
        bgField.text = Theme.bg
        surfaceField.text = Theme.surface
        surfaceHoverField.text = Theme.surfaceHover
        borderField.text = Theme.border
        borderIntField.text = Theme.borderInteractive
        textField.text = Theme.text
        textSecField.text = Theme.textSecondary
        wsActiveField.text = Theme.workspaceActive
        wsInactiveField.text = Theme.workspaceInactive
        barHeightField.text = String(Theme.barHeight)
        barPaddingField.text = String(Theme.barPadding)
        clock24hToggle.isOn = Theme.clock24h
        clockShowSecToggle.isOn = Theme.clockShowSeconds
        clockShowDateToggle.isOn = Theme.clockShowDate
        clockFontSizeField.text = String(Theme.clockFontSize)
        launcherWField.text = String(Theme.launcherWidth)
        launcherHField.text = String(Theme.launcherHeight)
        launcherOpField.text = String(Math.round(Theme.launcherOpacity * 100))
        launcherWpField.text = Theme.launcherWallpaper || ""
        pillSizeField.text = String(Theme.workspacePillSize)
        pillRadiusField.text = String(Theme.workspacePillRadius)
        pillSpacingField.text = String(Theme.workspaceSpacing)
        showClockToggle.isOn = Theme.showClockPill
        showWsToggle.isOn = Theme.showWorkspaces
        showTrayToggle.isOn = Theme.showSystemTray
        showWeatherToggle.isOn = Theme.showWeather
        latField.text = String(Theme.weatherLat)
        lonField.text = String(Theme.weatherLon)
        celsiusToggle.isOn = Theme.weatherCelsius
        cityField.text = Theme.weatherCity || ""
        _loading = false
    }

    function clampInt(value, min, max, fallback) {
        var n = parseInt(value, 10)
        if (isNaN(n)) return fallback
        return Math.max(min, Math.min(max, n))
    }

    function clampFloat(value, min, max, fallback) {
        var n = parseFloat(value)
        if (isNaN(n)) return fallback
        return Math.max(min, Math.min(max, n))
    }

    function previewLauncherWidth() {
        return clampInt(launcherWField.text, 300, 2000, 520)
    }

    function previewLauncherHeight() {
        return clampInt(launcherHField.text, 200, 1500, 400)
    }

    function applySettings() {
        var a = accentField.text.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(a)) { Theme.accent = a; Theme.workspaceActive = a }
        var b = bgField.text.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(b)) Theme.bg = b
        var s = surfaceField.text.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(s)) Theme.surface = s
        var sh = surfaceHoverField.text.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(sh)) Theme.surfaceHover = sh
        var br = borderField.text.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(br)) Theme.border = br
        var bri = borderIntField.text.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(bri)) Theme.borderInteractive = bri
        var t = textField.text.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(t)) Theme.text = t
        var ts = textSecField.text.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(ts)) Theme.textSecondary = ts
        var wa = wsActiveField.text.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(wa)) Theme.workspaceActive = wa
        var wi = wsInactiveField.text.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(wi)) Theme.workspaceInactive = wi
        Theme.barHeight = clampInt(barHeightField.text, 20, 80, Theme.barHeight)
        Theme.barPadding = clampInt(barPaddingField.text, 4, 40, Theme.barPadding)
        Theme.clock24h = clock24hToggle.isOn
        Theme.clockShowSeconds = clockShowSecToggle.isOn
        Theme.clockShowDate = clockShowDateToggle.isOn
        Theme.clockFontSize = clampInt(clockFontSizeField.text, 8, 32, Theme.clockFontSize)
        Theme.launcherWidth = clampInt(launcherWField.text, 300, 2000, Theme.launcherWidth)
        Theme.launcherHeight = clampInt(launcherHField.text, 200, 1500, Theme.launcherHeight)
        Theme.launcherOpacity = clampInt(launcherOpField.text, 30, 100, Theme.launcherOpacity * 100) / 100
        Theme.launcherWallpaper = launcherWpField.text.trim()
        Theme.workspacePillSize = clampInt(pillSizeField.text, 8, 30, Theme.workspacePillSize)
        Theme.workspacePillRadius = clampInt(pillRadiusField.text, 1, 15, Theme.workspacePillRadius)
        Theme.workspaceSpacing = clampInt(pillSpacingField.text, 2, 20, Theme.workspaceSpacing)
        Theme.showClockPill = showClockToggle.isOn
        Theme.showWorkspaces = showWsToggle.isOn
        Theme.showSystemTray = showTrayToggle.isOn
        Theme.showWeather = showWeatherToggle.isOn
        Theme.weatherLat = clampFloat(latField.text, -90, 90, Theme.weatherLat)
        Theme.weatherLon = clampFloat(lonField.text, -180, 180, Theme.weatherLon)
        Theme.weatherCelsius = celsiusToggle.isOn
        Theme.weatherCity = cityField.text.trim()
    }

    function writeConfig() {
        Theme.themeName = currentTheme
        function c(clr) { return Qt.colorEqual(clr, "transparent") ? "#000000" : String(clr) }
        var obj = {
            themeName: currentTheme,
            accent: c(Theme.accent), bg: c(Theme.bg), surface: c(Theme.surface),
            surfaceHover: c(Theme.surfaceHover), border: c(Theme.border),
            borderInteractive: c(Theme.borderInteractive),
            text: c(Theme.text), textSecondary: c(Theme.textSecondary),
            workspaceActive: c(Theme.workspaceActive), workspaceInactive: c(Theme.workspaceInactive),
            barHeight: Theme.barHeight, barPadding: Theme.barPadding,
            clock24h: Theme.clock24h, clockShowSeconds: Theme.clockShowSeconds,
            clockShowDate: Theme.clockShowDate, clockFontSize: Theme.clockFontSize,
            launcherWidth: Theme.launcherWidth, launcherHeight: Theme.launcherHeight,
            launcherOpacity: Theme.launcherOpacity,
            launcherWallpaper: Theme.launcherWallpaper,
            workspacePillSize: Theme.workspacePillSize, workspacePillRadius: Theme.workspacePillRadius,
            workspaceSpacing: Theme.workspaceSpacing,
            showClockPill: Theme.showClockPill, showWorkspaces: Theme.showWorkspaces,
            showSystemTray: Theme.showSystemTray, showWeather: Theme.showWeather,
            weatherLat: Theme.weatherLat, weatherLon: Theme.weatherLon,
            weatherCelsius: Theme.weatherCelsius, weatherCity: Theme.weatherCity
        }
        var json = JSON.stringify(obj)
        var dir = Quickshell.env("HOME") + "/.config/qsshell"
        // ponytail: tmp+mv atomic replace; a crash mid-write can't leave a corrupt settings.json
        saveProc.command = ["sh", "-c",
            "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/.settings.json.tmp\" && mv \"$1/.settings.json.tmp\" \"$1/settings.json\"",
            "_", dir, json]
        saveProc.running = true
        console.log("Settings: saving config (" + json.length + " chars)")
    }

    function resetToDefaults() {
        currentTheme = "Default"
        Theme.themeName = "Default"
        Theme.accent = "#e6b450"; Theme.workspaceActive = "#e6b450"
        Theme.bg = "#0d1017"; Theme.surface = "#151922"; Theme.surfaceHover = "#1c2230"
        Theme.border = "#1e2530"; Theme.borderInteractive = "#2a3545"
        Theme.text = "#bfbab4"; Theme.textSecondary = "#6e7681"
        Theme.workspaceInactive = "#3a4555"
        Theme.barHeight = 40; Theme.barPadding = 10
        Theme.clock24h = true; Theme.clockFontSize = 13
        Theme.clockShowSeconds = false; Theme.clockShowDate = true
        Theme.launcherWidth = 520; Theme.launcherHeight = 400; Theme.launcherOpacity = 1.0
        Theme.launcherWallpaper = ""
        Theme.workspacePillSize = 15; Theme.workspacePillRadius = 5; Theme.workspaceSpacing = 5
        Theme.showClockPill = true; Theme.showWorkspaces = true
        Theme.showSystemTray = true; Theme.showWeather = true
        Theme.weatherLat = 42.4501; Theme.weatherLon = -73.2454
        Theme.weatherCelsius = false; Theme.weatherCity = ""
        loadFromTheme()
        scheduleSave()
    }

    Process {
        id: saveProc
        command: ["echo"]
        onExited: function(exitCode) {
            _saving = false
            var ok = exitCode === 0
            console.log(ok ? "Settings: config saved successfully"
                           : "Settings: save failed with exit code " + exitCode)
            saveStatus.text = ok ? "// SAVED" : "// SAVE FAILED"
            saveDot.color = ok ? "#4ade80" : Theme.error
            saveStatusTimer.restart()
            if (_dirty) saveTimer.restart() // flush edits typed while the write was in flight
        }
    }

Timer {
        id: saveStatusTimer
        interval: 2000
        onTriggered: saveStatus.text = "// AUTO-SAVE ON"
      } // 2s to show saved status

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            if (_saving) return // onExited re-kicks the flush
            _dirty = false
            _saving = true
            applySettings()
            writeConfig()
        }
      } // 400ms debounce for auto-save

    function scheduleSave() {
        if (_loading) return
        _dirty = true
        saveTimer.restart()
    }

    property var themes: ({
        "Default":  { accent:"#e6b450", bg:"#0d1017", surface:"#151922", surfaceHover:"#1c2230", border:"#1e2530", borderInteractive:"#2a3545", text:"#bfbab4", textSecondary:"#6e7681", wsActive:"#e6b450", wsInactive:"#3a4555" },
        "Nord":     { accent:"#88c0d0", bg:"#2e3440", surface:"#3b4252", surfaceHover:"#434c5e", border:"#4c566a", borderInteractive:"#616e88", text:"#d8dee9", textSecondary:"#7b88a1", wsActive:"#88c0d0", wsInactive:"#4c566a" },
        "Dracula":  { accent:"#bd93f9", bg:"#282a36", surface:"#44475a", surfaceHover:"#6272a4", border:"#6272a4", borderInteractive:"#bd93f9", text:"#f8f8f2", textSecondary:"#6272a4", wsActive:"#bd93f9", wsInactive:"#6272a4" },
        "Gruvbox":  { accent:"#d79921", bg:"#282828", surface:"#3c3836", surfaceHover:"#504945", border:"#504945", borderInteractive:"#d79921", text:"#ebdbb2", textSecondary:"#928374", wsActive:"#d79921", wsInactive:"#504945" },
        "Catppuccin": { accent:"#cba6f7", bg:"#1e1e2e", surface:"#313244", surfaceHover:"#45475a", border:"#45475a", borderInteractive:"#cba6f7", text:"#cdd6f4", textSecondary:"#6c7086", wsActive:"#cba6f7", wsInactive:"#45475a" },
        "Tokyo Night": { accent:"#7aa2f7", bg:"#1a1b26", surface:"#24283b", surfaceHover:"#414868", border:"#414868", borderInteractive:"#7aa2f7", text:"#c0caf5", textSecondary:"#565f89", wsActive:"#7aa2f7", wsInactive:"#414868" },
        "Rose Pine": { accent:"#ebbcba", bg:"#191724", surface:"#1f1d2e", surfaceHover:"#26233a", border:"#393552", borderInteractive:"#ebbcba", text:"#e0def4", textSecondary:"#6e6a86", wsActive:"#ebbcba", wsInactive:"#393552" },
        "Solarized": { accent:"#b58900", bg:"#002b36", surface:"#073642", surfaceHover:"#0a4050", border:"#586e75", borderInteractive:"#b58900", text:"#839496", textSecondary:"#657b83", wsActive:"#b58900", wsInactive:"#586e75" }
    })

    function applyTheme(name) {
        currentTheme = name
        if (name === "Custom") { loadFromTheme(); scheduleSave(); return }
        var t = themes[name]
        if (!t) return
        Theme.accent = t.accent; Theme.workspaceActive = t.wsActive
        Theme.bg = t.bg; Theme.surface = t.surface; Theme.surfaceHover = t.surfaceHover
        Theme.border = t.border; Theme.borderInteractive = t.borderInteractive
        Theme.text = t.text; Theme.textSecondary = t.textSecondary
        Theme.workspaceInactive = t.wsInactive
        loadFromTheme()
        scheduleSave()
    }

    Rectangle {
        id: menuBg
        anchors.fill: parent
        color: Theme.bg
        focus: true
        Keys.onEscapePressed: root.close()

        RowLayout {
            anchors.fill: parent
            anchors.bottomMargin: root.footerHeight
            spacing: 0

            // ===== SIDEBAR =====
            Rectangle {
                id: sidebar
                Layout.preferredWidth: root.sidebarWidth
                Layout.fillHeight: true
                color: Theme.surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 0

                    // Logo
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Layout.bottomMargin: 16

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                color: Theme.surface
                border.color: Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: "QS"
                                color: Theme.accent
                                font.pixelSize: 10
                                font.bold: true
                                font.family: "monospace"
                            }
                        }

                        Column {
                            spacing: 1
                            Text { text: "settings_"; color: Theme.text; font.pixelSize: 13; font.bold: true; font.family: "monospace" }
                            Text { text: "Quickshell + Niri"; color: Theme.textSecondary; font.pixelSize: 8; font.family: "monospace" }
                        }
                    }

                    // Search
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 6
                        color: Theme.surface
                        border.color: searchInput.activeFocus ? Theme.borderInteractive : Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 6

                            Text { text: ">"; color: Theme.textSecondary; font.pixelSize: 11; font.family: "monospace" }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                color: Theme.text
                                font.pixelSize: 11
                                font.family: "monospace"
                                selectByMouse: true
                                verticalAlignment: Text.AlignVCenter
                                clip: true
                                onTextChanged: searchTimer.restart()
                            }
                        }

                        Timer {
                            id: searchTimer
                            interval: 200
                            onTriggered: {
                                var q = searchInput.text.trim().toLowerCase()
                                if (q === "") return
                                var labels = ["General","Appearance","Bar","Clock","Launcher","Workspaces","Weather"]
                                for (var i = 0; i < labels.length; i++) {
                                    if (labels[i].toLowerCase().includes(q)) {
                                        root.currentCategory = i; return
                                    }
                                }
                                var keywordMap = {
                                    0: ["config","reset","shell","framework","ipc","keybind"],
                                    1: ["accent","palette","color","surface","border","text","theme"],
                                    2: ["height","padding","widget","tray","visibility"],
                                    3: ["time","seconds","date","format","clock","fontsize"],
                                    4: ["size","width","dimensions","opacity","launcher"],
                                    5: ["pill","radius","active","inactive","workspace","spacing"],
                                    6: ["lat","lon","celsius","fahrenheit","city","location","weather"]
                                }
                                for (var cat in keywordMap) {
                                    var kws = keywordMap[cat]
                                    for (var j = 0; j < kws.length; j++) {
                                        if (kws[j].includes(q)) {
                                            root.currentCategory = parseInt(cat)
                                            return
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 12 }

                    // Section: 01 GENERAL
                    SectionLabel { text: "01 // GENERAL" }
                    SidebarItem { index: 0; label: "General"; active: root.currentCategory === 0; onClicked: root.currentCategory = 0 }

                    Item { Layout.preferredHeight: 12 }

                    // Section: 02 BAR
                    SectionLabel { text: "02 // BAR" }
                    SidebarItem { index: 1; label: "Appearance"; active: root.currentCategory === 1; onClicked: root.currentCategory = 1 }
                    SidebarItem { index: 2; label: "Bar"; active: root.currentCategory === 2; onClicked: root.currentCategory = 2 }
                    SidebarItem { index: 3; label: "Clock"; active: root.currentCategory === 3; onClicked: root.currentCategory = 3 }

                    Item { Layout.preferredHeight: 12 }

                    // Section: 03 DESKTOP
                    SectionLabel { text: "03 // DESKTOP" }
                    SidebarItem { index: 4; label: "Launcher"; active: root.currentCategory === 4; onClicked: root.currentCategory = 4 }
                    SidebarItem { index: 5; label: "Workspaces"; active: root.currentCategory === 5; onClicked: root.currentCategory = 5 }
                    SidebarItem { index: 6; label: "Weather"; active: root.currentCategory === 6; onClicked: root.currentCategory = 6 }

                    Item { Layout.fillHeight: true }

                    // Footer branding
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.bottomMargin: 10 }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        opacity: 0.5
                        Text { text: "///"; color: Theme.textSecondary; font.pixelSize: 9; font.family: "monospace" }
                        Text { text: "qs-shell"; color: Theme.textSecondary; font.pixelSize: 9; font.family: "monospace"; font.bold: true }
                    }
                }
            }

            // ===== DIVIDER =====
            Rectangle { Layout.fillHeight: true; width: 1; color: Theme.border }

            // ===== CONTENT =====
            Item {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Close button
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    width: 32
                    height: 32
                    radius: 8
                    color: closeHover.hovered ? Theme.surfaceHover : Theme.surface
                    border.color: closeHover.hovered ? Theme.borderInteractive : Theme.border

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "close"
                        pixelSize: 16
                        color: Theme.textSecondary
                    }

                    HoverHandler { id: closeHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }

                Flickable {
                    id: contentFlick
                    anchors.fill: parent
                    anchors.margins: 32
                    anchors.rightMargin: 48
                    contentHeight: contentCol.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick

                    ColumnLayout {
                        id: contentCol
                        width: contentFlick.width
                        spacing: 0

                        // ===== PAGE HEADERS =====
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Layout.bottomMargin: 24

                            Text {
                                text: ["General", "Appearance", "Bar", "Clock", "Launcher", "Workspaces", "Weather"][root.currentCategory]
                                color: Theme.text
                                font.pixelSize: 32
                                font.bold: true
                            }
                            Text {
                                text: [
                                    "Configure core shell behavior and manage your settings.",
                                    "Color palette and theme configuration for all components.",
                                    "Bar layout, height, and widget visibility controls.",
                                    "Time format, date display, and clock pill options.",
                                    "Launcher dimensions and search behavior.",
                                    "Workspace pill styling, size, and colors.",
                                    "Weather data source, location, and unit preferences."
                                ][root.currentCategory]
                                color: Theme.textSecondary
                                font.pixelSize: 12
                                font.family: "monospace"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 4 }
                        }

                        // ===== GENERAL PAGE =====
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root.currentCategory === 0

                            CardSection {
                                label: "SHELL"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    InfoRow { icon: "info"; label: "Shell"; value: "QS Shell" }
                                    InfoRow { icon: "code"; label: "Framework"; value: "Quickshell" }
                                    InfoRow { icon: "desktop_windows"; label: "Compositor"; value: "Niri (Wayland)" }
                                }
                            }

                            CardSection {
                                label: "CONFIGURATION"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    InfoRow { icon: "folder"; label: "Path"; value: "~/.config/qsshell/" }
                                    InfoRow { icon: "description"; label: "File"; value: "settings.json" }
                                    InfoRow { icon: "restart_alt"; label: "Reload"; value: "qs -r" }
                                }
                            }

                            CardSection {
                                label: "KEYBINDINGS"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    InfoRow { icon: "keyboard"; label: "Launcher"; value: "Mod+Space (niri)" }
                                    InfoRow { icon: "keyboard"; label: "Settings"; value: "Gear icon / IPC" }
                                }
                            }

                            CardSection {
                                label: "IPC"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    InfoRow { icon: "terminal"; label: "Toggle"; value: "qs ipc settings toggle" }
                                    InfoRow { icon: "terminal"; label: "Open"; value: "qs ipc settings open" }
                                    InfoRow { icon: "terminal"; label: "Close"; value: "qs ipc settings close" }
                                }
                            }

                            CardSection {
                                label: "RESET"
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    radius: 8
                                    color: resetHover.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.06) : Theme.surface
                                    border.color: resetHover.hovered ? Theme.error : Theme.border

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        MaterialIcon { iconName: "restart_alt"; pixelSize: 16; color: resetHover.hovered ? Theme.error : Theme.textSecondary }
                                        Text { text: "Reset All to Defaults"; color: resetHover.hovered ? Theme.error : Theme.textSecondary; font.pixelSize: 12; font.family: "monospace" }
                                    }

                                    HoverHandler { id: resetHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.resetToDefaults()
                                    }
                                }
                            }
                        }

                        // ===== APPEARANCE PAGE =====
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root.currentCategory === 1

                            CardSection {
                                label: "THEME"
                                description: "Select a color theme or customize individually."

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: Math.max(2, Math.floor((root.contentWidth + 8) / 130))
                                    rowSpacing: 8
                                    columnSpacing: 8

                                    Repeater {
                                        model: ["Custom"].concat(Object.keys(root.themes))
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 28
                                            radius: 6
                                            color: root.currentTheme === modelData ? Theme.accent : (themeBtnArea.containsMouse ? Theme.surfaceHover : Theme.surface)
                                            border.color: root.currentTheme === modelData ? Theme.accent : Theme.border

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Rectangle {
                                                    width: 10; height: 10; radius: 5
                                                    color: root.themes[modelData] ? root.themes[modelData].accent : Theme.accent
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    text: modelData
                                                    color: root.currentTheme === modelData ? Theme.bg : (root.themes[modelData] ? Theme.textSecondary : Theme.textSecondary)
                                                    font.pixelSize: 11
                                                    font.family: "monospace"
                                                    font.bold: root.currentTheme === modelData
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: themeBtnArea
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: root.applyTheme(modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            CardSection {
                                label: "DESKTOP PREVIEW"
                                description: "A live mockup of how the desktop will look with the current theme."
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 220
                                    radius: 12
                                    color: Theme.surface
                                    border.color: Theme.border
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Theme.bg }
                                            GradientStop { position: 0.55; color: Theme.surface }
                                            GradientStop { position: 1.0; color: Theme.borderInteractive }
                                        }
                                    }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 12
                                        height: 28
                                        radius: 10
                                        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.8)
                                        border.color: Theme.border

                                        Row {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 10
                                            spacing: 6

                                            Repeater {
                                                model: [1, 2, 3]
                                                Rectangle {
                                                    width: 8
                                                    height: 8
                                                    radius: 4
                                                    color: index === 0 ? Theme.accent : Theme.borderInteractive
                                                    opacity: index === 0 ? 1 : 0.75
                                                }
                                            }
                                        }

                                        Row {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            MaterialIcon {
                                                iconName: "signal_cellular_4_bar"
                                                pixelSize: 12
                                                color: Theme.textSecondary
                                            }
                                            MaterialIcon {
                                                iconName: "wifi"
                                                pixelSize: 12
                                                color: Theme.textSecondary
                                            }
                                            Text {
                                                text: Qt.formatDateTime(menuClock.date, "HH:mm")
                                                color: Theme.text
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.topMargin: 62
                                        anchors.leftMargin: 18
                                        width: 110
                                        height: 22
                                        radius: 11
                                        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.6)
                                        border.color: Theme.border

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Rectangle {
                                                width: 8
                                                height: 8
                                                radius: 4
                                                color: Theme.workspaceActive
                                            }
                                            Rectangle {
                                                width: 8
                                                height: 8
                                                radius: 4
                                                color: Theme.workspaceInactive
                                            }
                                            Rectangle {
                                                width: 8
                                                height: 8
                                                radius: 4
                                                color: Theme.workspaceInactive
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width - 90, 360)
                                        height: 110
                                        radius: 14
                                        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.5)
                                        border.color: Theme.border
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 6

                                            Text {
                                                text: {
                                                    var h = menuClock.date.getHours()
                                                    if (h < 5) return "GOOD NIGHT"
                                                    if (h < 12) return "GOOD MORNING"
                                                    if (h < 17) return "GOOD AFTERNOON"
                                                    return "GOOD EVENING"
                                                }
                                                color: Theme.accent
                                                font.pixelSize: 9
                                                font.bold: true
                                                font.letterSpacing: 1.5
                                            }

                                            Text {
                                                text: Qt.formatDateTime(menuClock.date, Theme.clock24h ? "HH:mm" : "h:mm AP")
                                                color: Theme.text
                                                font.pixelSize: 30
                                                font.bold: true
                                            }

                                            Row {
                                                spacing: 8
                                                Layout.fillWidth: true

                                                MaterialIcon {
                                                    iconName: root.weather && root.weather.iconName ? root.weather.iconName : "device_thermostat"
                                                    pixelSize: 14
                                                    color: Theme.accent
                                                }

                                                Text {
                                                    text: root.weather && !isNaN(root.weather.temperature)
                                                          ? (Math.round(root.weather.temperature) + (root.weather.useCelsius ? "°C" : "°F"))
                                                          : "--"
                                                    color: Theme.text
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                }

                                                Text {
                                                    text: root.weather && root.weather.condition ? root.weather.condition : "" 
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 10
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 18
                                        width: 150
                                        height: 52
                                        radius: 10
                                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.9)
                                        border.color: Theme.border

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8

                                            MaterialIcon {
                                                iconName: "music_note"
                                                pixelSize: 14
                                                color: Theme.accent
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    text: "Unknown Title"
                                                    color: Theme.text
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: "no active session"
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 8
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 10
                                        height: 26
                                        radius: 12
                                        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72)
                                        border.color: Theme.border

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 22

                                            MaterialIcon { iconName: "home"; pixelSize: 12; color: Theme.text }
                                            MaterialIcon { iconName: "apps"; pixelSize: 12; color: Theme.textSecondary }
                                            MaterialIcon { iconName: "terminal"; pixelSize: 12; color: Theme.textSecondary }
                                            MaterialIcon { iconName: "folder"; pixelSize: 12; color: Theme.textSecondary }
                                        }
                                    }
                                }
                            }

                            CardSection {
                                label: "ACCENT"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12
                                        Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18; color: accentField.text; border.color: "#ffffff20"; border.width: 2 }
                                        TextInput { id: accentField; Layout.preferredWidth: 90; color: Theme.text; font.pixelSize: 12; font.family: "monospace"; selectByMouse: true; verticalAlignment: Text.AlignVCenter; clip: true; onTextEdited: { root.currentTheme = "Custom"; root.scheduleSave() } }
                                        Item { Layout.fillWidth: true }
                                    }
                                    Flow { Layout.fillWidth: true; spacing: 8
                                        Repeater {
                                            model: ["#e6b450","#50a8e6","#e65050","#50e68a","#a850e6","#e6a050","#50c8e6","#e650a8","#8ac650","#c6508a"]
                                            Rectangle {
                                                width: 28; height: 28; radius: 14; color: modelData
                                                border.color: accentField.text === modelData ? Theme.text : "#ffffff10"
                                                border.width: accentField.text === modelData ? 2 : 1
                                                scale: accentField.text === modelData ? 1.15 : 1
                                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { accentField.text = modelData; root.currentTheme = "Custom" } }
                                            }
                                        }
                                    }
                                }
                            }

                            CardSection {
                                label: "PALETTE"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    ColorField { label: "Background"; id: bgField }
                                    ColorField { label: "Surface"; id: surfaceField }
                                    ColorField { label: "Surface Hover"; id: surfaceHoverField }
                                }
                            }

                            CardSection {
                                label: "BORDERS"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    ColorField { label: "Default"; id: borderField }
                                    ColorField { label: "Interactive"; id: borderIntField }
                                }
                            }

                            CardSection {
                                label: "TEXT"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    ColorField { label: "Primary"; id: textField }
                                    ColorField { label: "Secondary"; id: textSecField }
                                }
                            }

                            CardSection {
                                label: "WORKSPACES"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    ColorField { label: "Active"; id: wsActiveField }
                                    ColorField { label: "Inactive"; id: wsInactiveField }
                                }
                            }
                        }

                        // ===== BAR PAGE =====
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root.currentCategory === 2

                            CardSection {
                                label: "LAYOUT"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    NumberField { id: barHeightField; label: "Bar Height"; suffix: "px"; minVal: 20; maxVal: 80 }
                                    NumberField { id: barPaddingField; label: "Padding"; suffix: "px"; minVal: 4; maxVal: 40 }
                                }
                            }

                            CardSection {
                                label: "WIDGETS"
                                description: "Choose which widgets are visible in the bar."
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    SettingsToggle { id: showClockToggle; icon: "schedule"; label: "Clock Pill" }
                                    SettingsToggle { id: showWsToggle; icon: "view_carousel"; label: "Workspaces" }
                                    SettingsToggle { id: showTrayToggle; icon: "widgets"; label: "System Tray" }
                                    SettingsToggle { id: showWeatherToggle; icon: "cloud"; label: "Weather Icon" }
                                }
                            }
                        }

                        // ===== CLOCK PAGE =====
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root.currentCategory === 3

                            CardSection {
                                label: "FORMAT"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    SettingsToggle { id: clock24hToggle; icon: "schedule"; label: "24-hour format" }
                                    SettingsToggle { id: clockShowSecToggle; icon: "timer"; label: "Show seconds" }
                                    SettingsToggle { id: clockShowDateToggle; icon: "calendar_today"; label: "Show date" }
                                    NumberField { id: clockFontSizeField; label: "Font Size"; suffix: "px"; minVal: 8; maxVal: 32 }
                                }
                            }

                            CardSection {
                                label: "PREVIEW"
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 80
                                    radius: 10
                                    color: Theme.surface
                                    border.color: Theme.border

                                    SystemClock {
                                        id: previewClock
                                        precision: Theme.clockShowSeconds ? SystemClock.Seconds : SystemClock.Minutes
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width - 24, 400)
                                        height: 34
                                        radius: 15
                                        color: Theme.bg
                                        border.color: Theme.border

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 8

                                            MaterialIcon {
                                                iconName: root.weather && root.weather.error ? "cloud_off" : (root.weather && root.weather.iconName ? root.weather.iconName : "device_thermostat")
                                                pixelSize: 14
                                                color: root.weather && root.weather.error ? Theme.textSecondary : Theme.text
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: Qt.formatDateTime(previewClock.date, Theme.clock24h ? (Theme.clockShowSeconds ? "HH:mm:ss" : "HH:mm") : (Theme.clockShowSeconds ? "h:mm:ss AP" : "h:mm AP"))
                                                color: Theme.text
                                                font.pixelSize: Theme.clockFontSize
                                                font.bold: true
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                visible: Theme.clockShowDate
                                                text: Qt.formatDateTime(previewClock.date, "ddd, MMM d")
                                                color: Theme.textSecondary
                                                font.pixelSize: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== LAUNCHER PAGE =====
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root.currentCategory === 4

                            CardSection {
                                label: "DIMENSIONS"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    NumberField { id: launcherWField; label: "Width"; suffix: "px"; minVal: 300; maxVal: 2000 }
                                    NumberField { id: launcherHField; label: "Height"; suffix: "px"; minVal: 200; maxVal: 1500 }
                                    NumberField { id: launcherOpField; label: "Opacity"; suffix: "%"; minVal: 30; maxVal: 100 }
                                }
                            }

                            CardSection {
                                label: "CANVAS"
                                description: "Background image for the launcher overview clock widget."
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    SettingsTextField { id: launcherWpField; label: "Image Path" }
                                }
                            }

                            CardSection {
                                label: "PREVIEW"
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 120
                                    radius: 10
                                    color: Theme.surface
                                    border.color: Theme.border
                                    clip: true

                                    SystemClock {
                                        id: previewLaunchClock
                                        precision: SystemClock.Minutes
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width - 24, Math.max(160, root.previewLauncherWidth() / 3))
                                        height: Math.min(parent.height - 16, Math.max(120, root.previewLauncherHeight() / 3))
                                        radius: 6
                                        color: Theme.bg
                                        border.color: Theme.border
                                        border.width: 1
                                        opacity: root.clampInt(launcherOpField.text, 30, 100, 100) / 100

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 4

                                            // Search bar
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 16
                                                radius: 3
                                                color: Theme.surface
                                                border.color: Theme.border

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 5
                                                    anchors.rightMargin: 5
                                                    spacing: 4

                                                    MaterialIcon {
                                                        iconName: "bolt"
                                                        pixelSize: 8
                                                        color: Theme.textSecondary
                                                    }

                                                    Text {
                                                        text: "Search apps..."
                                                        color: Theme.textSecondary
                                                        font.pixelSize: 7
                                                        Layout.fillWidth: true
                                                    }
                                                }
                                            }

                                            // Clock area
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                radius: 4
                                                color: Theme.surface
                                                border.color: Theme.border
                                                clip: true

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 2

                                                    Column {
                                                        spacing: 1
                                                        Layout.fillWidth: true

                                                        Text {
                                                            text: {
                                                                var h = parseInt(Qt.formatDateTime(previewLaunchClock.date, "H"), 10)
                                                                if (h < 5) return "GOOD NIGHT"
                                                                if (h < 12) return "GOOD MORNING"
                                                                if (h < 17) return "GOOD AFTERNOON"
                                                                return "GOOD EVENING"
                                                            }
                                                            color: Theme.accent
                                                            font.pixelSize: 6
                                                            font.bold: true
                                                            font.letterSpacing: 1
                                                        }

                                                        Text {
                                                            text: Qt.formatDateTime(previewLaunchClock.date, "HH:mm")
                                                            color: Theme.text
                                                            font.pixelSize: 20
                                                            font.bold: true
                                                        }
                                                    }

                                                    Row {
                                                        spacing: 4
                                                        Layout.fillWidth: true
                                                        Layout.alignment: Qt.AlignRight

                                                        MaterialIcon {
                                                            iconName: root.weather && root.weather.iconName ? root.weather.iconName : "device_thermostat"
                                                            pixelSize: 9
                                                            color: Theme.accent
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        Text {
                                                            text: root.weather && !isNaN(root.weather.temperature)
                                                                  ? (Math.round(root.weather.temperature) + (root.weather.useCelsius ? "\u00B0C" : "\u00B0F"))
                                                                  : "--"
                                                            color: Theme.text
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        horizontalAlignment: Text.AlignRight
                                                        text: root.weather && root.weather.condition ? root.weather.condition : ""
                                                        color: Theme.text
                                                        font.pixelSize: 6
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        horizontalAlignment: Text.AlignRight
                                                        text: Qt.formatDateTime(previewLaunchClock.date, "ddd, MMM d")
                                                        color: Theme.textSecondary
                                                        font.pixelSize: 6
                                                    }

                                                    // Mini progress line
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 2
                                                        radius: 1
                                                        color: Theme.border

                                                        Rectangle {
                                                            width: parent.width * 0.6
                                                            height: parent.height
                                                            radius: 1
                                                            color: Theme.accent
                                                        }
                                                    }

                                                    // Mini player row
                                                    RowLayout {
                                                        spacing: 4
                                                        Layout.fillWidth: true

                                                        MaterialIcon {
                                                            iconName: "music_note"
                                                            pixelSize: 7
                                                            color: Theme.textSecondary
                                                        }

                                                        Column {
                                                            Layout.fillWidth: true
                                                            spacing: 0

                                                            Text {
                                                                text: "Unknown Title"
                                                                color: Theme.text
                                                                font.pixelSize: 6
                                                                font.bold: true
                                                                elide: Text.ElideRight
                                                                width: parent.width
                                                            }
                                                            Text {
                                                                text: "no active session"
                                                                color: Theme.textSecondary
                                                                font.pixelSize: 5
                                                            }
                                                        }

                                                        MaterialIcon { iconName: "skip_previous"; pixelSize: 8; color: Theme.textSecondary }
                                                        MaterialIcon { iconName: "play_arrow"; pixelSize: 8; color: Theme.text }
                                                        MaterialIcon { iconName: "skip_next"; pixelSize: 8; color: Theme.textSecondary }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== WORKSPACES PAGE =====
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root.currentCategory === 5

                            CardSection {
                                label: "PILL SIZE"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    NumberField { id: pillSizeField; label: "Size"; suffix: "px"; minVal: 8; maxVal: 30 }
                                    NumberField { id: pillRadiusField; label: "Radius"; suffix: "px"; minVal: 1; maxVal: 15 }
                                    NumberField { id: pillSpacingField; label: "Spacing"; suffix: "px"; minVal: 2; maxVal: 20 }
                                }
                            }

                            CardSection {
                                label: "PREVIEW"
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 50
                                    radius: 10
                                    color: Theme.surface
                                    border.color: Theme.border

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width - 24, 200)
                                        height: 25
                                        radius: 5
                                        color: Theme.bg
                                        border.color: Theme.border

                                        RowLayout {
                                            anchors {
                                                verticalCenter: parent.verticalCenter
                                                left: parent.left
                                                right: parent.right
                                                leftMargin: 10
                                                rightMargin: 10
                                            }
                                            spacing: root.clampInt(pillSpacingField.text, 2, 20, 5)

                                            Repeater {
                                                model: [true, false, false, false, false]
                                                    Rectangle {
                                                        property bool isActive: modelData
                                                        width: root.clampInt(pillSizeField.text, 8, 30, 15)
                                                        height: root.clampInt(pillSizeField.text, 8, 30, 15)
                                                        radius: root.clampInt(pillRadiusField.text, 1, 15, 5)
                                                        color: Theme.workspaceInactive

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            radius: parent.radius
                                                            color: Theme.workspaceActive
                                                            opacity: parent.isActive ? 1 : 0
                                                        }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: index + 1
                                                        color: Theme.text
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== WEATHER PAGE =====
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root.currentCategory === 6

                            CardSection {
                                label: "LOCATION"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    SettingsTextField { id: latField; label: "Latitude" }
                                    SettingsTextField { id: lonField; label: "Longitude" }
                                    SettingsTextField { id: cityField; label: "City Name" }
                                }
                            }

                            CardSection {
                                label: "UNITS"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    SettingsToggle { id: celsiusToggle; icon: "thermostat"; label: "Celsius (vs Fahrenheit)" }
                                }
                            }

                            CardSection {
                                label: "DATA SOURCE"
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    InfoRow { icon: "cloud"; label: "Provider"; value: "Open-Meteo" }
                                    InfoRow { icon: "refresh"; label: "Refresh"; value: "10 min" }
                                    InfoRow { icon: "link"; label: "API"; value: "api.open-meteo.com" }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ===== FOOTER =====
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.footerHeight
            radius: 0
            color: Theme.bg

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.border
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 16

                // Status
                RowLayout {
                    spacing: 8
                    Rectangle { id: saveDot; width: 6; height: 6; radius: 3; color: "#4ade80" }
                    Text {
                        id: saveStatus
                        text: "// AUTO-SAVE ON"
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        font.family: "monospace"
                    }
                }

                Item { Layout.fillWidth: true }

                // Reset button
                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: resetLabel.implicitWidth + 24
                    radius: 6
                    color: footerResetHover.hovered ? Theme.surfaceHover : "transparent"
                    border.color: Theme.border

                    Text {
                        id: resetLabel
                        anchors.centerIn: parent
                        text: "RESET"
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        font.family: "monospace"
                        font.bold: true
                    }

                    HoverHandler { id: footerResetHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetToDefaults()
                    }
                }
            }
        }
    }

    // ===== COMPONENTS =====

    component SectionLabel: Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        color: Theme.textSecondary
        font.pixelSize: 9
        font.family: "monospace"
        font.bold: true
        font.letterSpacing: 1
    }

    component SidebarItem: Rectangle {
        property int index: 0
        property string label: ""
        property bool active: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 6
                color: active ? Theme.surfaceHover : (sbItemHover.hovered ? Theme.border : "transparent")

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 8

            Rectangle {
                visible: active
                Layout.preferredWidth: 2
                Layout.preferredHeight: 16
                radius: 1
                color: Theme.accent
            }

            Text {
                text: (active ? "// " : "   ") + label
                color: active ? Theme.text : Theme.textSecondary
                font.pixelSize: 12
                font.family: "monospace"
                font.bold: active
                Layout.fillWidth: true
            }
        }

        HoverHandler { id: sbItemHover }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    component CardSection: Rectangle {
        property string label: ""
        property string description: ""
        default property alias content: cardContent.data

        Layout.fillWidth: true
        radius: 10
        color: Theme.surface
        border.color: Theme.border

        implicitHeight: cardCol.implicitHeight + 28

        ColumnLayout {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle { width: 3; height: 12; radius: 1.5; color: Theme.accent; opacity: 0.6 }

                Text {
                    text: "// " + label
                    color: Theme.textSecondary
                    font.pixelSize: 10
                    font.family: "monospace"
                    font.bold: true
                    font.letterSpacing: 1
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            Text {
                visible: description !== ""
                text: description
                color: Theme.textSecondary
                font.pixelSize: 11
                font.family: "monospace"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ColumnLayout { id: cardContent; Layout.fillWidth: true; spacing: 10 }
        }
    }

    component SettingsToggle: RowLayout {
        property string icon: ""
        property string label: ""
        property bool isOn: true
        onIsOnChanged: root.scheduleSave()
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        spacing: 10

        MaterialIcon { iconName: icon; pixelSize: 16; color: Theme.textSecondary }
        Text { text: label; color: Theme.text; font.pixelSize: 12; font.family: "monospace"; Layout.fillWidth: true }

        Rectangle {
            id: tBg
            Layout.preferredWidth: 40; Layout.preferredHeight: 22; radius: 11
            color: isOn ? Theme.accent : Theme.surface
            border.color: isOn ? Theme.accent : Theme.border

            Rectangle {
                x: isOn ? tBg.width - 20 : 2
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; radius: 9; color: isOn ? Theme.bg : Theme.textSecondary
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            }

            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: isOn = !isOn }
        }
    }

    component ColorField: RowLayout {
        property alias text: cfInput.text
        property string label: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        spacing: 10

        Text { text: label; color: Theme.textSecondary; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 100 }

        Rectangle {
            Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 6
            color: cfInput.text
            border.color: "#ffffff10"; border.width: 1
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 6
            color: Theme.surface
            border.color: cfInput.activeFocus ? Theme.borderInteractive : Theme.border

            TextInput {
                id: cfInput
                anchors.fill: parent
                anchors.leftMargin: 8
                color: Theme.text
                font.pixelSize: 11
                font.family: "monospace"
                selectByMouse: true
                verticalAlignment: Text.AlignVCenter
                clip: true
                onTextChanged: root.scheduleSave()
            }
        }
    }

    component NumberField: RowLayout {
        property alias text: nfInput.text
        property string label: ""
        property string suffix: ""
        property int minVal: 0
        property int maxVal: 999
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        spacing: 10

        Text { text: label; color: Theme.textSecondary; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 100 }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 6
            color: Theme.surface
            border.color: nfInput.activeFocus ? Theme.borderInteractive : Theme.border

            TextInput {
                id: nfInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                color: Theme.text
                font.pixelSize: 11
                font.family: "monospace"
                selectByMouse: true
                verticalAlignment: Text.AlignVCenter
                clip: true
                onTextChanged: root.scheduleSave()
            }
        }

        Text { text: suffix; color: Theme.textSecondary; font.pixelSize: 10; font.family: "monospace" }
    }

    component SettingsTextField: RowLayout {
        property alias text: tfInput.text
        property string label: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        spacing: 10

        Text { text: label; color: Theme.textSecondary; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 100 }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 6
            color: Theme.surface
            border.color: tfInput.activeFocus ? Theme.borderInteractive : Theme.border

            TextInput {
                id: tfInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                color: Theme.text
                font.pixelSize: 11
                font.family: "monospace"
                selectByMouse: true
                verticalAlignment: Text.AlignVCenter
                clip: true
                onTextChanged: root.scheduleSave()
            }
        }
    }

    component InfoRow: RowLayout {
        property string icon: ""
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 8

        MaterialIcon { iconName: icon; pixelSize: 14; color: Theme.textSecondary }
        Text { text: label; color: Theme.textSecondary; font.pixelSize: 11; font.family: "monospace"; Layout.fillWidth: true }
        Text { text: value; color: Theme.textSecondary; font.pixelSize: 11; font.family: "monospace" }
    }
}
