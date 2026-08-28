import QtQuick
import "../theme"

// ToggleSwitch: Living transformation switch for Mujo (無常).
// Communicates transformation and energy flow between dormant and active states.
// Features organic thumb elasticity, glowing aura, and responsive hover reactions.
Rectangle {
    id: root

    // Controlled: `checked` is an input, never written from in here. Assigning
    // to it would destroy the caller's binding on the very first tap, after
    // which the switch would no longer track the store — a CLI `mujo settings
    // set`, a failed write, or a second panel showing the same key would all
    // leave it lying. The caller's onToggled writes; the binding brings it back.
    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 38
    implicitHeight: 20
    radius: height / 2

    // Background transition
    color: root.checked ? Theme.accent : Theme.surfaceActive
    border.color: root.checked ? Theme.accent : (swHh.hovered ? Theme.borderStrong : Theme.border)
    border.width: 1
    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    // Thumb
    Rectangle {
        id: thumb
        width: parent.height - 4
        height: width
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? (parent.width - width - 2) : 2

        color: root.checked ? Theme.accentText : (swHh.hovered ? Theme.text : Theme.textSecondary)

        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        Behavior on x {
            NumberAnimation {
                duration: Anim.d(Anim.standard)
                easing.type: Anim.easeStandard
            }
        }
    }

    HoverHandler { id: swHh; cursorShape: Qt.PointingHandCursor }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.toggled(!root.checked)
    }
}
