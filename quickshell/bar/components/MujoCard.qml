import QtQuick
import QtQuick.Layouts
import "../theme"

// MujoCard: Standardized, atmospheric settings category container.
// Provides a clean titled surface with optional icon, badges, smooth accordion body,
// and action controls. Respects Theme tokens and reduced-motion preferences.
Rectangle {
    id: root

    property string title: ""
    property string iconName: ""
    property string badgeText: ""
    property color badgeColor: Theme.accent
    property bool isNixos: false
    property bool collapsible: true
    property bool expanded: true
    property bool hideable: false
    signal hideRequested()

    default property alias content: innerCol.children
    property alias actions: headerActions.children

    Layout.fillWidth: true
    implicitHeight: layoutCol.implicitHeight + 28
    radius: Theme.radiusLg
    color: Theme.surface
    border.color: cardHh.hovered ? Theme.borderStrong : Theme.border
    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    clip: true

    // Specular top highlight line
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Theme.withAlpha("#ffffff", 0.04)
    }

    HoverHandler { id: cardHh }

    ColumnLayout {
        id: layoutCol
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 14
        }
        spacing: 12

        // ── Card Header ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: 26

            RowLayout {
                anchors.fill: parent
                spacing: 9

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
                    font.pixelSize: Theme.fontSizeBody + 1
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // NixOS badge
                Rectangle {
                    visible: root.isNixos
                    implicitWidth: nbTxt.implicitWidth + 10
                    implicitHeight: 16
                    radius: Theme.radiusSm
                    color: Theme.withAlpha(Theme.accent, 0.14)
                    border.color: Theme.accent
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: nbTxt
                        anchors.centerIn: parent
                        text: "NIXOS"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        font.bold: true
                    }
                }

                // Generic badge
                Rectangle {
                    visible: root.badgeText !== "" && !root.isNixos
                    implicitWidth: cbTxt.implicitWidth + 10
                    implicitHeight: 16
                    radius: Theme.radiusSm
                    color: Theme.withAlpha(root.badgeColor, 0.14)
                    border.color: root.badgeColor
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: cbTxt
                        anchors.centerIn: parent
                        text: root.badgeText
                        color: root.badgeColor
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    id: headerActions
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter
                }

                // Hide button
                MaterialIcon {
                    visible: root.hideable && cardHh.hovered
                    iconName: "visibility_off"
                    pixelSize: 16
                    color: hideHh.hovered ? Theme.text : Theme.textDim
                    Layout.alignment: Qt.AlignVCenter
                    HoverHandler { id: hideHh; cursorShape: Qt.PointingHandCursor }
                    // Exclusive grab: without it the header's collapse tap
                    // below fires for this icon too.
                    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.hideRequested() }
                }

                // Collapse chevron
                MaterialIcon {
                    visible: root.collapsible
                    iconName: root.expanded ? "expand_less" : "expand_more"
                    pixelSize: 18
                    color: chevHh.hovered ? Theme.text : Theme.textSecondary
                    Layout.alignment: Qt.AlignVCenter
                    HoverHandler { id: chevHh; cursorShape: Qt.PointingHandCursor }
                    // Exclusive grab: the header tap below toggled `expanded`
                    // a second time, so the chevron appeared to do nothing.
                    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.expanded = !root.expanded }
                }
            }

            TapHandler {
                enabled: root.collapsible
                onTapped: root.expanded = !root.expanded
            }
        }

        // Header divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
            visible: root.expanded && innerCol.children.length > 0
        }

        // ── Card Body (Collapsible) ───────────────────────────────────────────
        ColumnLayout {
            id: innerCol
            Layout.fillWidth: true
            opacity: root.expanded ? 1.0 : 0.0
            visible: opacity > 0
            spacing: 10
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.enter); easing.type: Anim.easeStandard } }
        }
    }
}
