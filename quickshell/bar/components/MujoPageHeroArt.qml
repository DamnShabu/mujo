import QtQuick
import "../theme"

// MujoPageHeroArt: Dedicated, high-performance living vector & canvas illustration engine for Mujo (無常).
// Provides 20+ signature page-specific visual identities reflecting the core essence of each setting domain.
// Features mathematically continuous, seamless ambient animation loops ($p \in [0, 2\pi]$) with zero jumps or resets,
// boundary-attenuated particles, dynamic state resonance, and complete Anim.reduceMotion support.
Item {
    id: root

    property string brand: "general"
    property color accentColor: Theme.accent
    property color secondaryColor: Theme.withAlpha(Theme.textSecondary, 0.4)
    property bool animated: true
    property real intensity: 1.0
    property real flowSpeed: 1.0
    property bool isNixos: false

    // State reaction properties
    property bool activeState: false       // e.g. VPN connected, AI running, Dirty config
    property real stateValue: 0.0          // normalized 0.0 .. 1.0 value

    implicitWidth: 380
    implicitHeight: 120

    // Animation phase — strictly periodic over 0 .. 2*PI (or 4*PI)
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
    onBrandChanged: canvas.requestPaint()
    onActiveStateChanged: canvas.requestPaint()

    NumberAnimation on phase {
        running: root.animated && Anim.illustrations && root.visible
        from: 0.0
        to: Math.PI * 2
        duration: Math.max(2000, Anim.cycleDuration(16000 / Math.max(0.2, root.flowSpeed)))
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
            var br = (root.brand || "general").toLowerCase()

            ctx.save()

            // ── Common Ambient Radial Backdrop Glow ─────────────────────────
            var glowCx = w * 0.72
            var glowCy = h * 0.50
            var bgGrad = ctx.createRadialGradient(glowCx, glowCy, 5, glowCx, glowCy, Math.max(w, h) * 0.75)
            var baseAlpha = Anim.backgroundEffects
                ? Anim.ambientAlpha((0.07 + pulseVal * 0.12) * root.intensity) : 0.0
            bgGrad.addColorStop(0, Qt.rgba(r, g, b, baseAlpha))
            bgGrad.addColorStop(0.5, Qt.rgba(r, g, b, baseAlpha * 0.25))
            bgGrad.addColorStop(1, Qt.rgba(r, g, b, 0.0))
            ctx.fillStyle = bgGrad
            ctx.fillRect(0, 0, w, h)

            // ── Page-Specific Visual Artwork Rendering ──────────────────────
            switch (br) {
                case "animations":
                case "motion":
                    drawAnimations(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "appearance":
                    drawAppearance(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "ai":
                case "llm":
                    drawAi(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "privacy":
                    drawPrivacy(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "security":
                case "lock":
                    drawSecurity(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "clipboard":
                    drawClipboard(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "applications":
                case "integrations":
                    drawApplications(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "system":
                case "nixos":
                    drawSystem(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "overview":
                case "sanctuary":
                    drawOverview(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "wallpaper":
                    drawWallpaper(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "desktop":
                case "cava":
                    drawDesktop(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "island":
                    drawIsland(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "notifications":
                    drawNotifications(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "weather":
                    drawWeather(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "display":
                    drawDisplay(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "devices":
                case "keyboard":
                case "mouse":
                    drawDevices(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "network":
                case "mullvad":
                    drawNetwork(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "keyring":
                    drawKeyring(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "persistence":
                    drawPersistence(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "shortcuts":
                    drawShortcuts(ctx, w, h, p, r, g, b, pulseVal)
                    break
                case "general":
                case "behavior":
                case "defaults":
                default:
                    drawGeneral(ctx, w, h, p, r, g, b, pulseVal)
                    break
            }

            ctx.restore()
        }

        // ────────────────────────────────────────────────────────────────────
        // 0. ANIMATIONS & MOTION: Kinematic ribbons, morphing geometry & orbital resonance
        // ────────────────────────────────────────────────────────────────────
        // Qt's Canvas 2D context has no roundRect() (it is an HTML5-only addition):
        // calling it threw on every paint, aborting the rest of the illustration.
        // arcTo is supported, so build the path by hand.
        function roundRectPath(ctx, x, y, w, h, r) {
            var rr = Math.max(0, Math.min(r, Math.min(w, h) / 2))
            ctx.moveTo(x + rr, y)
            ctx.arcTo(x + w, y,     x + w, y + h, rr)
            ctx.arcTo(x + w, y + h, x,     y + h, rr)
            ctx.arcTo(x,     y + h, x,     y,     rr)
            ctx.arcTo(x,     y,     x + w, y,     rr)
            ctx.closePath()
        }

        function drawAnimations(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.74, cy = h * 0.50

            // 1. Dual harmonic flowing kinematic ribbon curves
            for (var ki = 0; ki < 2; ki++) {
                ctx.beginPath()
                var yOffset = (ki === 0 ? -12 : 12)
                var kPhase = p * (ki === 0 ? 1.0 : -1.0) + (ki * Math.PI)
                var kAmp = (14 + pulseVal * 16) * root.intensity
                var startX = w * 0.05
                var endX = w * 0.95

                ctx.moveTo(startX, cy + yOffset + Math.sin(kPhase) * kAmp)
                for (var x = startX; x <= endX; x += 6) {
                    var xNorm = (x - startX) / (endX - startX)
                    var envelope = Math.sin(xNorm * Math.PI)
                    var y = cy + yOffset + Math.sin(x * 0.016 + kPhase) * (kAmp * envelope)
                                         + Math.cos(x * 0.008 - kPhase) * (kAmp * 0.4 * envelope)
                    ctx.lineTo(x, y)
                }

                var kGrad = ctx.createLinearGradient(startX, 0, endX, 0)
                var ka = (0.45 - ki * 0.12 + pulseVal * 0.25) * root.intensity
                kGrad.addColorStop(0, Qt.rgba(r, g, b, 0.0))
                kGrad.addColorStop(0.3, Qt.rgba(r, g, b, ka))
                kGrad.addColorStop(0.7, Qt.rgba(0.9, 0.4, 0.95, ka * 0.9))
                kGrad.addColorStop(1, Qt.rgba(r, g, b, 0.0))

                ctx.strokeStyle = kGrad
                ctx.lineWidth = ki === 0 ? 2.4 : 1.4
                ctx.stroke()
            }

            // 2. Continuous living morphing geometric shape
            var baseSize = 28 + pulseVal * 6
            var shapeW = baseSize * (1.0 + Math.sin(p * 2) * 0.25)
            var shapeH = baseSize * (1.0 - Math.sin(p * 2) * 0.20)
            var shapeRadius = (shapeH / 2) * (0.4 + 0.6 * (0.5 + 0.5 * Math.cos(p)))

            ctx.save()
            ctx.translate(cx, cy)
            ctx.rotate(Math.sin(p) * 0.25)

            // Outer kinetic halo
            ctx.beginPath()
            roundRectPath(ctx, -shapeW * 0.7, -shapeH * 0.7, shapeW * 1.4, shapeH * 1.4, shapeRadius * 1.3)
            ctx.strokeStyle = Qt.rgba(r, g, b, (0.28 + pulseVal * 0.2) * root.intensity)
            ctx.lineWidth = 1.4
            ctx.stroke()

            // Main morphing shape core
            ctx.beginPath()
            roundRectPath(ctx, -shapeW / 2, -shapeH / 2, shapeW, shapeH, shapeRadius)
            var sGrad = ctx.createLinearGradient(-shapeW / 2, -shapeH / 2, shapeW / 2, shapeH / 2)
            sGrad.addColorStop(0, Qt.rgba(r, g, b, (0.45 + pulseVal * 0.3) * root.intensity))
            sGrad.addColorStop(1, Qt.rgba(0.7, 0.3, 0.9, (0.15 + pulseVal * 0.1) * root.intensity))
            ctx.fillStyle = sGrad
            ctx.fill()
            ctx.strokeStyle = Qt.rgba(r, g, b, 0.85 * root.intensity)
            ctx.lineWidth = 1.8
            ctx.stroke()

            ctx.restore()

            // 3. Desynchronized orbital pendulum nodes
            var orbitCount = 4
            for (var oi = 0; oi < orbitCount; oi++) {
                var orbSpeed = (oi % 2 === 0 ? 1 : -1) * (1.0 + oi * 0.3)
                var orbPhase = p * orbSpeed + (oi * Math.PI / 2)
                var orbRadX = 42 + oi * 8
                var orbRadY = 22 + oi * 5
                var ox = cx + Math.cos(orbPhase) * orbRadX
                var oy = cy + Math.sin(orbPhase) * orbRadY

                // Orbital trail
                ctx.beginPath()
                ctx.ellipse(cx, cy, orbRadX, orbRadY, 0, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(r, g, b, (0.12 - oi * 0.02) * root.intensity)
                ctx.lineWidth = 1.0
                ctx.stroke()

                // Orbital node with velocity beacon
                ctx.beginPath()
                ctx.arc(ox, oy, 2.4 + (oi === 0 ? pulseVal * 1.5 : 0), 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, (0.85 - oi * 0.1) * root.intensity)
                ctx.fill()

                // Radial connector to core
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(ox, oy)
                ctx.strokeStyle = Qt.rgba(r, g, b, (0.18 - oi * 0.03) * root.intensity)
                ctx.lineWidth = 0.8
                ctx.stroke()
            }

            // 4. Central Zen Kinetic Core
            ctx.beginPath()
            ctx.arc(cx, cy, 4.5 + pulseVal * 2.5, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.95 * root.intensity)
            ctx.fill()
        }

        // ────────────────────────────────────────────────────────────────────
        // 1. GENERAL & BEHAVIOR: Flowing adaptive ribbons & morphing nodes
        // ────────────────────────────────────────────────────────────────────
        function drawGeneral(ctx, w, h, p, r, g, b, pulseVal) {
            var waveCount = 3
            for (var wi = 0; wi < waveCount; wi++) {
                ctx.beginPath()
                var yBase = h * (0.42 + wi * 0.18)
                var freq = 0.011 + wi * 0.004
                var amp = (10 + wi * 6 + pulseVal * 12) * root.intensity
                var wPhase = p + wi * 1.57

                ctx.moveTo(0, yBase + Math.sin(wPhase) * amp)
                for (var x = 0; x <= w; x += 6) {
                    var y = yBase + Math.sin(x * freq + wPhase) * amp
                                  + Math.cos(x * freq * 0.5 - wPhase) * (amp * 0.35)
                    ctx.lineTo(x, y)
                }

                var grad = ctx.createLinearGradient(0, 0, w, 0)
                var a = (0.32 - wi * 0.07 + pulseVal * 0.2) * root.intensity
                grad.addColorStop(0, Qt.rgba(r, g, b, 0.0))
                grad.addColorStop(0.35, Qt.rgba(r, g, b, a))
                grad.addColorStop(0.75, Qt.rgba(r, g, b, a * 0.7))
                grad.addColorStop(1, Qt.rgba(r, g, b, 0.0))

                ctx.strokeStyle = grad
                ctx.lineWidth = wi === 0 ? 2.2 : 1.2
                ctx.stroke()
            }

            // Adaptive morphing nodal vertices
            var cx = w * 0.76, cy = h * 0.50
            for (var ni = 0; ni < 4; ni++) {
                var angle = p + (ni * Math.PI / 2)
                var dist = 24 + Math.sin(p * 2 + ni) * 6
                var nx = cx + Math.cos(angle) * dist
                var ny = cy + Math.sin(angle) * (dist * 0.6)

                ctx.beginPath()
                ctx.arc(nx, ny, 2.5 + (ni === 0 ? 1.5 : 0), 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, 0.65 * root.intensity)
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(nx, ny)
                ctx.strokeStyle = Qt.rgba(r, g, b, 0.22 * root.intensity)
                ctx.lineWidth = 1.0
                ctx.stroke()
            }
        }

        // ────────────────────────────────────────────────────────────────────
        // 2. APPEARANCE: Chromatic spectral dispersion prism & faceted hue rings
        // ────────────────────────────────────────────────────────────────────
        function drawAppearance(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.75, cy = h * 0.50
            var prismR = Math.min(w, h) * 0.38

            // Concentric faceted hue rings with smooth continuous rotation
            var ringCount = 3
            for (var ri = 0; ri < ringCount; ri++) {
                var rad = prismR * (0.45 + ri * 0.28)
                var rot = (ri % 2 === 0 ? 1 : -1) * p * 0.5 + (ri * 0.8)

                ctx.beginPath()
                ctx.arc(cx, cy, rad, rot, rot + Math.PI * 1.55, false)
                var rGrad = ctx.createLinearGradient(cx - rad, cy - rad, cx + rad, cy + rad)
                rGrad.addColorStop(0, Qt.rgba(r, g, b, (0.55 - ri * 0.12) * root.intensity))
                rGrad.addColorStop(0.5, Qt.rgba(0.9, 0.4, 0.8, (0.4 - ri * 0.1) * root.intensity))
                rGrad.addColorStop(1, Qt.rgba(0.2, 0.8, 0.9, 0.05))
                ctx.strokeStyle = rGrad
                ctx.lineWidth = 2.0 - ri * 0.4
                ctx.stroke()
            }

            // Spectral dispersion prism ray
            var rayColors = ["#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#89b4fa", "#cba6f7"]
            for (var bi = 0; bi < rayColors.length; bi++) {
                var rayAngle = -0.35 + (bi * 0.14) + Math.sin(p) * 0.05
                var rayLen = 55 + bi * 4
                var rx = cx + Math.cos(rayAngle) * rayLen
                var ry = cy + Math.sin(rayAngle) * rayLen

                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(rx, ry)
                ctx.strokeStyle = rayColors[bi]
                ctx.globalAlpha = 0.55 * root.intensity
                ctx.lineWidth = 1.6
                ctx.stroke()
                ctx.globalAlpha = 1.0

                // Spectral tip beacon
                ctx.beginPath()
                ctx.arc(rx, ry, 1.8, 0, Math.PI * 2)
                ctx.fillStyle = rayColors[bi]
                ctx.fill()
            }

            // Central crystal core
            ctx.beginPath()
            ctx.arc(cx, cy, 4 + pulseVal * 2, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.9)
            ctx.fill()
        }

        // ────────────────────────────────────────────────────────────────────
        // 3. AI & INTELLIGENCE: Synaptic neural brain core & thought streams
        // ────────────────────────────────────────────────────────────────────
        function drawAi(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.74, cy = h * 0.50
            var nodes = [
                { dx: 0, dy: 0, rad: 5.5, core: true },
                { dx: -38, dy: -22, rad: 3.2 },
                { dx: -24, dy: 28, rad: 3.0 },
                { dx: 36, dy: -26, rad: 3.4 },
                { dx: 42, dy: 20, rad: 3.2 },
                { dx: -55, dy: 6, rad: 2.4 },
                { dx: 60, dy: -2, rad: 2.6 },
                { dx: 12, dy: -38, rad: 2.8 },
                { dx: 8, dy: 38, rad: 2.8 }
            ]

            // Synaptic axon links with traveling pulses
            for (var i = 0; i < nodes.length; i++) {
                for (var j = i + 1; j < nodes.length; j++) {
                    var n1 = nodes[i], n2 = nodes[j]
                    var dist = Math.hypot(n1.dx - n2.dx, n1.dy - n2.dy)
                    if (dist < 55) {
                        var x1 = cx + n1.dx + Math.sin(p + i) * 3
                        var y1 = cy + n1.dy + Math.cos(p + i) * 2
                        var x2 = cx + n2.dx + Math.sin(p + j) * 3
                        var y2 = cy + n2.dy + Math.cos(p + j) * 2

                        ctx.beginPath()
                        ctx.moveTo(x1, y1)
                        ctx.lineTo(x2, y2)
                        ctx.strokeStyle = Qt.rgba(r, g, b, (0.28 - (dist / 160)) * root.intensity)
                        ctx.lineWidth = 1.1
                        ctx.stroke()

                        // Synaptic spark traveling along axon
                        var tPulse = (p * 2 + i * 0.7 + j * 1.1) % (Math.PI * 2)
                        var sparkRatio = tPulse / (Math.PI * 2)
                        var sx = x1 + (x2 - x1) * sparkRatio
                        var sy = y1 + (y2 - y1) * sparkRatio
                        var sAlpha = Math.sin(sparkRatio * Math.PI) * 0.75 * root.intensity

                        ctx.beginPath()
                        ctx.arc(sx, sy, 1.5, 0, Math.PI * 2)
                        ctx.fillStyle = Qt.rgba(r, g, b, sAlpha)
                        ctx.fill()
                    }
                }
            }

            // Synapse node clusters
            for (var k = 0; k < nodes.length; k++) {
                var nd = nodes[k]
                var nx = cx + nd.dx + Math.sin(p + k) * 3
                var ny = cy + nd.dy + Math.cos(p + k) * 2
                var nAlpha = (nd.core ? 0.9 : 0.65) * root.intensity

                ctx.beginPath()
                ctx.arc(nx, ny, nd.rad + (nd.core ? pulseVal * 2.5 : 0), 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, nAlpha)
                ctx.fill()

                if (nd.core) {
                    ctx.beginPath()
                    ctx.arc(nx, ny, nd.rad * 2.2 + Math.sin(p * 2) * 2, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(r, g, b, 0.35 * root.intensity)
                    ctx.lineWidth = 1.2
                    ctx.stroke()
                }
            }
        }

        // ────────────────────────────────────────────────────────────────────
        // 4. PRIVACY: Layered protective veil & disappearing/revealing particles
        // ────────────────────────────────────────────────────────────────────
        function drawPrivacy(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.75, cy = h * 0.50

            // Concentric protective privacy veils
            for (var vi = 0; vi < 3; vi++) {
                var vRadX = 48 + vi * 18
                var vRadY = 28 + vi * 11
                var vRot = Math.sin(p + vi) * 0.12

                ctx.save()
                ctx.translate(cx, cy)
                ctx.rotate(vRot)
                ctx.beginPath()
                ctx.ellipse(0, 0, vRadX, vRadY, 0, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(r, g, b, (0.42 - vi * 0.11) * root.intensity)
                ctx.lineWidth = 1.4
                ctx.setLineDash([4 + vi * 2, 4 + vi])
                ctx.stroke()
                ctx.restore()
            }

            // Obscured / redacted particle stream that fades in and out smoothly
            for (var pi = 0; pi < 10; pi++) {
                var pxNorm = (pi / 10.0 + p / (Math.PI * 2)) % 1.0
                var px = cx - 60 + pxNorm * 120
                var py = cy + Math.sin(pxNorm * Math.PI * 4 + pi) * 16
                var pAlpha = Math.sin(pxNorm * Math.PI) * 0.7 * root.intensity

                ctx.beginPath()
                ctx.arc(px, py, 2.0, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, pAlpha)
                ctx.fill()
            }

            // Central protective iris
            ctx.beginPath()
            ctx.arc(cx, cy, 6 + pulseVal * 2, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.85 * root.intensity)
            ctx.fill()
        }

        // ────────────────────────────────────────────────────────────────────
        // 5. SECURITY: Hexagonal cyber-barrier & fortress shield plates
        // ────────────────────────────────────────────────────────────────────
        function drawSecurity(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.75, cy = h * 0.50
            var hexSize = 28 + pulseVal * 4

            // Hexagonal shield contours
            for (var hi = 0; hi < 3; hi++) {
                var s = hexSize + hi * 16
                ctx.beginPath()
                for (var a = 0; a < 6; a++) {
                    var angle = (a * Math.PI / 3) + (hi % 2 === 0 ? p * 0.2 : -p * 0.2)
                    var hx = cx + Math.cos(angle) * s
                    var hy = cy + Math.sin(angle) * (s * 0.85)
                    if (a === 0) ctx.moveTo(hx, hy); else ctx.lineTo(hx, hy)
                }
                ctx.closePath()
                ctx.strokeStyle = Qt.rgba(r, g, b, (0.5 - hi * 0.12) * root.intensity)
                ctx.lineWidth = 1.6
                ctx.stroke()
            }

            // Protective energy vertices
            for (var a2 = 0; a2 < 6; a2++) {
                var angle2 = (a2 * Math.PI / 3) + p * 0.2
                var vx = cx + Math.cos(angle2) * hexSize
                var vy = cy + Math.sin(angle2) * (hexSize * 0.85)
                ctx.beginPath()
                ctx.arc(vx, vy, 2.8, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, 0.8 * root.intensity)
                ctx.fill()
            }

            // Central shield core
            ctx.beginPath()
            ctx.arc(cx, cy, 4.5, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.9 * root.intensity)
            ctx.fill()
        }

        // ────────────────────────────────────────────────────────────────────
        // 6. CLIPBOARD: Flowing snippet cards & archival transformation stack
        // ────────────────────────────────────────────────────────────────────
        function drawClipboard(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.74, cy = h * 0.50

            // Floating snippet cards ascending in smooth stack
            var cardCount = 4
            for (var ci = 0; ci < cardCount; ci++) {
                var t = (ci / cardCount + p / (Math.PI * 2)) % 1.0
                var cardX = cx - 35 + t * 70
                var cardY = cy + (1.0 - t) * 36 - 18
                var cardW = 38
                var cardH = 22
                var cAlpha = Math.sin(t * Math.PI) * 0.65 * root.intensity

                ctx.save()
                ctx.translate(cardX, cardY)
                ctx.rotate((t - 0.5) * 0.2)

                ctx.beginPath()
                roundRectPath(ctx, -cardW / 2, -cardH / 2, cardW, cardH, 4)
                ctx.fillStyle = Qt.rgba(r, g, b, cAlpha * 0.25)
                ctx.fill()
                ctx.strokeStyle = Qt.rgba(r, g, b, cAlpha)
                ctx.lineWidth = 1.2
                ctx.stroke()

                // Text line placeholders on card
                ctx.beginPath()
                ctx.moveTo(-cardW / 2 + 5, -3)
                ctx.lineTo(cardW / 2 - 8, -3)
                ctx.moveTo(-cardW / 2 + 5, 3)
                ctx.lineTo(cardW / 2 - 14, 3)
                ctx.strokeStyle = Qt.rgba(r, g, b, cAlpha * 0.7)
                ctx.lineWidth = 1.0
                ctx.stroke()

                ctx.restore()
            }
        }

        // ────────────────────────────────────────────────────────────────────
        // 7. APPLICATIONS: Interconnected modular application node constellation
        // ────────────────────────────────────────────────────────────────────
        function drawApplications(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.74, cy = h * 0.50
            var appNodes = [
                { ox: 0, oy: 0, s: 18, main: true },
                { ox: -40, oy: -20, s: 13 },
                { ox: 38, oy: -22, s: 14 },
                { ox: -30, oy: 25, s: 12 },
                { ox: 34, oy: 22, s: 13 },
                { ox: 0, oy: -36, s: 11 },
                { ox: 0, oy: 34, s: 11 }
            ]

            // Conduits between app tiles
            for (var i = 0; i < appNodes.length; i++) {
                var an1 = appNodes[i]
                var x1 = cx + an1.ox + Math.sin(p + i) * 2
                var y1 = cy + an1.oy + Math.cos(p + i) * 2

                if (!an1.main) {
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.lineTo(x1, y1)
                    ctx.strokeStyle = Qt.rgba(r, g, b, 0.22 * root.intensity)
                    ctx.lineWidth = 1.0
                    ctx.stroke()
                }

                // App icon tile rounded rect
                ctx.beginPath()
                roundRectPath(ctx, x1 - an1.s / 2, y1 - an1.s / 2, an1.s, an1.s, 3)
                ctx.fillStyle = Qt.rgba(r, g, b, (an1.main ? 0.35 : 0.15) * root.intensity)
                ctx.fill()
                ctx.strokeStyle = Qt.rgba(r, g, b, (an1.main ? 0.75 : 0.45) * root.intensity)
                ctx.lineWidth = 1.2
                ctx.stroke()
            }
        }

        // ────────────────────────────────────────────────────────────────────
        // 8. SYSTEM & NIXOS: Declarative crystalline snowflake & generation strata
        // ────────────────────────────────────────────────────────────────────
        function drawSystem(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.75, cy = h * 0.50
            var flakeR = Math.min(w, h) * 0.36

            // Concentric immutable generation strata rings
            for (var si = 1; si <= 3; si++) {
                var sRad = flakeR * (si / 3.0)
                ctx.beginPath()
                ctx.arc(cx, cy, sRad, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(r, g, b, (0.28 - si * 0.06) * root.intensity)
                ctx.lineWidth = 1.0
                ctx.setLineDash([2 + si, 4])
                ctx.stroke()
                ctx.setLineDash([])
            }

            // 6-fold declarative snowflake arms
            for (var arm = 0; arm < 6; arm++) {
                var armAngle = (arm * Math.PI / 3) + p * 0.15
                var ax = cx + Math.cos(armAngle) * flakeR
                var ay = cy + Math.sin(armAngle) * flakeR

                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(ax, ay)
                ctx.strokeStyle = Qt.rgba(r, g, b, 0.65 * root.intensity)
                ctx.lineWidth = 1.8
                ctx.stroke()

                // Fractal branchlets (lambda λ facets)
                for (var bi = 1; bi <= 2; bi++) {
                    var bDist = flakeR * (bi * 0.36)
                    var bx = cx + Math.cos(armAngle) * bDist
                    var by = cy + Math.sin(armAngle) * bDist
                    var bLen = 8

                    var bAngle1 = armAngle + Math.PI / 4
                    var bAngle2 = armAngle - Math.PI / 4

                    ctx.beginPath()
                    ctx.moveTo(bx, by)
                    ctx.lineTo(bx + Math.cos(bAngle1) * bLen, by + Math.sin(bAngle1) * bLen)
                    ctx.moveTo(bx, by)
                    ctx.lineTo(bx + Math.cos(bAngle2) * bLen, by + Math.sin(bAngle2) * bLen)
                    ctx.strokeStyle = Qt.rgba(r, g, b, 0.45 * root.intensity)
                    ctx.lineWidth = 1.2
                    ctx.stroke()
                }

                // Arm vertex node
                ctx.beginPath()
                ctx.arc(ax, ay, 2.4, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, 0.85 * root.intensity)
                ctx.fill()
            }

            // Central declarative core
            ctx.beginPath()
            ctx.arc(cx, cy, 5 + pulseVal * 2, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.95 * root.intensity)
            ctx.fill()
        }

        // ────────────────────────────────────────────────────────────────────
        // 9. OVERVIEW: Harmonic vital heartbeat pulse & living resonance rings
        // ────────────────────────────────────────────────────────────────────
        function drawOverview(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.74, cy = h * 0.50

            // Concentric vital pulse resonance rings
            for (var ri = 0; ri < 3; ri++) {
                var rPhase = (p + ri * (Math.PI * 2 / 3)) % (Math.PI * 2)
                var rNorm = rPhase / (Math.PI * 2)
                var rad = 12 + rNorm * 44
                var rAlpha = (1.0 - rNorm) * 0.55 * root.intensity

                ctx.beginPath()
                ctx.arc(cx, cy, rad, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(r, g, b, rAlpha)
                ctx.lineWidth = 1.5
                ctx.stroke()
            }

            // Living ECG / Telemetry pulse stream
            ctx.beginPath()
            var ecgW = w * 0.75
            var ecgY = h * 0.52
            ctx.moveTo(0, ecgY)
            for (var ex = 0; ex <= ecgW; ex += 4) {
                var xRel = (ex / ecgW + p / (Math.PI * 2)) % 1.0
                var spike = 0
                if (xRel > 0.45 && xRel < 0.55) {
                    var sT = (xRel - 0.45) / 0.10
                    spike = (Math.sin(sT * Math.PI * 3) * 16)
                }
                var ey = ecgY + spike + Math.sin(ex * 0.04 + p) * 3
                ctx.lineTo(ex, ey)
            }
            var ecgGrad = ctx.createLinearGradient(0, 0, ecgW, 0)
            ecgGrad.addColorStop(0, Qt.rgba(r, g, b, 0.0))
            ecgGrad.addColorStop(0.5, Qt.rgba(r, g, b, 0.6 * root.intensity))
            ecgGrad.addColorStop(1, Qt.rgba(r, g, b, 0.0))
            ctx.strokeStyle = ecgGrad
            ctx.lineWidth = 1.8
            ctx.stroke()

            // Heartbeat core
            ctx.beginPath()
            ctx.arc(cx, cy, 4.5 + pulseVal * 3, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.9 * root.intensity)
            ctx.fill()
        }

        // ────────────────────────────────────────────────────────────────────
        // 10. WALLPAPER: Multi-layer mountain/horizon depth contours & celestial orb
        // ────────────────────────────────────────────────────────────────────
        function drawWallpaper(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.78, cy = h * 0.38
            var sunR = 18 + pulseVal * 2

            // Luminous celestial sun/moon orb
            ctx.beginPath()
            ctx.arc(cx, cy, sunR, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.35 * root.intensity)
            ctx.fill()
            ctx.strokeStyle = Qt.rgba(r, g, b, 0.8 * root.intensity)
            ctx.lineWidth = 1.6
            ctx.stroke()

            // Mountain / horizon layer contours with parallax depth sway
            for (var mi = 0; mi < 3; mi++) {
                ctx.beginPath()
                var mYBase = h * (0.55 + mi * 0.14)
                var mFreq = 0.015 + mi * 0.008
                var mPhase = Math.sin(p) * (0.2 + mi * 0.2) + mi * 1.2
                var mAmp = 10 + mi * 5

                ctx.moveTo(0, h)
                ctx.lineTo(0, mYBase + Math.sin(mPhase) * mAmp)
                for (var x = 0; x <= w; x += 8) {
                    var y = mYBase + Math.sin(x * mFreq + mPhase) * mAmp
                                  + Math.cos(x * mFreq * 0.5 - mPhase) * (mAmp * 0.4)
                    ctx.lineTo(x, y)
                }
                ctx.lineTo(w, h)
                ctx.closePath()

                var mGrad = ctx.createLinearGradient(0, mYBase - mAmp, 0, h)
                var ma = (0.25 - mi * 0.06) * root.intensity
                mGrad.addColorStop(0, Qt.rgba(r, g, b, ma))
                mGrad.addColorStop(1, Qt.rgba(r, g, b, 0.02))
                ctx.fillStyle = mGrad
                ctx.fill()
                ctx.strokeStyle = Qt.rgba(r, g, b, (0.45 - mi * 0.1) * root.intensity)
                ctx.lineWidth = 1.2
                ctx.stroke()
            }
        }

        // ────────────────────────────────────────────────────────────────────
        // 11. DESKTOP & CAVA: Kinetic audio spectrum visualizer & widget blueprint
        // ────────────────────────────────────────────────────────────────────
        function drawDesktop(ctx, w, h, p, r, g, b, pulseVal) {
            var barCount = 18
            var startX = w * 0.42
            var totalW = w * 0.54
            var barW = totalW / barCount - 3
            var baseH = h * 0.82

            for (var bi = 0; bi < barCount; bi++) {
                var bx = startX + bi * (barW + 3)
                var bH = (12 + Math.sin(p * 2 + bi * 0.45) * 16 + Math.cos(p + bi * 0.3) * 10 + pulseVal * 20) * root.intensity
                bH = Math.max(4, Math.min(h * 0.65, bH))
                var by = baseH - bH

                ctx.beginPath()
                roundRectPath(ctx, bx, by, barW, bH, 2)
                var bGrad = ctx.createLinearGradient(bx, by, bx, baseH)
                bGrad.addColorStop(0, Qt.rgba(r, g, b, 0.85 * root.intensity))
                bGrad.addColorStop(1, Qt.rgba(r, g, b, 0.15 * root.intensity))
                ctx.fillStyle = bGrad
                ctx.fill()

                // Peak cap dot
                ctx.beginPath()
                ctx.arc(bx + barW / 2, by - 3, 1.5, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, 0.9 * root.intensity)
                ctx.fill()
            }
        }

        // ────────────────────────────────────────────────────────────────────
        // 12. DYNAMIC ISLAND: Morphing notch capsule & acoustic notch aura
        // ────────────────────────────────────────────────────────────────────
        function drawIsland(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.74, cy = h * 0.48
            var capW = 75 + Math.sin(p * 2) * 12 + pulseVal * 25
            var capH = 26 + Math.sin(p * 2) * 4 + pulseVal * 6

            // Dynamic notch outer acoustic glow
            ctx.beginPath()
            roundRectPath(ctx, cx - capW / 2 - 8, cy - capH / 2 - 6, capW + 16, capH + 12, (capH + 12) / 2)
            ctx.strokeStyle = Qt.rgba(r, g, b, (0.28 + pulseVal * 0.2) * root.intensity)
            ctx.lineWidth = 1.5
            ctx.stroke()

            // Main Island Capsule
            ctx.beginPath()
            roundRectPath(ctx, cx - capW / 2, cy - capH / 2, capW, capH, capH / 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.32 * root.intensity)
            ctx.fill()
            ctx.strokeStyle = Qt.rgba(r, g, b, 0.85 * root.intensity)
            ctx.lineWidth = 1.6
            ctx.stroke()

            // Notch mini wave bars
            for (var i = -2; i <= 2; i++) {
                var wh = 6 + Math.sin(p * 3 + i) * 5
                ctx.beginPath()
                ctx.moveTo(cx + i * 8, cy - wh)
                ctx.lineTo(cx + i * 8, cy + wh)
                ctx.strokeStyle = Qt.rgba(r, g, b, 0.9 * root.intensity)
                ctx.lineWidth = 1.6
                ctx.stroke()
            }
        }

        // ────────────────────────────────────────────────────────────────────
        // 13. NOTIFICATIONS: Concentric acoustic bell chime ripples & focal beacon
        // ────────────────────────────────────────────────────────────────────
        function drawNotifications(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.75, cy = h * 0.50

            // Concentric bell chime ripples
            for (var ci = 0; ci < 3; ci++) {
                var cPhase = (p + ci * (Math.PI * 2 / 3)) % (Math.PI * 2)
                var cNorm = cPhase / (Math.PI * 2)
                var rad = 8 + cNorm * 46
                var cAlpha = (1.0 - cNorm) * 0.6 * root.intensity

                ctx.beginPath()
                ctx.arc(cx, cy, rad, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(r, g, b, cAlpha)
                ctx.lineWidth = 1.4
                ctx.stroke()
            }

            // Floating notification particle beacons
            for (var bi = 0; bi < 6; bi++) {
                var bAngle = (bi * Math.PI / 3) + p * 0.3
                var bDist = 28 + Math.sin(p * 2 + bi) * 6
                var bx = cx + Math.cos(bAngle) * bDist
                var by = cy + Math.sin(bAngle) * bDist

                ctx.beginPath()
                ctx.arc(bx, by, 2.2, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, 0.75 * root.intensity)
                ctx.fill()
            }

            // Focal bell beacon
            ctx.beginPath()
            ctx.arc(cx, cy, 4.5 + pulseVal * 2, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.95 * root.intensity)
            ctx.fill()
        }

        // ────────────────────────────────────────────────────────────────────
        // 14. WEATHER: Isobar meteorological currents & celestial sun/cloud
        // ────────────────────────────────────────────────────────────────────
        function drawWeather(ctx, w, h, p, r, g, b, pulseVal) {
            // Isobar aerodynamic wind currents
            for (var wi = 0; wi < 3; wi++) {
                ctx.beginPath()
                var yBase = h * (0.35 + wi * 0.2)
                var freq = 0.012
                var amp = 8 + wi * 4
                var wPhase = p + wi * 1.4

                ctx.moveTo(0, yBase)
                for (var x = 0; x <= w; x += 8) {
                    var y = yBase + Math.sin(x * freq + wPhase) * amp
                    ctx.lineTo(x, y)
                }

                ctx.strokeStyle = Qt.rgba(r, g, b, (0.35 - wi * 0.08) * root.intensity)
                ctx.lineWidth = 1.2
                ctx.stroke()
            }

            // Celestial radiant sun orb
            var cx = w * 0.74, cy = h * 0.44
            var sRad = 16 + pulseVal * 2
            ctx.beginPath()
            ctx.arc(cx, cy, sRad, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.4 * root.intensity)
            ctx.fill()
            ctx.strokeStyle = Qt.rgba(r, g, b, 0.85 * root.intensity)
            ctx.lineWidth = 1.6
            ctx.stroke()

            // Cloud contour
            ctx.beginPath()
            ctx.arc(cx - 10, cy + 8, 12, Math.PI * 0.7, Math.PI * 1.8)
            ctx.arc(cx + 6, cy + 2, 14, Math.PI * 1.1, Math.PI * 2.0)
            ctx.arc(cx + 18, cy + 10, 10, Math.PI * 1.6, Math.PI * 0.3)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(r, g, b, 0.25 * root.intensity)
            ctx.fill()
            ctx.strokeStyle = Qt.rgba(r, g, b, 0.75 * root.intensity)
            ctx.lineWidth = 1.4
            ctx.stroke()
        }

        // ────────────────────────────────────────────────────────────────────
        // 15. DISPLAY: Multi-monitor perspective matrix & beam sweep
        // ────────────────────────────────────────────────────────────────────
        function drawDisplay(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.74, cy = h * 0.50

            // Primary display frame
            var mw = 68, mh = 42
            ctx.beginPath()
            roundRectPath(ctx, cx - mw / 2, cy - mh / 2, mw, mh, 4)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.15 * root.intensity)
            ctx.fill()
            ctx.strokeStyle = Qt.rgba(r, g, b, 0.85 * root.intensity)
            ctx.lineWidth = 1.6
            ctx.stroke()

            // Display stand
            ctx.beginPath()
            ctx.moveTo(cx - 8, cy + mh / 2)
            ctx.lineTo(cx + 8, cy + mh / 2)
            ctx.lineTo(cx + 12, cy + mh / 2 + 10)
            ctx.lineTo(cx - 12, cy + mh / 2 + 10)
            ctx.closePath()
            ctx.strokeStyle = Qt.rgba(r, g, b, 0.5 * root.intensity)
            ctx.lineWidth = 1.2
            ctx.stroke()

            // High-Hz scanline beam sweep
            var beamY = cy - mh / 2 + ((p / (Math.PI * 2)) * mh)
            ctx.beginPath()
            ctx.moveTo(cx - mw / 2 + 2, beamY)
            ctx.lineTo(cx + mw / 2 - 2, beamY)
            ctx.strokeStyle = Qt.rgba(r, g, b, 0.9 * root.intensity)
            ctx.lineWidth = 1.8
            ctx.stroke()
        }

        // ────────────────────────────────────────────────────────────────────
        // 16. DEVICES: Tactile switch matrix vectors & precision cursor radar
        // ────────────────────────────────────────────────────────────────────
        function drawDevices(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.75, cy = h * 0.50

            // Precision crosshair radar circles
            for (var ri = 1; ri <= 3; ri++) {
                ctx.beginPath()
                ctx.arc(cx, cy, ri * 15, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(r, g, b, (0.38 - ri * 0.09) * root.intensity)
                ctx.lineWidth = 1.0
                ctx.stroke()
            }

            // Kinetic cursor trail vector
            var curX = cx + Math.cos(p) * 26
            var curY = cy + Math.sin(p * 2) * 14

            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.lineTo(curX, curY)
            ctx.strokeStyle = Qt.rgba(r, g, b, 0.3 * root.intensity)
            ctx.lineWidth = 1.0
            ctx.stroke()

            // Cursor tip
            ctx.beginPath()
            ctx.arc(curX, curY, 3.2 + pulseVal * 2, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.9 * root.intensity)
            ctx.fill()
        }

        // ────────────────────────────────────────────────────────────────────
        // 17. NETWORK & VPN: Encrypted tunnel vortex & connected mesh nodes
        // ────────────────────────────────────────────────────────────────────
        function drawNetwork(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.74, cy = h * 0.50

            // 3D Encrypted tunnel vortex rings
            for (var ti = 0; ti < 4; ti++) {
                var tPhase = (p + ti * (Math.PI * 2 / 4)) % (Math.PI * 2)
                var tNorm = tPhase / (Math.PI * 2)
                var radX = (tNorm * 52)
                var radY = radX * 0.6
                var tAlpha = (1.0 - tNorm) * 0.55 * root.intensity

                ctx.beginPath()
                ctx.ellipse(cx, cy, Math.max(1, radX), Math.max(1, radY), 0, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(r, g, b, tAlpha)
                ctx.lineWidth = 1.5
                ctx.stroke()
            }

            // Encrypted packet pulse streams
            for (var pi = 0; pi < 6; pi++) {
                var pAngle = (pi * Math.PI / 3) + p * 0.4
                var pDist = 34 + Math.sin(p * 3 + pi) * 6
                var px = cx + Math.cos(pAngle) * pDist
                var py = cy + Math.sin(pAngle) * (pDist * 0.6)

                ctx.beginPath()
                ctx.arc(px, py, 2.2, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, 0.85 * root.intensity)
                ctx.fill()
            }

            // Secure tunnel core
            ctx.beginPath()
            ctx.arc(cx, cy, 4.0, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.95 * root.intensity)
            ctx.fill()
        }

        // ────────────────────────────────────────────────────────────────────
        // 18. KEYRING: Cryptographic vault lattice & concentric tumbler rings
        // ────────────────────────────────────────────────────────────────────
        function drawKeyring(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.74, cy = h * 0.50

            // Concentric tumbler lock gear rings
            for (var gi = 0; gi < 3; gi++) {
                var gRad = 16 + gi * 14
                var gRot = (gi % 2 === 0 ? 1 : -1) * p * 0.4

                ctx.save()
                ctx.translate(cx, cy)
                ctx.rotate(gRot)
                ctx.beginPath()
                ctx.arc(0, 0, gRad, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(r, g, b, (0.45 - gi * 0.1) * root.intensity)
                ctx.lineWidth = 1.4
                ctx.setLineDash([4 + gi * 2, 4])
                ctx.stroke()
                ctx.restore()
            }

            // Key shard vectors
            ctx.beginPath()
            ctx.arc(cx, cy, 4.5 + pulseVal * 2, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(r, g, b, 0.9 * root.intensity)
            ctx.fill()
        }

        // ────────────────────────────────────────────────────────────────────
        // 19. PERSISTENCE: Enduring root crystal veins surviving root wipe
        // ────────────────────────────────────────────────────────────────────
        function drawPersistence(ctx, w, h, p, r, g, b, pulseVal) {
            var cx = w * 0.74, cy = h * 0.35

            // Indestructible btrfs crystal bedrock line
            var bedY = h * 0.65
            ctx.beginPath()
            ctx.moveTo(w * 0.35, bedY)
            ctx.lineTo(w, bedY)
            ctx.strokeStyle = Qt.rgba(r, g, b, 0.65 * root.intensity)
            ctx.lineWidth = 1.8
            ctx.stroke()

            // Enduring root branch pathways anchoring into bedrock
            var roots = [
                { x: cx, y: cy, tx: cx - 28, ty: bedY + 18 },
                { x: cx, y: cy, tx: cx, ty: bedY + 24 },
                { x: cx, y: cy, tx: cx + 32, ty: bedY + 18 }
            ]
            for (var ri = 0; ri < roots.length; ri++) {
                var rt = roots[ri]
                ctx.beginPath()
                ctx.moveTo(rt.x, rt.y)
                var midX = (rt.x + rt.tx) / 2 + Math.sin(p + ri) * 4
                var midY = (rt.y + rt.ty) / 2
                ctx.quadraticCurveTo(midX, midY, rt.tx, rt.ty)
                ctx.strokeStyle = Qt.rgba(r, g, b, 0.5 * root.intensity)
                ctx.lineWidth = 1.4
                ctx.stroke()

                // Anchor node in bedrock
                ctx.beginPath()
                ctx.arc(rt.tx, rt.ty, 2.5, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, 0.85 * root.intensity)
                ctx.fill()
            }

            // Ephemeral floating particles dissolving above bedrock
            for (var ep = 0; ep < 6; ep++) {
                var epX = cx - 35 + ep * 14
                var epY = bedY - 12 - Math.sin(p * 2 + ep) * 14
                var epAlpha = Math.sin(p + ep) * 0.45 * root.intensity

                ctx.beginPath()
                ctx.arc(epX, epY, 1.6, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(r, g, b, epAlpha)
                ctx.fill()
            }
        }

        // ────────────────────────────────────────────────────────────────────
        // 20. SHORTCUTS: Tactile mechanical keycap matrix & chord constellations
        // ────────────────────────────────────────────────────────────────────
        function drawShortcuts(ctx, w, h, p, r, g, b, pulseVal) {
            var startX = w * 0.52, startY = h * 0.28
            var kSize = 16, kGap = 4

            for (var row = 0; row < 3; row++) {
                for (var col = 0; col < 5; col++) {
                    var kx = startX + col * (kSize + kGap) + (row * 3)
                    var ky = startY + row * (kSize + kGap)
                    var isChord = (row === 1 && (col === 1 || col === 3)) || (row === 0 && col === 2)
                    var kActive = isChord && Math.sin(p * 2 + col) > 0

                    ctx.beginPath()
                    roundRectPath(ctx, kx, ky, kSize, kSize, 3)
                    ctx.fillStyle = Qt.rgba(r, g, b, (kActive ? 0.45 : 0.12) * root.intensity)
                    ctx.fill()
                    ctx.strokeStyle = Qt.rgba(r, g, b, (kActive ? 0.9 : 0.4) * root.intensity)
                    ctx.lineWidth = kActive ? 1.5 : 1.0
                    ctx.stroke()
                }
            }
        }
    }
}
