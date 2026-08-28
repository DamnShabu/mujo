import QtQuick
import QtQuick.Effects
import "../../theme"
import "../../components"

// One context-menu card. Used twice by DesktopWidgets: once for the menu itself
// and once for whichever submenu is open, which is why it is a component rather
// than inline markup — a submenu that looked or behaved differently from its
// parent would read as a different control.
//
// Purely presentational plus hit-testing: the owner decides what an action does.
// An entry is { icon, label, action | cmd | sub, divider }.
Item {
    id: root

    property var actions: []
    property bool open: false
    property int cardWidth: 248

    signal triggered(var act)
    // Emitted on every row the pointer enters, with that row's top edge relative
    // to this card — the owner positions a submenu from it. `act` is null for a
    // row that has no submenu, which is what closes an open one.
    signal rowHovered(var act, real rowY)

    implicitWidth: root.cardWidth
    implicitHeight: col.implicitHeight + 12
    width: implicitWidth
    height: implicitHeight

    opacity: root.open ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

    Rectangle {
        id: shadowSrc
        anchors.fill: card
        radius: card.radius
        color: "#000000"
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: shadowSrc
        source: shadowSrc
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: "#000000"
        shadowBlur: 1.0
        shadowVerticalOffset: 6
        shadowOpacity: 0.5
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Theme.bg
        radius: Theme.radiusLg
        border.color: Theme.border
        scale: root.open ? 1 : 0.96
        transformOrigin: Item.TopLeft
        Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic } }
        clip: true

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 0

            Repeater {
                model: root.actions
                delegate: Loader {
                    required property var modelData
                    width: parent.width
                    sourceComponent: modelData.divider ? dividerComp : itemComp

                    Component {
                        id: dividerComp
                        Item {
                            width: parent ? parent.width : 0
                            height: 9
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors { left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6 }
                                height: 1
                                color: Theme.border
                            }
                        }
                    }
                    Component {
                        id: itemComp
                        Rectangle {
                            id: row
                            width: parent ? parent.width : 0
                            height: 34
                            radius: Theme.radiusSm
                            readonly property bool disabled: modelData.disabled === true
                            color: (item_hh.hovered && !row.disabled) ? Theme.surfaceHover : "transparent"
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                spacing: 11
                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    iconName: modelData.icon
                                    pixelSize: 18
                                    color: row.disabled ? Theme.textDim
                                         : item_hh.hovered ? Theme.accent : Theme.textSecondary
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: row.disabled ? Theme.textDim : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                }
                            }
                            // Submenu affordance, in the place every menu puts it.
                            MaterialIcon {
                                visible: modelData.sub !== undefined
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                iconName: "chevron_right"
                                pixelSize: 16
                                color: item_hh.hovered ? Theme.accent : Theme.textSecondary
                            }
                            HoverHandler {
                                id: item_hh
                                cursorShape: row.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (!hovered) return
                                    root.rowHovered(modelData.sub !== undefined ? modelData : null,
                                                    row.mapToItem(root, 0, 0).y)
                                }
                            }
                            TapHandler {
                                // Submenu rows stay enabled so the tap is absorbed
                                // here and re-opens the submenu. Leaving them
                                // disabled let the click fall through to the
                                // dismiss layer, closing the whole menu.
                                enabled: !row.disabled
                                onTapped: {
                                    if (modelData.sub === undefined) root.triggered(modelData)
                                    else root.rowHovered(modelData, row.mapToItem(root, 0, 0).y)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
