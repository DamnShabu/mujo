import QtQuick

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property color fillColor: Theme.accent
    signal moved(real value)

    implicitHeight: 16

    readonly property real ratio: root.to > root.from ? Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from))) : 0

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 7
        radius: 3.5
        color: Theme.surfaceActive

        Rectangle {
            width: track.width * root.ratio
            height: track.height
            radius: track.radius
            color: root.fillColor
        }
    }

    Rectangle {
        id: handle
        width: 14
        height: 14
        radius: 7
        color: Theme.text
        border.color: Theme.bg
        border.width: 2
        anchors.verticalCenter: track.verticalCenter
        x: track.width * root.ratio - width / 2
    }

    function setFromX(px) {
        var ratio = Math.max(0, Math.min(1, px / root.width))
        var v = root.from + ratio * (root.to - root.from)
        root.value = v
        root.moved(v)
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.setFromX(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.setFromX(mouse.x) }
    }
}
