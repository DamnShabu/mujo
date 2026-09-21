import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// Theme Presets, Appearance Mode, Day/Night Schedule, Accent Overrides, and Surface Transparency.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    readonly property var accentSwatches: [
        "#ff385c", "#e63946", "#ff2a4b", "#e95678", "#ee6d85", "#f07178", "#f38ba8", "#eb6f92",
        "#5cc2ff", "#7aa2f7", "#89b4fa", "#61afef", "#82aaff", "#88c0d0", "#7e9cd8", "#58a6ff", "#268bd2",
        "#03edf9", "#3ddbd9", "#5de4c7", "#a6e3a1", "#a7c080", "#b8bb26", "#00ff9f",
        "#ffe600", "#ffd866", "#f9e2af", "#ffb454", "#fe8019",
        "#bd93f9", "#c4a7e7", "#c792ea", "#e879f9", "#ffffff"
    ]

    property real pendingTransparency: Theme.transparency
    property bool viewingLightPresets: Theme.isLight

    function runTheme(args) { Quickshell.execDetached(["mujo", "theme"].concat(args)) }

    Timer {
        id: transparencyDebounce
        interval: 140
        onTriggered: {
            root.runTheme(["transparency", root.pendingTransparency.toFixed(2)])
            root.pendingTransparency = Qt.binding(function () { return Theme.transparency })
        }
    }

    Connections {
        target: Theme
        function onModeChanged() {
            root.viewingLightPresets = Theme.isLight
        }
        function onEffectivePresetChanged() {
            root.viewingLightPresets = Theme.isLight
        }
    }

    // ── 1. Appearance Mode Card ───────────────────────────────────────────────
    MujoCard {
        title: "Appearance Mode"
        iconName: "brightness_medium"
        badgeText: Theme.mode === "auto" ? ("Auto (" + (Theme.isDaytime ? "Day" : "Night") + ")") : (Theme.mode === "light" ? "Light Mode" : "Dark Mode")
        badgeColor: Theme.accent

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            MujoSettingRow {
                iconName: Theme.mode === "light" ? "light_mode" : (Theme.mode === "auto" ? "schedule" : "dark_mode")
                title: "Color Scheme"
                description: "Choose permanent dark, permanent light, or an automated day/night schedule."

                MujoSegmented {
                    id: modeSeg
                    a11yName: "Theme Mode"
                    model: [
                        { id: "dark", label: "Dark", icon: "dark_mode" },
                        { id: "light", label: "Light", icon: "light_mode" },
                        { id: "auto", label: "Schedule", icon: "schedule" }
                    ]
                    current: Theme.mode
                    onSelected: function(id) {
                        root.runTheme(["mode", id])
                    }
                }
            }
        }
    }

    // ── 2. Automated Day & Night Schedule Card ────────────────────────────────
    MujoCard {
        id: scheduleCard
        visible: Theme.mode === "auto"
        title: "Automated Day & Night Schedule"
        iconName: "routine"
        badgeText: Theme.scheduleType === "solar" ? "Solar Cycle" : "Fixed Time"
        badgeColor: Theme.accent

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            MujoSettingRow {
                iconName: "wb_twilight"
                title: "Schedule Type"
                description: "Switch palette according to local sunrise/sunset or at fixed hours."

                MujoSegmented {
                    a11yName: "Schedule Type"
                    model: [
                        { id: "solar", label: "Solar (Sunrise/Sunset)" },
                        { id: "time", label: "Custom Hours" }
                    ]
                    current: Theme.scheduleType
                    onSelected: function(id) {
                        root.runTheme(["schedule", id, Theme.dayStart, Theme.nightStart])
                    }
                }
            }

            // Solar status telemetry row
            Rectangle {
                visible: Theme.scheduleType === "solar"
                Layout.fillWidth: true
                radius: Theme.radiusSm
                color: Theme.withAlpha(Theme.accent, 0.08)
                border.width: 1
                border.color: Theme.withAlpha(Theme.accent, 0.25)
                implicitHeight: 52

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    MaterialIcon {
                        iconName: Weather.hasData ? "wb_sunny" : "schedule"
                        pixelSize: 22
                        color: Theme.accent
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: Weather.hasData && Weather.sunriseTime && Weather.sunsetTime
                                ? ("Sunrise: " + Weather.sunriseTime + " • Sunset: " + Weather.sunsetTime + (Weather.data.city ? (" (" + Weather.data.city + ")") : ""))
                                : ("Solar times via weather service (fallback hours: " + Theme.dayStart + " – " + Theme.nightStart + ")")
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }
                        Text {
                            text: "Current cycle: " + (Theme.isDaytime ? "Daytime (Active: Light Palette)" : "Nighttime (Active: Dark Palette)")
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    StatusTag {
                        text: Theme.isDaytime ? "Day" : "Night"
                        color: Theme.isDaytime ? Theme.warning : Theme.accent
                    }
                }
            }

            // Custom Hours Inputs
            MujoSettingRow {
                visible: Theme.scheduleType === "time"
                iconName: "lightbulb"
                title: "Day Starts (Light Mode)"
                description: "24-hour time to activate day theme (HH:MM)"

                TextField {
                    id: dayStartField
                    Layout.preferredWidth: 100
                    text: Theme.dayStart
                    placeholder: "07:00"
                    onAccepted: root.runTheme(["schedule", "time", text, Theme.nightStart])
                }
            }

            MujoSettingRow {
                visible: Theme.scheduleType === "time"
                iconName: "bedtime"
                title: "Night Starts (Dark Mode)"
                description: "24-hour time to activate night theme (HH:MM)"

                TextField {
                    id: nightStartField
                    Layout.preferredWidth: 100
                    text: Theme.nightStart
                    placeholder: "19:00"
                    onAccepted: root.runTheme(["schedule", "time", Theme.dayStart, text])
                }
            }

            // Paired Presets Display
            InfoRow {
                iconName: "swap_horiz"
                label: "Scheduled Theme Pair"
                value: (Theme.presetLabels[Theme.lightPreset] || Theme.lightPreset) + " ⇄ " + (Theme.presetLabels[Theme.darkPreset] || Theme.darkPreset)
            }
        }
    }

    // ── 3. Theme Presets Card ─────────────────────────────────────────────────
    MujoCard {
        title: "Theme Presets"
        iconName: "palette"
        badgeText: Theme.presetLabels[Theme.effectivePreset] || Theme.presetLabels[Theme.presetName] || Theme.presetName
        badgeColor: Theme.accent

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MujoSegmented {
                    id: presetCatSeg
                    a11yName: "Preset Category"
                    model: [
                        { id: "dark", label: "Dark Palettes (" + Theme.presetOrder.length + ")" },
                        { id: "light", label: "Light Palettes (" + Theme.lightPresetOrder.length + ")" }
                    ]
                    current: root.viewingLightPresets ? "light" : "dark"
                    onSelected: function(id) {
                        root.viewingLightPresets = (id === "light")
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Active: " + (Theme.presetLabels[Theme.effectivePreset] || Theme.presetLabels[Theme.presetName] || Theme.presetName)
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Flow {
                id: presetFlow
                Layout.fillWidth: true
                spacing: 10
                readonly property int cols: Math.max(1, Math.floor((width + spacing) / (154 + spacing)))
                readonly property real cardW: Math.floor((width - (cols - 1) * spacing) / cols)

                Repeater {
                    model: root.viewingLightPresets ? Theme.lightPresetOrder : Theme.presetOrder
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property var pal: Theme.presets[modelData] || Theme.presets.ayu
                        readonly property bool selected: Theme.effectivePreset === modelData || Theme.presetName === modelData
                        width: presetFlow.cardW
                        height: 88
                        radius: Theme.radiusMd
                        color: pal.surface
                        border.width: selected ? 2 : 1
                        border.color: selected ? Theme.accent : pal.border
                        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            // Mini palette preview
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                radius: Theme.radiusSm
                                color: card.pal.bg
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 6
                                    Repeater {
                                        model: [card.pal.accent, card.pal.success, card.pal.warning, card.pal.error]
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: 10; height: 10; radius: 5
                                            color: modelData
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    Layout.fillWidth: true
                                    text: Theme.presetLabels[card.modelData] || card.modelData
                                    color: card.pal.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: card.selected
                                    elide: Text.ElideRight
                                }
                                MaterialIcon {
                                    visible: card.selected
                                    iconName: "check_circle"
                                    pixelSize: 15
                                    color: Theme.accent
                                }
                            }
                        }

                        HoverHandler { id: card_hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.runTheme(["set", card.modelData]) }
                        scale: card_hh.hovered && !card.selected ? 1.02 : 1.0
                        Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutQuad } }
                    }
                }
            }
        }
    }

    // ── 4. Accent Color & Surface Opacity Card ────────────────────────────────
    MujoCard {
        title: "Accent Color & Surface Opacity"
        iconName: "colorize"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Accent override"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                // Default preset button
                Rectangle {
                    implicitWidth: 68; implicitHeight: 28
                    radius: Theme.radiusSm
                    color: Theme.accentOverride === "" ? Theme.accentDim : Theme.bg
                    border.color: Theme.accentOverride === "" ? Theme.accent : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "Default"
                        color: Theme.accentOverride === "" ? Theme.accent : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.runTheme(["accent", ""]) }
                }

                Repeater {
                    model: root.accentSwatches
                    delegate: Rectangle {
                        id: swatchItem
                        required property var modelData
                        readonly property bool selected: Theme.accentOverride.toLowerCase() === modelData.toLowerCase()
                        width: 28; height: 28
                        radius: Theme.radiusSm
                        color: modelData
                        border.width: selected ? 2 : 0
                        border.color: Theme.text

                        MaterialIcon {
                            visible: swatchItem.selected
                            anchors.centerIn: parent
                            iconName: "check"
                            pixelSize: 14
                            color: Theme.accentText
                        }
                        HoverHandler { id: sw_hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.runTheme(["accent", modelData]) }
                        scale: sw_hh.hovered ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast) } }
                    }
                }
            }
        }

        MujoSettingRow {
            iconName: "opacity"
            title: "Surface Transparency"
            description: "Opacity of floating bars, panels, menus, and overlays."

            RowLayout {
                spacing: 12

                Slider {
                    id: opacitySlider
                    Layout.preferredWidth: 160
                    from: 0.6
                    to: 1.0
                    value: root.pendingTransparency
                    valueText: Math.round(root.pendingTransparency * 100) + "%"
                    onMoved: function(v) {
                        root.pendingTransparency = v
                        transparencyDebounce.restart()
                    }
                }

                Text {
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(opacitySlider.value * 100) + "%"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
