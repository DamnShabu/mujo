import QtQuick
import QtQuick.Controls
import "../bar/theme"

Item {
    id: root

    property int selX: 0
    property int selY: 0
    property int selWidth: 0
    property int selHeight: 0
    property bool active: selWidth > 0 && selHeight > 0
    property bool resizable: true

    signal moved(int newX, int newY)
    signal resized(int newX, int newY, int newW, int newH)

    x: selX
    y: selY
    width: selWidth
    height: selHeight
    visible: active

    // Selection border
    Rectangle {
        id: box
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.accent
        border.width: 2

        // Semi-transparent inner highlight
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            color: Theme.withAlpha(Theme.accent, 0.05)
        }
    }

    // Move Area (inside rectangle)
    MouseArea {
        anchors.fill: parent
        anchors.margins: 10
        cursorShape: Qt.SizeAllCursor
        enabled: root.resizable

        property int startMouseX: 0
        property int startMouseY: 0
        property int startSelX: 0
        property int startSelY: 0

        onPressed: function(mouse) {
            startMouseX = mouse.x
            startMouseY = mouse.y
            startSelX = root.selX
            startSelY = root.selY
        }

        onPositionChanged: function(mouse) {
            if (pressed) {
                var dx = mouse.x - startMouseX
                var dy = mouse.y - startMouseY
                var nx = Math.max(0, startSelX + dx)
                var ny = Math.max(0, startSelY + dy)
                if (root.parent) {
                    nx = Math.min(root.parent.width - root.selWidth, nx)
                    ny = Math.min(root.parent.height - root.selHeight, ny)
                }
                root.moved(Math.round(nx), Math.round(ny))
            }
        }
    }

    // Helper component for 8 handles
    component ResizeHandle: Rectangle {
        id: handle
        property int handleSize: 10
        property var cursor: Qt.ArrowCursor
        property string handlePosition: "tl"

        width: handleSize
        height: handleSize
        radius: 2
        color: Theme.surface
        border.color: Theme.accent
        border.width: 2
        visible: root.resizable && root.selWidth > 20 && root.selHeight > 20

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: handle.cursor

            property int startMouseX: 0
            property int startMouseY: 0
            property int startX: 0
            property int startY: 0
            property int startW: 0
            property int startH: 0

            onPressed: function(mouse) {
                var globalPos = mapToItem(root.parent, mouse.x, mouse.y)
                startMouseX = globalPos.x
                startMouseY = globalPos.y
                startX = root.selX
                startY = root.selY
                startW = root.selWidth
                startH = root.selHeight
            }

            onPositionChanged: function(mouse) {
                if (!pressed) return
                var globalPos = mapToItem(root.parent, mouse.x, mouse.y)
                var dx = globalPos.x - startMouseX
                var dy = globalPos.y - startMouseY

                var nx = startX
                var ny = startY
                var nw = startW
                var nh = startH

                switch (handle.handlePosition) {
                    case "tl":
                        nx = Math.min(startX + startW - 10, startX + dx)
                        ny = Math.min(startY + startH - 10, startY + dy)
                        nw = startW - (nx - startX)
                        nh = startH - (ny - startY)
                        break
                    case "t":
                        ny = Math.min(startY + startH - 10, startY + dy)
                        nh = startH - (ny - startY)
                        break
                    case "tr":
                        ny = Math.min(startY + startH - 10, startY + dy)
                        nw = Math.max(10, startW + dx)
                        nh = startH - (ny - startY)
                        break
                    case "r":
                        nw = Math.max(10, startW + dx)
                        break
                    case "br":
                        nw = Math.max(10, startW + dx)
                        nh = Math.max(10, startH + dy)
                        break
                    case "b":
                        nh = Math.max(10, startH + dy)
                        break
                    case "bl":
                        nx = Math.min(startX + startW - 10, startX + dx)
                        nw = startW - (nx - startX)
                        nh = Math.max(10, startH + dy)
                        break
                    case "l":
                        nx = Math.min(startX + startW - 10, startX + dx)
                        nw = startW - (nx - startX)
                        break
                }

                root.resized(Math.round(nx), Math.round(ny), Math.round(nw), Math.round(nh))
            }
        }
    }

    // Corner Handles
    ResizeHandle {
        handlePosition: "tl"
        anchors.horizontalCenter: parent.left
        anchors.verticalCenter: parent.top
        cursor: Qt.SizeFDiagCursor
    }
    ResizeHandle {
        handlePosition: "t"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        cursor: Qt.SizeVerCursor
    }
    ResizeHandle {
        handlePosition: "tr"
        anchors.horizontalCenter: parent.right
        anchors.verticalCenter: parent.top
        cursor: Qt.SizeBDiagCursor
    }
    ResizeHandle {
        handlePosition: "r"
        anchors.horizontalCenter: parent.right
        anchors.verticalCenter: parent.verticalCenter
        cursor: Qt.SizeHorCursor
    }
    ResizeHandle {
        handlePosition: "br"
        anchors.horizontalCenter: parent.right
        anchors.verticalCenter: parent.bottom
        cursor: Qt.SizeFDiagCursor
    }
    ResizeHandle {
        handlePosition: "b"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.bottom
        cursor: Qt.SizeVerCursor
    }
    ResizeHandle {
        handlePosition: "bl"
        anchors.horizontalCenter: parent.left
        anchors.verticalCenter: parent.bottom
        cursor: Qt.SizeBDiagCursor
    }
    ResizeHandle {
        handlePosition: "l"
        anchors.horizontalCenter: parent.left
        anchors.verticalCenter: parent.verticalCenter
        cursor: Qt.SizeHorCursor
    }
}
