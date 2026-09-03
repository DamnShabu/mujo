import QtQuick
import "../theme"

// The one keyboard-focus indicator.
//
// Every interactive control parents one of these instead of drawing its own
// ring, so focus looks identical across the shell and follows the active
// theme's accent. It sits just outside the control's own border, which keeps it
// legible on both filled surfaces (ToggleSwitch, DisplayChip) and outlined ones
// (TextField, MujoSegmented).
Rectangle {
    id: ring

    // The control this ring belongs to. Defaults to whatever it is parented to,
    // which is right for every current call site.
    property Item target: parent
    // Corner radius of the control underneath. Rectangles can pass their own
    // `radius`; Item-based controls (Slider) state the shape they present.
    property real ringRadius: 6

    anchors.fill: parent
    anchors.margins: -3
    radius: ring.ringRadius + 3
    color: "transparent"
    border.color: Theme.accent
    border.width: 2
    visible: ring.target !== null && ring.target.activeFocus
}
