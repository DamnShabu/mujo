import QtQuick

Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 36
    implicitHeight: 20
    radius: height / 2
    color: root.checked ? Theme.accent : Theme.surfaceActive

    Behavior on color { ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }

    Rectangle {
        width: parent.height - 6
        height: parent.height - 6
        radius: height / 2
        color: root.checked ? Theme.accentText : Theme.text
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3

        Behavior on color { ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }

        Behavior on x { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast; easing.type: Easing.OutQuad } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
