import QtQuick
import QtQuick.Layouts
import Quickshell

// About: identity + a live read-out of the current theme state. Real content,
// not a placeholder — reflects whatever theme.json currently holds.
Item {
    id: root

    function row(k, v) { return { key: k, value: v } }
    readonly property var info: [
        row("Shell", "mujō — Quickshell + niri"),
        row("Theme", Theme.presetLabels[Theme.presetName] || Theme.presetName),
        row("Accent", Theme.accentOverride === "" ? "Preset default" : Theme.accentOverride),
        row("Surface opacity", Math.round(Theme.transparency * 100) + "%"),
        row("Config", "~/.config/quickshell/theme.json")
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 22

        RowLayout {
            spacing: 14
            Rectangle {
                width: 56; height: 56
                radius: Theme.radiusLg
                color: Theme.accentDim
                border.color: Theme.accent
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "desktop_windows"
                    color: Theme.accent
                    pixelSize: 28
                }
            }
            ColumnLayout {
                spacing: 3
                Text {
                    text: "mujō Settings"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle + 7
                    font.bold: true
                }
                Text {
                    text: "A cohesive control center for the shell."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: infoCol.implicitHeight + 24
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: Theme.border

            ColumnLayout {
                id: infoCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 0

                Repeater {
                    model: root.info
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        spacing: 12
                        Text {
                            Layout.preferredWidth: 130
                            text: modelData.key
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.value
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "More sections — Display, Desktop, Wallpaper, Persistence, Keyring, "
                + "Integrations — arrive in upcoming passes and will slot into the sidebar."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }
    }
}
