import QtQuick
import "../theme"

Rectangle {
    id: root

    property string iconName: ""
    property bool active: false
    property bool hovered: hoverHandler.hovered
    property bool pressed: tapHandler.pressed
    property color iconColor: root.active ? Theme.accent : (root.hovered ? Theme.text : Theme.textSecondary)
    signal clicked()

    implicitWidth: 30
    implicitHeight: 30
    radius: Theme.radiusSm
    
    // Living background state
    color: root.active ? Theme.accentDim
         : (root.pressed ? Theme.surfaceActive : (root.hovered ? Theme.surfaceHover : "transparent"))
    border.color: root.active ? Theme.accent : (root.hovered ? Theme.borderStrong : "transparent")
    border.width: 1

    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    // Tactile micro-interaction
    scale: Anim.microInteractions ? (root.pressed ? 0.94 : 1.0) : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: Anim.d(Anim.fast)
            easing.type: Anim.easeStandard
        }
    }

    MaterialIcon {
        iconName: root.iconName
        pixelSize: 17
        anchors.centerIn: parent
        color: root.iconColor
        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    }

    HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }
    // ReleaseWithinBounds takes an exclusive grab on press. The default
    // (DragThreshold) does not, so a button stacked over another tappable item
    // fired both — a modal's close button also hit whatever sat beneath it.
    TapHandler {
        id: tapHandler
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }
}

