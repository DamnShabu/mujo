import QtQuick
import QtQuick.Layouts

// A floating, rounded container that clusters bar widgets into one "pill group"
// (see the reference shells: search+workspaces, clock, and the status icons each
// live in their own detached rounded group). Children are laid out in `row` and
// vertically centered.
Rectangle {
    id: root
    default property alias content: row.data
    property int spacing: Theme.groupPadding

    implicitHeight: Theme.barHeight
    implicitWidth: row.implicitWidth + Theme.groupPadding * 2 + 2
    radius: Theme.groupRadius
    // WP-17: bar.opacity scales the group-background alpha (content/border stay).
    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.surface.a * Theme.barGroupOpacity)
    border.color: Theme.border

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.spacing
    }
}
