pragma Singleton
import QtQuick
import "../services"

// Mujo Motion System (無常) — Centralized Motion Architecture.
// Single source of truth for animation timing, easing curves, intensity scaling,
// ambient life cycles, and accessibility overrides across the entire shell and settings.
//
// Features:
// - 3-tier Intensity Scale (Minimal / Balanced / Expressive)
// - Granular motion domain gating (ambient, illustrations, transitions, micro-interactions, background)
// - Seamless desynchronized timing helpers
// - Full prefers-reduced-motion and performance mode support
//
// Usage:
//   Behavior on x { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }
QtObject {
    id: anim

    // ─── Global State & Configuration ──────────────────────────────────────────
    readonly property bool enabled: SettingsBus.get("motion.enabled", true)
    readonly property string intensity: SettingsBus.get("motion.intensity", "balanced") // minimal | balanced | expressive
    readonly property bool reduceMotion: SettingsBus.get("motion.reduce", false)
    readonly property bool performanceMode: SettingsBus.get("motion.performanceMode", false)

    // One intensity scale. Durations move less than sizes do — a 35% longer
    // animation reads as sluggish where a 35% wider motion reads as expressive —
    // so durations use the multiplier pulled toward 1, and ambient cycle lengths
    // use its reciprocal (more intensity = faster cycle).
    readonly property real intensityMultiplier:
        intensity === "minimal" ? 0.65 : (intensity === "expressive" ? 1.35 : 1.0)
    readonly property real durationScale: 1.0 + (intensityMultiplier - 1.0) * 0.55

    // Granular motion domain gates
    // performanceMode gates the two domains that actually cost something on a
    // weak GPU: the continuous ambient phase oscillators and the per-frame
    // Canvas repaints behind the hero art and the launcher backdrop.
    readonly property bool ambient: enabled && !reduceMotion && !performanceMode && SettingsBus.get("motion.ambient", true)
    readonly property bool pageTransitions: enabled && !reduceMotion && SettingsBus.get("motion.pageTransitions", true)
    readonly property bool microInteractions: enabled && !reduceMotion && SettingsBus.get("motion.microInteractions", true)
    readonly property bool illustrations: enabled && !reduceMotion && !performanceMode && SettingsBus.get("motion.illustrations", true)
    readonly property bool backgroundEffects: enabled && !reduceMotion && !performanceMode && SettingsBus.get("motion.backgroundEffects", true)

    // ─── Durations (ms) ────────────────────────────────────────────────────────
    readonly property int fast: 90
    readonly property int enter: 180         // popups/panels appearing
    readonly property int exit: 120          // popups/panels leaving
    readonly property int standard: 180      // general property transitions
    readonly property int slow: 260          // large / deliberate moves
    readonly property int deliberate: 420    // major spatial changes
    readonly property int pulse: 800         // pulse and state resonance

    // ─── Global Ambient Phase Oscillators ────────────────────────────────────
    // Continuous loops over $p \in [0, 2\pi]$ with co-prime periods so the
    // domains never fall into lockstep. These are NOT free: each phase is a
    // 60fps property write that re-evaluates every binding reading it, for the
    // life of the process. Only add a phase that has a consumer.
    property real breathPhase: 0.0
    property real shimmerPhase: 0.0
    property real vitalityPhase: 0.0

    NumberAnimation on breathPhase {
        running: anim.ambient
        from: 0.0; to: Math.PI * 2
        duration: anim.cycleDuration(6000)
        loops: Animation.Infinite
    }

    NumberAnimation on shimmerPhase {
        running: anim.ambient
        from: 0.0; to: Math.PI * 2
        duration: anim.cycleDuration(3600)
        loops: Animation.Infinite
    }

    NumberAnimation on vitalityPhase {
        running: anim.ambient
        from: 0.0; to: Math.PI * 2
        duration: anim.cycleDuration(4900)
        loops: Animation.Infinite
    }

    // ─── Easings ───────────────────────────────────────────────────────────────
    // Three names, by role. easeOvershoot / easeSpring / easeFluid / easeOrganic
    // used to sit here too, but every one of them resolved to OutCubic — the
    // names promised spring and overshoot personalities the shell never had.
    // The companion `overshoot` factor was inert for the same reason: Qt only
    // reads easing.overshoot for OutBack/InBack. If a role ever wants its own
    // curve, add it here with a real curve behind it.
    readonly property int easeEnter: Easing.OutCubic
    readonly property int easeExit: Easing.OutQuad
    readonly property int easeStandard: Easing.OutCubic

    // ─── Duration & Cycle Scaling Helpers ──────────────────────────────────────
    // Reduced-motion and master-disabled aware duration helper: returns scaled
    // ms, or 0 when motion is disabled or reduced.
    //
    // Pass a token (Anim.fast, Anim.enter, ...) for anything with a role. Raw
    // milliseconds are legitimate only inside a choreographed sequence — the
    // bell wobble, the auth-failure shake, the window-title crossfade — where
    // the individual step lengths are the design and a single token would
    // flatten the rhythm. Those still scale and still honour reduced motion.
    function d(ms) {
        if (!anim.enabled || anim.reduceMotion) return 0
        return Math.max(1, Math.round(ms * anim.durationScale))
    }

    // Seamless desynchronized cycle duration for ambient loops:
    function cycleDuration(baseMs) {
        if (!anim.ambient) return 1000
        return Math.max(1000, Math.round(baseMs / anim.intensityMultiplier))
    }

    // Ambient opacity scaler based on active intensity:
    function ambientAlpha(baseAlpha) {
        if (!anim.ambient) return 0.0
        return Math.min(1.0, baseAlpha * anim.intensityMultiplier)
    }

    // Periodic scalar interpolation helpers [min, max] with continuous sine curves
    function breath(minVal, maxVal) {
        if (!anim.ambient) return minVal
        var s = (Math.sin(anim.breathPhase) + 1.0) * 0.5
        return minVal + (maxVal - minVal) * s
    }

    function shimmer(minVal, maxVal) {
        if (!anim.ambient) return minVal
        var s = (Math.sin(anim.shimmerPhase) + 1.0) * 0.5
        return minVal + (maxVal - minVal) * s
    }

    function vitality(offset, minVal, maxVal) {
        if (!anim.ambient) return minVal
        var off = offset !== undefined ? offset : 0.0
        var s = (Math.sin(anim.vitalityPhase + off) + 1.0) * 0.5
        return minVal + (maxVal - minVal) * s
    }
}

