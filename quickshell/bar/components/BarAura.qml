import QtQuick
import "../theme"

// BarAura: Mujo Living Ambient Luminescence (無常)
// Subtle sub-surface ambient warmth embedded in floating bar clusters.
Item {
    id: root

    property color auraColor: Theme.accent
    property real intensity: 1.0
    property bool hovered: false
    property bool active: false
    property real radius: Theme.groupRadius

    anchors.fill: parent
    z: -1

    readonly property real targetAlpha: (root.active ? 0.10 : (root.hovered ? 0.06 : 0.0)) * root.intensity

    Rectangle {
        id: bgGlow
        anchors.fill: parent
        radius: root.radius
        color: Theme.withAlpha(root.auraColor, root.targetAlpha)

        Behavior on color {
            ColorAnimation { duration: Anim.d(Anim.fast) }
        }
    }
}
