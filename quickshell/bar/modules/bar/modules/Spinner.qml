import QtQuick

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

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.spinning && root.visible
        }
    }
}
