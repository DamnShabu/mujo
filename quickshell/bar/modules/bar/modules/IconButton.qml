import QtQuick

Rectangle {
    id: root

    property string iconName: ""
    property bool active: false
    property bool hovered: hoverHandler.hovered
    property color iconColor: root.active ? Theme.accent : (root.hovered ? Theme.text : Theme.textSecondary)
    signal clicked()

    implicitWidth: 30
    implicitHeight: 30
    radius: Theme.radiusSm
    color: root.active ? Theme.accentDim : (root.hovered ? Theme.surfaceHover : "transparent")
    border.color: root.active ? Theme.accent : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }

    MaterialIcon {
        iconName: root.iconName
        pixelSize: 17
        anchors.centerIn: parent
        color: root.iconColor
        Behavior on color { ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }
    }

    HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.clicked() }
}
