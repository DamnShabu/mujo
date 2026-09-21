import QtQuick
import QtQuick.Layouts
import "../theme"

// One item in a list of real objects: a generation, an override, a VM, a
// credential, a registered application, a mute rule.
//
// These are the one thing on a settings page that still gets a surface — they
// are discrete things you act on, not settings. Ten groups drew them by hand at
// heights of 34, 38, 40, 44 and 52, half with a hover state and half without.
Rectangle {
    id: item

    property bool active: false
    property bool interactive: false
    property bool disabled: false

    signal clicked()

    default property alias content: line.children

    Layout.fillWidth: true
    implicitHeight: Math.max(40, line.implicitHeight + 14)
    radius: Theme.radiusSm
    opacity: item.disabled ? 0.5 : 1
    color: item.active ? Theme.accentDim
         : ((hh.hovered && item.interactive) ? Theme.surfaceHover : Theme.surface)
    border.width: 1
    border.color: item.active ? Theme.withAlpha(Theme.accent, 0.55) : Theme.border
    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    HoverHandler { id: hh; enabled: item.interactive; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: item.interactive; onTapped: item.clicked() }

    RowLayout {
        id: line
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 10
        }
        spacing: 10
    }
}
