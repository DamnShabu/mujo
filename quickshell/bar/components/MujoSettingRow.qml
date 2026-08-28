import QtQuick
import QtQuick.Layouts
import "../theme"

// MujoSettingRow: High-scannability, atmospheric setting row item for Mujo (無常).
// Layout: [Icon] Title + Description [NixOS/Status Tags] ... [Control Slot]
Rectangle {
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
    implicitHeight: Math.max(42, rowLayout.implicitHeight + 12)
    color: "transparent"
    opacity: root.disabled ? 0.45 : 1.0
    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

    HoverHandler { id: rowHh }

    // The row content sits flush with the card's content column so icons and
    // controls line up with the card header and its divider. The hover
    // highlight is a separate rectangle that bleeds outwards into the card's
    // padding, so it still reads as a padded pill without indenting the row.
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -10
        anchors.rightMargin: -10
        radius: Theme.radiusMd
        color: (rowHh.hovered && !root.disabled) ? Theme.surfaceHover : "transparent"
        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    }

    RowLayout {
        id: rowLayout
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: 12

        // Icon with subtle container
        Item {
            visible: root.iconName !== ""
            implicitWidth: 28
            implicitHeight: 28
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: (rowHh.hovered && !root.disabled) ? Theme.withAlpha(Theme.accent, 0.12) : Theme.withAlpha(Theme.surfaceActive, 0.6)
                border.color: (rowHh.hovered && !root.disabled) ? Theme.withAlpha(Theme.accent, 0.25) : Theme.border
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: root.iconName
                    pixelSize: 17
                    color: (rowHh.hovered && !root.disabled) ? Theme.accent : Theme.textSecondary
                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                }
            }
        }

        // Title + Subtitle + Tag Pills
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                spacing: 6

                Text {
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: false
                }

                // NixOS tag
                Rectangle {
                    visible: root.isNixos
                    implicitWidth: nrTxt.implicitWidth + 8
                    implicitHeight: 15
                    radius: 3
                    color: Theme.withAlpha(Theme.accent, 0.12)
                    border.color: Theme.withAlpha(Theme.accent, 0.4)

                    Text {
                        id: nrTxt
                        anchors.centerIn: parent
                        text: "NIXOS"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel - 1
                        font.bold: true
                    }
                }

                // Badge tag
                Rectangle {
                    visible: root.badgeText !== "" && !root.isNixos
                    implicitWidth: brTxt.implicitWidth + 8
                    implicitHeight: 15
                    radius: 3
                    color: Theme.withAlpha(root.badgeColor, 0.12)
                    border.color: Theme.withAlpha(root.badgeColor, 0.4)

                    Text {
                        id: brTxt
                        anchors.centerIn: parent
                        text: root.badgeText
                        color: root.badgeColor
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel - 1
                        font.bold: true
                    }
                }
            }

            Text {
                visible: root.description !== ""
                text: root.description
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // Control Slot
        RowLayout {
            id: controlSlot
            spacing: 8
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
