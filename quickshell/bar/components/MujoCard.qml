import QtQuick
import QtQuick.Layouts
import "../theme"

// A modern elevated card section in the settings UI.
Item {
    id: root

    property string title: ""
    property string iconName: ""
    property string badgeText: ""
    property color badgeColor: Theme.accent
    property bool isNixos: false
    property bool collapsible: false
    property bool expanded: true

    default property alias content: bodyCol.children
    property alias actions: headerActions.children

    Accessible.role: Accessible.Grouping
    Accessible.name: root.title

    Layout.fillWidth: true
    implicitHeight: cardBg.implicitHeight

    Rectangle {
        id: cardBg
        anchors.fill: parent
        implicitHeight: innerCol.implicitHeight + 28
        radius: Theme.radiusMd
        color: Theme.surface
        border.width: 1
        border.color: cardHh.hovered ? Theme.borderStrong : Theme.border

        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

        HoverHandler { id: cardHh }

        ColumnLayout {
            id: innerCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 14
            }
            spacing: 0

            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: 8
                visible: root.title !== "" || root.iconName !== "" || root.badgeText !== "" || root.isNixos

                MaterialIcon {
                    visible: root.iconName !== ""
                    iconName: root.iconName
                    pixelSize: 18
                    color: Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                }

                StatusTag {
                    visible: root.isNixos || root.badgeText !== ""
                    text: root.isNixos ? "NIXOS" : root.badgeText
                    toneColor: root.isNixos ? Theme.accent : root.badgeColor
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    id: headerActions
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter
                }

                MaterialIcon {
                    visible: root.collapsible
                    iconName: "expand_more"
                    pixelSize: 18
                    color: chevHh.hovered ? Theme.text : Theme.textDim
                    rotation: root.expanded ? 180 : 0
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on rotation {
                        NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard }
                    }
                    HoverHandler { id: chevHh; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.expanded = !root.expanded
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                implicitHeight: 1
                color: Theme.border
                visible: headerRow.visible && root.expanded
            }

            ColumnLayout {
                id: bodyCol
                Layout.fillWidth: true
                spacing: 6
                visible: root.expanded
            }
        }
    }
}
