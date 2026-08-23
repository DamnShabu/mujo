import QtQuick
import Quickshell

// Themed hover tooltip primitive (WP-18). Renders on its own PopupWindow so it
// isn't clipped by the bar's thin layer surface. Show it by binding `hovered`
// and `target` (the item to anchor to); appears after a 400ms delay.
Item {
    id: tip

    property var panelWindow
    property Item target: null
    property string text: ""
    property string status: ""
    property bool hovered: false

    Timer { id: delay; interval: 400; onTriggered: if (tip.hovered && tip.text) pop.shown = true }
    onHoveredChanged: { if (hovered && text) delay.restart(); else { delay.stop(); pop.shown = false } }

    PopupWindow {
        id: pop
        property bool shown: false
        visible: shown && tip.target !== null
        color: "transparent"
        anchor.window: tip.panelWindow
        anchor.item: tip.target
        anchor.edges: Theme.popupEdge
        anchor.gravity: Theme.popupGravity
        anchor.adjustment: PopupAdjustment.Slide
        implicitWidth: bubble.implicitWidth + 4
        implicitHeight: bubble.implicitHeight + 10

        Rectangle {
            id: bubble
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 6
            implicitWidth: label.implicitWidth + 18
            implicitHeight: label.implicitHeight + 12
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: Theme.borderStrong

            Column {
                id: label
                anchors.centerIn: parent
                spacing: 1
                Text {
                    text: tip.text
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                Text {
                    visible: tip.status !== ""
                    text: tip.status
                    color: Theme.textSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                }
            }
        }
    }
}
