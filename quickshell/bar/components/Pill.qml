import QtQuick
import "../theme"

Rectangle {
    id: root

    property bool interactive: true
    property bool hovered: hoverHandler.hovered
    property bool pressed: tapHandler.pressed
    property bool active: false
    signal clicked()

    radius: Theme.groupRadius
    color: root.active ? Theme.accentDim
         : (root.hovered && root.interactive ? Theme.surfaceHover : Theme.surface)
    border.color: root.active ? Theme.accent : (root.hovered && root.interactive ? Theme.borderStrong : Theme.border)
    border.width: 1

    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    scale: (root.interactive && Anim.microInteractions) ? (root.pressed ? 0.96 : 1.0) : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: Anim.d(Anim.fast)
            easing.type: Anim.easeStandard
        }
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        id: tapHandler
        enabled: root.interactive
        onTapped: root.clicked()
    }
}

