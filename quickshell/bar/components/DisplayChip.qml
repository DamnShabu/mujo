import QtQuick
import "../theme"

// Small selectable pill used by the Display panel for resolution / refresh /
// scale options.
Rectangle {
    id: chip
    property string label: ""
    property bool selected: false
    signal clicked()

    implicitWidth: chipLabel.implicitWidth + 22
    implicitHeight: 30
    radius: Theme.radiusSm
    color: selected ? Theme.accentDim : (chip_hh.hovered ? Theme.surfaceHover : Theme.surface)
    border.color: selected ? Theme.accent : Theme.border
    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

    scale: (chip_hh.hovered && Anim.microInteractions) ? (tap_h.pressed ? 0.96 : 1.04) : 1.0
    Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }

    Text {
        id: chipLabel
        anchors.centerIn: parent
        text: chip.label
        color: chip.selected ? Theme.accent : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.bold: chip.selected
    }

    HoverHandler { id: chip_hh; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap_h; onTapped: chip.clicked() }
}
