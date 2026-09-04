import QtQuick
import QtQuick.Layouts
import "../../theme"

Rectangle {
    id: root
    property var panelWindow
    property string screenName: ""

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: 1
    implicitHeight: Math.round(Theme.barHeight * 0.45)
    color: Theme.borderStrong
    opacity: 0.7
}
