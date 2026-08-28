import QtQuick
import QtQuick.Layouts
import "../theme"

// MujoSegmented: Organic, fluid segmented choice selector.
// Features a smooth sliding indicator pill with subtle glow and spring-like easing.
Item {
    id: root

    property var model: []          // Array of { id, label, icon } or strings
    // Controlled: `current` is an input. See ToggleSwitch for why.
    property var current: ""
    signal selected(var id)

    implicitHeight: 34
    implicitWidth: layoutRow.implicitWidth + 8

    Rectangle {
        id: bgContainer
        anchors.fill: parent
        radius: Theme.radiusMd
        color: Theme.withAlpha(Theme.bg, 0.6)
        border.color: Theme.border
        clip: true

        // Sliding Active Indicator Pill
        Rectangle {
            id: indicator
            property Item targetItem: null
            visible: targetItem !== null
            y: 3
            height: parent.height - 6
            radius: Theme.radiusSm
            color: Theme.accentDim
            border.color: Theme.withAlpha(Theme.accent, 0.4)

            x: targetItem ? targetItem.x : 0
            width: targetItem ? targetItem.width : 0

            Behavior on x { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }
            Behavior on width { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }

            // Subtle inner glow
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.withAlpha(Theme.accent, 0.3)
            }
        }

        RowLayout {
            id: layoutRow
            anchors.fill: parent
            anchors.margins: 3
            spacing: 2

            Repeater {
                id: rep
                model: root.model
                delegate: Item {
                    id: segItem
                    required property var modelData
                    required property int index

                    readonly property string itemId: typeof modelData === "object" ? modelData.id : modelData
                    readonly property string itemLabel: typeof modelData === "object" ? (modelData.label || modelData.id) : modelData
                    readonly property string itemIcon: typeof modelData === "object" ? (modelData.icon || "") : ""
                    readonly property bool isSelected: root.current === itemId

                    onIsSelectedChanged: {
                        if (isSelected) indicator.targetItem = segItem
                    }
                    Component.onCompleted: {
                        if (isSelected || (root.current === "" && index === 0)) {
                            indicator.targetItem = segItem
                        }
                    }

                    Layout.fillHeight: true
                    implicitWidth: Math.max(64, labelRow.implicitWidth + 18)

                    RowLayout {
                        id: labelRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIcon {
                            visible: segItem.itemIcon !== ""
                            iconName: segItem.itemIcon
                            pixelSize: 15
                            color: segItem.isSelected ? Theme.accent : (itemHh.hovered ? Theme.text : Theme.textSecondary)
                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                        }

                        Text {
                            text: segItem.itemLabel
                            color: segItem.isSelected ? Theme.text : (itemHh.hovered ? Theme.text : Theme.textSecondary)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: segItem.isSelected
                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                        }
                    }

                    HoverHandler { id: itemHh; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.selected(segItem.itemId)
                    }
                }
            }
        }
    }
}
