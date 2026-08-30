import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Desktop & Widgets Settings Panel — Mujo (無常).
// Configuration for desktop widgets (clock, weather, sysmon), Cava audio visualizer spectrum,
// and screen-edge Shelf staging drop zone.
Item {
    id: root

    // ── Desktop widgets state ────────────────────────────────────────────────
    property bool widgetsLocked: true
    property var widgetList: []
    property string selectedWidgetType: "clock"
    function runW(args) { Quickshell.execDetached(["mujo", "widgets"].concat(args)) }

    FileView {
        id: widgetsConf
        path: (Quickshell.env("HOME") || "/tmp") + "/.config/qsshell/widgets.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var c = JSON.parse(text())
                root.widgetsLocked = !!c.locked
                root.widgetList = c.widgets || []
            } catch (e) {
                root.widgetList = []
            }
        }
    }

    // The single source for widget types and icons
    readonly property var widgetTypes: [
        { t: "clock", l: "Clock", i: "schedule" },
        { t: "weather", l: "Weather", i: "partly_cloudy_day" },
        { t: "sysmon", l: "System", i: "monitoring" },
        { t: "cava", l: "Visualizer", i: "graphic_eq" },
        { t: "calendar", l: "Calendar", i: "calendar_month" },
        { t: "media", l: "Now Playing", i: "music_note" },
        { t: "notes", l: "Sticky Note", i: "sticky_note_2" },
        { t: "photo", l: "Photo Frame", i: "photo" },
        { t: "vpn", l: "VPN Status", i: "vpn_key" },
        { t: "aiusage", l: "AI Usage", i: "neurology" }
    ]

    readonly property int cavaCount: {
        var n = 0
        for (var i = 0; i < root.widgetList.length; i++)
            if (root.widgetList[i].type === "cava") n++
        return n
    }

    function typeDef(t) {
        for (var i = 0; i < root.widgetTypes.length; i++)
            if (root.widgetTypes[i].t === t) return root.widgetTypes[i]
        return { t: t, l: t, i: "widgets" }
    }

    MujoFlickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + 48

        ColumnLayout {
            id: mainCol
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 16

            // ── Hero Banner ───────────────────────────────────────────────────
            MujoHero {
                brand: "desktop"
                title: "Desktop & Widgets"
                subtitle: "Desktop overlay widgets, Cava audio spectrum visualizer, and edge file drop zone."
                badgeText: root.widgetList.length > 0 ? (root.widgetList.length + " ACTIVE WIDGETS") : "DESKTOP"
                badgeColor: Theme.accent
            }

            // ── Desktop Widgets Card ──────────────────────────────────────────
            MujoCard {
                title: "Desktop Widgets"
                iconName: "widgets"
                badgeText: root.widgetsLocked ? "LOCKED" : "EDITING"
                badgeColor: root.widgetsLocked ? Theme.textSecondary : Theme.warning

                actions: [
                    DisplayChip {
                        label: "Reset positions"
                        onClicked: root.runW(["reset"])
                    }
                ]

                MujoSettingRow {
                    iconName: root.widgetsLocked ? "lock" : "lock_open"
                    title: "Widget Edit Mode"
                    description: "Unlock to freely reposition widgets across monitors on the desktop."

                    ToggleSwitch {
                        checked: !root.widgetsLocked
                        onToggled: function(c) { root.runW(["lock", c ? "off" : "on"]) }
                    }
                }

                // Add widget actions
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Add New Widget"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: root.widgetTypes
                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: addRow.implicitWidth + 20
                                implicitHeight: 32
                                radius: Theme.radiusSm
                                color: add_hh.hovered ? Theme.surfaceHover : Theme.surfaceActive
                                border.color: Theme.border

                                RowLayout {
                                    id: addRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialIcon { iconName: "add"; pixelSize: 15; color: Theme.accent }
                                    MaterialIcon { iconName: modelData.i; pixelSize: 15; color: Theme.textSecondary }
                                    Text { text: modelData.l; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                }
                                HoverHandler { id: add_hh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.runW(["add", modelData.t]) }
                            }
                        }
                    }
                }

                // Current Active Widgets List
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Active Widgets (" + root.widgetList.length + ")"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Repeater {
                        model: root.widgetList
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: Theme.radiusSm
                            color: Theme.bg
                            border.color: root.selectedWidgetType === modelData.type ? Theme.accent : Theme.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 6
                                spacing: 10

                                MaterialIcon {
                                    iconName: root.typeDef(modelData.type).i
                                    pixelSize: 16
                                    color: Theme.accent
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.typeDef(modelData.type).l
                                        + (modelData.monitor ? ("  ·  " + modelData.monitor) : "")
                                        + (modelData.rot ? ("  ·  " + modelData.rot + "°") : "")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                }
                                DisplayChip {
                                    label: "Style"
                                    selected: root.selectedWidgetType === modelData.type
                                    onClicked: root.selectedWidgetType = modelData.type
                                }
                                IconButton {
                                    iconName: "delete"
                                    onClicked: root.runW(["remove", modelData.id])
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.widgetList.length === 0
                        text: "No widgets placed yet. Choose one from above."
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // ── Global Widget Surface & Glassmorphism Card ────────────────────
            MujoCard {
                title: "Global Widget Styles & Glassmorphism"
                iconName: "auto_awesome"

                MujoSettingRow {
                    iconName: "opacity"
                    title: "Widget Surface Glass Opacity"
                    description: "Alpha transparency level for glassmorphic widget containers on the desktop."

                    RowLayout {
                        spacing: 12
                        Slider {
                            Layout.preferredWidth: 160
                            from: 0.3; to: 1.0
                            value: SettingsBus.get("desktop.widgets.glassOpacity", 0.82)
                            valueText: Math.round(SettingsBus.get("desktop.widgets.glassOpacity", 0.82) * 100) + "%"
                            onMoved: function (v) { SettingsBus.set("desktop.widgets.glassOpacity", v) }
                        }
                        Text {
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(SettingsBus.get("desktop.widgets.glassOpacity", 0.82) * 100) + "%"
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                MujoSettingRow {
                    iconName: "rounded_corner"
                    title: "Widget Corner Radius"
                    description: "Curvature of desktop widget cards and glass surfaces."

                    RowLayout {
                        spacing: 12
                        Slider {
                            Layout.preferredWidth: 160
                            from: 4; to: 28
                            value: SettingsBus.get("desktop.widgets.radius", 16)
                            valueText: Math.round(SettingsBus.get("desktop.widgets.radius", 16)) + "px"
                            onMoved: function (v) { SettingsBus.set("desktop.widgets.radius", Math.round(v)) }
                        }
                        Text {
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(SettingsBus.get("desktop.widgets.radius", 16)) + "px"
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                MujoSettingRow {
                    iconName: "blur_on"
                    title: "Dynamic Drop Shadows"
                    description: "Soft ambient shadows beneath widgets that elevate during drag and resize."

                    ToggleSwitch {
                        checked: SettingsBus.get("desktop.widgets.shadows", true)
                        onToggled: function (c) { SettingsBus.set("desktop.widgets.shadows", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "flare"
                    title: "Border Glow & Specular Line"
                    description: "Subtle top specular light reflection and interactive border highlighting."

                    ToggleSwitch {
                        checked: SettingsBus.get("desktop.widgets.borderGlow", true)
                        onToggled: function (c) { SettingsBus.set("desktop.widgets.borderGlow", c) }
                    }
                }
            }

            // ── Per-Widget Style Settings Card ────────────────────────────────
            MujoCard {
                title: "Widget Customization & Styles"
                iconName: "tune"
                badgeText: root.typeDef(root.selectedWidgetType).l.toUpperCase()

                // Widget Selector Tabs
                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.widgetTypes
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: root.selectedWidgetType === modelData.t
                            implicitWidth: typeRow.implicitWidth + 18
                            implicitHeight: 32
                            radius: Theme.radiusSm
                            color: sel ? Theme.accentDim : (thh.hovered ? Theme.surfaceHover : Theme.surfaceActive)
                            border.color: sel ? Theme.accent : Theme.border
                            border.width: sel ? 1.5 : 1

                            RowLayout {
                                id: typeRow
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIcon {
                                    iconName: parent.parent.modelData.i
                                    pixelSize: 15
                                    color: parent.parent.sel ? Theme.accent : Theme.textSecondary
                                }
                                Text {
                                    text: parent.parent.modelData.l
                                    color: parent.parent.sel ? Theme.text : Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: parent.parent.sel
                                }
                            }
                            HoverHandler { id: thh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.selectedWidgetType = modelData.t }
                        }
                    }
                }

                // ── 1. Clock Widget Settings ──────────────────────────────────
                ColumnLayout {
                    visible: root.selectedWidgetType === "clock"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "schedule"
                        title: "24-Hour Time Format"
                        description: "Display time as 24-hour clock (14:30) instead of 12-hour AM/PM (2:30 PM)."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.clock.format24", true)
                            onToggled: function(c) { SettingsBus.set("desktop.clock.format24", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "timer"
                        title: "Show Seconds"
                        description: "Render live seconds in the clock display."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.clock.showSeconds", false)
                            onToggled: function(c) { SettingsBus.set("desktop.clock.showSeconds", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "calendar_today"
                        title: "Show Date"
                        description: "Render current calendar day beneath time."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.clock.showDate", true)
                            onToggled: function(c) { SettingsBus.set("desktop.clock.showDate", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "short_text"
                        title: "Date Format Style"
                        description: "Choose date presentation complexity."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "full", l: "Full" },
                                    { k: "short", l: "Short" },
                                    { k: "iso", l: "ISO" },
                                    { k: "minimal", l: "Minimal" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("desktop.clock.dateFormat", "full") === modelData.k
                                    onClicked: SettingsBus.set("desktop.clock.dateFormat", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "format_paint"
                        title: "Visual Card Style"
                        description: "Surface presentation mode for the clock widget."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "glass", l: "Glass" },
                                    { k: "solid", l: "Solid" },
                                    { k: "chromeless", l: "Chromeless" },
                                    { k: "accent", l: "Accent Glow" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("desktop.clock.style", "glass") === modelData.k
                                    onClicked: SettingsBus.set("desktop.clock.style", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "format_align_center"
                        title: "Text Alignment"
                        description: "Alignment of time and date numerals."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: ["left", "center", "right"]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData
                                    selected: SettingsBus.get("desktop.clock.alignment", "center") === modelData
                                    onClicked: SettingsBus.set("desktop.clock.alignment", modelData)
                                }
                            }
                        }
                    }
                }

                // ── 2. Weather Widget Settings ────────────────────────────────
                ColumnLayout {
                    visible: root.selectedWidgetType === "weather"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "view_agenda"
                        title: "Weather Display Layout"
                        description: "Presentation density and metrics depth."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "standard", l: "Standard" },
                                    { k: "compact", l: "Compact" },
                                    { k: "detailed", l: "Detailed (Humidity + Wind)" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("desktop.weather.style", "standard") === modelData.k
                                    onClicked: SettingsBus.set("desktop.weather.style", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "location_city"
                        title: "Show City Location"
                        description: "Display detected or configured city name in widget."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.weather.showCity", true)
                            onToggled: function(c) { SettingsBus.set("desktop.weather.showCity", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "wb_sunny"
                        title: "Show Condition Text"
                        description: "Display weather condition summary (Clear, Rain, Cloud…)."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.weather.showCondition", true)
                            onToggled: function(c) { SettingsBus.set("desktop.weather.showCondition", c) }
                        }
                    }
                }

                // ── 3. Sysmon Widget Settings ─────────────────────────────────
                ColumnLayout {
                    visible: root.selectedWidgetType === "sysmon"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "view_stream"
                        title: "Telemetry Display Style"
                        description: "Progress bars or compact hardware status pills."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "bars", l: "SysBars" },
                                    { k: "pills", l: "Status Pills" },
                                    { k: "compact", l: "Compact" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("desktop.sysmon.style", "bars") === modelData.k
                                    onClicked: SettingsBus.set("desktop.sysmon.style", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "speed"
                        title: "Show CPU Usage"
                        description: "Display processor utilization metrics."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.sysmon.showCpu", true)
                            onToggled: function(c) { SettingsBus.set("desktop.sysmon.showCpu", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "memory"
                        title: "Show RAM Memory"
                        description: "Display memory allocation and total capacity."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.sysmon.showMem", true)
                            onToggled: function(c) { SettingsBus.set("desktop.sysmon.showMem", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "update"
                        title: "Telemetry Refresh Interval"
                        description: "Sampling frequency for CPU and RAM monitoring."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: 1, l: "1 sec" },
                                    { k: 2, l: "2 sec" },
                                    { k: 3, l: "3 sec" },
                                    { k: 5, l: "5 sec" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("desktop.sysmon.refreshSec", 3) === modelData.k
                                    onClicked: SettingsBus.set("desktop.sysmon.refreshSec", modelData.k)
                                }
                            }
                        }
                    }
                }

                // ── 4. Cava Audio Visualizer Settings ─────────────────────────
                ColumnLayout {
                    visible: root.selectedWidgetType === "cava"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "style"
                        title: "Visualizer Waveform Style"
                        description: "Spectrum geometry and visual representation."
                        RowLayout {
                            spacing: 8
                            Repeater {
                                model: ["bars", "wave", "circle"]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData
                                    selected: SettingsBus.get("cava.style", "bars") === modelData
                                    onClicked: SettingsBus.set("cava.style", modelData)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Spectrum Color Preset"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            DisplayChip {
                                label: "Theme Accent"
                                selected: SettingsBus.get("cava.color", "") === ""
                                onClicked: SettingsBus.set("cava.color", "")
                            }
                            Repeater {
                                model: ["#f38ba8", "#a6e3a1", "#89b4fa", "#f9e2af", "#cba6f7", "#38bdf8", "#ff385c", "#03edf9"]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: SettingsBus.get("cava.color", "") === modelData
                                    width: 28; height: 28
                                    radius: Theme.radiusSm
                                    color: modelData
                                    border.width: sel ? 2 : 0
                                    border.color: Theme.text
                                    MaterialIcon {
                                        visible: parent.sel
                                        anchors.centerIn: parent
                                        iconName: "check"
                                        pixelSize: 14
                                        color: "#181818"
                                    }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: SettingsBus.set("cava.color", modelData) }
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "opacity"
                        title: "Visualizer Opacity"
                        description: "Transparency of spectrum bars."
                        RowLayout {
                            spacing: 12
                            Slider {
                                Layout.preferredWidth: 160
                                from: 0.2; to: 1.0
                                value: SettingsBus.get("cava.opacity", 0.85)
                                valueText: Math.round(SettingsBus.get("cava.opacity", 0.85) * 100) + "%"
                                onMoved: function (v) { SettingsBus.set("cava.opacity", v) }
                            }
                            Text {
                                Layout.preferredWidth: 42
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(SettingsBus.get("cava.opacity", 0.85) * 100) + "%"
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "flip"
                        title: "Downward Reflection Effect"
                        description: "Draw downward mirror reflection beneath the visualizer."
                        ToggleSwitch {
                            checked: SettingsBus.get("cava.reflection", true)
                            onToggled: function (c) { SettingsBus.set("cava.reflection", c) }
                        }
                    }
                }

                // ── 5. Calendar Widget Settings ───────────────────────────────
                ColumnLayout {
                    visible: root.selectedWidgetType === "calendar"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "format_list_numbered"
                        title: "Show Week Numbers"
                        description: "Display ISO week number along left column of calendar."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.calendar.showWeekNumbers", false)
                            onToggled: function(c) { SettingsBus.set("desktop.calendar.showWeekNumbers", c) }
                        }
                    }
                }

                // ── 6. Now Playing / Media Widget Settings ────────────────────
                ColumnLayout {
                    visible: root.selectedWidgetType === "media"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "album"
                        title: "Player Visual Mode"
                        description: "Album card, compact strip, or spinning vinyl record."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "standard", l: "Standard Card" },
                                    { k: "compact", l: "Compact" },
                                    { k: "vinyl", l: "Vinyl Record" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("desktop.media.style", "standard") === modelData.k
                                    onClicked: SettingsBus.set("desktop.media.style", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "play_circle"
                        title: "Playback Controls"
                        description: "Show Previous, Play/Pause, and Next buttons on the widget."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.media.showControls", true)
                            onToggled: function(c) { SettingsBus.set("desktop.media.showControls", c) }
                        }
                    }

                    MujoSettingRow {
                        iconName: "person"
                        title: "Show Artist Name"
                        description: "Display track artist beneath song title."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.media.showArtist", true)
                            onToggled: function(c) { SettingsBus.set("desktop.media.showArtist", c) }
                        }
                    }
                }

                // ── 7. Sticky Notes Settings ──────────────────────────────────
                ColumnLayout {
                    visible: root.selectedWidgetType === "notes"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "palette"
                        title: "Note Color Theme"
                        description: "Choose color palette for sticky notes."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "slate", l: "Slate Glass" },
                                    { k: "yellow", l: "Yellow" },
                                    { k: "rose", l: "Rose" },
                                    { k: "emerald", l: "Emerald" },
                                    { k: "dark", l: "Dark" },
                                    { k: "accent", l: "Accent Glow" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("desktop.notes.theme", "slate") === modelData.k
                                    onClicked: SettingsBus.set("desktop.notes.theme", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "format_size"
                        title: "Note Font Size"
                        description: "Font scaling for note body text."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: ["small", "medium", "large"]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData
                                    selected: SettingsBus.get("desktop.notes.fontSize", "medium") === modelData
                                    onClicked: SettingsBus.set("desktop.notes.fontSize", modelData)
                                }
                            }
                        }
                    }
                }

                // ── 8. Photo Frame Settings ───────────────────────────────────
                ColumnLayout {
                    visible: root.selectedWidgetType === "photo"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "timer"
                        title: "Slideshow Interval"
                        description: "Time between photo transitions (0 = single static image)."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: 0, l: "Static" },
                                    { k: 5, l: "5s" },
                                    { k: 15, l: "15s" },
                                    { k: 30, l: "30s" },
                                    { k: 60, l: "1m" },
                                    { k: 300, l: "5m" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("desktop.photo.interval", 0) === modelData.k
                                    onClicked: SettingsBus.set("desktop.photo.interval", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "aspect_ratio"
                        title: "Photo Fit Mode"
                        description: "Crop to fill frame or preserve aspect ratio with letterboxing."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "crop", l: "Crop to Fill" },
                                    { k: "fit", l: "Fit to Frame" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("desktop.photo.fitMode", "crop") === modelData.k
                                    onClicked: SettingsBus.set("desktop.photo.fitMode", modelData.k)
                                }
                            }
                        }
                    }
                }

                // ── 9. VPN Status Settings ────────────────────────────────────
                ColumnLayout {
                    visible: root.selectedWidgetType === "vpn"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "view_compact"
                        title: "VPN Widget Layout"
                        description: "Full status card or compact toggle badge."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: ["standard", "compact"]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData
                                    selected: SettingsBus.get("desktop.vpn.style", "standard") === modelData
                                    onClicked: SettingsBus.set("desktop.vpn.style", modelData)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "public"
                        title: "Show Relay Location"
                        description: "Display connected country and city relay name."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.vpn.showLocation", true)
                            onToggled: function(c) { SettingsBus.set("desktop.vpn.showLocation", c) }
                        }
                    }
                }

                // ── 10. AI Usage Settings ─────────────────────────────────────
                ColumnLayout {
                    visible: root.selectedWidgetType === "aiusage"
                    Layout.fillWidth: true
                    spacing: 10

                    MujoSettingRow {
                        iconName: "psychology"
                        title: "Tracked AI Assistant"
                        description: "Assistant provider to track on this widget."
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { k: "", l: "Follow Default" },
                                    { k: "claude", l: "Claude" },
                                    { k: "opencode", l: "opencode" },
                                    { k: "antigravity", l: "Antigravity" },
                                    { k: "ollama", l: "Ollama" }
                                ]
                                delegate: DisplayChip {
                                    required property var modelData
                                    label: modelData.l
                                    selected: SettingsBus.get("desktop.aiusage.provider", "") === modelData.k
                                    onClicked: SettingsBus.set("desktop.aiusage.provider", modelData.k)
                                }
                            }
                        }
                    }

                    MujoSettingRow {
                        iconName: "speed"
                        title: "Show Rate-Limit Gauges"
                        description: "Display remaining request quota and session limits."
                        ToggleSwitch {
                            checked: SettingsBus.get("desktop.aiusage.showGauges", true)
                            onToggled: function(c) { SettingsBus.set("desktop.aiusage.showGauges", c) }
                        }
                    }
                }
            }

            // ── Shelf Drop Zone Card ──────────────────────────────────────────
            MujoCard {
                title: "Shelf Drop Zone"
                iconName: "inbox"
                badgeText: SettingsBus.get("shelf.enabled", true) ? "ENABLED" : "OFF"
                badgeColor: SettingsBus.get("shelf.enabled", true) ? Theme.success : Theme.textDim

                MujoSettingRow {
                    iconName: "layers"
                    title: "Screen Edge Staging Zone"
                    description: "Collect dragged files along the screen edge for effortless multi-folder transfer."

                    ToggleSwitch {
                        checked: SettingsBus.get("shelf.enabled", true)
                        onToggled: function (c) { SettingsBus.set("shelf.enabled", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "border_right"
                    title: "Screen Edge"
                    description: "Which display edge hosts the staging drop strip."

                    RowLayout {
                        spacing: 6
                        Repeater {
                            model: ["left", "right"]
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData
                                selected: SettingsBus.get("shelf.edge", "right") === modelData
                                onClicked: SettingsBus.set("shelf.edge", modelData)
                            }
                        }
                    }
                }

                MujoSettingRow {
                    iconName: "straighten"
                    title: "Strip Length"
                    description: "Proportion of vertical edge occupied by the Shelf."

                    RowLayout {
                        spacing: 12
                        Slider {
                            Layout.preferredWidth: 160
                            from: 0.15; to: 0.8
                            value: SettingsBus.get("shelf.stripLength", 0.4)
                            valueText: Math.round(SettingsBus.get("shelf.stripLength", 0.4) * 100) + "%"
                            onMoved: function (v) { SettingsBus.set("shelf.stripLength", v) }
                        }
                        Text {
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(SettingsBus.get("shelf.stripLength", 0.4) * 100) + "%"
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                MujoSettingRow {
                    iconName: "restart_alt"
                    title: "Restore Items on Restart"
                    description: "Keep collected items in Shelf across desktop reloads and reboots."

                    ToggleSwitch {
                        checked: SettingsBus.get("shelf.restoreOnRestart", true)
                        onToggled: function (c) { SettingsBus.set("shelf.restoreOnRestart", c) }
                    }
                }
            }

            Item { implicitHeight: 12 }
        }
    }
}
