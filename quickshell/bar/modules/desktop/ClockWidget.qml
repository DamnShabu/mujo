import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// ClockWidget: Standardized desktop clock widget component.
// Utilizes BaseWidget for uniform glassmorphic styling and interaction.
BaseWidget {
    id: root

    property var wcfg: ({})
    readonly property bool format24: wcfg.format24 !== undefined ? !!wcfg.format24 : SettingsBus.get("desktop.clock.format24", true)
    readonly property bool showSeconds: wcfg.showSeconds !== undefined ? !!wcfg.showSeconds : SettingsBus.get("desktop.clock.showSeconds", false)
    readonly property bool showDate: wcfg.showDate !== undefined ? !!wcfg.showDate : SettingsBus.get("desktop.clock.showDate", true)
    readonly property string dateFormat: wcfg.dateFormat !== undefined ? wcfg.dateFormat : SettingsBus.get("desktop.clock.dateFormat", "full")
    readonly property string clockStyle: wcfg.style !== undefined ? wcfg.style : SettingsBus.get("desktop.clock.style", "glass")
    readonly property string alignment: wcfg.alignment !== undefined ? wcfg.alignment : SettingsBus.get("desktop.clock.alignment", "center")

    chromeless: clockStyle === "chromeless"
    title: ""
    iconName: ""

    readonly property string datePattern: {
        if (dateFormat === "short") return "ddd, MMM d"
        if (dateFormat === "iso") return "yyyy-MM-dd"
        if (dateFormat === "minimal") return "MMM d"
        return "dddd, MMMM d"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.chromeless ? 0 : 8
        spacing: 2

        Item { Layout.fillHeight: true }

        Text {
            id: timeText
            Layout.alignment: root.alignment === "left" ? Qt.AlignLeft : (root.alignment === "right" ? Qt.AlignRight : Qt.AlignHCenter)
            color: root.clockStyle === "accent" ? Theme.accent : Theme.text
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
            Layout.alignment: root.alignment === "left" ? Qt.AlignLeft : (root.alignment === "right" ? Qt.AlignRight : Qt.AlignHCenter)
            visible: root.showDate
            text: Qt.formatDate(new Date(), root.datePattern)
            color: root.clockStyle === "accent" ? Theme.withAlpha(Theme.accent, 0.8) : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Math.min(14, Math.floor(root.height * 0.14)))
            elide: Text.ElideRight
            Layout.maximumWidth: Math.max(50, root.width - 24)
        }

        Item { Layout.fillHeight: true }
    }
}
