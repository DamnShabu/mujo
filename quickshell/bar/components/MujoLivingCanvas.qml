import QtQuick
import "../theme"

// MujoLivingCanvas: Signature generative flow artwork embodying Mujo (無常).
// Implements procedural harmonic waveforms, living Ensō (円相) transformation curve,
// ambient drifting particles, and interactive state resonance.
// Every animation loop is strictly periodic ($p \in [0, 2\pi]$) with zero jumps or resets.
// Respects Theme tokens and Anim.reduceMotion.
Item {
    id: root

    property color accentColor: Theme.accent
    property color secondaryColor: Theme.withAlpha(Theme.textSecondary, 0.4)
    property bool animated: true
    property real intensity: 1.0
    property real flowSpeed: 1.0
    property bool showEnso: true
    property bool showWaves: true
    property bool showParticles: true

    implicitWidth: 320
    implicitHeight: 180

    // Animation phase — strictly periodic over 0 .. 2*PI
    property real phase: 0.0
    property real pulseAmount: 0.0

    function pulse() {
        if (Anim.reduceMotion) return
        pulseAnim.restart()
    }

    onAccentColorChanged: {
        pulse()
        canvas.requestPaint()
    }

    NumberAnimation on phase {
        running: root.animated && Anim.illustrations && root.visible
        from: 0.0
        to: Math.PI * 2
        duration: Math.max(1000, Anim.cycleDuration(16000 / Math.max(0.2, root.flowSpeed)))
        loops: Animation.Infinite
    }

    NumberAnimation {
        id: pulseAnim
        target: root
        property: "pulseAmount"
        from: 1.0
        to: 0.0
        duration: Anim.pulse
        easing.type: Easing.OutQuad
    }

    onPhaseChanged: canvas.requestPaint()
    onPulseAmountChanged: canvas.requestPaint()

    // Deterministic particle set with integer speed multipliers for seamless looping
    readonly property var particles: [
        { xRatio: 0.15, yRatio: 0.35, size: 2.2, speed: 1, phaseOff: 0.3 },
        { xRatio: 0.30, yRatio: 0.65, size: 1.6, speed: 1, phaseOff: 1.8 },
        { xRatio: 0.50, yRatio: 0.25, size: 2.8, speed: 2, phaseOff: 2.7 },
        { xRatio: 0.68, yRatio: 0.55, size: 1.8, speed: 1, phaseOff: 3.9 },
        { xRatio: 0.82, yRatio: 0.40, size: 2.4, speed: 2, phaseOff: 4.8 },
        { xRatio: 0.92, yRatio: 0.70, size: 1.5, speed: 1, phaseOff: 5.6 }
    ]

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var w = width
            var h = height
            if (w <= 0 || h <= 0) return

            var p = Anim.reduceMotion ? 0.0 : root.phase
            var pulseVal = root.pulseAmount
            var acc = root.accentColor
            var r = acc.r, g = acc.g, b = acc.b

            ctx.save()

            // ── 1. Ambient Background Gradient Aura ─────────────────────────────
            var bgGrad = ctx.createRadialGradient(w * 0.7, h * 0.4, 10, w * 0.7, h * 0.4, Math.max(w, h) * 0.8)
            var glowAlpha = Anim.backgroundEffects ? (0.08 + pulseVal * 0.12) * root.intensity : 0.0
            bgGrad.addColorStop(0, Qt.rgba(r, g, b, glowAlpha))
            bgGrad.addColorStop(0.5, Qt.rgba(r, g, b, glowAlpha * 0.3))
            bgGrad.addColorStop(1, Qt.rgba(r, g, b, 0.0))
            ctx.fillStyle = bgGrad
            ctx.fillRect(0, 0, w, h)

            // ── 2. Harmonic Fluid Waveforms (strictly periodic) ─────────────────
            if (root.showWaves) {
                var waveCount = 3
                for (var wi = 0; wi < waveCount; wi++) {
                    ctx.beginPath()
                    var yBase = h * (0.45 + wi * 0.18)
                    var freq = 0.012 + wi * 0.005
                    var amp = (12 + wi * 7 + pulseVal * 15) * root.intensity
                    var wPhase = p + wi * (Math.PI / 2)

                    ctx.moveTo(0, yBase + Math.sin(wPhase) * amp)
                    for (var x = 0; x <= w; x += 6) {
                        var y = yBase + Math.sin(x * freq + wPhase) * amp
                                      + Math.cos(x * freq * 0.5 - wPhase) * (amp * 0.35)
                        ctx.lineTo(x, y)
                    }

                    var waveGrad = ctx.createLinearGradient(0, 0, w, 0)
                    var wAlpha = (0.35 - wi * 0.08 + pulseVal * 0.25) * root.intensity
                    waveGrad.addColorStop(0, Qt.rgba(r, g, b, 0.0))
                    waveGrad.addColorStop(0.3, Qt.rgba(r, g, b, wAlpha))
                    waveGrad.addColorStop(0.7, Qt.rgba(r, g, b, wAlpha * 0.8))
                    waveGrad.addColorStop(1, Qt.rgba(r, g, b, 0.0))

                    ctx.strokeStyle = waveGrad
                    ctx.lineWidth = wi === 0 ? 2.0 : 1.2
                    ctx.stroke()
                }
            }

            // ── 3. Living Ensō (円相) Dynamic Open Arc (strictly periodic) ──────
            if (root.showEnso) {
                var ensoCx = w * 0.78
                var ensoCy = h * 0.50
                var ensoR = Math.min(w, h) * (0.36 + pulseVal * 0.06)

                // Outer rotating ring segment (1 full rotation per cycle)
                ctx.beginPath()
                var eStart = p
                var eEnd = eStart + Math.PI * 1.62
                ctx.arc(ensoCx, ensoCy, ensoR, eStart, eEnd, false)

                var ensoGrad = ctx.createLinearGradient(ensoCx - ensoR, ensoCy - ensoR, ensoCx + ensoR, ensoCy + ensoR)
                ensoGrad.addColorStop(0, Qt.rgba(r, g, b, (0.55 + pulseVal * 0.3) * root.intensity))
                ensoGrad.addColorStop(0.7, Qt.rgba(r, g, b, (0.20 + pulseVal * 0.15) * root.intensity))
                ensoGrad.addColorStop(1, Qt.rgba(r, g, b, 0.02))

                ctx.strokeStyle = ensoGrad
                ctx.lineWidth = 2.4 + pulseVal * 1.5
                ctx.lineCap = "round"
                ctx.stroke()

                // Counter-harmonic inner crescent (1 full counter-rotation per cycle)
                ctx.beginPath()
                var eInnerStart = -p + Math.PI * 0.6
                var eInnerEnd = eInnerStart + Math.PI * 1.15
                ctx.arc(ensoCx, ensoCy, ensoR * 0.65, eInnerStart, eInnerEnd, false)

                var innerGrad = ctx.createLinearGradient(ensoCx + ensoR, ensoCy - ensoR, ensoCx - ensoR, ensoCy + ensoR)
                innerGrad.addColorStop(0, Qt.rgba(r, g, b, 0.35 * root.intensity))
                innerGrad.addColorStop(1, Qt.rgba(r, g, b, 0.0))

                ctx.strokeStyle = innerGrad
                ctx.lineWidth = 1.4
                ctx.stroke()

                // Focal Energy Core (Zen point)
                var focalX = ensoCx + Math.cos(eStart) * ensoR
                var focalY = ensoCy + Math.sin(eStart) * ensoR
                ctx.beginPath()
                ctx.arc(focalX, focalY, 3.2 + pulseVal * 2.0, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, (0.85 + pulseVal * 0.15) * root.intensity)
                ctx.fill()
            }

            // ── 4. Floating Luminous Energy Particles (strictly periodic) ───────
            if (root.showParticles && !Anim.reduceMotion) {
                for (var pi = 0; pi < root.particles.length; pi++) {
                    var pt = root.particles[pi]
                    var ptX = (pt.xRatio * w) + Math.cos(p * pt.speed + pt.phaseOff) * 16
                    var ptY = (pt.yRatio * h) + Math.sin(p * pt.speed + pt.phaseOff) * 10

                    var ptAlpha = (0.35 + 0.35 * Math.sin(p * pt.speed + pt.phaseOff)) * root.intensity
                    ctx.beginPath()
                    ctx.arc(ptX, ptY, pt.size * (1.0 + pulseVal * 0.5), 0, Math.PI * 2)
                    ctx.fillStyle = Qt.rgba(r, g, b, ptAlpha)
                    ctx.fill()
                }
            }

            ctx.restore()
        }
    }
}
