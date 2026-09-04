import QtQuick
import "../theme"

// Standard UI icon rendered directly via Material Symbols Rounded.
//
// Square by construction: the implicit size is exactly `pixelSize`, so icons
// occupy identical cells and icon columns stay aligned. Follows the bounding box
// rather than fixed pixelSize when anchored, so the glyph scales cleanly.
Item {
    id: root

    property string iconName: ""
    property real pixelSize: 16
    property color color: Theme.text

    // Optional outline, for icons drawn straight onto a wallpaper where no
    // surface guarantees contrast. Defaults are inert for every other caller.
    property int outlineStyle: Text.Normal
    property color outlineColor: "transparent"

    implicitWidth: root.pixelSize
    implicitHeight: root.pixelSize

    Text {
        anchors.fill: parent
        text: root.iconName
        font.family: "Material Symbols Rounded"
        font.pixelSize: Math.min(root.width, root.height)
        color: root.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        style: root.outlineStyle
        styleColor: root.outlineColor
        elide: Text.ElideNone
    }
}
