import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// LauncherGroupHeader: Elegant section header for Mujo (無常) List View.
// Clearly delineates group boundaries and organizational categories with
// subtle iconography, count badges, and specular dividers.
Item {
    id: root

    property string groupName: ""
    property string groupIcon: "folder"
    property int count: 0
    property bool isFirst: false

    width: parent ? parent.width : 0
    implicitHeight: isFirst ? 28 : 36

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Spacer before non-first sections
        Item {
            visible: !root.isFirst
            Layout.fillWidth: true
            Layout.preferredHeight: 8
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Section Icon Pill
            Rectangle {
                implicitWidth: 22
                implicitHeight: 22
                radius: Theme.radiusSm
                color: Theme.withAlpha(Theme.accent, 0.15)
                border.color: Theme.withAlpha(Theme.accent, 0.3)
                border.width: 1

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: root.groupIcon || "folder"
                    pixelSize: 12
                    color: Theme.accent
                }
            }

            // Group Name Title
            Text {
                text: root.groupName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                elide: Text.ElideRight
            }

            // Count Badge Pill
            Rectangle {
                visible: root.count > 0
                implicitWidth: countTxt.implicitWidth + 10
                implicitHeight: 18
                radius: 9
                color: Theme.surfaceActive
                border.color: Theme.borderStrong
                border.width: 1

                Text {
                    id: countTxt
                    anchors.centerIn: parent
                    text: root.count
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel - 1
                    font.bold: true
                }
            }

            // Subtle Horizontal Accent Divider Line
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.leftMargin: 4
                color: Theme.border
                opacity: 0.6
            }
        }
    }
}
