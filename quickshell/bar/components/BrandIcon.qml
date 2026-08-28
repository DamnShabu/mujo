import QtQuick
import "../theme"

// Full-color service/section icon: a rounded, brand-colored tile with a subtle
// vertical gradient and the brand glyph (inline SVG, Material symbol, or a text
// monogram). One consistent, premium look for every identity in the shell.
Item {
    id: root
    property string brand: ""
    property real size: 40
    property real radiusFactor: 0.28
    readonly property var b: Brand.get(brand)

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: root.size * root.radiusFactor
        border.color: Theme.withAlpha(Qt.lighter(root.b.color, 1.25), 0.35)
        border.width: 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(root.b.color, 1.12) }
            GradientStop { position: 1.0; color: Qt.darker(root.b.color, 1.08) }
        }

        // 1) inline SVG glyph
        Image {
            visible: root.b.svg !== undefined
            anchors.centerIn: parent
            width: root.size * 0.58
            height: root.size * 0.58
            sourceSize.width: Math.round(root.size * 1.2)
            source: root.b.svg !== undefined ? Brand.svgUri(root.brand, root.b.fg) : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // 2) Material glyph
        MaterialIcon {
            visible: root.b.svg === undefined && root.b.mat !== undefined
            anchors.centerIn: parent
            iconName: root.b.mat || ""
            pixelSize: root.size * 0.52
            color: root.b.fg
        }

        // 3) text monogram (e.g. λ for NixOS)
        Text {
            visible: root.b.svg === undefined && root.b.mat === undefined
            anchors.centerIn: parent
            text: root.b.text || "?"
            color: root.b.fg
            font.family: Theme.fontFamily
            font.pixelSize: root.size * 0.56
            font.bold: true
        }
    }
}
