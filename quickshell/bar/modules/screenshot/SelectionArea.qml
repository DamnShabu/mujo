import QtQuick
import QtQuick.Controls
import "../../theme"

Item {
    id: root

    property int selX: 0
    property int selY: 0
    property int selWidth: 0
    property int selHeight: 0
    property bool resizable: true

    signal moved(int newX, int newY)
    signal resized(int newX, int newY, int newW, int newH)

    visible: selWidth > 0 && selHeight > 0
    x: selX
    y: selY
    width: selWidth
    height: selHeight
    z: 9990

    // Selection border outline
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.accent
        border.width: 2

        // Drag whole selection to move
        MouseArea {
            id: moveArea
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            enabled: root.resizable

            property int startMouseX: 0
            property int startMouseY: 0
            property int startSelX: 0
            property int startSelY: 0
            property bool isMoving: false

            onPressed: function(mouse) {
                isMoving = true
                startMouseX = mouse.x
                startMouseY = mouse.y
                startSelX = root.selX
                startSelY = root.selY
            }

            onPositionChanged: function(mouse) {
                if (isMoving) {
                    var dx = mouse.x - startMouseX
                    var dy = mouse.y - startMouseY
                    root.moved(Math.max(0, startSelX + dx), Math.max(0, startSelY + dy))
                }
            }

            onReleased: function(mouse) {
                isMoving = false
            }
        }
    }

    // ─── 8 Resize Handles ────────────────────────────────────────────────────
    readonly property int handleSize: 10

    component ResizeHandle: Rectangle {
        id: handle
        property int edgeX: 0 // -1: left, 0: center, 1: right
        property int edgeY: 0 // -1: top, 0: center, 1: bottom
        property var cursorType: Qt.ArrowCursor

        width: root.handleSize
        height: root.handleSize
        radius: 2
        color: Theme.accent
        border.color: Theme.bg
        border.width: 1
        visible: root.resizable

        x: {
            if (edgeX === -1) return -root.handleSize / 2
            if (edgeX === 0) return (root.width - root.handleSize) / 2
            return root.width - root.handleSize / 2
        }
        y: {
            if (edgeY === -1) return -root.handleSize / 2
            if (edgeY === 0) return (root.height - root.handleSize) / 2
            return root.height - root.handleSize / 2
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4 // expand hit box
            cursorShape: handle.cursorType

            property int startMouseX: 0
            property int startMouseY: 0
            property int origX: 0
            property int origY: 0
            property int origW: 0
            property int origH: 0

            onPressed: function(mouse) {
                startMouseX = mouse.x
                startMouseY = mouse.y
                origX = root.selX
                origY = root.selY
                origW = root.selWidth
                origH = root.selHeight
            }

            onPositionChanged: function(mouse) {
                if (!pressed) return
                var dx = mouse.x - startMouseX
                var dy = mouse.y - startMouseY

                var nx = origX
                var ny = origY
                var nw = origW
                var nh = origH

                // Horizontal resize
                if (handle.edgeX === -1) {
                    var potentialW = origW - dx
                    if (potentialW > 10) {
                        nx = origX + dx
                        nw = potentialW
                    }
                } else if (handle.edgeX === 1) {
                    nw = Math.max(10, origW + dx)
                }

                // Vertical resize
                if (handle.edgeY === -1) {
                    var potentialH = origH - dy
                    if (potentialH > 10) {
                        ny = origY + dy
                        nh = potentialH
                    }
                } else if (handle.edgeY === 1) {
                    nh = Math.max(10, origH + dy)
                }

                root.resized(nx, ny, nw, nh)
            }
        }
    }

    // Top-Left
    ResizeHandle { edgeX: -1; edgeY: -1; cursorType: Qt.SizeFDiagCursor }
    // Top-Center
    ResizeHandle { edgeX: 0; edgeY: -1; cursorType: Qt.SizeVerCursor }
    // Top-Right
    ResizeHandle { edgeX: 1; edgeY: -1; cursorType: Qt.SizeBDiagCursor }
    // Middle-Right
    ResizeHandle { edgeX: 1; edgeY: 0; cursorType: Qt.SizeHorCursor }
    // Bottom-Right
    ResizeHandle { edgeX: 1; edgeY: 1; cursorType: Qt.SizeFDiagCursor }
    // Bottom-Center
    ResizeHandle { edgeX: 0; edgeY: 1; cursorType: Qt.SizeVerCursor }
    // Bottom-Left
    ResizeHandle { edgeX: -1; edgeY: 1; cursorType: Qt.SizeBDiagCursor }
    // Middle-Left
    ResizeHandle { edgeX: -1; edgeY: 0; cursorType: Qt.SizeHorCursor }
}
