import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    implicitWidth: 36
    implicitHeight: Theme.barHeight
    Layout.alignment: Qt.AlignVCenter
    visible: CavaService.running

    Component.onCompleted: CavaService.acquire()
    Component.onDestruction: CavaService.release()

    Row {
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: 5
            delegate: Rectangle {
                required property int index
                width: 3
                height: Math.max(3, Math.min(18, (CavaService.values[index] || 0) * 18))
                radius: 1.5
                color: Theme.accent
                anchors.bottom: parent.bottom
            }
        }
    }
}
