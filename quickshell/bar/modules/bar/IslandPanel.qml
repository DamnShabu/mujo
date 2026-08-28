import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Island settings (WP-16): module selection + ordering, appearance, behavior.
// Built from the same MujoHero / MujoCard / MujoSettingRow vocabulary as every
// other settings panel — it used to roll its own bare headings and full-width
// sliders, which made it the one page that looked foreign inside the app.
Item {
    id: root

    readonly property var allModules: ["clock", "media", "weather", "cava-mini"]
    readonly property var modules: SettingsBus.get("island.modules", ["clock", "media", "weather"])
    readonly property bool islandOn: SettingsBus.get("island.enabled", true)

    function setModules(a) { SettingsBus.set("island.modules", a) }
    function move(i, dir) {
        var a = modules.slice(), j = i + dir
        if (j < 0 || j >= a.length) return
        var t = a[i]; a[i] = a[j]; a[j] = t
        setModules(a)
    }
    function removeAt(i) { var a = modules.slice(); a.splice(i, 1); setModules(a) }
    function add(name) { var a = modules.slice(); if (a.indexOf(name) < 0) { a.push(name); setModules(a) } }

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
                brand: "island"
                title: "Dynamic Island"
                subtitle: "Floating top-center cluster: clock, media, weather, spectrum."
                badgeText: root.islandOn ? (root.modules.length + " MODULES") : "OFF"
                badgeColor: root.islandOn ? Theme.accent : Theme.textDim
                activeState: root.islandOn
            }

            // ── Modules ───────────────────────────────────────────────────────
            MujoCard {
                title: "Modules & Ordering"
                iconName: "view_day"
                badgeText: root.modules.length + " ACTIVE"

                MujoSettingRow {
                    iconName: "blur_on"
                    title: "Dynamic Island"
                    description: "Show the floating cluster at the top of the focused screen."

                    ToggleSwitch {
                        checked: root.islandOn
                        onToggled: function (c) { SettingsBus.set("island.enabled", c) }
                    }
                }

                SectionLabel { text: "Order — top to bottom" }

                Repeater {
                    model: root.modules
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: Theme.border
                        implicitHeight: 42

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 8
                            MaterialIcon { iconName: "drag_indicator"; pixelSize: 15; color: Theme.textDim }
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: Theme.text
                                font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall
                            }
                            MaterialIcon {
                                iconName: "keyboard_arrow_up"; pixelSize: 18
                                color: index > 0 ? Theme.textSecondary : Theme.textDim
                                TapHandler { onTapped: root.move(index, -1) }
                            }
                            MaterialIcon {
                                iconName: "keyboard_arrow_down"; pixelSize: 18
                                color: index < root.modules.length - 1 ? Theme.textSecondary : Theme.textDim
                                TapHandler { onTapped: root.move(index, 1) }
                            }
                            MaterialIcon {
                                iconName: "close"; pixelSize: 16; color: Theme.error
                                TapHandler { onTapped: root.removeAt(index) }
                            }
                        }
                    }
                }

                Text {
                    visible: root.modules.length === 0
                    Layout.fillWidth: true
                    text: "No modules — add one below and the island will start showing it."
                    color: Theme.textDim
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                // Add any module not already present.
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.allModules
                        delegate: DisplayChip {
                            required property var modelData
                            visible: root.modules.indexOf(modelData) < 0
                            label: "+ " + modelData
                            onClicked: root.add(modelData)
                        }
                    }
                }
            }

            // ── Appearance ────────────────────────────────────────────────────
            MujoCard {
                title: "Appearance"
                iconName: "style"

                Repeater {
                    model: [
                        { key: "island.maxWidth", icon: "straighten", label: "Max width", desc: "Widest the cluster may grow before its content elides.", from: 300, to: 800, def: 520, unit: "px", round: true },
                        { key: "island.radius", icon: "rounded_corner", label: "Corner radius", desc: "Roundness of the island's outer edge.", from: 0, to: 30, def: 18, unit: "px", round: true },
                        { key: "island.opacity", icon: "opacity", label: "Opacity", desc: "Translucency of the island surface.", from: 0.3, to: 1, def: 1, unit: "%", round: false },
                        { key: "island.yOffset", icon: "vertical_align_top", label: "Vertical offset", desc: "Nudge the cluster up or down from the screen edge.", from: -10, to: 20, def: 0, unit: "px", round: true }
                    ]
                    delegate: MujoSettingRow {
                        required property var modelData
                        readonly property real val: SettingsBus.get(modelData.key, modelData.def)
                        readonly property string shown: modelData.round
                            ? (Math.round(val) + modelData.unit)
                            : (Math.round(val * 100) + modelData.unit)

                        iconName: modelData.icon
                        title: modelData.label
                        description: modelData.desc

                        RowLayout {
                            spacing: 12
                            Slider {
                                Layout.preferredWidth: 160
                                from: modelData.from; to: modelData.to
                                value: val
                                valueText: shown
                                onMoved: function (v) { SettingsBus.set(modelData.key, modelData.round ? Math.round(v) : v) }
                            }
                            Text {
                                Layout.preferredWidth: 42
                                horizontalAlignment: Text.AlignRight
                                text: shown
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }

                MujoSettingRow {
                    iconName: "format_color_fill"
                    title: "Background"
                    description: "Follow the theme surface, or pin a fixed colour."

                    Flow {
                        spacing: 6
                        DisplayChip {
                            label: "Auto"
                            selected: SettingsBus.get("island.background", "") === ""
                            onClicked: SettingsBus.set("island.background", "")
                        }
                        Repeater {
                            model: ["#11111b", "#1e1e2e", "#181825", "#232634"]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool sel: SettingsBus.get("island.background", "") === modelData
                                width: 28; height: 28; radius: Theme.radiusSm
                                color: modelData
                                border.width: sel ? 2 : 1
                                border.color: sel ? Theme.accent : Theme.borderStrong
                                MaterialIcon {
                                    visible: parent.sel
                                    anchors.centerIn: parent
                                    iconName: "check"
                                    pixelSize: 13
                                    color: Theme.text
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: SettingsBus.set("island.background", modelData) }
                            }
                        }
                    }
                }
            }

            // ── Behavior ──────────────────────────────────────────────────────
            MujoCard {
                title: "Behavior"
                iconName: "motion_photos_on"

                MujoSettingRow {
                    iconName: "timer"
                    title: "Auto-expand"
                    description: "How long the island stays expanded before collapsing again."

                    RowLayout {
                        spacing: 12
                        Slider {
                            Layout.preferredWidth: 160
                            from: 1000; to: 8000
                            value: SettingsBus.get("island.autoExpandMs", 4000)
                            valueText: (SettingsBus.get("island.autoExpandMs", 4000) / 1000).toFixed(1) + "s"
                            onMoved: function (v) { SettingsBus.set("island.autoExpandMs", Math.round(v)) }
                        }
                        Text {
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            text: (SettingsBus.get("island.autoExpandMs", 4000) / 1000).toFixed(1) + "s"
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                MujoSettingRow {
                    iconName: "notifications"
                    title: "Expand on notification"
                    description: "Briefly open the island when a notification arrives."

                    ToggleSwitch {
                        checked: SettingsBus.get("island.expandOnNotify", true)
                        onToggled: function (c) { SettingsBus.set("island.expandOnNotify", c) }
                    }
                }
            }
        }
    }
}
