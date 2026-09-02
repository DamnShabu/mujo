import QtQuick
import "../theme"
import "Scroll.js" as Scroll

// MujoFlickable (無常) — the shell's scrolling container: a drop-in Flickable
// with kinetic wheel physics, elastic overshoot and no scrollbar chrome. The
// wheel maths live in Scroll.js, shared with MujoGridView.
Flickable {
    id: flick

    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    boundsMovement: Flickable.FollowBoundsBehavior
    flickDeceleration: 1800
    maximumFlickVelocity: 3500
    pixelAligned: true

    // Where an in-flight animation is heading, so consecutive notches compound
    // instead of restarting from whichever frame happens to be on screen.
    property real targetContentY: contentY
    property real targetContentX: contentX
    property real _lastWheelTime: 0
    property real _wheelMultiplier: 1.0

    onMovementStarted: {
        scrollYAnim.stop()
        scrollXAnim.stop()
        targetContentY = contentY
        targetContentX = contentX
        _wheelMultiplier = 1.0
    }

    NumberAnimation {
        id: scrollYAnim
        target: flick
        property: "contentY"
        duration: Anim.d(Anim.enter)
        easing.type: Easing.OutCubic
        onFinished: {
            flick.targetContentY = flick.contentY
            flick._wheelMultiplier = 1.0
        }
    }

    NumberAnimation {
        id: scrollXAnim
        target: flick
        property: "contentX"
        duration: Anim.d(Anim.enter)
        easing.type: Easing.OutCubic
        onFinished: flick.targetContentX = flick.contentX
    }

    WheelHandler {
        target: flick
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            const step = Scroll.wheelStep(flick, event, scrollYAnim.running, scrollXAnim.running)
            if (step === null) return
            const anim = step.axis === "y" ? scrollYAnim : scrollXAnim
            anim.stop()
            anim.duration = Anim.d(step.duration)
            anim.to = step.to
            anim.start()
        }
    }
}
