import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property bool hasWeather: WeatherService.hasData
    readonly property bool barVisible: root.hasWeather
    visible: root.barVisible
    implicitWidth: visible ? weatherRow.implicitWidth + Theme.barItemPadding * 2 : 0
    implicitHeight: Theme.barHeight
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: Theme.barItemHeight
        radius: Theme.radiusSm
        color: weatherHover.hovered ? Theme.surfaceHover : "transparent"

        HoverHandler { id: weatherHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                if (root.panelWindow) {
                    PopupCoordinator.toggle(root.screenName + ":weather")
                }
            }
        }

        RowLayout {
            id: weatherRow
            anchors.centerIn: parent
            spacing: 5

            MaterialIcon {
                iconName: WeatherService.iconName || "wb_cloudy"
                pixelSize: 14
                color: Theme.accent
            }

            Text {
                text: WeatherService.tempFormatted || "--°C"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
