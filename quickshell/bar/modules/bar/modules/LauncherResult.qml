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
    height: 42
    radius: Theme.radiusMd
    color: root.highlighted ? Theme.surfaceHover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: root.highlighted ? 20 : 0
        radius: 1.5
        color: Theme.accent
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 11

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            source: root.entry ? root.iconSource(root.entry.icon) : ""
            width: 22
            height: 22
            visible: root.entry && root.entry.icon !== ""
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 22 - 11 - 14
            spacing: 1
            Text {
                text: root.entry ? root.entry.name : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.entry ? root.entry.genericName : ""
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
                width: parent.width
                visible: root.entry && root.entry.genericName && root.entry.genericName !== "" &&
                         root.entry.genericName !== root.entry.name
            }
        }
    }
}
