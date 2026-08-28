import QtQuick
import QtQuick.Layouts
import "../theme"

// MujoHero: Atmospheric, signature panel hero banner for Mujo (無常).
// Blends layered glassmorphism, living page-specific vector & canvas artwork, and clean typography.
Rectangle {
    id: root

    property string brand: "general"
    property string title: ""
    property string subtitle: ""
    property string badgeText: ""
    property color badgeColor: Theme.accent
    property bool isNixos: false
    property bool showFlow: true
    property string kanji: ""
    property bool activeState: false
    property real stateValue: 0.0
    default property alias actions: actionsHolder.children

    Layout.fillWidth: true
    implicitHeight: Math.max(92, contentRow.implicitHeight + 28)
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
        color: Theme.withAlpha("#ffffff", 0.05)
    }

    // Page-specific vector & canvas artwork backdrop
    MujoPageHeroArt {
        id: heroArt
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.min(420, parent.width * 0.52)
        visible: root.showFlow
        opacity: 0.16
        brand: root.brand
        accentColor: root.badgeColor
        isNixos: root.isNixos
        activeState: root.activeState
        stateValue: root.stateValue
        flowSpeed: 0.6
        intensity: 0.7
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Brand Icon with radiant aura
        Item {
            implicitWidth: 48
            implicitHeight: 48
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Theme.withAlpha(root.badgeColor, 0.14)
                border.color: Theme.withAlpha(root.badgeColor, 0.30)
                border.width: 1

                BrandIcon {
                    anchors.centerIn: parent
                    brand: root.brand
                    size: 32
                }
            }
        }

        // Title + Subtitle + Kanji mark + Badges
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                spacing: 8

                Text {
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle + 5
                    font.bold: true
                }

                // Optional Kanji Mark Stamp
                Rectangle {
                    visible: root.kanji !== ""
                    implicitWidth: kjTxt.implicitWidth + 8
                    implicitHeight: 18
                    radius: Theme.radiusSm
                    color: Theme.withAlpha(root.badgeColor, 0.12)
                    border.color: Theme.withAlpha(root.badgeColor, 0.35)

                    Text {
                        id: kjTxt
                        anchors.centerIn: parent
                        text: root.kanji
                        color: root.badgeColor
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel - 1
                        font.bold: true
                    }
                }

                // NixOS configuration badge
                Rectangle {
                    visible: root.isNixos
                    implicitWidth: nixTxt.implicitWidth + 12
                    implicitHeight: 18
                    radius: Theme.radiusSm
                    color: Theme.withAlpha(Theme.accent, 0.16)
                    border.color: Theme.accent

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
                    implicitWidth: bgTxt.implicitWidth + 12
                    implicitHeight: 18
                    radius: Theme.radiusSm
                    color: Theme.withAlpha(root.badgeColor, 0.16)
                    border.color: root.badgeColor

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
                font.pixelSize: Theme.fontSizeSmall + 1
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
