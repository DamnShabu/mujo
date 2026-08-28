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

    // The single source for the add-widget chips, the per-row icons and the
    // row labels below. Adding a widget kind here is the only edit this panel
    // needs.
    readonly property var widgetTypes: [
        { t: "clock", l: "Clock", i: "schedule" },
        { t: "weather", l: "Weather", i: "partly_cloudy_day" },
        { t: "sysmon", l: "System", i: "monitoring" },
        { t: "cava", l: "Visualizer", i: "graphic_eq" },
        { t: "calendar", l: "Calendar", i: "calendar_month" },
        { t: "media", l: "Now playing", i: "music_note" },
        { t: "notes", l: "Note", i: "sticky_note_2" },
        { t: "photo", l: "Photo", i: "photo" },
        { t: "vpn", l: "VPN", i: "vpn_key" },
        { t: "aiusage", l: "AI usage", i: "neurology" }
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

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: mainCol.implicitHeight + 30
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            width: parent.width
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
                            implicitHeight: 38
                            radius: Theme.radiusSm
                            color: Theme.bg
                            border.color: Theme.border

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
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
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

            // ── Audio Visualizer (Cava) Card ──────────────────────────────────
            MujoCard {
                title: "Audio Visualizer (Cava)"
                iconName: "graphic_eq"
                badgeText: root.cavaCount > 0 ? (root.cavaCount + " ACTIVE") : "OFF"
                badgeColor: root.cavaCount > 0 ? Theme.success : Theme.textDim

                MujoSettingRow {
                    iconName: "equalizer"
                    title: "Desktop Spectrum Audio Visualizer"
                    description: "The visualizer is a desktop widget: add one above, then drag, resize and rotate it like any other. These settings are the defaults every cava widget starts from. Pauses when playback is silent."
                }

                // Style
                MujoSettingRow {
                    iconName: "style"
                    title: "Visualizer Style"
                    description: "Waveform geometry. Placement is the widget's own position and rotation."

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

                // Color Swatches
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Spectrum Color"
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
                            model: ["#f38ba8", "#a6e3a1", "#89b4fa", "#f9e2af", "#cba6f7", "#38bdf8"]
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

                // Sizing & Reflection
                MujoSettingRow {
                    iconName: "opacity"
                    title: "Spectrum Opacity"
                    description: "Alpha transparency of the spectrum bars."

                    RowLayout {
                        spacing: 12
                        Slider {
                            Layout.preferredWidth: 160
                            from: 0.2; to: 1
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
                    title: "Reflection Effect"
                    description: "Draw mirrored downward reflection under the visualizer."

                    ToggleSwitch {
                        checked: SettingsBus.get("cava.reflection", true)
                        onToggled: function (c) { SettingsBus.set("cava.reflection", c) }
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
