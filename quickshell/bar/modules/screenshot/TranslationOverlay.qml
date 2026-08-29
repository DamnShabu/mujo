import QtQuick
import "../../theme"

// Paints translated text where the original text sits, the way a phone camera
// translator does — one translucent plate per OCR line, so the source stays
// ghosted underneath instead of being replaced by a separate results window.
//
// Boxes arrive from `mujo-screenshot ocr-lines` in cropped-image pixels; the
// selection rectangle maps them back onto the overlay. On this host that ratio
// is 1:1, but it is computed rather than assumed so a scaled output still lands.
Item {
    id: root

    property int selX: 0
    property int selY: 0
    property int selWidth: 0
    property int selHeight: 0

    // Size of the image the boxes were measured against.
    property int sourceWidth: 0
    property int sourceHeight: 0

    // [{ x, y, w, h, text }], already translated.
    property var lines: []
    property bool busy: false
    property string errorMessage: ""

    readonly property real scaleX: sourceWidth > 0 ? selWidth / sourceWidth : 1
    readonly property real scaleY: sourceHeight > 0 ? selHeight / sourceHeight : 1

    anchors.fill: parent
    z: 9997

    Repeater {
        model: root.lines

        Rectangle {
            required property var modelData

            x: root.selX + modelData.x * root.scaleX
            y: root.selY + modelData.y * root.scaleY
            width: Math.max(2, modelData.w * root.scaleX)
            height: Math.max(2, modelData.h * root.scaleY)
            radius: 3

            // Translucent: the original line stays readable through the plate.
            color: Theme.withAlpha(Theme.surface, 0.72)
            border.color: Theme.withAlpha(Theme.accent, 0.35)
            border.width: 1

            Text {
                anchors.fill: parent
                anchors.margins: 2
                text: modelData.text
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Math.round(parent.height * 0.78))
                // A translation is often longer than its source, and the plate is
                // the size of the source. Shrink to fit, then elide.
                fontSizeMode: Text.Fit
                minimumPixelSize: 7
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Status pill — the only feedback while a network round-trip is in flight.
    Rectangle {
        visible: root.busy || root.errorMessage !== ""
        x: root.selX + (root.selWidth - width) / 2
        // Above the selection: the FloatingToolbar owns the space below it.
        y: Math.max(10, root.selY - height - 12)
        width: statusText.implicitWidth + 24
        height: 28
        radius: 14
        color: Theme.bg
        border.color: root.errorMessage !== "" ? Theme.borderStrong : Theme.accent
        border.width: 1

        Text {
            id: statusText
            anchors.centerIn: parent
            text: root.busy ? "Translating…" : root.errorMessage
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.text
        }
    }
}
