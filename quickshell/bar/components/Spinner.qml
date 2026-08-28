import QtQuick
import "../theme"

// Lightweight indeterminate spinner: the Material "progress_activity" glyph
// spun by a RotationAnimator. Pauses when hidden so it costs nothing off-screen.
Item {
    id: root
    property real size: 16
    property color color: Theme.accent
    property bool spinning: true

    implicitWidth: size
    implicitHeight: size

    MaterialIcon {
        anchors.centerIn: parent
        iconName: "progress_activity"
        pixelSize: root.size
        color: root.color

        // reduceMotion: hold the glyph static (still reads as "loading") rather
        // than spinning; a duration:0 infinite loop would busy-spin the CPU.
        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.spinning && root.visible && !Anim.reduceMotion
        }
    }
}
