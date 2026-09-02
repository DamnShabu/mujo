.pragma library

// Kinetic wheel scrolling, shared by MujoFlickable and MujoGridView so every
// scrollable surface in the shell behaves the same way. A GridView derives from
// Flickable but cannot be *built on* MujoFlickable, so the behaviour lives here
// as a function both call rather than in a base component.
//
// The caller owns the NumberAnimations and runs them, because the duration
// scale comes from the Anim singleton, which a shared JS library cannot import.

// Flickable's FlickableDirection enum. A shared JS library has no QML imports,
// so the values are repeated here; test-scroll.qml asserts they still match
// `Flickable.*`, which is what makes repeating them safe.
var AUTO_FLICK = 0x00
var HORIZONTAL_FLICK = 0x01
var VERTICAL_FLICK = 0x02
var HORIZONTAL_AND_VERTICAL_FLICK = 0x03

// Pixel deltas paired with an angle delta this small mean a precision trackpad
// rather than a notched wheel.
var TOUCHPAD_ANGLE_LIMIT = 120

// One wheel notch travels this far before acceleration. Both callers used the
// same value, so it lives here rather than as a per-component property nobody
// ever set.
var WHEEL_STEP_PX = 140

// Notches arriving faster than REPEAT_WINDOW_MS compound into a longer throw; a
// gap longer than RESET_WINDOW_MS starts the acceleration over.
var REPEAT_WINDOW_MS = 130
var RESET_WINDOW_MS = 280
var MAX_MULTIPLIER = 2.4
var MULTIPLIER_STEP = 0.3

function _isTouchpad(event) {
    return (event.pixelDelta.y !== 0 || event.pixelDelta.x !== 0)
        && Math.abs(event.angleDelta.y) < TOUCHPAD_ANGLE_LIMIT
        && Math.abs(event.angleDelta.x) < TOUCHPAD_ANGLE_LIMIT
}

function _clamp(value, max) {
    return Math.max(0, Math.min(max, value))
}

// Longer throws ease over proportionally longer, capped so that even a
// full-page jump still lands promptly.
function durationFor(distance) {
    return Math.min(280, Math.max(140, Math.round(140 + Math.abs(distance) * 0.18)))
}

function _scrollsVertically(flick, event) {
    if (event.angleDelta.y === 0) return false
    return flick.flickableDirection === AUTO_FLICK
        || flick.flickableDirection === VERTICAL_FLICK
        || (flick.flickableDirection === HORIZONTAL_AND_VERTICAL_FLICK
            && flick.contentHeight > flick.height)
}

// Consume a wheel event. Returns {axis, to, duration} for the caller to
// animate, or null when there is nothing to animate — either the event was
// already handled (a trackpad moves 1:1, so animating would only add lag) or
// the axis has nothing to scroll.
function wheelStep(flick, event, yAnimRunning, xAnimRunning) {
    if (!flick.interactive) return null

    var maxY = Math.max(0, flick.contentHeight - flick.height)
    var maxX = Math.max(0, flick.contentWidth - flick.width)

    if (_isTouchpad(event)) {
        flick.cancelFlick()
        if (event.pixelDelta.y !== 0 && maxY > 0) {
            flick.contentY = _clamp(flick.contentY - event.pixelDelta.y, maxY)
            flick.targetContentY = flick.contentY
        }
        if (event.pixelDelta.x !== 0 && maxX > 0) {
            flick.contentX = _clamp(flick.contentX - event.pixelDelta.x, maxX)
            flick.targetContentX = flick.contentX
        }
        event.accepted = true
        return null
    }

    var now = Date.now()
    var sinceLast = now - flick._lastWheelTime
    flick._lastWheelTime = now
    if (sinceLast < REPEAT_WINDOW_MS) {
        flick._wheelMultiplier = Math.min(MAX_MULTIPLIER,
                                          flick._wheelMultiplier + MULTIPLIER_STEP)
    } else if (sinceLast > RESET_WINDOW_MS) {
        flick._wheelMultiplier = 1.0
    }

    var vertical = _scrollsVertically(flick, event)
    var max = vertical ? maxY : maxX
    if (max <= 0) return null

    // A horizontal-only view scrolls on the vertical wheel too; that is the
    // only way to drive one with an ordinary mouse.
    var notches = vertical
        ? -event.angleDelta.y / 120.0
        : (event.angleDelta.x !== 0 ? -event.angleDelta.x : -event.angleDelta.y) / 120.0
    var step = notches * WHEEL_STEP_PX * flick._wheelMultiplier

    flick.cancelFlick()

    var position = vertical ? flick.contentY : flick.contentX
    var running = vertical ? yAnimRunning : xAnimRunning
    var base = running ? (vertical ? flick.targetContentY : flick.targetContentX)
                       : position

    // Reversing direction mid-throw: drop the queued distance and the built-up
    // acceleration, or the view lurches the old way before turning around.
    if ((step > 0 && base < position) || (step < 0 && base > position)) {
        base = position
        flick._wheelMultiplier = 1.0
    }

    var to = _clamp(base + step, max)
    if (vertical) flick.targetContentY = to
    else flick.targetContentX = to

    event.accepted = true
    return { axis: vertical ? "y" : "x", to: to, duration: durationFor(to - position) }
}
