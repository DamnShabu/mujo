import QtQuick
import Quickshell
import Quickshell.Widgets


Rectangle {
    id: root

    property var entry
    property bool highlighted: false

    function iconSource(name) {
        if (!name) return ""
        if (name.indexOf("://") >= 0) return name
        if (name.charAt(0) === "/") return "file://" + name
        return Quickshell.iconPath(name, "application-x-executable")
    }

    width: 0
    height: 36
    radius: 5
    color: root.highlighted ? Theme.surfaceHover : "transparent"

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        radius: 1.5
        color: Theme.textSecondary
        opacity: root.highlighted ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            source: root.entry ? root.iconSource(root.entry.icon) : ""
            width: 18
            height: 18
            visible: root.entry && root.entry.icon !== ""
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 18 - 8 - 10
            Text {
                text: root.entry ? root.entry.name : ""
                color: Theme.text
                font.pixelSize: 13
            }
            Text {
                text: root.entry ? root.entry.genericName : ""
                color: Theme.textSecondary
                font.pixelSize: 10
                visible: root.entry && root.entry.genericName && root.entry.genericName !== "" &&
                         root.entry.genericName !== root.entry.name
            }
        }
    }
}
