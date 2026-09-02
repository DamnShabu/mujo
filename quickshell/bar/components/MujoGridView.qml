import QtQuick
import "../theme"

// MujoGridView (無常) — GridView with the shell's kinetic wheel scrolling.
//
// GridView derives from Flickable but cannot be built on MujoFlickable, so the
// smooth-scroll block would otherwise be copied into every grid that wants it.
// It lives here once instead. The curve is deliberately the simpler one the
// wallpaper grids have always used, not MujoFlickable's accelerating variant —
// grid cells are large, and matching the panel exactly is what keeps this a
// refactor rather than a change in feel.
GridView {
    id: grid

    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1800
    maximumFlickVelocity: 3500

    // Where the wheel animation is heading, so consecutive notches compound
    // instead of restarting from wherever the current frame happens to be.
    property real targetContentY: contentY

    NumberAnimation {
        id: scrollAnim
        target: grid
        property: "contentY"
        duration: Anim.d(Anim.enter)
        easing.type: Easing.OutCubic
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            grid.cancelFlick()
            const maxContentY = Math.max(0, grid.contentHeight - grid.height)
            const delta = (event.angleDelta.y !== 0) ? -event.angleDelta.y : -event.pixelDelta.y
            const from = scrollAnim.running ? grid.targetContentY : grid.contentY
            grid.scrollTo(Math.max(0, Math.min(maxContentY, from + delta * 1.2)), Anim.enter)
            event.accepted = true
        }
    }

    onMovementStarted: scrollAnim.stop()
    onFlickStarted: scrollAnim.stop()
    onMovementEnded: targetContentY = contentY
    onFlickEnded: targetContentY = contentY

    function scrollTo(y, duration) {
        targetContentY = y
        scrollAnim.stop()
        scrollAnim.duration = Anim.d(duration)
        scrollAnim.to = y
        scrollAnim.start()
    }

    function scrollToTop() {
        cancelFlick()
        scrollTo(0, Anim.slow)
    }
}
