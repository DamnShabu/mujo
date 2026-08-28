import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// WeatherWidget: Standardized desktop weather widget component.
// Utilizes BaseWidget for uniform glassmorphic styling, async lifecycle, and interaction.
BaseWidget {
    id: root

    property var wcfg: ({})
    readonly property bool compact: Weather.style === "compact" || width < 180

    title: ""
    iconName: ""
    loading: Weather.data === null && Weather.error === ""
    error: Weather.data === null ? Weather.error : ""
    onRetryClicked: Weather.refresh(true)

    opacity: Weather.stale ? 0.6 : 1.0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 12

        Item { Layout.fillWidth: true }

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            iconName: Weather.data ? Weather.iconFor(Weather.data.code) : "cloud"
            pixelSize: Math.max(28, Math.min(54, Math.floor(root.height * 0.5)))
            color: Theme.accent
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: -2

            RowLayout {
                spacing: 2
                Text {
                    text: Weather.data ? Weather.data.temp : "–"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(22, Math.min(36, Math.floor(root.height * 0.36)))
                    font.bold: true
                }
                Text {
                    text: Weather.unitSymbol()
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(12, Math.min(16, Math.floor(root.height * 0.16)))
                    Layout.topMargin: 4
                }
            }

            Text {
                visible: !root.compact
                text: Weather.data ? Weather.descFor(Weather.data.code) : "Loading…"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.maximumWidth: Math.max(50, root.width - 90)
            }

            Text {
                visible: !root.compact
                text: Weather.data ? Weather.data.city : ""
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                elide: Text.ElideRight
                Layout.maximumWidth: Math.max(50, root.width - 90)
            }
        }

        Item { Layout.fillWidth: true }
    }
}
