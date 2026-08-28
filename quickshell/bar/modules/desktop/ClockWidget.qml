import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// ClockWidget: Standardized desktop clock widget component.
// Utilizes BaseWidget for uniform glassmorphic styling and interaction.
BaseWidget {
    id: root

    property var wcfg: ({})
    readonly property bool format24: wcfg.format24 !== undefined ? !!wcfg.format24 : Theme.clock24h
    readonly property bool showSeconds: wcfg.showSeconds !== undefined ? !!wcfg.showSeconds : Theme.clockShowSeconds
    readonly property bool showDate: wcfg.showDate !== undefined ? !!wcfg.showDate : Theme.clockShowDate

    title: ""
    iconName: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        Item { Layout.fillHeight: true }

        Text {
            id: timeText
            Layout.alignment: Qt.AlignHCenter
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(24, Math.min(54, Math.floor(Math.min(root.width * 0.22, root.height * 0.44))))
            font.bold: true

            // Only wake per second when seconds are actually displayed;
            // otherwise sleep to the next minute boundary. `now` is tracked so
            // the interval can re-aim after each tick.
            property date now: new Date()
            Timer {
                interval: root.showSeconds
                          ? 1000
                          : Math.max(1000, 60000 - (timeText.now.getSeconds() * 1000 + timeText.now.getMilliseconds()))
                running: true
                repeat: true
                onTriggered: {
                    timeText.now = new Date()
                    timeText.updateTime()
                }
            }

            function updateTime() {
                var pattern = (root.format24 ? "HH:mm" : "h:mm AP") + (root.showSeconds ? ":ss" : "")
                timeText.text = Qt.formatTime(new Date(), pattern)
            }

            Component.onCompleted: updateTime()
        }

        Text {
            id: dateText
            Layout.alignment: Qt.AlignHCenter
            visible: root.showDate
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Math.min(14, Math.floor(root.height * 0.14)))
            elide: Text.ElideRight
            Layout.maximumWidth: Math.max(50, root.width - 24)
        }

        Item { Layout.fillHeight: true }
    }
}
