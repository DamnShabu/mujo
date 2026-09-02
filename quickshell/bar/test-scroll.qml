import QtQuick
import Quickshell
import "components"
import "components/Scroll.js" as Scroll

// Self-check for the wheel scrolling MujoFlickable and MujoGridView share.
// Run: qs -p ./test-scroll.qml
//
// Scroll.js is a shared library, so it cannot import QML and repeats
// Flickable's direction enum as plain numbers. The first group is what makes
// that safe; the rest exercises the maths on a stand-in flickable.
ShellRoot {
    id: root

    property var fails: []
    function check(name, ok) { if (!ok) root.fails.push(name) }

    // A stand-in for the parts of a Flickable that Scroll.wheelStep touches.
    function stubFlick(overrides) {
        const f = {
            interactive: true,
            flickableDirection: Flickable.AutoFlickDirection,
            width: 400, height: 400,
            contentWidth: 400, contentHeight: 2000,
            contentX: 0, contentY: 0,
            targetContentX: 0, targetContentY: 0,
            _lastWheelTime: 0, _wheelMultiplier: 1.0,
            cancelFlick: function() { this.flickCancelled = true },
            flickCancelled: false
        }
        for (const k in overrides) f[k] = overrides[k]
        return f
    }

    function wheelEvent(angleY, pixelY) {
        return {
            angleDelta: { x: 0, y: angleY },
            pixelDelta: { x: 0, y: pixelY === undefined ? 0 : pixelY },
            accepted: false
        }
    }

    Item {
        id: host
        width: 400
        height: 400
        MujoFlickable {
            id: flickable
            anchors.fill: parent
            contentWidth: 400
            contentHeight: 2000
        }
        MujoGridView { id: gridView; anchors.fill: parent; model: 40; cellWidth: 100; cellHeight: 100
                       delegate: Item { width: 100; height: 100 } }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            // 1. The repeated enum must still match the one Qt ships.
            check("AUTO_FLICK matches Qt", Scroll.AUTO_FLICK === Flickable.AutoFlickDirection)
            check("HORIZONTAL_FLICK matches Qt", Scroll.HORIZONTAL_FLICK === Flickable.HorizontalFlick)
            check("VERTICAL_FLICK matches Qt", Scroll.VERTICAL_FLICK === Flickable.VerticalFlick)
            check("HORIZONTAL_AND_VERTICAL_FLICK matches Qt",
                  Scroll.HORIZONTAL_AND_VERTICAL_FLICK === Flickable.HorizontalAndVerticalFlick)

            // 2. Both components resolve and share the same scroll state.
            check("MujoFlickable instantiated", flickable !== null)
            check("MujoGridView instantiated", gridView !== null)
            check("grid exposes scrollToTop", typeof gridView.scrollToTop === "function")

            // 3. The real components expose everything the shared code needs: a
            //    wheel step on the live MujoFlickable must actually move it.
            const before = flickable.contentY
            const liveEvent = wheelEvent(-120)
            const liveStep = Scroll.wheelStep(flickable, liveEvent, false, false)
            check("a live MujoFlickable produces a step", liveStep !== null)
            check("a live MujoFlickable takes the target", flickable.targetContentY > before)
            check("a live MujoFlickable consumes the event", liveEvent.accepted === true)
            check("a live MujoGridView produces a step",
                  Scroll.wheelStep(gridView, wheelEvent(-120), false, false) !== null)

            // 4. Duration grows with distance, inside its documented bounds.
            check("short throw hits the floor", Scroll.durationFor(0) === 140)
            check("long throw hits the ceiling", Scroll.durationFor(100000) === 280)
            check("duration is monotonic", Scroll.durationFor(200) > Scroll.durationFor(50))
            check("duration ignores sign", Scroll.durationFor(-300) === Scroll.durationFor(300))

            // 5. One notch down scrolls down by one step and accepts the event.
            let f = stubFlick({})
            let e = wheelEvent(-120)
            let s = Scroll.wheelStep(f, e, false, false)
            check("a notch produces a vertical step", s !== null && s.axis === "y")
            check("one notch is one step", s.to === Scroll.WHEEL_STEP_PX)
            check("the event is consumed", e.accepted === true)
            check("the flick is cancelled", f.flickCancelled === true)
            check("the target is recorded", f.targetContentY === s.to)

            // 6. Repeat notches compound; a pause resets the acceleration.
            f = stubFlick({})
            Scroll.wheelStep(f, wheelEvent(-120), false, false)
            const firstMultiplier = f._wheelMultiplier
            Scroll.wheelStep(f, wheelEvent(-120), true, false)
            check("a fast repeat accelerates", f._wheelMultiplier > firstMultiplier)
            f._lastWheelTime -= 1000
            Scroll.wheelStep(f, wheelEvent(-120), true, false)
            check("a pause resets acceleration", f._wheelMultiplier === 1.0)

            // 7. Clamping at both ends.
            f = stubFlick({ contentY: 0 })
            check("cannot scroll above the top",
                  Scroll.wheelStep(f, wheelEvent(120), false, false).to === 0)
            f = stubFlick({ contentY: 1600 })
            check("cannot scroll past the bottom",
                  Scroll.wheelStep(f, wheelEvent(-120), false, false).to === 1600)
            check("nothing to scroll returns null",
                  Scroll.wheelStep(stubFlick({ contentHeight: 100 }), wheelEvent(-120), false, false) === null)
            check("a non-interactive view ignores the wheel",
                  Scroll.wheelStep(stubFlick({ interactive: false }), wheelEvent(-120), false, false) === null)

            // 8. A trackpad moves 1:1 and needs no animation.
            f = stubFlick({})
            // A positive pixel delta is a push upward, so the content moves down.
            e = wheelEvent(0, -40)
            check("trackpad returns no animation", Scroll.wheelStep(f, e, false, false) === null)
            check("trackpad moves the content directly", f.contentY === 40)
            check("trackpad consumes the event", e.accepted === true)

            // 9. A horizontal-only view scrolls on the vertical wheel, which is
            //    the only way a plain mouse can drive one.
            f = stubFlick({
                flickableDirection: Flickable.HorizontalFlick,
                contentWidth: 2000, contentHeight: 400
            })
            s = Scroll.wheelStep(f, wheelEvent(-120), false, false)
            check("horizontal view steps on the x axis", s !== null && s.axis === "x")
            check("horizontal target is recorded", f.targetContentX === s.to)

            if (root.fails.length === 0) {
                console.log("PASS  scroll: enum matches Qt, both components resolve, wheel maths hold")
            } else {
                console.log("FAIL  scroll: " + root.fails.length + " check(s) failed")
                for (const f2 of root.fails) console.log("        - " + f2)
            }
            Qt.exit(root.fails.length === 0 ? 0 : 1)
        }
    }
}
