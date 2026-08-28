import QtQuick
import QtQuick.Effects
import "../theme"

// A standard-action icon.
//
// Draws the system icon theme's symbolic icon when the theme ships one for this
// action (see theme/Icons.qml) and falls back to the bundled Material Symbols
// glyph when it does not, so the shell matches the rest of the desktop without
// losing the actions the freedesktop naming spec never named. Callers keep
// using Material Symbol names — the mapping lives in one place.
//
// Symbolic icons are monochrome line art, so they are recoloured to `color` the
// same way GTK recolours them. That is what keeps a 16px bar icon legible and
// lets accent/error states keep working at the 121 call sites that set a colour.
//
// Square by construction: the implicit size is exactly `pixelSize`, so themed
// icons and glyphs occupy identical cells and icon columns stay aligned.
Item {
    id: root

    property string iconName: ""
    property real pixelSize: 16
    property color color: Theme.text

    // Optional outline, for icons drawn straight onto a wallpaper where no
    // surface guarantees contrast. Defaults are inert for every other caller.
    property int outlineStyle: Text.Normal
    property color outlineColor: "transparent"

    // "" when the theme has no icon for this action — the glyph then draws.
    readonly property string themedSource: Icons.path(root.iconName)

    implicitWidth: root.pixelSize
    implicitHeight: root.pixelSize

    Image {
        id: themed
        anchors.fill: parent
        visible: root.themedSource !== ""
        source: root.themedSource
        // Theme icons are square, but never assume it: fit rather than crop, so
        // a non-square icon is shown whole instead of clipped or stretched.
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.max(1, Math.round(root.width))
        sourceSize.height: Math.max(1, Math.round(root.height))
        smooth: true
        mipmap: true
        // ponytail: one render target per icon. Fine for the ~30 icons on screen
        // at once; if icon-dense views ever stutter, pre-tint the SVG source
        // instead (Brand.svgUri does that trick) rather than layering each one.
        layer.enabled: visible
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: root.color
        }
    }

    Text {
        anchors.fill: parent
        visible: root.themedSource === ""
        text: root.iconName
        font.family: "Material Symbols Rounded"
        // Follows the box rather than pixelSize so the glyph still fills the
        // cell when a caller anchors this item instead of sizing it.
        font.pixelSize: Math.min(root.width, root.height)
        color: root.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        style: root.outlineStyle
        styleColor: root.outlineColor
        elide: Text.ElideNone
    }
}
