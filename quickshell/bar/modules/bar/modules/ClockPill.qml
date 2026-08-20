import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: systemClockWidget
    width: 150
    height: 30

    property var weather

    Rectangle {
        radius: 15
        color: Theme.bg
        border.color: Theme.border
        anchors.fill: parent

        RowLayout {
            anchors.centerIn: parent

            MaterialIcon {
                id: weatherIcon
                iconName: weather ? (weather.error ? "cloud_off" : weather.iconName) : "device_thermostat"
                pixelSize: 14
                color: weather && weather.error ? Theme.textSecondary : Theme.text
                HoverHandler { id: errorHover }
            }

            SystemClock {
                id: clock
                precision: Theme.clockShowSeconds ? SystemClock.Seconds : SystemClock.Minutes
            }

            Text {
                id: clockText
                text: {
                    var fmt = Theme.clock24h ? "HH:mm" : "h:mm AP"
                    if (Theme.clockShowSeconds) fmt += ":ss"
                    return Qt.formatDateTime(clock.date, fmt)
                }
                color: Theme.text
                font.pixelSize: Theme.clockFontSize
                font.bold: true
            }

            Text {
                id: dateText
                text: Qt.formatDateTime(clock.date, "ddd, MMM d")
                color: Theme.textSecondary
                font.pixelSize: 10
                visible: Theme.clockShowDate
            }
        }

        Text {
            visible: weather && weather.error && errorHover.hovered
            text: "Weather unavailable"
            color: Theme.textSecondary
            font.pixelSize: 10
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
