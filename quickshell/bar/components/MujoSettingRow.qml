import QtQuick
import QtQuick.Layouts
import "../theme"

// One setting on a page: its name and what it does on the left, the control
// that changes it on the right.
//
//     Bar height
//     Content height of the floating groups          [ ──●── 34px ]
//
// The row draws no container of its own. Settings pages are a single flat
// plane — the sections above give the grouping, the hover band gives the
// scan line, and the control is the only thing with a shape. The previous
// version boxed every row's icon in a bordered tile and every group in a
// filled card, which put three nested rectangles behind one toggle.
Item {
    id: root

    property string iconName: ""
    property string title: ""
    property string description: ""
    property string badgeText: ""
    property color badgeColor: Theme.accent
    property bool isNixos: false
    property bool disabled: false

    default property alias control: controlSlot.children

    Layout.fillWidth: true
    implicitHeight: Math.max(46, body.implicitHeight + 14)
    opacity: root.disabled ? 0.4 : 1
    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

    // The control inside carries the interactive role; the row groups the name
    // and helper text with it so a screen reader reads them together.
    Accessible.role: Accessible.Grouping
    Accessible.name: root.title
    Accessible.description: root.description

    HoverHandler { id: hh }

    // The scan band. It bleeds past the content column so it reads as a full
    // row of the page rather than a box drawn around the text.
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -12
        anchors.rightMargin: -12
        radius: Theme.radiusSm
        color: (hh.hovered && !root.disabled) ? Theme.surfaceHover : "transparent"
        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    }

    RowLayout {
        id: body
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: 13

        // A bare glyph, aligned to the name — not a tile. Optional; most rows
        // read better without one, and the section heading already names the
        // group they belong to.
        MaterialIcon {
            visible: root.iconName !== ""
            iconName: root.iconName
            pixelSize: 16
            color: Theme.textSecondary
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            RowLayout {
                spacing: 7
                Layout.fillWidth: true

                Text {
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    elide: Text.ElideRight
                }

                // NIXOS marks a setting the flake owns, so it outranks a
                // caller.s own badge on the same row.
                StatusTag {
                    visible: root.isNixos || root.badgeText !== ""
                    text: root.isNixos ? "NIXOS" : root.badgeText
                    toneColor: root.isNixos ? Theme.accent : root.badgeColor
                }

                Item { Layout.fillWidth: true }
            }

            Text {
                visible: root.description !== ""
                text: root.description
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                lineHeight: 1.25
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        RowLayout {
            id: controlSlot
            spacing: 8
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
