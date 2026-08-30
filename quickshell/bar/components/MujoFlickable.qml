import QtQuick
import "../theme"

// MujoFlickable (無常) — Unified smooth-scrolling container for mujō desktop.
// Direct drop-in replacement for QtQuick Flickable with smooth kinetic physics.
//
// Features:
// - Smooth kinetic mouse wheel scrolling with dynamic acceleration and cubic easing
// - 1:1 direct low-latency touchpad/trackpad gesture response
// - Organic elastic overshoot bounds with spring rebound
// - Direction reversal smoothing (no judder or lag)
// - Clean, minimalist UI with zero scrollbar clutter
// - Programmatic and keyboard scrolling helpers (scrollTo, scrollBy, pageUp, pageDown, scrollToTop, scrollToBottom)
Flickable {
    id: flick

    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    boundsMovement: Flickable.FollowBoundsBehavior
    flickDeceleration: 1800
    maximumFlickVelocity: 3500
    pixelAligned: true

    property bool smoothScroll: true
    property real scrollStep: 140

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
        onFinished: {
            flick.targetContentX = flick.contentX
        }
    }

    WheelHandler {
        id: wheelHandler
        target: flick
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            if (!flick.smoothScroll || !flick.interactive) return

            var isTouchpad = (event.pixelDelta.y !== 0 || event.pixelDelta.x !== 0) &&
                             (Math.abs(event.angleDelta.y) < 120 && Math.abs(event.angleDelta.x) < 120)

            // Touchpad / Precision trackpad: 1:1 direct low-latency movement
            if (isTouchpad) {
                scrollYAnim.stop()
                scrollXAnim.stop()
                flick.cancelFlick()

                var maxContentY = Math.max(0, flick.contentHeight - flick.height)
                var maxContentX = Math.max(0, flick.contentWidth - flick.width)

                if (event.pixelDelta.y !== 0 && maxContentY > 0) {
                    flick.contentY = Math.max(0, Math.min(maxContentY, flick.contentY - event.pixelDelta.y))
                    flick.targetContentY = flick.contentY
                }
                if (event.pixelDelta.x !== 0 && maxContentX > 0) {
                    flick.contentX = Math.max(0, Math.min(maxContentX, flick.contentX - event.pixelDelta.x))
                    flick.targetContentX = flick.contentX
                }
                event.accepted = true
                return
            }

            // Discrete mouse wheel notches: smooth kinetic acceleration & easing
            var now = Date.now()
            var timeDelta = now - flick._lastWheelTime
            flick._lastWheelTime = now

            if (timeDelta < 130) {
                flick._wheelMultiplier = Math.min(2.4, flick._wheelMultiplier + 0.3)
            } else if (timeDelta > 280) {
                flick._wheelMultiplier = 1.0
            }

            // Vertical scrolling
            if (event.angleDelta.y !== 0 && (flick.flickableDirection === Flickable.AutoFlickDirection || flick.flickableDirection === Flickable.VerticalFlick || (flick.flickableDirection === Flickable.HorizontalAndVerticalFlick && flick.contentHeight > flick.height))) {
                var maxContentY = Math.max(0, flick.contentHeight - flick.height)
                if (maxContentY <= 0) return

                flick.cancelFlick()

                var rawNotches = -event.angleDelta.y / 120.0
                var step = rawNotches * flick.scrollStep * flick._wheelMultiplier

                var currentBase = scrollYAnim.running ? flick.targetContentY : flick.contentY

                if ((step > 0 && currentBase < flick.contentY) || (step < 0 && currentBase > flick.contentY)) {
                    currentBase = flick.contentY
                    flick._wheelMultiplier = 1.0
                }

                var nextY = Math.max(0, Math.min(maxContentY, currentBase + step))
                flick.targetContentY = nextY

                var dist = Math.abs(nextY - flick.contentY)
                var animDur = Math.min(280, Math.max(140, Math.round(140 + dist * 0.18)))

                scrollYAnim.stop()
                scrollYAnim.duration = Anim.d(animDur)
                scrollYAnim.to = nextY
                scrollYAnim.start()
                event.accepted = true
            }
            // Horizontal scrolling (for horizontal flickable or Shift+wheel)
            else if ((event.angleDelta.x !== 0) || (event.angleDelta.y !== 0 && flick.flickableDirection === Flickable.HorizontalFlick)) {
                var maxContentX = Math.max(0, flick.contentWidth - flick.width)
                if (maxContentX <= 0) return

                flick.cancelFlick()

                var rawNotchesX = event.angleDelta.x !== 0 ? (-event.angleDelta.x / 120.0) : (-event.angleDelta.y / 120.0)
                var stepX = rawNotchesX * flick.scrollStep * flick._wheelMultiplier

                var currentBaseX = scrollXAnim.running ? flick.targetContentX : flick.contentX

                if ((stepX > 0 && currentBaseX < flick.contentX) || (stepX < 0 && currentBaseX > flick.contentX)) {
                    currentBaseX = flick.contentX
                    flick._wheelMultiplier = 1.0
                }

                var nextX = Math.max(0, Math.min(maxContentX, currentBaseX + stepX))
                flick.targetContentX = nextX

                var distX = Math.abs(nextX - flick.contentX)
                var animDurX = Math.min(280, Math.max(140, Math.round(140 + distX * 0.18)))

                scrollXAnim.stop()
                scrollXAnim.duration = Anim.d(animDurX)
                scrollXAnim.to = nextX
                scrollXAnim.start()
                event.accepted = true
            }
        }
    }

    function scrollTo(yPos, animDuration) {
        var maxContentY = Math.max(0, flick.contentHeight - flick.height)
        var target = Math.max(0, Math.min(maxContentY, yPos))
        flick.targetContentY = target
        var dist = Math.abs(target - flick.contentY)
        var dur = animDuration !== undefined ? animDuration : Math.min(320, Math.max(160, Math.round(160 + dist * 0.15)))
        scrollYAnim.stop()
        scrollYAnim.duration = Anim.d(dur)
        scrollYAnim.to = target
        scrollYAnim.start()
    }

    function scrollBy(deltaY, animDuration) {
        var base = scrollYAnim.running ? flick.targetContentY : flick.contentY
        scrollTo(base + deltaY, animDuration)
    }

    function scrollToX(xPos, animDuration) {
        var maxContentX = Math.max(0, flick.contentWidth - flick.width)
        var target = Math.max(0, Math.min(maxContentX, xPos))
        flick.targetContentX = target
        var dist = Math.abs(target - flick.contentX)
        var dur = animDuration !== undefined ? animDuration : Math.min(320, Math.max(160, Math.round(160 + dist * 0.15)))
        scrollXAnim.stop()
        scrollXAnim.duration = Anim.d(dur)
        scrollXAnim.to = target
        scrollXAnim.start()
    }

    function pageDown() { scrollBy(Math.max(120, flick.height * 0.8)) }
    function pageUp() { scrollBy(-Math.max(120, flick.height * 0.8)) }
    function scrollToTop() { scrollTo(0, 220) }
    function scrollToBottom() { scrollTo(flick.contentHeight - flick.height, 220) }
}
