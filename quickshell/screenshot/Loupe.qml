import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../bar/theme"

Item {
    id: root

    property string rawSource: ""
    property real cursorX: 0
    property real cursorY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0
    property bool isSelecting: false
    property real zoomFactor: 3.0
    property int loupeSize: 130

    visible: isSelecting && cursorX > 0 && cursorY > 0
    z: 9999

    // Position offset from cursor with edge detection
    x: {
        var targetX = cursorX + 25
        if (parent && targetX + loupeSize > parent.width) {
            targetX = cursorX - loupeSize - 25
        }
        return Math.max(10, Math.min(parent ? parent.width - loupeSize - 10 : targetX, targetX))
    }
    y: {
        var targetY = cursorY + 25
        if (parent && targetY + loupeSize + 40 > parent.height) {
            targetY = cursorY - loupeSize - 40
        }
        return Math.max(10, Math.min(parent ? parent.height - loupeSize - 40 : targetY, targetY))
    }

    width: loupeSize
    height: loupeSize + (selectionWidth > 0 ? 32 : 0)

    Column {
        anchors.fill: parent
        spacing: 6

        // Circular Magnifier
        Rectangle {
            id: loupeCircle
            width: root.loupeSize
            height: root.loupeSize
            radius: root.loupeSize / 2
            color: Theme.bg
            border.color: Theme.accent
            border.width: 2
            clip: true

            // Zoomed Screen View
            Item {
                anchors.fill: parent
                clip: true

                Image {
                    id: zoomedImg
                    source: root.rawSource
                    asynchronous: true
                    cache: false
                    smooth: false // pixelated for crisp pixel view

                    width: parent.width * root.zoomFactor
                    height: parent.height * root.zoomFactor

                    x: root.loupeSize / 2 - root.cursorX * root.zoomFactor
                    y: root.loupeSize / 2 - root.cursorY * root.zoomFactor
                }
            }

            // Crosshair Lines
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.accent, 0.6)
            }
            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: parent.height
                color: Theme.withAlpha(Theme.accent, 0.6)
            }

            // Center target dot
            Rectangle {
                anchors.centerIn: parent
                width: 4
                height: 4
                radius: 2
                color: Theme.accent
            }
        }

        // Dimension / Coordinate Badge
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 24
            width: dimText.implicitWidth + 16
            radius: 12
            color: Theme.surface
            border.color: Theme.borderStrong
            border.width: 1

            Text {
                id: dimText
                anchors.centerIn: parent
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: true
                color: Theme.text
                text: root.selectionWidth > 0 && root.selectionHeight > 0
                      ? Math.round(root.selectionWidth) + " × " + Math.round(root.selectionHeight) + " px"
                      : Math.round(root.cursorX) + ", " + Math.round(root.cursorY)
            }
        }
    }
}
