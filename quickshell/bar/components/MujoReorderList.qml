import QtQuick
import QtQuick.Layouts
import "../theme"

// Reusable animated drag-and-drop & button reorderable list component.
// Provides tactile grabbing with cursor feedback, real-time live gap slotting,
// keyboard/click single-step movement buttons, and deletion.
Item {
    id: root

    property var model: []
    property int itemHeight: 38
    property int spacing: 8
    property real itemRadius: Theme.radiusMd
    property bool fontMono: true
    property bool showButtons: true
    property bool showRemove: true
    property var formatter: null
    property var iconResolver: null
    property var badgeResolver: null
    property var badgeColorResolver: null

    signal reordered(var newModel)
    signal itemMoved(int fromIndex, int toIndex)
    signal itemRemoved(int index, var item)

    readonly property int count: model ? model.length : 0
    readonly property int step: itemHeight + spacing

    Layout.fillWidth: true
    implicitWidth: 300
    implicitHeight: count > 0 ? (count * itemHeight + (count - 1) * spacing) : 0

    property int dragIndex: -1
    property real dragY: 0
    property int targetIndex: -1
    readonly property bool isDragging: dragIndex >= 0

    function move(fromIdx, dir) {
        var toIdx = fromIdx + dir
        if (!model || toIdx < 0 || toIdx >= model.length) return
        var arr = model.slice()
        var temp = arr[fromIdx]
        arr[fromIdx] = arr[toIdx]
        arr[toIdx] = temp
        root.model = arr
        root.itemMoved(fromIdx, toIdx)
        root.reordered(arr)
    }

    function remove(idx) {
        if (!model || idx < 0 || idx >= model.length) return
        var arr = model.slice()
        var removedItem = arr.splice(idx, 1)[0]
        root.model = arr
        root.itemRemoved(idx, removedItem)
        root.reordered(arr)
    }

    Repeater {
        id: repeater
        model: root.model

        delegate: Rectangle {
            id: rowItem
            required property int index
            required property var modelData

            readonly property bool isThisDragged: root.dragIndex === index

            // Calculate the prospective slot index during live drag
            readonly property int visualSlot: {
                if (!root.isDragging || root.dragIndex === root.targetIndex) return index
                if (root.dragIndex < root.targetIndex) {
                    if (index > root.dragIndex && index <= root.targetIndex) return index - 1
                    return index
                } else {
                    if (index >= root.targetIndex && index < root.dragIndex) return index + 1
                    return index
                }
            }

            width: root.width
            height: root.itemHeight
            radius: root.itemRadius

            x: 0
            y: isThisDragged ? root.dragY : (visualSlot * root.step)
            z: isThisDragged ? 100 : (10 - Math.min(10, index))

            // Smooth sliding displacement for other rows while dragging
            Behavior on y {
                enabled: !rowItem.isThisDragged
                NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard }
            }

            // Visual Styling
            color: isThisDragged
                   ? Theme.surfaceActive
                   : (rowHover.hovered ? Theme.surfaceHover : Theme.bg)
            border.color: isThisDragged
                          ? Theme.accent
                          : (rowHover.hovered ? Theme.borderStrong : Theme.border)
            border.width: isThisDragged ? 1.5 : 1

            scale: isThisDragged ? 1.02 : 1.0
            opacity: root.isDragging && !isThisDragged ? 0.85 : 1.0

            Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }
            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            // Outer highlight aura during drag
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: Theme.accent
                border.width: 1
                opacity: rowItem.isThisDragged ? 0.45 : 0.0
                scale: 1.03
                z: -1
                visible: rowItem.isThisDragged
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 8

                // Drag Handle Glyph Area
                Item {
                    implicitWidth: 20
                    implicitHeight: parent.height
                    Layout.alignment: Qt.AlignVCenter

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "drag_indicator"
                        pixelSize: 16
                        color: rowItem.isThisDragged ? Theme.accent : (rowHover.hovered ? Theme.text : Theme.textDim)
                    }
                }

                // Optional Module Icon
                MaterialIcon {
                    visible: root.iconResolver ? (root.iconResolver(rowItem.modelData) !== "") : false
                    iconName: root.iconResolver ? (root.iconResolver(rowItem.modelData) || "") : ""
                    pixelSize: 16
                    color: Theme.accent
                }

                // Title / Identifier Text
                Text {
                    Layout.fillWidth: true
                    text: root.formatter ? root.formatter(rowItem.modelData) : String(rowItem.modelData)
                    color: Theme.text
                    font.family: root.fontMono ? Theme.fontMono : Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    elide: Text.ElideRight
                }

                // Optional Custom Badge
                Rectangle {
                    visible: root.badgeResolver ? (root.badgeResolver(rowItem.modelData) !== "") : false
                    implicitHeight: 18
                    implicitWidth: badgeTxt.implicitWidth + 10
                    radius: Theme.radiusSm
                    color: root.badgeColorResolver ? root.badgeColorResolver(rowItem.modelData) : Theme.accentDim

                    Text {
                        id: badgeTxt
                        anchors.centerIn: parent
                        text: root.badgeResolver ? (root.badgeResolver(rowItem.modelData) || "") : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.bold: true
                    }
                }

                // Reorder Up
                IconButton {
                    visible: root.showButtons
                    iconName: "arrow_upward"
                    enabled: rowItem.index > 0 && !root.isDragging
                    onClicked: root.move(rowItem.index, -1)
                }

                // Reorder Down
                IconButton {
                    visible: root.showButtons
                    iconName: "arrow_downward"
                    enabled: rowItem.index < root.count - 1 && !root.isDragging
                    onClicked: root.move(rowItem.index, 1)
                }

                // Remove from List
                IconButton {
                    visible: root.showRemove
                    iconName: "close"
                    enabled: !root.isDragging
                    onClicked: root.remove(rowItem.index)
                }
            }

            HoverHandler { id: rowHover }

            // Drag Gestures Handler (excludes the button area on the right)
            MouseArea {
                id: dragArea
                anchors.fill: parent
                anchors.rightMargin: (root.showButtons ? 72 : 0) + (root.showRemove ? 36 : 0)
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true

                property real pressOffsetY: 0

                onPressed: (mouse) => {
                    pressOffsetY = mouse.y
                    root.dragIndex = rowItem.index
                    root.targetIndex = rowItem.index
                    root.dragY = rowItem.index * root.step
                }

                onPositionChanged: (mouse) => {
                    if (root.dragIndex !== rowItem.index) return
                    var rootPos = mapToItem(root, mouse.x, mouse.y)
                    var newY = rootPos.y - pressOffsetY
                    var maxBoundY = Math.max(0, (root.count - 1) * root.step)
                    root.dragY = Math.max(0, Math.min(maxBoundY, newY))
                    root.targetIndex = Math.max(0, Math.min(root.count - 1, Math.round(root.dragY / root.step)))
                }

                onReleased: {
                    if (root.dragIndex === rowItem.index) {
                        var fromI = root.dragIndex
                        var toI = root.targetIndex
                        root.dragIndex = -1
                        root.targetIndex = -1
                        if (fromI !== toI && fromI >= 0 && toI >= 0 && fromI < root.count && toI < root.count) {
                            var arr = root.model.slice()
                            var item = arr.splice(fromI, 1)[0]
                            arr.splice(toI, 0, item)
                            root.model = arr
                            root.itemMoved(fromI, toI)
                            root.reordered(arr)
                        }
                    }
                }

                onCanceled: {
                    root.dragIndex = -1
                    root.targetIndex = -1
                }
            }
        }
    }
}
