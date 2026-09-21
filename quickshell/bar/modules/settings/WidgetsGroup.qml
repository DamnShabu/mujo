import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Desktop Overlay Widgets & Glassmorphic Canvas Customizer Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

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

    function typeDef(t) {
        for (var i = 0; i < root.widgetTypes.length; i++)
            if (root.widgetTypes[i].t === t) return root.widgetTypes[i]
        return { t: t, l: t, i: "widgets" }
    }

    // ── 1. Desktop Overlay Widgets Card ───────────────────────────────────────
    MujoCard {
        title: "Desktop Overlay Widgets"
        iconName: "widgets"
        badgeText: root.widgetsLocked ? "LOCKED" : "EDITING"
        badgeColor: root.widgetsLocked ? Theme.textSecondary : Theme.warning

        actions: DisplayChip {
            label: "Reset positions"
            onClicked: root.runW(["reset"])
        }

        MujoSettingRow {
            iconName: root.widgetsLocked ? "lock" : "lock_open"
            title: "Widget Edit Mode"
            description: "Unlock to freely drag and reposition widgets across monitors on the desktop."

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
                text: "Add a widget"
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
                        implicitHeight: 28
                        radius: Theme.radiusSm
                        color: add_hh.hovered ? Theme.surfaceHover : Theme.surface
                        border.width: 1
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

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 6

            Text {
                text: "On the desktop (" + root.widgetList.length + ")"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                Layout.bottomMargin: 2
            }

            Repeater {
                model: root.widgetList

                delegate: ListRow {
                    required property var modelData
                    active: root.selectedWidgetType === modelData.type

                    MaterialIcon {
                        iconName: root.typeDef(modelData.type).i
                        pixelSize: 17
                        color: Theme.accent
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.typeDef(modelData.type).l
                            + (modelData.monitor ? " · " + modelData.monitor : "")
                            + (modelData.rot ? " · " + modelData.rot + "°" : "")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        elide: Text.ElideRight
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

            Text {
                visible: root.widgetList.length === 0
                text: "Nothing on the desktop yet. Add one from the row above."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                Layout.fillWidth: true
            }
        }
    }


    // ── 2. Global Widget Surface & Glassmorphism Card ─────────────────────────
    MujoCard {
        title: "Global Widget Styles & Glassmorphism"
        iconName: "auto_awesome"

        SettingRow {
            path: "desktop.widgets.glassOpacity"
            def: 0.82
            kind: "slider"
            from: 0.3
            to: 1.0
            roundValue: false
            format: "%"
            valueText: (Number(SettingsBus.get("desktop.widgets.glassOpacity", 0.82)) * 100).toFixed(0) + "%"
            iconName: "opacity"
            title: "Widget Surface Glass Opacity"
            description: "Alpha transparency level for glassmorphic widget containers."
        }

        SettingRow {
            path: "desktop.widgets.radius"
            def: 16
            kind: "slider"
            from: 4
            to: 28
            format: "px"
            iconName: "rounded_corner"
            title: "Widget Corner Radius"
            description: "Curvature of desktop widget cards and glass surfaces."
        }

        SettingRow {
            path: "desktop.widgets.shadows"
            def: true
            kind: "toggle"
            iconName: "blur_on"
            title: "Dynamic Drop Shadows"
            description: "Soft ambient shadows beneath widgets that elevate during drag."
        }

        SettingRow {
            path: "desktop.widgets.borderGlow"
            def: true
            kind: "toggle"
            iconName: "flare"
            title: "Border Glow & Specular Line"
            description: "Subtle top specular light reflection and interactive border highlighting."
        }
    }

    // ── 3. Per-Widget Style Settings Card ─────────────────────────────────────
    MujoCard {
        title: "Widget Customization & Styles"
        iconName: "tune"
        badgeText: root.typeDef(root.selectedWidgetType).l.toUpperCase()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            MujoFlickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                contentWidth: widgetTabsRow.implicitWidth + 24
                flickableDirection: Flickable.HorizontalFlick

                RowLayout {
                    id: widgetTabsRow
                    spacing: 6
                    Repeater {
                        model: root.widgetTypes
                        delegate: DisplayChip {
                            required property var modelData
                            label: modelData.l
                            selected: root.selectedWidgetType === modelData.t
                            onClicked: root.selectedWidgetType = modelData.t
                        }
                    }
                }
            }

            // ── Clock Widget ──
            ColumnLayout {
                visible: root.selectedWidgetType === "clock"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "desktop.clock.format24"
                    def: true
                    kind: "toggle"
                    iconName: "schedule"
                    title: "24-Hour Time Format"
                    description: "Display time in 24-hour notation (14:30) vs 12-hour (2:30 PM)."
                }

                SettingRow {
                    path: "desktop.clock.showSeconds"
                    def: false
                    kind: "toggle"
                    iconName: "timer"
                    title: "Show Seconds"
                    description: "Render live seconds counter in desktop widget."
                }

                SettingRow {
                    path: "desktop.clock.showDate"
                    def: true
                    kind: "toggle"
                    iconName: "calendar_today"
                    title: "Show Date"
                    description: "Render full day of week and month date."
                }

                MujoSettingRow {
                    iconName: "style"
                    title: "Clock Visual Style"
                    description: "Glass card, solid background, or minimal text only."
                    MujoSegmented {
                        model: [
                            { id: "glass", label: "Glass" },
                            { id: "solid", label: "Solid" },
                            { id: "minimal", label: "Minimal" }
                        ]
                        current: SettingsBus.get("desktop.clock.style", "glass")
                        onSelected: function(id) { SettingsBus.set("desktop.clock.style", id) }
                    }
                }
            }

            // ── Weather Widget ──
            ColumnLayout {
                visible: root.selectedWidgetType === "weather"
                Layout.fillWidth: true
                spacing: 10

                MujoSettingRow {
                    iconName: "thermostat"
                    title: "Temperature Units"
                    description: "Display Celsius or Fahrenheit."
                    MujoSegmented {
                        model: [
                            { id: "metric", label: "Metric (°C)" },
                            { id: "imperial", label: "Imperial (°F)" }
                        ]
                        current: SettingsBus.get("desktop.weather.units", "metric")
                        onSelected: function(id) { SettingsBus.set("desktop.weather.units", id) }
                    }
                }

                SettingRow {
                    path: "desktop.weather.showCity"
                    def: true
                    kind: "toggle"
                    iconName: "location_city"
                    title: "Show City Name"
                    description: "Display localized city or region label."
                }

                SettingRow {
                    path: "desktop.weather.showCondition"
                    def: true
                    kind: "toggle"
                    iconName: "cloud"
                    title: "Show Condition Text"
                    description: "Display weather description (e.g. Sunny, Rain)."
                }
            }

            // ── System Monitor Widget ──
            ColumnLayout {
                visible: root.selectedWidgetType === "sysmon"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "desktop.sysmon.showCpu"
                    def: true
                    kind: "toggle"
                    iconName: "memory"
                    title: "Show CPU Telemetry"
                    description: "Display processor utilization and sparkline."
                }

                SettingRow {
                    path: "desktop.sysmon.showMem"
                    def: true
                    kind: "toggle"
                    iconName: "storage"
                    title: "Show RAM / Memory"
                    description: "Display memory and swap allocation."
                }

                SettingRow {
                    path: "desktop.sysmon.refreshSec"
                    def: 3
                    kind: "slider"
                    from: 1
                    to: 10
                    format: "s"
                    iconName: "speed"
                    title: "Polling Interval"
                    description: "Seconds between system metric samples."
                }
            }

            // ── Cava Spectrum Visualizer ──
            ColumnLayout {
                visible: root.selectedWidgetType === "cava"
                Layout.fillWidth: true
                spacing: 10

                MujoSettingRow {
                    iconName: "graphic_eq"
                    title: "Spectrum Rendering Style"
                    description: "Equalizer bar geometry."
                    MujoSegmented {
                        model: [
                            { id: "bars", label: "Bars" },
                            { id: "wave", label: "Wave" },
                            { id: "dots", label: "Dots" }
                        ]
                        current: SettingsBus.get("cava.style", "bars")
                        onSelected: function(id) { SettingsBus.set("cava.style", id) }
                    }
                }

                SettingRow {
                    path: "cava.opacity"
                    def: 0.85
                    kind: "slider"
                    from: 0.2
                    to: 1.0
                    roundValue: false
                    format: "%"
                    valueText: (Number(SettingsBus.get("cava.opacity", 0.85)) * 100).toFixed(0) + "%"
                    iconName: "opacity"
                    title: "Visualizer Opacity"
                    description: "Translucency of equalizer bars."
                }

                SettingRow {
                    path: "cava.reflection"
                    def: true
                    kind: "toggle"
                    iconName: "flip"
                    title: "Mirror Reflection"
                    description: "Render an inverted ambient reflection below bars."
                }
            }

            // ── Sticky Notes Widget ──
            ColumnLayout {
                visible: root.selectedWidgetType === "notes"
                Layout.fillWidth: true
                spacing: 10

                MujoSettingRow {
                    iconName: "palette"
                    title: "Note Color Palette"
                    description: "Paper card color theme."
                    MujoSegmented {
                        model: [
                            { id: "slate", label: "Slate" },
                            { id: "yellow", label: "Yellow" },
                            { id: "rose", label: "Rose" },
                            { id: "emerald", label: "Emerald" },
                            { id: "dark", label: "Dark" }
                        ]
                        current: SettingsBus.get("desktop.notes.theme", "slate")
                        onSelected: function(id) { SettingsBus.set("desktop.notes.theme", id) }
                    }
                }

                MujoSettingRow {
                    iconName: "format_size"
                    title: "Note Font Size"
                    description: "Text typography scale."
                    MujoSegmented {
                        model: [
                            { id: "small", label: "Small" },
                            { id: "medium", label: "Medium" },
                            { id: "large", label: "Large" }
                        ]
                        current: SettingsBus.get("desktop.notes.fontSize", "medium")
                        onSelected: function(id) { SettingsBus.set("desktop.notes.fontSize", id) }
                    }
                }
            }

            // ── Media & Photo & VPN & AI Usage ──
            ColumnLayout {
                visible: root.selectedWidgetType === "media"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "desktop.media.showControls"
                    def: true
                    kind: "toggle"
                    iconName: "play_arrow"
                    title: "Show Playback Controls"
                    description: "Display previous, play/pause, and next track buttons."
                }

                SettingRow {
                    path: "desktop.media.showArtist"
                    def: true
                    kind: "toggle"
                    iconName: "person"
                    title: "Show Artist & Album"
                    description: "Render artist metadata line below track title."
                }
            }

            ColumnLayout {
                visible: root.selectedWidgetType === "photo"
                Layout.fillWidth: true
                spacing: 10

                MujoSettingRow {
                    iconName: "aspect_ratio"
                    title: "Photo Fit Mode"
                    description: "Crop to fill frame or preserve aspect ratio."
                    MujoSegmented {
                        model: [
                            { id: "crop", label: "Crop to Fill" },
                            { id: "fit", label: "Fit to Frame" }
                        ]
                        current: SettingsBus.get("desktop.photo.fitMode", "crop")
                        onSelected: function(id) { SettingsBus.set("desktop.photo.fitMode", id) }
                    }
                }
            }

            ColumnLayout {
                visible: root.selectedWidgetType === "vpn"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "desktop.vpn.showLocation"
                    def: true
                    kind: "toggle"
                    iconName: "public"
                    title: "Show Relay Location"
                    description: "Display connected country and city relay name."
                }
            }

            ColumnLayout {
                visible: root.selectedWidgetType === "aiusage"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "desktop.aiusage.showGauges"
                    def: true
                    kind: "toggle"
                    iconName: "speed"
                    title: "Show Rate-Limit Gauges"
                    description: "Display remaining request quota and session limits."
                }
            }

            ColumnLayout {
                visible: root.selectedWidgetType === "calendar"
                Layout.fillWidth: true
                spacing: 10

                SettingRow {
                    path: "desktop.calendar.showWeekNumbers"
                    def: false
                    kind: "toggle"
                    iconName: "date_range"
                    title: "Show Week Numbers"
                    description: "Display ISO week number column in calendar grid."
                }
            }
        }
    }
}
