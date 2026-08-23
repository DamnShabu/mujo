pragma Singleton
import QtQuick

// Motion vocabulary — the single source of truth for animation durations and
// easings across the shell, so every surface moves consistently and honours
// Theme.reduceMotion. Enter is soft/roomy, exit is quicker/sharper, and islands
// & popups get a gentle overshoot. New code reads these tokens instead of
// hardcoding numbers; wrap any duration in d() so reduced-motion zeroes it.
//
//   Behavior on x { NumberAnimation { duration: Anim.d(Anim.standard)
//                                     easing.type: Anim.easeStandard } }
QtObject {
    id: anim

    // ── durations (ms) ──────────────────────────────────────────────────────
    readonly property int fast: 90
    readonly property int enter: 150       // popups/panels appearing
    readonly property int exit: 100        // popups/panels leaving
    readonly property int standard: 150    // general property transitions
    readonly property int slow: 220        // large / deliberate moves

    // ── easings ─────────────────────────────────────────────────────────────
    readonly property int easeEnter: Easing.OutCubic
    readonly property int easeExit: Easing.InQuad
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeOvershoot: Easing.OutBack   // islands / popup pop-in
    readonly property real overshoot: 1.15                // easing.overshoot amount

    // Reduced-motion-aware duration: pass a token, get 0 when motion is reduced
    // (animation still "runs" but completes instantly, so onStopped/state logic
    // that depends on the animation firing stays intact).
    function d(ms) { return Theme.reduceMotion ? 0 : ms }
}
