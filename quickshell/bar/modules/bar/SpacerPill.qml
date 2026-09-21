import QtQuick
import QtQuick.Layouts
import "../../theme"

// A fixed gap between two modules in the same group. Not elastic: every
// container on the bar is sized by its content, so there is no surplus width
// for a filler to absorb.
Item {
    id: root
    property var panelWindow
    property string screenName: ""

    implicitWidth: Theme.barItemPadding * 2
    implicitHeight: 1
    Layout.alignment: Qt.AlignVCenter
}
