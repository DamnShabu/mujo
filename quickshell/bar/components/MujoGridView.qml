import QtQuick
import "../theme"
import "Scroll.js" as Scroll

// MujoGridView (無常) — GridView with the shell's kinetic wheel scrolling.
//
// GridView derives from Flickable but cannot be built on MujoFlickable, so both
// call the same Scroll.js instead: a grid then scrolls exactly like every other
// surface, rather than on a curve of its own.
GridView {
    id: grid

    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1800
    maximumFlickVelocity: 3500

    property real targetContentY: contentY
    property real targetContentX: contentX
    property real _lastWheelTime: 0
    property real _wheelMultiplier: 1.0

    onMovementStarted: {
        scrollAnim.stop()
        targetContentY = contentY
        _wheelMultiplier = 1.0
    }
    onFlickStarted: scrollAnim.stop()
    onFlickEnded: targetContentY = contentY

    NumberAnimation {
        id: scrollAnim
        target: grid
        property: "contentY"
        duration: Anim.d(Anim.enter)
        easing.type: Easing.OutCubic
        onFinished: {
            grid.targetContentY = grid.contentY
            grid._wheelMultiplier = 1.0
        }
    }

    WheelHandler {
        target: grid
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            // A grid only ever scrolls vertically here, so there is no second
            // animation to hand over; a horizontal step would be a no-op.
            const step = Scroll.wheelStep(grid, event, scrollAnim.running, false)
            if (step === null || step.axis !== "y") return
            grid.scrollTo(step.to, step.duration)
        }
    }

    function scrollTo(y, duration) {
        targetContentY = y
        scrollAnim.stop()
        scrollAnim.duration = Anim.d(duration)
        scrollAnim.to = y
        scrollAnim.start()
    }

    function scrollToTop() {
        cancelFlick()
        scrollTo(0, Scroll.durationFor(contentY))
    }
}
