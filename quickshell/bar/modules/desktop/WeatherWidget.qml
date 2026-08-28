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
    readonly property string weatherStyle: wcfg.style !== undefined ? wcfg.style : SettingsBus.get("desktop.weather.style", "standard")
    readonly property bool compact: weatherStyle === "compact" || width < 180
    readonly property bool detailed: weatherStyle === "detailed" && width >= 220
    readonly property bool showCity: wcfg.showCity !== undefined ? !!wcfg.showCity : SettingsBus.get("desktop.weather.showCity", true)
    readonly property bool showCondition: wcfg.showCondition !== undefined ? !!wcfg.showCondition : SettingsBus.get("desktop.weather.showCondition", true)
    readonly property string cardStyle: wcfg.cardStyle !== undefined ? wcfg.cardStyle : "glass"

    chromeless: cardStyle === "chromeless"
    title: ""
    iconName: ""
    loading: Weather.data === null && Weather.error === ""
    error: Weather.data === null ? Weather.error : ""
    onRetryClicked: Weather.refresh(true)

    opacity: Weather.stale ? 0.6 : 1.0

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.chromeless ? 0 : 8
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
                visible: !root.compact && root.showCondition
                text: Weather.data ? Weather.descFor(Weather.data.code) : "Loading…"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.maximumWidth: Math.max(50, root.width - 90)
            }

            Text {
                visible: !root.compact && root.showCity
                text: Weather.data ? Weather.data.city : ""
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                elide: Text.ElideRight
                Layout.maximumWidth: Math.max(50, root.width - 90)
            }

            RowLayout {
                visible: root.detailed && Weather.data && (Weather.data.humidity !== undefined || Weather.data.wind !== undefined)
                spacing: 8
                Layout.topMargin: 2

                Text {
                    visible: Weather.data && Weather.data.humidity !== undefined
                    text: "💧 " + (Weather.data ? Weather.data.humidity : "") + "%"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel - 1
                }

                Text {
                    visible: Weather.data && Weather.data.wind !== undefined
                    text: "💨 " + (Weather.data ? Weather.data.wind : "") + " km/h"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel - 1
                }
            }
        }

        Item { Layout.fillWidth: true }
    }
}
