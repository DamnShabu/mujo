import QtQuick
import QtQuick.Layouts
import Quickshell

// Appearance: pick a preset, override the accent, tune surface transparency.
// Every change shells out to `mujo theme …`, which rewrites theme.json; the
// Theme singleton (shared with the bar) reloads and restyles everything live —
// this panel IS its own preview.
Item {
    id: root

    // Fixed accent suggestions offered on top of the preset default.
    readonly property var accentSwatches: [
        "#5cc2ff", "#7aa2f7", "#89b4fa", "#61afef", "#88c0d0",
        "#a6e3a1", "#b8bb26", "#f9e2af", "#ffb454", "#fe8019",
        "#f38ba8", "#eb6f92", "#bd93f9", "#c4a7e7"
    ]

    property real pendingTransparency: Theme.transparency

    function runTheme(args) { Quickshell.execDetached(["mujo", "theme"].concat(args)) }

    Timer {
        id: transparencyDebounce
        interval: 140
        onTriggered: root.runTheme(["transparency", root.pendingTransparency.toFixed(2)])
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 22

        // ─── Header ─────────────────────────────────────────────────────────────
        ColumnLayout {
            spacing: 3
            Text {
                text: "Appearance"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle + 7
                font.bold: true
            }
            Text {
                text: "Theme, accent color, and surface transparency for the whole shell."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
            }
        }

        // ─── Theme presets ──────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            SectionLabel { text: "Theme" }

            Grid {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: Theme.presetOrder
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property var pal: Theme.presets[modelData]
                        readonly property bool selected: Theme.presetName === modelData
                        width: 148
                        height: 92
                        radius: Theme.radiusMd
                        color: pal.surface
                        border.width: selected ? 2 : 1
                        border.color: selected ? Theme.accent : pal.border
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 9

                            // mini palette preview
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: Theme.radiusSm
                                color: card.pal.bg
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6
                                    Repeater {
                                        model: [card.pal.accent, card.pal.success, card.pal.warning, card.pal.error]
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: 11; height: 11; radius: 6
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
                                    text: Theme.presetLabels[card.modelData]
                                    color: card.pal.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    font.bold: card.selected
                                    elide: Text.ElideRight
                                }
                                MaterialIcon {
                                    visible: card.selected
                                    iconName: "check_circle"
                                    pixelSize: 16
                                    color: Theme.accent
                                }
                            }
                        }

                        HoverHandler { id: card_hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.runTheme(["set", card.modelData]) }
                        scale: card_hh.hovered && !card.selected ? 1.02 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutQuad } }
                    }
                }
            }
        }

        // ─── Accent color ───────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            SectionLabel { text: "Accent color" }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                // "Default" → clear the override, fall back to the preset accent.
                Rectangle {
                    width: 74; height: 30
                    radius: Theme.radiusSm
                    color: Theme.accentOverride === "" ? Theme.accentDim : Theme.surface
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
                        required property var modelData
                        readonly property bool selected: Theme.accentOverride.toLowerCase() === modelData.toLowerCase()
                        width: 30; height: 30
                        radius: Theme.radiusSm
                        color: modelData
                        border.width: selected ? 3 : 0
                        border.color: Theme.text
                        MaterialIcon {
                            visible: parent.selected
                            anchors.centerIn: parent
                            iconName: "check"
                            pixelSize: 16
                            color: Theme.accentText
                        }
                        HoverHandler { id: sw_hh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.runTheme(["accent", modelData]) }
                        scale: sw_hh.hovered ? 1.1 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
                    }
                }
            }
        }

        // ─── Transparency ───────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            SectionLabel { text: "Surface opacity" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Slider {
                    id: opacitySlider
                    Layout.fillWidth: true
                    from: 0.6
                    to: 1.0
                    value: Theme.transparency
                    onMoved: function(v) {
                        root.pendingTransparency = v
                        transparencyDebounce.restart()
                    }
                }
                Text {
                    Layout.preferredWidth: 46
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(opacitySlider.value * 100) + "%"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeBody
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
