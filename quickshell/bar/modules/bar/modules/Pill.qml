import QtQuick

Rectangle {
    id: root

    property bool interactive: true
    property bool hovered: hoverHandler.hovered
    property bool active: false
    signal clicked()

    radius: Theme.groupRadius
    color: root.active ? Theme.accentDim
                       : (root.hovered && root.interactive ? Theme.surfaceHover : Theme.surface)
    border.color: root.active ? Theme.accent : Theme.border

    Behavior on color { ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }

    HoverHandler {
        id: hoverHandler
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.interactive
        onTapped: root.clicked()
    }
}
