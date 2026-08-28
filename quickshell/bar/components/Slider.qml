import QtQuick
import "../theme"

// Slider: Harmonic fluid slider for Mujo (無常).
// Provides an organic glowing progress track, responsive magnetic handle, and smooth seek gestures.
Item {
    id: root

    // Controlled: `value` is an input. See ToggleSwitch for why this must not
    // be written from in here. Every caller's onMoved writes to a source its
    // own `value` binding reads back, so the handle still tracks the drag.
    property real value: 0
    property real from: 0
    property real to: 1
    property color fillColor: Theme.accent
    property bool showValueBubble: true
    property string format: ""   // e.g. "%" or "px"
    // Text for the drag bubble. Sliders whose range is not already in display
    // units (volume is 0..1.5, opacity 0..1) must override this, or the bubble
    // rounds the raw value to a meaningless 0/1.
    property string valueText: Math.round(root.value) + root.format
    signal moved(real value)

    implicitHeight: 22
    implicitWidth: 160

    readonly property real ratio: root.to > root.from ? Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from))) : 0

    // Background track
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Theme.surfaceActive
        border.color: Theme.border
        border.width: 1

        // Active fluid fill
        Rectangle {
            id: fillRect
            width: Math.max(track.height, track.width * root.ratio)
            height: track.height
            radius: track.radius
            color: root.fillColor
        }
    }

    // Handle
    Rectangle {
        id: handle
        width: sliderArea.pressed ? 16 : (sliderArea.containsMouse ? 14 : 12)
        height: width
        radius: width / 2
        color: Theme.text
        border.color: root.fillColor
        border.width: 2
        anchors.verticalCenter: track.verticalCenter
        x: Math.max(0, Math.min(track.width - width, track.width * root.ratio - width / 2))

        Behavior on width { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }

        // Subtle hover ring
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 6
            height: width
            radius: width / 2
            color: root.fillColor
            opacity: sliderArea.pressed ? 0.25 : (sliderArea.containsMouse ? 0.15 : 0)
            z: -1
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }
        }

        // Floating Value Callout Bubble
        Rectangle {
            visible: root.showValueBubble && (sliderArea.containsMouse || sliderArea.pressed)
            anchors.bottom: parent.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: bubbleText.implicitWidth + 12
            implicitHeight: 20
            radius: Theme.radiusSm
            color: Theme.surface
            border.color: Theme.borderStrong
            z: 10

            Text {
                id: bubbleText
                anchors.centerIn: parent
                text: root.valueText
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                font.bold: true
            }
        }
    }

    // hitPad widens the grab area past the track; px arrives in MouseArea
    // coordinates, so it has to come back off before mapping to a value.
    readonly property int hitPad: 4

    function setFromX(px) {
        var r = Math.max(0, Math.min(1, (px - root.hitPad) / root.width))
        root.moved(root.from + r * (root.to - root.from))
    }

    MouseArea {
        id: sliderArea
        anchors.fill: parent
        anchors.margins: -root.hitPad
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.setFromX(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.setFromX(mouse.x) }
    }
}
