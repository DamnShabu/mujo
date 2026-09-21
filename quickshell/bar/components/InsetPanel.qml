import QtQuick
import "../theme"

// A recessed area inside a section: a log stream, a canvas, a scrolling list,
// a form. Sections themselves draw nothing now, so this is what says "the thing
// inside here is one object, not more page".
//
// Sunk rather than raised — it sits on `bg`, a step *below* the page, which is
// what separates it from a control (a control is raised, on `surface`).
Rectangle {
    id: panel

    // Border tone for a panel that is reporting state: "" keeps the hairline.
    property color accentBorder: Theme.border

    radius: Theme.radiusMd
    color: Theme.bg
    border.width: 1
    border.color: panel.accentBorder
    clip: true

    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }
}
