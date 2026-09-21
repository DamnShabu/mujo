import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// One row of the sidebar tree — a category, or a sub-category under the open
// one. The active row carries its own highlight and a marker in the rail
// gutter; there is no separate glider, because a tree has rows of two heights
// and index arithmetic breaks on the first sub-category.
Item {
    id: row

    property var entry: ({})          // { kind, id, cat, label, icon }
    property bool active: false
    property bool inBranch: false     // the parent of the open branch
    property bool open: false         // this parent is expanded
    property bool compact: false
    property bool focused: false      // the rail has keyboard focus

    signal activated()

    readonly property bool isSub: entry.kind === "sub"

    implicitHeight: row.isSub ? 30 : 38
    Layout.fillWidth: true

    Accessible.role: row.isSub ? Accessible.PageTab : Accessible.PageTabList
    Accessible.name: row.entry.label || ""
    Accessible.checked: row.active

    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: row.activated() }

    // Selection marker in the gutter. It is the one place in the sidebar that
    // uses the accent, so the eye finds the current row immediately.
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: row.active ? (row.isSub ? 14 : 18) : 0
        radius: 1.5
        visible: !row.compact
        color: Theme.accent
        Behavior on height { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: row.compact ? 0 : 11
        radius: Theme.radiusSm
        color: row.active ? Theme.accentDim : (hh.hovered ? Theme.surfaceHover : "transparent")
        border.width: 1
        border.color: (row.active && row.focused) ? Theme.withAlpha(Theme.accent, 0.55) : "transparent"
        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: row.compact ? 0 : (row.isSub ? 22 : 10)
            anchors.rightMargin: row.compact ? 0 : 9
            spacing: row.compact ? 0 : 10

            Item { visible: row.compact; Layout.fillWidth: true }

            MaterialIcon {
                iconName: row.entry.icon || ""
                pixelSize: row.isSub ? 15 : 17
                color: row.active ? Theme.accent
                     : (row.inBranch || hh.hovered ? Theme.text : Theme.textDim)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }

            Item { visible: row.compact; Layout.fillWidth: true }

            Text {
                visible: !row.compact
                text: row.entry.label || ""
                color: (row.active || row.inBranch) ? Theme.text
                     : (hh.hovered ? Theme.text : Theme.textSecondary)
                font.family: Theme.fontFamily
                font.pixelSize: row.isSub ? Theme.fontSizeSmall : Theme.fontSizeBody
                font.weight: row.active ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                Layout.fillWidth: true
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }

            // Disclosure. A count badge used to live here too, which said
            // nothing you could not get by opening the branch.
            MaterialIcon {
                visible: !row.isSub && !row.compact && (row.entry.count || 0) > 0
                iconName: "expand_more"
                pixelSize: 15
                color: row.inBranch ? Theme.textSecondary : Theme.textDim
                rotation: row.open ? 180 : 0
                Layout.alignment: Qt.AlignVCenter
                Behavior on rotation {
                    NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard }
                }
            }
        }
    }
}
