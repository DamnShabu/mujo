import QtQuick
import QtQuick.Layouts
import "../theme"

// MujoHero: Sleek, high-readability section header for settings panels.
// Provides clean typography, brand iconography, category metadata, and an action slot.
Rectangle {
    id: root

    property string brand: "general"
    property string title: ""
    property string subtitle: ""
    property string badgeText: ""
    property color badgeColor: Theme.accent
    property bool isNixos: false
    property bool showFlow: false
    property string kanji: ""
    property bool activeState: false
    property real stateValue: 0.0
    default property alias actions: actionsHolder.children

    Layout.fillWidth: true
    implicitHeight: Math.max(56, contentRow.implicitHeight + 20)
    radius: Theme.radiusLg
    color: Theme.surface
    border.color: Theme.border
    clip: true

    // Specular top highlight line
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Theme.withAlpha("#ffffff", 0.04)
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 14

        // Brand Icon Container
        Item {
            implicitWidth: 36
            implicitHeight: 36
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Theme.withAlpha(root.badgeColor, 0.12)
                border.color: Theme.withAlpha(root.badgeColor, 0.25)
                border.width: 1

                BrandIcon {
                    anchors.centerIn: parent
                    brand: root.brand
                    size: 22
                }
            }
        }

        // Title + Subtitle + Badges
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                spacing: 8

                Text {
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeHeading
                    font.bold: true
                }

                // NixOS configuration badge
                Rectangle {
                    visible: root.isNixos
                    implicitWidth: nixTxt.implicitWidth + 10
                    implicitHeight: 18
                    radius: Theme.radiusSm
                    color: Theme.withAlpha(Theme.accent, 0.14)
                    border.color: Theme.withAlpha(Theme.accent, 0.4)

                    Text {
                        id: nixTxt
                        anchors.centerIn: parent
                        text: "NIXOS"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        font.bold: true
                    }
                }

                // Custom badge (e.g. LIVE, STATUS, MODIFIED)
                Rectangle {
                    visible: root.badgeText !== "" && !root.isNixos
                    implicitWidth: bgTxt.implicitWidth + 10
                    implicitHeight: 18
                    radius: Theme.radiusSm
                    color: Theme.withAlpha(root.badgeColor, 0.14)
                    border.color: Theme.withAlpha(root.badgeColor, 0.4)

                    Text {
                        id: bgTxt
                        anchors.centerIn: parent
                        text: root.badgeText
                        color: root.badgeColor
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        font.bold: true
                    }
                }
            }

            Text {
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Action controls (Refresh, Rebuild, etc.)
        RowLayout {
            id: actionsHolder
            spacing: 8
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
