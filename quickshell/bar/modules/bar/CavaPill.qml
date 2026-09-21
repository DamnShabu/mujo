import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    // Content-driven like every other module, so the visualiser keeps the same
    // padding as the chips beside it instead of a fixed 36px box.
    implicitWidth: bars.implicitWidth + Theme.barItemPadding * 2
    implicitHeight: Theme.barHeight
    Layout.alignment: Qt.AlignVCenter
    readonly property bool barVisible: CavaService.running
    visible: root.barVisible

    Component.onCompleted: CavaService.acquire()
    Component.onDestruction: CavaService.release()

    Row {
        id: bars
        anchors.centerIn: parent
        spacing: 2
        readonly property int maxBar: Math.max(6, Theme.barItemHeight - 8)
        Repeater {
            model: 5
            delegate: Rectangle {
                required property int index
                width: 3
                height: Math.max(3, Math.min(bars.maxBar, (CavaService.values[index] || 0) * bars.maxBar))
                radius: 1.5
                color: Theme.accent
                anchors.bottom: parent.bottom
            }
        }
    }
}
