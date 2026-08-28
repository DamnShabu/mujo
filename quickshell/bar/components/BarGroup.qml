import QtQuick
import QtQuick.Layouts
import "../theme"

// Mujo Floating Pill Cluster (無常)
// Detached, living container with ambient edge luminescence, soft backdrop refraction,
// and fluid layout width transitions as widgets enter/exit.
Rectangle {
    id: root
    default property alias content: row.data
    property int spacing: Theme.groupPadding
    property bool hovered: groupHover.hovered
    property color auraColor: Theme.accent
    property bool active: false
    // Which edge the content is pinned to. The group.s width animates, so centred
    // content drifts by half the surplus while it does — pin it to the same edge
    // the group itself is anchored to and only the free edge moves.
    property int contentAlign: Qt.AlignHCenter   // AlignLeft | AlignHCenter | AlignRight

    implicitHeight: Theme.barHeight
    // groupPadding on each side, plus a little extra so content clears the
    // pill's rounded ends rather than tangenting them.
    readonly property int endCap: 3
    implicitWidth: row.implicitWidth + (Theme.groupPadding + endCap) * 2
    radius: Theme.groupRadius
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Anim.d(Anim.slow)
            easing.type: Anim.easeStandard
        }
    }

    // Surface fill with opacity scaling
    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.surface.a * Theme.barGroupOpacity)
    
    // Clean border with hover accentuation
    border.color: root.hovered ? Theme.borderStrong : Theme.border
    border.width: 1

    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    // Sub-surface ambient warmth
    BarAura {
        auraColor: root.auraColor
        hovered: root.hovered
        active: root.active
        radius: root.radius
    }

    HoverHandler {
        id: groupHover
    }

    RowLayout {
        id: row
        spacing: root.spacing
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.contentAlign === Qt.AlignLeft ? parent.left : undefined
        anchors.right: root.contentAlign === Qt.AlignRight ? parent.right : undefined
        anchors.horizontalCenter: root.contentAlign === Qt.AlignHCenter ? parent.horizontalCenter : undefined
        anchors.leftMargin: Theme.groupPadding + root.endCap
        anchors.rightMargin: Theme.groupPadding + root.endCap
    }
}

