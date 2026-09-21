import QtQuick
import QtQuick.Layouts
import "../theme"

// A read-only fact: what it is on the left, what it says on the right.
//
//     Nix store                              18.4G used of 3.9G
//     Flake status                        ✓  up to date (2d)
//
// The value sits in the same right-hand column a SettingRow puts its control
// in, so a section that mixes facts and settings keeps one edge. The groups
// used to pin the value at `Layout.preferredWidth: 140` after the label, which
// left it stranded mid-row with the rest of the section empty beside it.
//
// Exactly one item in the row fills — the label. A spacer plus a width-capped
// value gives two things a claim on the slack and neither ends up where you
// asked for it.
Item {
    id: row

    property string label: ""
    property string value: ""
    property string iconName: ""            // status glyph in front of the value
    property color iconColor: Theme.textSecondary
    property color valueColor: Theme.text
    property bool mono: true

    default property alias trailing: trailingSlot.children

    Layout.fillWidth: true
    implicitHeight: Math.max(30, line.implicitHeight + 8)

    Accessible.role: Accessible.StaticText
    Accessible.name: row.label + ": " + row.value

    RowLayout {
        id: line
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 12

        Text {
            text: row.label
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        MaterialIcon {
            visible: row.iconName !== ""
            iconName: row.iconName
            pixelSize: 15
            color: row.iconColor
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            visible: row.value !== ""
            text: row.value
            color: row.valueColor
            font.family: row.mono ? Theme.fontMono : Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideLeft
            Layout.alignment: Qt.AlignVCenter
        }

        RowLayout {
            id: trailingSlot
            spacing: 6
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
